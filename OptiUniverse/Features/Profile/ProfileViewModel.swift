//
//  ProfileViewModel.swift
//  OptiUniverse
//
//  Created by max on 04.05.2026.
//

import Foundation
import Observation
import AuthenticationServices

@Observable
final class ProfileViewModel {

    struct AppleAuthData {
        let userId: String
        let email: String?
        let firstName: String?
        let secondName: String?
        let authorizationCodeString: String?
        let tokenString: String?
    }

    private struct SocialAuthRequest: Encodable {
        let provider: String
        let identityToken: String
        let authorizationCode: String
        let nonce: String
        let firstName: String
        let lastName: String
        let email: String

        enum CodingKeys: String, CodingKey {
            case provider
            case identityToken = "identity_token"
            case authorizationCode = "authorization_code"
            case nonce
            case firstName = "first_name"
            case lastName = "last_name"
            case email
        }
    }

    enum AuthenticationError: LocalizedError {
        case missingAuthData
        case missingIdentityToken
        case missingAuthorizationCode
        case invalidResponse
        case invalidResponseData
        case requestFailed(statusCode: Int, responseBody: String)

        var errorDescription: String? {
            switch self {
            case .missingAuthData:
                return "Apple sign-in data is missing."
            case .missingIdentityToken:
                return "Apple identity token is missing."
            case .missingAuthorizationCode:
                return "Apple authorization code is missing."
            case .invalidResponse:
                return "The server returned an invalid response."
            case .invalidResponseData:
                return "The server returned an invalid response data."
            case .requestFailed(let statusCode, let responseBody):
                if responseBody.isEmpty {
                    return "Authentication failed with status code \(statusCode)."
                }

                return "Authentication failed with status code \(statusCode): \(responseBody)"
            }
        }
    }

    private(set) var appleAuthData: AppleAuthData?
    private(set) var appleAuthError: Error?
    private(set) var authenticationResponseBody: String?
    private(set) var isAuthenticating = false

    init(appleAuthData: AppleAuthData? = nil, appleAuthError: Error? = nil) {
        self.appleAuthData = appleAuthData
        self.appleAuthError = appleAuthError
    }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            appleAuthData = AppleAuthData(
                userId: credential.user,
                email: credential.email,
                firstName: credential.fullName?.givenName,
                secondName: credential.fullName?.familyName,
                authorizationCodeString: credential.authorizationCode
                    .flatMap { String(data: $0, encoding: .utf8) },
                tokenString: credential.identityToken
                    .flatMap { String(data: $0, encoding: .utf8) }
            )
        case .failure(let error):
            appleAuthError = error
        }
    }

    func authenticate() {
        Task {
            do {
                try await authenticateWithBackend()
            } catch {
                appleAuthError = error
            }
        }
    }

    private func authenticateWithBackend() async throws {
        guard let appleAuthData else {
            throw AuthenticationError.missingAuthData
        }

        guard let tokenString = appleAuthData.tokenString, !tokenString.isEmpty else {
            throw AuthenticationError.missingIdentityToken
        }

        guard let authorizationCodeString = appleAuthData.authorizationCodeString,
              !authorizationCodeString.isEmpty else {
            throw AuthenticationError.missingAuthorizationCode
        }

        let payload = SocialAuthRequest(
            provider: "apple",
            identityToken: tokenString,
            authorizationCode: authorizationCodeString,
            nonce: "",
            firstName: appleAuthData.firstName ?? "",
            lastName: appleAuthData.secondName ?? "",
            email: appleAuthData.email ?? ""
        )

        var request = URLRequest(url: URL(string: "https://api.kb404.com/api/v1/auth/social/")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        appleAuthError = nil
        authenticationResponseBody = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.invalidResponse
        }

        guard let responseBody = String(bytes: data, encoding: .utf8) else {
            throw AuthenticationError.invalidResponseData
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AuthenticationError.requestFailed(
                statusCode: httpResponse.statusCode,
                responseBody: responseBody
            )
        }

        authenticationResponseBody = responseBody
    }
}
