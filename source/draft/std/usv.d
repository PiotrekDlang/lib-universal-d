module draft.std.usv;


enum UsvFormat {Common};

struct UsvDocument
{
	UsvFormat format;
	Node docNode;
	
	string toString()
	{
		string result = "UsvDocument:\n" ;
		foreach (node; docNode.children)
		{
			result ~= node.toString(0, 2);
		}
		return result;
	}
}

struct Attribute
{
	string name;
	string value;
}

struct Node
{
	string nodeName;
	string nodeValue;	
	Attribute[] attributes;
	
	const auto opIndex(size_t idx)
	{
		return children[idx];
	}
	
	void append(Node child)
	{
		children ~= child;
	}
	
	string toString(int level, int spaces)
	{
		import std.range;
		string result = " ".repeat(level*spaces).join;
		result ~= nodeName ~ " = " ~ nodeValue ~ "\n";
		++level;
		foreach (child; children)
		{
			result ~= child.toString(level, spaces);
		}
		return result;
	}
	
	private:

	Node* parent;
	Node[] children;
}

auto parseDocument(string content)
{
	import std.csv;
	import std.string : strip;
	import std.array: split;
	
	UsvDocument doc = {format: UsvFormat.Common, docNode: Node()};
	string[] contextFullPath = [];
	string[] previousPath = [];
	
	// Variable points alternativly to node which was most recently created
	Node * parentNode = null; 
	
	foreach (record; csvReader!(string, Malformed.ignore)(content, ';'))
    {
		auto pathString = record.front.strip;
		
		if (pathString.length == 0 )
		{
			continue; // Empty line
		}
		
		Type type = selectType(pathString);			
		if (type == Type.FullPath || type == Type.RelativePath)
		{
			// process a new path		
			auto currentPath = pathString.split(".");
			
			// extract attributes and remove from the node path info
			Attribute[] attributes = extractAttributes(currentPath);
			
			// update and normalize path info
			if (type == Type.FullPath)
			{
				contextFullPath = currentPath;
			}
			else
			{
				currentPath = contextFullPath ~ currentPath[1..$];
			}
			
			// get value string if available
			record.popFront;
			auto valueString = record.empty ? "" : record.front.strip;
			
			// check how many steps back the common node is located
			auto levels = levelsToCommonNode(currentPath, previousPath);
			
			// checki if top level node has to be created
			if (levels == previousPath.length)
			{
				Node node = {nodeName: currentPath[0], nodeValue: "", parent: null};
				doc.docNode.children ~= node;
				
				// top node added, subsequet node creation has to be aligned
				levels--;
				parentNode = &doc.docNode.children[$-1];
			}
			else
			{
				// go to common node
				for(auto i = 0; i < levels; i++)
				{
					parentNode = parentNode.parent;
				}
			}
			
			// create only nodes which appear after common node
			auto startIdx = previousPath.length - levels;
			foreach(newNodeName; currentPath[startIdx..$])
			{
				Node node = {nodeName: newNodeName, nodeValue: "", parent: parentNode};
				parentNode.children ~= node;
				parentNode = &parentNode.children[$-1];
			}
			
			// only the last node from the path gets the value
			parentNode.nodeValue = valueString;
			
			// save the current path for comparision with the subsequesnt path (line)
			previousPath = currentPath;
		}
    }

    return doc;
}

unittest
{
	import std.stdio;
	
	static struct TestData
	{
		auto usvString = "";
		auto doc = UsvDocument();
	}
	TestData[] testData = [
		{
			usvString: "",
			doc: UsvDocument(),
		},
		{
			usvString: "root;text",
			doc: UsvDocument(UsvFormat.Common, Node("", "", [], null, [Node("root", "text", [], null, [])])),
		},
		{
			usvString: "root;text1\nroot.child;text2",
		},
		{
			usvString: "root;text1
			root.child1.superchild1;text2
			root.child2;remove",
		},
	];
	
	foreach (check; testData)
	{
		auto result = parseDocument(check.usvString);
		writeln(check.usvString, "\n", result);
		//assert(result == check.doc);
	}
}

unittest
{
	import std.stdio;
	string usv = "
			book.header
				.title; Big thing
				.author; \"Riki Tiki\"
			
			book.content
				# chapter 1
				.chapter.paragraph; jeden
				.chapter.paragraph; dwa
				.chapter.paragraph.extra; extra jeden
				.chapter.paragraph; trzy
				.picture.paragraph; pic jeden
				# chapter 2
				.chapter; dwa
				.chapter.paragraph; jeden
				.appendix.chapter.paragraph; appendix jeden
				.chapter; trzy
			book.content.chapter.paragraph
			book.content.chapter
			book.content.chapter.paragraph
				.paragraph id=\"x\"	; \"Hello book.\"
";

	writeln(parseDocument(usv));
}
private:

enum Type {Empty, Comment, FullPath, RelativePath, MetaInfo}

Type selectType(string pathString)
{
	Type type = Type.FullPath;			
	switch (pathString[0])
	{
		case '#': 
			type = Type.Comment;
			break;
		case '.':
			type = Type.RelativePath;
			break;
		default: 
			break;
	}
	return type;
}

Attribute[] extractAttributes(ref string[] path)
{
	import std.string;
	
	Attribute[] attributes;
	auto lastNode = path[$-1];
	auto parts = lastNode.split(" ");
	path[$-1] = parts[0];
	if (parts.length > 0)
	{
		foreach(attributeString; parts[1..$])
		{
			auto attributePair = attributeString.split("=");
			attributes ~= Attribute(attributePair[0], attributePair[1]);
		}
	}
	return attributes;
}

auto levelsToCommonNode(const string[] currentPath, const string[] prevoiusPath)
{
	auto levels = prevoiusPath.length;
	
	foreach(idx,element; prevoiusPath)
	{
		if (idx < (currentPath.length -1))
		{
			if (element == currentPath[idx])
			{
				levels--;
			}
			else
			{
				break;
			}
		}
		else
		{
			// currentPath < prevoiusPath
			break;
		}	
	}
	
	return levels;
}


//compare paths
unittest
{
	import std.stdio;
	static struct TestData
	{
		auto currentPath = [""];
		auto previousPath = [""];
		auto levelsToCommonNode = -1;
	}
	TestData[] testData = [
		{
			previousPath: [],
			currentPath: ["book"],
			levelsToCommonNode: 0,
		},
		{
			previousPath: ["book"],
			currentPath: ["book"],
			levelsToCommonNode: 1,
		},
		{
			previousPath: ["book"],
			currentPath: ["book","chapter"],
			levelsToCommonNode: 0,
		},
		{
			previousPath: ["book","chapter"],
			currentPath: ["book","chapter"],
			levelsToCommonNode: 1,
		},
		{
			previousPath: ["book","chapter"],
			currentPath: ["book",],
			levelsToCommonNode: 2,
		},
		{
			previousPath: ["book"],
			currentPath: ["book","chapter","paragraph"],
			levelsToCommonNode: 0,
		},
		{
			previousPath: ["book", "header", "title"],
			currentPath: ["book", "content", "chapter", "paragraph"],
			levelsToCommonNode: 2,
		},
		{
			previousPath: ["book", "header", "title"],
			currentPath: ["book", "header", ],
			levelsToCommonNode: 2,
		},
	];
	
	foreach (check; testData)
	{
		auto result = levelsToCommonNode(check.currentPath, check.previousPath);
		writeln(check, " = ", result);
		assert (result == check.levelsToCommonNode);
	}
}
