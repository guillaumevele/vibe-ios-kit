// FILE: Article.swift
import Foundation

struct Article: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let contentHTML: String
    let contentText: String
    let url: URL?
    let imageURL: URL?
    let author: String?
    let date: Date

    init(dto: ItemDTO) {
        id = dto.id ?? dto.url ?? UUID().uuidString

        let rawTitle = (dto.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        title = rawTitle.isEmpty ? "Untitled article" : rawTitle

        contentHTML = dto.contentHTML ?? ""
        contentText = dto.contentText ?? (contentHTML.isEmpty ? "" : Article.plainText(fromHTML: contentHTML))

        let rawSummary = (dto.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        summary = rawSummary.isEmpty ? String(contentText.prefix(200)) : rawSummary

        url = dto.url.flatMap { URL(string: $0) }
        imageURL = dto.image.flatMap { URL(string: $0) }
        author = dto.authors?.compactMap(\.name).first ?? dto.author?.name

        date = Article.parseDate(dto.datePublished ?? "") ?? .now
    }

    /// Renders the HTML body once, outside of any view body.
    func renderedBody() -> AttributedString {
        guard !contentHTML.isEmpty, let htmlData = contentHTML.data(using: .utf8) else {
            return AttributedString(contentText)
        }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let nsAttributed = try? NSAttributedString(data: htmlData, options: options, documentAttributes: nil) {
            return AttributedString(nsAttributed)
        }
        return AttributedString(contentText)
    }

    /// Parses an RFC 3339 / ISO 8601 timestamp with the base strategy, then,
    /// if that fails, strips fractional seconds (which the base strategy
    /// rejects) and tries once more. Returns nil for anything unrecognized.
    private static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let strategy = Date.ISO8601FormatStyle()
        if let date = Date(trimmed, strategy: strategy) {
            return date
        }
        let withoutFractionalSeconds = trimmed.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
        if withoutFractionalSeconds != trimmed {
            return Date(withoutFractionalSeconds, strategy: strategy)
        }
        return nil
    }

    private static func plainText(fromHTML html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&nbsp;": " "
        ]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
