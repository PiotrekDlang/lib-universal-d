module usv3;


/*
 * FIXME change buffer implementation to use an UTF range
 *
 */


struct UsvDocument
{
    // UsvFormat format;
    
    string name	= "";
    Node internalRoot;
    
    // FIXME Implement subsections
    //Node[string] sections;
    
    string toString()
	{
		string result = "UsvDocument:\n" ;
		foreach (node; internalRoot.children)
		{
			result ~= node.toString(0, 2);
		}
		return result;
	}
}

UsvDocument parseUsv(string text)
{
    UsvParser parser;
    return parser.parseUsv(Buffer(text));
}

struct UsvParser
{
    import std.uni;
    import std.algorithm: findSkip, commonPrefix, stripLeft, count, until;
    import std.string: stripRight;
    import std.range;

    enum BlockType
    {
	    Invalid,
	    Empty,
	    Meta, //  #!
	    Comment, // #
	    Node,
	    Unknown,
    }
    
    enum PathType 
    {
        Invalid,
        FullPath, 
        RelativePath
    }
       
    enum Character 
    {
        Dot = '.',
        Colon = ':',
        Space = ' ', 
        Tab = '\t',
        NewLine = '\n',
        Carriage = '\r',
        Hash = '#',
        Quote = '\"',
        SingleQuote = '\'',
        BackSlash = '\\',      
    }

    UsvDocument parseUsv(Buffer buffer)
    {
        /* Grammar draft: 
	     * Document = Block*
	     * 
	     * Block = NodeBlock | EmptyBlock | CommentBlock | MetaBlock
	     * 
	     * NodeBlock =
	     * (NodePath)? name Attribute* ":" value (NewLine | EndOfSteam)
	     *
	     * Comment Block
	     * "#" Comment
	     * 
	     * Meta Block
	     * '#!' MetaInfo
	     * 
	     */
	     
        UsvDocument doc;

        this.currentParentNode = &doc.internalRoot;
        
	    while( !buffer.empty() )
	    {
		    auto block = parseBlock(buffer);
		    
		    switch (block.type)
		    {
		        case BlockType.Node:
		            // append block to the document tree
		            appendNodeBlock(block);
		            break;
		        
		        case BlockType.Comment:    
		        case BlockType.Empty:
		        case BlockType.Meta:
		            break;
		            
                case BlockType.Invalid:
		        case BlockType.Unknown:
        		    // TODO break for now
		           assert(false);
		           
		           
		        default:
		            assert(false);
		    }
		    
	    }
	    return doc;
    }
    

    unittest
    {
        static void addNewLine(ref string str, string line) {str ~= line ~ '\n';}
	    
	    string str1;
	    addNewLine(str1, ` abc.def gh = 13:test `);
	    addNewLine(str1,` b:            12 34`);
	    addNewLine(str1,`   bnode.cnode.dnode x: res1`);
	    addNewLine(str1,``);
	    addNewLine(str1,`   # test`);
	    addNewLine(str1,`.foo attr1="11" attr2 = 22: res2`);
	    addNewLine(str1,`.bar attr01=01 attr02=02 attr03=03 : res3`);
	    addNewLine(str1,`b.two attr77: res4`);
	    addNewLine(str1,`last`);
	    addNewLine(str1,``);
	    
	    Buffer buf1 = Buffer(str1);
	    
        UsvParser parser;
	    auto doc = parser.parseUsv (buf1);

	    assert(doc.internalRoot.children[0].name == "abc");
	    assert(doc.internalRoot.children[0].value == "");
	    assert(doc.internalRoot.children[0].children[0].name== "def");
	    assert(doc.internalRoot.children[0].children[0].value == "test ");
	    
	    
	    assert(doc.internalRoot.children[1].name == "b");
	    assert(doc.internalRoot.children[1].value == "12 34");
        
        auto node = doc.internalRoot.children[2].children[0].children[0].children[1];
	    assert(node.name == "bar");
	    assert(node.value == "res3");
	    
  	    assert(doc.internalRoot.children[4].name == "last");
	    assert(doc.internalRoot.children[4].value == "");

    }
    
    // Context members used for tree creation
    private:   
    string contextFullPath; // the last explicitly provided full path known to the parser
	string previousPath; // the full path of the last added node
	Node * currentParentNode; // reference to the node just processed

    void appendNodeBlock(Block block)
    {
        import std.algorithm;
        import std.range;
        
	    auto currentPath = block.nodePath;
	    
	    assert (currentPath.length);
	    
	    // update and normalize path variables
	    if (block.pathType == PathType.FullPath)
	    {
		    this.contextFullPath = block.nodePath;
	    }
	    else
	    {
		    currentPath = this.contextFullPath ~ currentPath;
	    }
	    
	    // check how many steps back the common parent is located
	    auto levels = levelsToCommonNode(currentPath, this.previousPath);

	    // move to common parent
	    for(auto i = 0; i < levels; i++)
		{
		    this.currentParentNode = currentParentNode.parent;
		}

        // previous parent node level
	    auto prevDepth =  this.previousPath.count('.') + 1;
        if (this.previousPath == "")
        {
            prevDepth = 0;
        }        

	    // create only nodes which appear after common point node
	    auto startIdx = prevDepth - levels;
	    foreach(newname; currentPath.splitter(".").drop(startIdx))
	    {
		    Node node = {
		        name: newname, 
		        value: "", 
		        parent: this.currentParentNode};
		        
		    this.currentParentNode.children ~= node;

		    this.currentParentNode = &this.currentParentNode.children[$-1];
	    }
	    
	    // only the last node from the path gets the value
	    this.currentParentNode.value = block.value;
	    
	    // save the current path for comparison with the subsequent path (line)
	    this.previousPath = currentPath;
    }
    

    unittest
    {
        {
            Node root = { name: "internalRoot" };
            UsvParser parser = { contextFullPath : "", previousPath: "", currentParentNode: &root};
       
            Block block1 = { BlockType.Node, PathType.FullPath, "abc.def", [], "79"};            
            parser.appendNodeBlock(block1);
            
            auto node1 = root.children[0];
            assert(root.name == "internalRoot");
            assert(node1.name == "abc");
            assert(node1.value == "");
            assert(node1.children[0].name == "def");
            assert(node1.children[0].value == "79");
            
            
            Block block2 = { BlockType.Node, PathType.FullPath, "b", [], "12 34"};
            parser.appendNodeBlock(block2);
            
            auto node2a = root.children[0];
            assert(node2a.name == "abc");
            assert(node2a.children[0].name == "def");
            
            auto node2b = root.children[1];
            assert(node2b.name == "b");
            assert(node2b.value == "12 34");        

            Block block3 = { BlockType.Node, PathType.FullPath, "b", [], "987"};            
            parser.appendNodeBlock(block3);
            
            auto node3 = root.children[2];
            assert(node3.name == "b");
            assert(node3.value == "987");
            
            // check previous nodes
            assert(root.children[1].name == "b");
        }
        
        {
            Node root = { name: "internalRoot" };
            UsvParser parser = { contextFullPath : "", previousPath: "", currentParentNode: &root};
       
            Block block1 = { BlockType.Node, PathType.FullPath, "a", [], "79"};            
            parser.appendNodeBlock(block1);
            
            auto node1 = root.children[0];
            assert(root.name == "internalRoot");
            assert(node1.name == "a");
            assert(node1.value == "79");
            
            
            Block block2 = { BlockType.Node, PathType.FullPath, "anode.bnode", [], "1234"};
            parser.appendNodeBlock(block2);
            
            auto node2a = root.children[1];
            assert(node2a.name == "anode");
            assert(node2a.value == "");
            
            auto node2b = root.children[1].children[0];
            assert(node2b.name == "bnode");
            assert(node2b.value == "1234");        
        }
        
    }
    
    // All below are static Parser members
    static:
    
    struct Block
    {
	    BlockType type = BlockType.Unknown;
        PathType pathType = PathType.Invalid;
	    string nodePath	= "";
	    Attribute[] attributes;
	    string value = "";
    }
    
    Block parseBlock(ref Buffer buffer)
    {
	    Block block;

        buffer.findSkip!isSpaceOrTab;
        
        if (buffer.empty)
        {
            block.type = BlockType.Empty;
        }
	    else if (buffer.front == '#')
	    {
		    
		    if (buffer.nextChar() == '!')
		    {
			    block.type = BlockType.Meta;
		    }
		    else
		    {
			    block.type = BlockType.Comment;
		    }
		    buffer.findSkip!(c => c == Character.NewLine ? false : true);
		    
	    }
	    else if (isAlpha(buffer.front) || buffer.front == Character.Dot)
	    {
		    block = parseNodeBlock(buffer);
	    }
	    else if (buffer.front == Character.NewLine)
	    {
	        block.type = BlockType.Empty;
	    }
	    else if (buffer.front.isControl)
	    {
	        // TODO Error handling
	        buffer.popFront;
	        block.type = BlockType.Empty;
	    }
	    else if ( buffer.front == Character.Colon )
	    {
	        block.type = BlockType.Invalid;
	    }
	    else
	    {
	        assert(0);
	    }
	    
	    // consume NewLine character
	    if(!buffer.empty)
	    {
	        assert(buffer.front == Character.NewLine);
	        buffer.popFront;
	    }
 
	    return block;
    }

    Block parseNodeBlock(ref Buffer buffer)
    {
        assert(!isSpaceOrTab(buffer.front));
        
        enum State {Unknown, ParsingPath, ParsingAttributes, ParsingValue }

        Block block;
        block.type = BlockType.Node;

        auto state = State.ParsingPath;
        
        parsingNodeBlock:
        while( !buffer.empty() )
        {

	        switch (state)
	        {		        
		        case State.ParsingPath:

			        block.nodePath = parseNodePath(buffer);
                    
                    block.pathType = PathType.FullPath;
                    if (block.nodePath.front == Character.Dot) 
                    {
                        block.pathType = PathType.RelativePath;
                    }

                    buffer.findSkip!isSpaceOrTab;
                    
                    if (buffer.empty)
                    {
                        break parsingNodeBlock;
                    }
                    
                    if (buffer.front == Character.NewLine)
                    {
                        break parsingNodeBlock;
                    }
                    else if (buffer.front == Character.Colon)
                    {
			            buffer.popFront;
			            state = State.ParsingValue;
                    }
                    else
                    {
                        state = State.ParsingAttributes;
			        }
			        break;

		        case State.ParsingAttributes:

                    auto attrs = parseNodeAttributes(buffer);
                    block.attributes = attrs;
			        state  = State.ParsingValue;
			        break;

		        case State.ParsingValue:

                    buffer.findSkip!isSpaceOrTab;
                    
			        block.value = parseValueString(buffer);
			      			        
			        break parsingNodeBlock;
			        
		        case State.Unknown:
		        default:
			        assert(0);
	        }	        
        }        
        
        return block;
    }

    string parseNodePath(ref Buffer buffer)
    {     
        assert(!isSpaceOrTab(buffer.front));

        string nodePath;

        while( !buffer.empty )
        {
            
            if ( isSpaceOrTab(buffer.front) || 
                   buffer.front == Character.Colon ||
                   buffer.front == Character.NewLine)
            {
                break;
            }
            else
            {
                nodePath ~= buffer.front;
            }
            
            buffer.popFront;
        }
        return nodePath;
    }
    
    unittest
    {
        Buffer buffer = Buffer("em\n\n");       
        assert ( parseNodePath(buffer) == "em");       
    }

    
    Attribute[] parseNodeAttributes(ref Buffer buffer)
    {
        assert(!isSpaceOrTab(buffer.front));

        Attribute[] attributes;

        enum State {ParsingName, ParsingValue, ParsingFinished}
        State state = State.ParsingName;
        
        
        parsingAttributes:
        while( !buffer.empty)
        {
            buffer.findSkip!isSpaceOrTab;
            switch(state)
            {
                case State.ParsingName:
                    
                    string name = parseAlphaName(buffer);
                    assert( name != "" );
                    
                    attributes ~= Attribute(name, "");
                    
                    buffer.findSkip!isSpaceOrTab;
                    
                    if (buffer.front == '=')
                    {
                        buffer.popFront;
                        state = State.ParsingValue;
                    }
                    else if (buffer.front == Character.NewLine ||
                                buffer.front == Character.Colon)
                    {
                        buffer.popFront;
                        
                        break parsingAttributes;
                    }
                    else
                    {
                        assert(0);
                    }
                    
                    break;
                    
                case State.ParsingValue:
                    
                    string value = parseAttributeValue(buffer);
                    
                    buffer.findSkip!isSpaceOrTab;
                    
                    attributes[$-1].value = value;
                    
                    if (buffer.empty)
                    {
                        break parsingAttributes;
                    }
                    
                    if (buffer.front == Character.NewLine ||
                                buffer.front == Character.Colon)
                    {
                        buffer.popFront;                       
                        break parsingAttributes;
                    }
                    else
                    {
                        state = State.ParsingName;
                    }
                    
                    break;

                default:
                    assert(0);
            }
        }
          
        return attributes;  
    }

    unittest
    {
        Buffer buffer = Buffer("attr1=\"12\" \n");
        
        assert(parseNodeAttributes(buffer) == [Attribute("attr1", "12")]);
    }
    
    
    string parseAlphaName(ref Buffer buffer)
    {
        import std.ascii;
        
        assert(!isSpaceOrTab(buffer.front));
        
        string text;
        
        while( !buffer.empty )
        {
             if (!std.ascii.isAlphaNum(buffer.front))
             {
                break;
             }
             text ~= buffer.front;
             buffer.popFront;
        }

        return text;
    }


    string parseAttributeValue(ref Buffer buffer)
    {
        assert(!isSpaceOrTab(buffer.front));
        
        string text;
        
        if (buffer.front == Character.Quote)
        {
            text = parseEscapedString(buffer);
        }
        else
        {
            text = parseAlphaName(buffer);
        }
        
        return text;
    }

    
    string parseValueString(ref Buffer buffer)
    {
        assert(!isSpaceOrTab(buffer.front));
        
        string text;
        
        if (buffer.front == Character.Quote )
        {
            if (buffer.nextChar != Character.Quote)
            {
                text = parseEscapedString(buffer);
            }
            else
            {
                text = parseMultilineEscapedString(buffer);
            } 
        }
        else
        {
            text = parseSimpleString(buffer);
        }
        
        return text;
    }

    
    string parseSimpleString(ref Buffer buffer)
    {
        assert(!isSpaceOrTab(buffer.front));
        
        string text;
        
        // FIXME Implement checking for forbidden characters, ':', '\r' etc
        while( !buffer.empty )
        {
             if (buffer.front == '\n')
             {
                break;
             }
             text ~= buffer.front;
             buffer.popFront;
        }

        return text;
    }

   
    string parseEscapedString(ref Buffer buffer)
    {
        // FIXME Implement checking for wrongly escaped strings
        
        assert (buffer.front == Character.Quote);
        
        string text;
        
        parsingEscapedString:
        while(!buffer.empty)
        {
            buffer.popFront;
            switch(buffer.front)
            {   
                case Character.Quote:
                    buffer.popFront;               
                    break parsingEscapedString;
                
                case Character.BackSlash:
                    buffer.popFront;
                    
                    if(!buffer.empty)
                    {
                        text ~= escapedCharacter(buffer.front);
                    }
                    else
                    {
                        assert(0);
                    }
                    
                    break;
                      
                case Character.NewLine:
                    assert(0);
                
                default:
                    text ~= buffer.front;
                    break;
            }
        }
                
        return text;
    }
    
    unittest
    {
        {
            Buffer buffer = Buffer(`"1234"6`);
            assert(parseEscapedString(buffer) == "1234");
            assert(buffer.front == '6');
        }
        {
            Buffer buffer = Buffer(`"123\n4"`);
            assert(parseEscapedString(buffer) == "123\n4");
        }
        {
            Buffer buffer = Buffer(`"123\t4"`);
            assert(parseEscapedString(buffer) == "123\t4");
        }         
    }

    
    dchar escapedCharacter(dchar character)
    {
        switch(character)
        {
            case '\\': 
            case '\"': 
                return character;
                
            case 'n': return '\n';
            case 't': return '\t';
            
            default:
                assert(0);
        }
    }

    
    string parseMultilineEscapedString(ref Buffer buffer)
    {
        string text;
        
        for(int i = 0; i < 3; i++)
        {
            if (buffer.front != Character.Quote)
            {
                assert(0);
            }
            buffer.popFront();
        }
        
        buffer.findSkip!isSpaceOrTab;
        if (buffer.front == Character.NewLine)
        {
            buffer.popFront();
        }
        else
        {
            assert(0);
        }
        
        bool terminated = false;
        while(!buffer.empty)
        {
            text ~= buffer.front;
            
            bool firstQuote = false;
            
            if(buffer.front == Character.Quote)
            {
                firstQuote = true;
            }
            
            buffer.popFront();
            
            terminated = false;
            if (firstQuote && !buffer.empty && buffer.front == Character.Quote)
            {
                if (buffer.nextChar == Character.Quote)
                {
                    buffer.popFront(); // remove second quote
                    buffer.popFront(); // remove third quote
                    buffer.findSkip!isSpaceOrTab;
                    if (!buffer.empty)
                    {
                        if (buffer.front == Character.NewLine)
                        {
                            buffer.popFront();
                        }
                        else
                        {
                            assert(0);
                        }
                    }
                    terminated = true;
                    break;
                }
            }   
        }
        
        if (terminated)
        {
            auto revText = retro(text);
            revText.findSkip("\n");
            text = retro(revText);            
        }
        else
        {
            assert(0);
        }
        return text;
    }
    unittest
    {
        Buffer buffer = Buffer("\"\"\"  \n \ntwo \n \"three\"\"  \"\n\n  \"\"\" \ncanary");   
        assert(parseMultilineEscapedString(buffer) == " \ntwo \n \"three\"\"  \"\n");
        assert(buffer.front == 'c');
    }
    
    
    @property
    bool isSpaceOrTab(dchar character)
    {

        if (character == Character.Space || character == Character.Tab) return true;
        return false;
    }

    
    // computes where is the common parent node to which new nodes should be appended
    auto levelsToCommonNode(string currentPath, string prevoiusPath)
    {
        assert(currentPath.length);
        
        
        
        if (prevoiusPath.length == 0)
        {
            // starting from root
            return 0;
        }

        int commonPathNodeCount = 0;
        int prevoiusPathNodeCount = 1;
        bool equal = true;

        for (int i = 0; i < prevoiusPath.length; ++i)
        {
	        if (i == currentPath.length)
            {
                equal = false;
            }

            if(prevoiusPath[i] == Character.Dot)
            {
                
                ++prevoiusPathNodeCount;
            }
            
            if (equal)
            {
                if(currentPath[i] == prevoiusPath[i])
                {
                    if(currentPath[i] == Character.Dot)
                    {
                        commonPathNodeCount++;
                    }
                }
                else
                {
                    equal = false;
                }
            }
        }

        // TODO simplify those special cases
        if (prevoiusPath.length == currentPath.length)
        {
            if (equal)
            {
                // paths are equal
                return 1;
            }
        }
        else
        {
            if (equal)
            {
                // Check if the last node of the previous path was actually the common part
                if ( prevoiusPath.length < currentPath.length &&
                    currentPath[prevoiusPath.length] == Character.Dot)
                {
                    commonPathNodeCount++;
                }
                    
            }
        }

        auto levels = prevoiusPathNodeCount - commonPathNodeCount;
        return levels;
	     
	    version(old)
        {
            if (prevoiusPath.length == 0)
            {
                // starting from root
                return 0;
            }
        

            if (currentPath == prevoiusPath)
            {
                return 1;
            }

            // strip the last path section (after the last '.', if exists)
            auto reversed = retro(currentPath);
            bool found = reversed.findSkip(".");
            if (!found)
            {
                currentPath = "";
            }
            else
            {
                currentPath =  reversed.retro;
            }
              
            auto common = commonPrefix(prevoiusPath, currentPath);

            prevoiusPath.findSkip(common);
            if (prevoiusPath == "")
            {
	            return 0;
	        }
	        
            prevoiusPath = prevoiusPath.stripLeft('.');
	        auto levels = prevoiusPath.count('.') + 1;
	        return levels;

        } 
    }
    
    unittest
    {
	    import std.stdio;
	    static struct TestData
	    {
		    auto currentPath = "";
		    auto previousPath = "";
		    auto levelsToCommonNode = -1;
	    }
	    TestData[] testData = [
		    {
			    previousPath: "",
			    currentPath: "book",
			    levelsToCommonNode: 0,
		    },
		    {
			    previousPath: "",
			    currentPath: "book.chapter",
			    levelsToCommonNode: 0,
		    },
		    {
			    previousPath: "book",
			    currentPath: "book",
			    levelsToCommonNode: 1,
		    },
		    {
			    previousPath: "book",
			    currentPath: "book.chapter",
			    levelsToCommonNode: 0,
		    },
		    {
			    previousPath: "book.chapter",
			    currentPath: "book.chapter",
			    levelsToCommonNode: 1,
		    },
		    {
			    previousPath: "book.chapter",
			    currentPath: "book",
			    levelsToCommonNode: 2,
		    },
		    {
			    previousPath: "book",
			    currentPath: "book.chapter.paragraph",
			    levelsToCommonNode: 0,
		    },
		    {
			    previousPath: "book.header.title",
			    currentPath: "book.content.chapter.paragraph",
			    levelsToCommonNode: 2,
		    },
		    {
			    previousPath: "book.header.title",
			    currentPath: "book.header",
			    levelsToCommonNode: 2,
		    },
		    {
			    previousPath: "a",
			    currentPath: "anode.bnode",
			    levelsToCommonNode: 1,
		    },
	    ];
	    
	    foreach (idx, check; testData)
	    {
		    auto result = UsvParser.levelsToCommonNode(check.currentPath, check.previousPath);
		    // debug log(check, " = ", result);
		    assert (result == check.levelsToCommonNode);
	    }
    }    
}


struct Buffer
{

    this(string payload, int position)
    {
        payload = payload;
        position = position;
    }

    this(string text)
    {
        payload = text;
    }	


    @property
	dchar front()
	{
	    return payload[position];
	}
	
	
	void popFront()
	{
	    position++;
	}
	
    @property
	bool empty()
	{
		return position == payload.length ;
	}
	
	
	dchar nextChar()
	{
	    if (position+1 < payload.length)
	    {
	        return payload[position+1];
	    }
	    else
	    {
	        return 0;
	    }
	}

	
	@property
	Buffer save()
	{
	    return Buffer(payload,position);
	}
	    
private:
    string payload;
	int position = 0;
}


struct Attribute
{
	string name;
	string value;
}


struct Node
{
	string name;
	string value;	
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
		result ~= name ~ " = " ~ value ~ "\n";
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


debug
{
    import std.experimental.logger;
}

