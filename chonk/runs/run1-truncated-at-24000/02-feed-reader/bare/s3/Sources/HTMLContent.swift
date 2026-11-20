// FILE: HTMLContent.swift
import Foundation
import UIKit

enum HTMLContent {
    /// Converts an HTML string (e.g. JSON Feed `content_html`) into an AttributedString
    /// using only Apple frameworks, falling back to plain text on failure.
    static func attributedString(from html: String) -> AttributedString {
        guard let data = html.data(using: .utf8) else {
            return AttributedString(plainText(from: html))
        }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        do {
            let nsAttributed = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return AttributedString(nsAttributed)
        } catch {
            return AttributedString(plainText(from: html))
        }
    }

    /// Minimal HTML-to-plain-text fallback.
    static func plainText(from html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": " "
        ]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text
    }

    static func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
