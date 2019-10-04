module draft.std.script;

import std.stdio;
import std.process;


/* API */

Result executeCommand(Command command)
{
    auto pid = spawnProcess(command.args);
	auto errorCode = wait(pid);
	Result result = {success: true};
	return result;
}

void log();

void findFiles();
void createFolders(); // makeDirs

void readText();
void writeText();

void downloadFile();
void uploadFile();

/* Other */


struct Command
{

	string program;
	string[] options;
	string[] args() { return program ~ options;};	
}

struct Result
{
    bool success;
	int result;
	// string[] output;
}



void step(Script script)
{
	script.logDebug("step");
	
	Command command  = { program: "ls", options: ["-al"]},

	executeCommands(command);
}


struct Script
{
	string name;
	this (string name)
	{
		
	}
	void run(Command command)
	{
		print("run " ~ name);
		
		executeCommand(command);
	}

	void print(string message)
	{
		
	}
}
