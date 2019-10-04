module draft.std.build;

import std.process, std.stdio;


CommandResult build(string directoryPath, BuildOption option = BuildOption.Default)
{
	Config config;
	
	auto input = check(config);

	auto obj = compile(config, input);
	
	auto app = link(config, obj);

	auto dep = deploy(config, app);

	auto ret = clean(config, dep);

	return ret;
}


enum CommandOk = CommandResult(true, [""], 0);

enum ResultFlag
{
	Check,
	Compile,
	Link,
	Deploy,
	Clean,
	Test
}

enum BuildOption
{
	Default,
	CleanExistingDirecory
}

struct CommandResult
{
	bool success;
	string[] output;
	int failCode;
}

struct BuildStepResult
{
}

struct BuildResult
{
	bool success;
	int payload = 0;
	/*
	// TODO define bit position
	void flag(ResultFlag)(bool success)
	{
		auto pos = 0;
		payload |= (success >> pos);
	}
	*/
}

struct Command
{

	string program;
	string[] options;
	string[] args() { return program ~ options;};	
}

BuildStepResult check(Config)
{
	return CommandOk;
}

BuildStepResult compile(Config config, BuildStatus status)
{
	BuildStep step("Compilation", config);
	step.checkEntry()
	// ldc compiler file
	Command listCmd = {program:"ls", options: ["-al"], };
	step.run(listCmd, exepectSuccess());

	// second
	Command cmdUser = {program:"whoami"};
	run(cmdUser);
	//run(Command("ls",["-al"]));
	run({program:"", options: ["-al",""]});
	return CommandOk;
}

CommandResult link(Config, CommandResult compiler)
{
	return CommandOk;
}

CommandResult deploy(Config, CommandResult linker)
{
	return CommandOk;
}

CommandResult clean(Config, CommandResult deployment)
{
	return CommandOk;
}

CommandResult test(Config)
{
	return CommandOk;
}

CommandResult run(Command command)
{
	auto pid = spawnProcess(command.args);
	auto errorCode = wait(pid);
	return CommandResult();
}


// ----- alt --------------

struct Builder
{
	BuildConfig config;
	
	this(string config)
	{
	}

	Result check()
	{
		return CommandOk;
	}

	Result compile()
	{
		auto script = Script("Compilation");
		
		Command listCmd = {program:"ls", options: ["-al"], };
		script.run(listCmd);

		Command cmdUser = {program:"whoami"};
		script.run(cmdUser);

		return CommandOk;
	}

	Result link()
	{
		return CommandOk;
	}

	Result deploy()
	{
		return CommandOk;
	}

	Result clean()
	{
		return CommandOk;
	}

	Result test()
	{
		return CommandOk;
	}
}

// -------------------------

/*
 *
 * files:
 * 		app.d
 *
 * 
 * rdmd app.d
 *

-------

project
    output
        build_name
            release_folder
                documentation
                    manual.pdf
                    readme.txt
                app.exe
            config
                build.csv
            bin
                obj
                    draft.o
                    d.o
                    app.o
                    main.o
                executable 
                libraries
            source
               # lib 1 
               draft
                    build.d
                    command.d 
               # lib 2
               d
                    types.d
               app
                    block.d
               object.d
               main.d
    docs 
    source
        app
            logic.d
            
        main.d
    build.csv

 */
