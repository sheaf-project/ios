import AuthenticationServices
import UIKit

enum PasskeyError: LocalizedError {
    case cancelled
    case notAssociated
    case malformedOptions
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .notAssociated:
            return String(localized: "This server hasn't approved this app for passkeys. Its operator needs to add the app to PASSKEY_IOS_APPS, and the app has to be built with the server's domain.")
        case .malformedOptions:
            return String(localized: "The server sent passkey options that could not be read.")
        case .failed(let msg):
            return msg
        }
    }
}

/// Runs the platform passkey ceremonies and translates between the WebAuthn
/// JSON the server speaks and AuthenticationServices. The options and the
/// credential are passed around as plain dictionaries so nothing re-encodes
/// a number on the way through.
@MainActor
final class PasskeyAuthenticator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private var controller: ASAuthorizationController?

    /// `navigator.credentials.create()` options in, `PublicKeyCredential.toJSON()` out.
    func register(options: [String: Any]) async throws -> [String: Any] {
        guard let rp = options["rp"] as? [String: Any],
              let rpID = rp["id"] as? String,
              let challenge = (options["challenge"] as? String).flatMap(Data.init(base64URL:)),
              let user = options["user"] as? [String: Any],
              let userID = (user["id"] as? String).flatMap(Data.init(base64URL:)),
              let name = user["name"] as? String else {
            throw PasskeyError.malformedOptions
        }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpID)
        let request = provider.createCredentialRegistrationRequest(challenge: challenge, name: name, userID: userID)
        request.userVerificationPreference = .required

        let auth = try await perform(request)
        guard let cred = auth.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
              let attestation = cred.rawAttestationObject else {
            throw PasskeyError.failed(String(localized: "Couldn't create a passkey"))
        }
        let id = cred.credentialID.base64URL
        return [
            "id": id,
            "rawId": id,
            "type": "public-key",
            "authenticatorAttachment": "platform",
            "clientExtensionResults": [String: Any](),
            "response": [
                "clientDataJSON": cred.rawClientDataJSON.base64URL,
                "attestationObject": attestation.base64URL,
                "transports": ["internal"],
            ] as [String: Any],
        ]
    }

    /// `navigator.credentials.get()` options in, `PublicKeyCredential.toJSON()` out.
    func assert(options: [String: Any]) async throws -> [String: Any] {
        guard let rpID = options["rpId"] as? String,
              let challenge = (options["challenge"] as? String).flatMap(Data.init(base64URL:)) else {
            throw PasskeyError.malformedOptions
        }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpID)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.userVerificationPreference = .required

        let auth = try await perform(request)
        guard let cred = auth.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyError.failed(String(localized: "Couldn't use a passkey"))
        }
        let id = cred.credentialID.base64URL
        var response: [String: Any] = [
            "clientDataJSON": cred.rawClientDataJSON.base64URL,
            "authenticatorData": cred.rawAuthenticatorData.base64URL,
            "signature": cred.signature.base64URL,
        ]
        if !cred.userID.isEmpty { response["userHandle"] = cred.userID.base64URL }
        return [
            "id": id,
            "rawId": id,
            "type": "public-key",
            "authenticatorAttachment": "platform",
            "clientExtensionResults": [String: Any](),
            "response": response,
        ]
    }

    private func perform(_ request: ASAuthorizationRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            let c = ASAuthorizationController(authorizationRequests: [request])
            c.delegate = self
            c.presentationContextProvider = self
            controller = c
            c.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            continuation?.resume(returning: authorization)
            continuation = nil
            self.controller = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: Self.translate(error))
            continuation = nil
            self.controller = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let windows = scenes.flatMap { $0.windows }
            return windows.first { $0.isKeyWindow } ?? windows.first ?? ASPresentationAnchor()
        }
    }

    private static func translate(_ error: Error) -> Error {
        if let e = error as? ASAuthorizationError {
            switch e.code {
            case .canceled:
                return PasskeyError.cancelled
            case .failed, .unknown:
                let text = e.localizedDescription.lowercased()
                if text.contains("associated") || text.contains("webcredentials") {
                    return PasskeyError.notAssociated
                }
            default:
                break
            }
        }
        return PasskeyError.failed(error.localizedDescription)
    }
}

extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL: String) {
        var s = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        self.init(base64Encoded: s)
    }
}
