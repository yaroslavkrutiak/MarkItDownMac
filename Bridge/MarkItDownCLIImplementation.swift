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
        let script = """
        import sys
        try:
            from markitdown import MarkItDown
            m = MarkItDown()
            exts = set()

            # Strategy A: _extension_to_converter dict (v0.1.x)
            if hasattr(m, '_extension_to_converter'):
                exts.update(m._extension_to_converter.keys())

            # Strategy B: walk converter objects and probe every
            # attribute name that has been used across versions
            if hasattr(m, '_converters'):
                items = m._converters
                if isinstance(items, dict):
                    items = items.values()
                for c in items:
                    for attr in (
                        'accepted_file_extensions',
                        'file_extensions',
                        'extensions',
                        'supported_extensions',
                    ):
                        if not hasattr(c, attr):
                            continue
                        val = getattr(c, attr)
                        if callable(val):
                            try:
                                val = val()
                            except Exception:
                                continue
                        if isinstance(val, (list, tuple, set, frozenset)):
                            exts.update(val)
                        elif isinstance(val, str) and val:
                            exts.add(val)

            # Strategy C: module-level constant
            try:
                from markitdown._markitdown import SUPPORTED_EXTENSIONS
                if isinstance(SUPPORTED_EXTENSIONS, (list, tuple, set, frozenset)):
                    exts.update(SUPPORTED_EXTENSIONS)
                elif isinstance(SUPPORTED_EXTENSIONS, dict):
                    exts.update(SUPPORTED_EXTENSIONS.keys())
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
            result = try shell.runShell("python3 -c \(shellEscape(script))", timeout: 10)
        } catch {
            result = nil
        }

        if let r = result, r.exitCode == 0 {
            return parseExtensions(from: r.output)
        }

        // Log the failure so the user can diagnose with debug mode.
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

        // Look for patterns like ".pdf", ".docx" etc.
        let regex = try? NSRegularExpression(pattern: #"\.\b([a-z0-9]{2,5})\b"#)
        let text = result.output + " " + result.error
        let range = NSRange(text.startIndex..., in: text)
        var found = Set<String>()
        regex?.enumerateMatches(in: text, range: range) { match, _, _ in
            if let r = match?.range(at: 1), let swiftRange = Range(r, in: text) {
                found.insert(String(text[swiftRange]))
            }
        }
        let filtered = found.sorted()
        return filtered.isEmpty ? nil : filtered
    }

    // MARK: - Utilities

    private func parseExtensions(from output: String) -> [String] {
        output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
