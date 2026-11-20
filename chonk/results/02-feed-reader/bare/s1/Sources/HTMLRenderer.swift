// FILE: HTMLRenderer.swift
import Foundation
import UIKit

/// Converts article HTML into an `AttributedString` that SwiftUI can display,
/// using only Foundation/UIKit. Fonts are rescaled relative to the body text,
/// and hard-coded foreground colors are removed so text adapts to dark mode.
enum HTMLRenderer {
    static func attributedString(from html: String) -> AttributedString {
        let wrapped = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            body { font-family: -apple-system, Helvetica, sans-serif; font-size: 17px; line-height: 1.55; }
            img { max-width: 100%; height: auto; }
            blockquote { margin: 8px 0 8px 16px; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """

        guard let data = wrapped.data(using: .utf8) else {
            return AttributedString(html)
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let nsAttributed = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else {
            // Fall back to showing the raw markup as plain text.
            return AttributedString(html)
        }

        let mutable = NSMutableAttributedString(attributedString: nsAttributed)
        let bodyPointSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        let fullRange = NSRange(location: 0, length: mutable.length)

        // The HTML importer defaults to a 12pt font; scale every run so the default
        // becomes the user's preferred body size while keeping relative sizes
        // (headings, captions) intact.
        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let base = value as? UIFont
            let pointSize = base?.pointSize ?? 12
            let scaledSize = max(10, pointSize * bodyPointSize / 12)
            let font = base?.withSize(scaledSize)
                ?? UIFont.preferredFont(forTextStyle: .body)
            mutable.addAttribute(.font, value: font, range: range)
        }

        // Remove hard-coded colors so text follows the system label color (dark-mode safe).
        // Links keep their `.link` attribute and remain tappable in SwiftUI Text.
        mutable.enumerateAttribute(.foregroundColor, in: fullRange) { _, range, _ in
            mutable.removeAttribute(.foregroundColor, range: range)
        }

        return AttributedString(mutable)
    }
}
