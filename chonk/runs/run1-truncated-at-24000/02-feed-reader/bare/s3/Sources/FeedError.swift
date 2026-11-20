// FILE: FeedError.swift
import Foundation

enum FeedError: LocalizedError {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case decodingFailed
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The feed URL is invalid."
        case .invalidResponse(let statusCode):
            return "The server returned an unexpected status code (\(statusCode))."
        case .decodingFailed:
            return "The feed could not be decoded. Check that it is valid JSON Feed."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}
