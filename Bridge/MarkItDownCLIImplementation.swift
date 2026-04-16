import Foundation

/// Concrete implementor that shells out to the `markitdown` Python CLI.
final class MarkItDownCLIImplementation: ConverterImplementation {

    private let shell = ShellRunner.shared

    // MARK: - ConverterImplementation

    func convert(fileURL: URL) throws -> String {
        let path = try resolvedBinaryPath()
        let result = try shell.runShell("\(shellEscape(path)) \(shellEscape(fileURL.path))")
        if result.exitCode != 0 {
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
            # v0.1.x: _extension_to_converter dict
            if hasattr(m, '_extension_to_converter'):
                exts.update(m._extension_to_converter.keys())
            # v0.0.x: list of converter objects with file_extensions attr
            if hasattr(m, '_converters'):
                items = m._converters if isinstance(m._converters, list) else m._converters.values()
                for c in items:
                    for attr in ('file_extensions', 'extensions', 'supported_extensions'):
                        if hasattr(c, attr):
                            val = getattr(c, attr)
                            if isinstance(val, (list, tuple, set, frozenset)):
                                exts.update(val)
            exts = sorted({e.lstrip('.').lower() for e in exts if e})
            if exts:
                print('\\n'.join(exts))
            else:
                sys.exit(1)
        except Exception:
            sys.exit(1)
        """

        guard let result = try? shell.runShell(
            "python3 -c \(shellEscape(script))", timeout: 10
        ), result.exitCode == 0 else {
            return nil
        }
        return parseExtensions(from: result.output)
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
