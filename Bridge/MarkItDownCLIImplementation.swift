import Foundation

/// Concrete implementor that shells out to the `markitdown` Python CLI.
final class MarkItDownCLIImplementation: ConverterImplementation {

    private let shell = ShellRunner.shared

    // MARK: - ConverterImplementation

    func convert(fileURL: URL) throws -> String {
        let path = try resolvedBinaryPath()
        let command = "\(shellEscape(path)) \(shellEscape(fileURL.path))"
        let result: ShellResult
        do {
            result = try shell.runShell(command)
        } catch {
            DebugLogger.shared.logFailure(
                sourceFile: fileURL, command: command,
                exitCode: -1, stdout: "", stderr: "",
                error: error.localizedDescription
            )
            throw error
        }
        if result.exitCode != 0 {
            DebugLogger.shared.logFailure(
                sourceFile: fileURL, command: command,
                exitCode: result.exitCode,
                stdout: result.output, stderr: result.error,
                error: "Non-zero exit code"
            )
            throw ShellError.executionFailed(stderr: result.error, exitCode: result.exitCode)
        }
        return result.output
    }

    func convertStreaming(fileURL: URL) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let path = try? resolvedBinaryPath() else {
                continuation.finish(throwing: ShellError.commandNotFound("markitdown"))
                return
            }
            let command = "\(shellEscape(path)) \(shellEscape(fileURL.path))"
            let (lines, exits) = shell.runShellStreaming(command)

            Task {
                var fullOutput = ""
                for await line in lines {
                    continuation.yield(line)
                    // Accumulate non-meta lines as the markdown output.
                    if !line.hasPrefix("[stderr] ") && !line.hasPrefix("[error] ") {
                        if !fullOutput.isEmpty { fullOutput += "\n" }
                        fullOutput += line
                    }
                }
                var exitCode: Int32 = 0
                for await code in exits { exitCode = code }

                if exitCode != 0 {
                    continuation.finish(throwing: ShellError.executionFailed(
                        stderr: "Non-zero exit code", exitCode: exitCode))
                } else {
                    continuation.finish()
                }
            }
        }
    }

    func isInstalled() -> Bool {
        (try? resolvedBinaryPath()) != nil
    }

    func installedSupportedFormats() -> [String] {
        // Strategy 1: introspect the Python library for file extensions.
        if let exts = formatsViaPythonIntrospection(), !exts.isEmpty {
            return exts
        }
        // Strategy 2: parse `markitdown --help` for recognisable extensions.
        if let exts = formatsViaHelp(), !exts.isEmpty {
            return exts
        }
        return []
    }

    // MARK: - Binary discovery

    /// Search common locations for the `markitdown` binary and return its
    /// absolute path, or throw if not found.
    private func resolvedBinaryPath() throws -> String {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.pyenv/shims/markitdown",
            "\(home)/.local/bin/markitdown",
            "/opt/homebrew/bin/markitdown",
            "/usr/local/bin/markitdown",
        ]

        let fm = FileManager.default
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return path
        }

        // Fallback: ask the shell.
        if let result = try? shell.runShell("which markitdown", timeout: 5),
           result.exitCode == 0,
           !result.output.isEmpty {
            return result.output
        }

        throw ShellError.commandNotFound("markitdown")
    }

    // MARK: - Format discovery strategies

    /// Use Python to introspect `MarkItDown` internals for supported
    /// extensions. Tries several internal APIs that have existed across
    /// different library versions.
    private func formatsViaPythonIntrospection() -> [String]? {
        // Scan every converter for any attribute whose name contains "ext",
        // regardless of the markitdown version's internal naming convention.
        let script = """
        import sys, warnings
        warnings.filterwarnings("ignore")
        try:
            from markitdown import MarkItDown
            m = MarkItDown()
            exts = set()

            # Strategy A: _extension_to_converter dict
            if hasattr(m, '_extension_to_converter'):
                exts.update(m._extension_to_converter.keys())

            # Strategy B: scan every converter attribute containing "ext"
            if hasattr(m, '_converters'):
                items = m._converters
                if isinstance(items, dict):
                    items = items.values()
                for c in items:
                    for attr_name in dir(c):
                        if 'ext' not in attr_name.lower():
                            continue
                        if attr_name.startswith('__'):
                            continue
                        val = getattr(c, attr_name, None)
                        if callable(val):
                            try:
                                val = val()
                            except Exception:
                                continue
                        if isinstance(val, (list, tuple, set, frozenset)):
                            exts.update(str(e) for e in val)
                        elif isinstance(val, str) and val:
                            exts.add(val)

            # Strategy C: module-level constants
            for mod_path in ('markitdown._markitdown', 'markitdown'):
                try:
                    mod = __import__(mod_path, fromlist=['_'])
                    for name in dir(mod):
                        if 'EXTENSION' not in name.upper():
                            continue
                        val = getattr(mod, name, None)
                        if isinstance(val, (list, tuple, set, frozenset)):
                            exts.update(str(e) for e in val)
                        elif isinstance(val, dict):
                            exts.update(str(e) for e in val.keys())
                except Exception:
                    pass

            exts = sorted({e.lstrip('.').lower() for e in exts if e})
            if exts:
                print('\\n'.join(exts))
            else:
                sys.exit(1)
        except Exception as exc:
            print(str(exc), file=sys.stderr)
            sys.exit(1)
        """

        let result: ShellResult?
        do {
            result = try shell.runShell("python3 -c \(shellEscape(script))", timeout: 15)
        } catch {
            result = nil
        }

        if let r = result, r.exitCode == 0 {
            return parseExtensions(from: r.output)
        }

        DebugLogger.shared.logFailure(
            sourceFile: URL(fileURLWithPath: "/"),
            command: "python3 format introspection",
            exitCode: result?.exitCode ?? -1,
            stdout: result?.output ?? "",
            stderr: result?.error ?? "",
            error: "Format discovery via Python introspection failed"
        )
        return nil
    }

    /// Fallback: parse `markitdown --help` for file extension references.
    private func formatsViaHelp() -> [String]? {
        guard let path = try? resolvedBinaryPath(),
              let result = try? shell.runShell("\(shellEscape(path)) --help", timeout: 10),
              result.exitCode == 0 else {
            return nil
        }

        let regex = try? NSRegularExpression(pattern: #"\.\b([a-z0-9]{2,5})\b"#)
        let text = result.output + " " + result.error
        let range = NSRange(text.startIndex..., in: text)
        var found = Set<String>()
        regex?.enumerateMatches(in: text, range: range) { match, _, _ in
            if let r = match?.range(at: 1), let swiftRange = Range(r, in: text) {
                found.insert(String(text[swiftRange]))
            }
        }
        let filtered = found.subtracting(Self.outputOnlyFormats).sorted()
        return filtered.isEmpty ? nil : filtered
    }

    /// Formats that are output targets, not input sources.
    private static let outputOnlyFormats: Set<String> = ["md", "markdown"]

    // MARK: - Utilities

    private func parseExtensions(from output: String) -> [String] {
        output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty && !Self.outputOnlyFormats.contains($0) }
    }

    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
