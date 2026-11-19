// FILE: FeedError.swift
import Foundation

enum FeedError: LocalizedError, Sendable {
    case unexpectedResponse
    case httpStatus(Int)
    case invalidData(underlying: String)

    var errorDescription: String? {
        switch self {
        case .unexpectedResponse:
            return "The feed sent a response that could not be understood."
        case .httpStatus(let statusCode):
            return "The feed server returned an error (status \(statusCode))."
        case .invalidData:
            return "The feed data could not be parsed."
        }
    }
}
