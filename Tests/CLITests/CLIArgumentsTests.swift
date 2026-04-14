import Testing
@testable import AirplaneAI

@Suite("CLIArguments parsing")
struct CLIArgumentsTests {
    @Test("--prompt plus -n yields named command")
    func namedPromptParses() throws {
        let args = try CLIArguments.parse(["-p", "hello", "-n", "demo"])
        #expect(args.prompt == "hello")
        #expect(args.name == "demo")
        #expect(args.continuing == false)
        #expect(args.mode == .named)
    }

    @Test("long forms are equivalent")
    func longFormsParse() throws {
        let args = try CLIArguments.parse(["--prompt", "hi", "--name", "foo", "--continue"])
        #expect(args.prompt == "hi")
        #expect(args.name == "foo")
        #expect(args.continuing == true)
    }

    @Test("single-shot with just -p")
    func singleShotParses() throws {
        let args = try CLIArguments.parse(["-p", "2+2?"])
        #expect(args.mode == .single)
        #expect(args.prompt == "2+2?")
        #expect(args.name == nil)
    }

    @Test("positional prompt without -p")
    func positionalPromptParses() throws {
        let args = try CLIArguments.parse(["What is 2+2?"])
        #expect(args.mode == .single)
        #expect(args.prompt == "What is 2+2?")
    }

    @Test("--list builds list mode")
    func listParses() throws {
        let args = try CLIArguments.parse(["--list"])
        #expect(args.mode == .list)
    }

    @Test("--show requires -n")
    func showRequiresName() {
        #expect(throws: CLIArgumentError.self) {
            _ = try CLIArguments.parse(["--show"])
        }
    }

    @Test("--delete with -n")
    func deleteParses() throws {
        let args = try CLIArguments.parse(["--delete", "-n", "demo"])
        #expect(args.mode == .delete)
        #expect(args.name == "demo")
    }

    @Test("no arguments is an error")
    func emptyArgumentsFail() {
        #expect(throws: CLIArgumentError.self) {
            _ = try CLIArguments.parse([])
        }
    }

    @Test("-p without value fails")
    func promptFlagWithoutValue() {
        #expect(throws: CLIArgumentError.self) {
            _ = try CLIArguments.parse(["-p"])
        }
    }

    @Test("unknown flag fails")
    func unknownFlag() {
        #expect(throws: CLIArgumentError.self) {
            _ = try CLIArguments.parse(["--nope"])
        }
    }

    @Test("--continue without -n fails")
    func continueRequiresName() {
        #expect(throws: CLIArgumentError.self) {
            _ = try CLIArguments.parse(["-p", "hi", "--continue"])
        }
    }

    @Test("flags coexist: system + max-tokens + quiet")
    func optionalFlagsParse() throws {
        let args = try CLIArguments.parse([
            "-p", "hi",
            "-s", "Be terse.",
            "--max-tokens", "64",
            "-q",
        ])
        #expect(args.systemOverride == "Be terse.")
        #expect(args.maxTokens == 64)
        #expect(args.quiet == true)
    }

    @Test("isCLIInvocation: true when -p or --prompt present")
    func detectsCLIInvocation() {
        #expect(CLIArguments.isCLIInvocation(arguments: ["AirplaneAI", "-p", "hi"]))
        #expect(CLIArguments.isCLIInvocation(arguments: ["AirplaneAI", "--prompt", "hi"]))
        #expect(CLIArguments.isCLIInvocation(arguments: ["AirplaneAI", "--list"]))
        #expect(CLIArguments.isCLIInvocation(arguments: ["AirplaneAI", "--help"]))
    }

    @Test("isCLIInvocation: false for plain launch or seed mode")
    func detectsGUILaunch() {
        #expect(!CLIArguments.isCLIInvocation(arguments: ["AirplaneAI"]))
        #expect(!CLIArguments.isCLIInvocation(arguments: ["AirplaneAI", "--seed-sample-conversations"]))
    }
}
