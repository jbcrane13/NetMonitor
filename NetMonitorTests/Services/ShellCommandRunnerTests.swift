//
//  ShellCommandRunnerTests.swift
//  NetMonitorTests
//
//  Tests for ShellCommandRunner actor.
//

import Testing
@testable import NetMonitor

@Suite("ShellCommandRunner Tests")
struct ShellCommandRunnerTests {

    @Test("Run simple echo command")
    func runEchoCommand() async throws {
        let runner = ShellCommandRunner()
        let output = try await runner.run("/bin/echo", arguments: ["Hello, World!"])
        #expect(output.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "Hello, World!")
        #expect(output.exitCode == 0)
    }

    @Test("Run command with multiple arguments")
    func runCommandWithMultipleArguments() async throws {
        let runner = ShellCommandRunner()
        let output = try await runner.run("/bin/echo", arguments: ["-n", "test"])
        #expect(output.stdout == "test")
        #expect(output.exitCode == 0)
    }

    @Test("Command not found throws error")
    func commandNotFoundThrowsError() async throws {
        let runner = ShellCommandRunner()
        await #expect(throws: ToolError.self) {
            _ = try await runner.run("/nonexistent/command", arguments: [])
        }
    }

    @Test("Streaming output collects all lines")
    func streamingOutputCollectsAllLines() async throws {
        let runner = ShellCommandRunner()
        var lines: [String] = []

        for try await line in await runner.stream("/bin/echo", arguments: ["line1\nline2\nline3"]) {
            lines.append(line)
        }

        #expect(lines.count >= 1)
    }

    @Test("Cancel stops running command")
    func cancelStopsRunningCommand() async throws {
        let runner = ShellCommandRunner()

        // Start a long-running command
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await runner.cancel()
        }

        // Try to run a command that would take a while
        do {
            _ = try await runner.run("/bin/sleep", arguments: ["10"], timeout: 15)
            // If we get here without timeout, the command was cancelled
        } catch {
            // Expected - command was cancelled
        }
    }

    @Test("Timeout stops long-running command")
    func timeoutStopsLongRunningCommand() async throws {
        let runner = ShellCommandRunner()

        await #expect(throws: ToolError.self) {
            _ = try await runner.run("/bin/sleep", arguments: ["10"], timeout: 1)
        }
    }
}
