import Foundation

/// Lightweight grouping used only for the UI label that summarises what the
/// tool can convert. The *authoritative* list of extensions comes from the
/// bridge at runtime — these categories are just a display convenience.
enum FormatCategory: String, CaseIterable {
    case documents = "Documents"
    case presentations = "Presentations"
    case spreadsheets = "Spreadsheets"
    case images = "Images"
    case audio = "Audio"
    case web = "Web"
    case data = "Data"
    case other = "Other"

    /// Map a file extension to a human-readable category.
    static func category(for ext: String) -> FormatCategory {
        let lower = ext.lowercased()
        switch lower {
        case "pdf", "docx", "doc", "rtf", "txt", "odt":
            return .documents
        case "pptx", "ppt", "odp":
            return .presentations
        case "xlsx", "xls", "csv", "ods":
            return .spreadsheets
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "svg":
            return .images
        case "mp3", "wav", "m4a", "ogg", "flac", "aac":
            return .audio
        case "html", "htm", "xml", "mhtml":
            return .web
        case "json", "yaml", "yml", "toml":
            return .data
        default:
            return .other
        }
    }

    /// Group a flat list of extensions into categories, returning only
    /// categories that have at least one extension.
    static func grouped(_ extensions: [String]) -> [(category: FormatCategory, extensions: [String])] {
        let dict = Dictionary(grouping: extensions) { category(for: $0) }
        return FormatCategory.allCases.compactMap { cat in
            guard let exts = dict[cat], !exts.isEmpty else { return nil }
            return (cat, exts.sorted())
        }
    }

    /// One-line summary: "Documents, Presentations, Spreadsheets, …"
    static func summary(_ extensions: [String]) -> String {
        grouped(extensions).map(\.category.rawValue).joined(separator: ", ")
    }

    /// Comprehensive list of all formats supported by the official markitdown tool.
    /// Used as a fallback when dynamic detection returns too few results.
    static let knownMarkitdownFormats: [String] = [
        // Documents
        "pdf", "docx", "doc", "rtf", "txt", "odt", "epub",
        // Presentations
        "pptx", "ppt", "odp",
        // Spreadsheets
        "xlsx", "xls", "csv", "ods",
        // Images
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "svg",
        // Audio
        "mp3", "wav", "m4a", "ogg", "flac", "aac",
        // Web
        "html", "htm", "xml", "mhtml", "rss",
        // Data
        "json", "yaml", "yml", "toml",
        // Archives
        "zip",
        // Notebooks / Code
        "ipynb",
    ]
}
