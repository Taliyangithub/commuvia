//
//  AuthViewModel.swift
//  Commuvia
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import FirebaseCore
import UIKit
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: NSObject, ObservableObject {

    @Published var isAuthenticated = false
    @Published var isEmailVerified = false
    @Published var hasAcceptedTerms = false
    @Published var currentUserName: String?
    @Published var errorMessage: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    // Sign in with Apple state
    private var currentNonce: String?

    override init() {
        super.init()
        observeAuthState()
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    private func observeAuthState() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                if let user {
                    self.isAuthenticated = true
                    self.isEmailVerified = user.isEmailVerified
                    self.loadCurrentUserProfile()
                    self.refreshTermsStatus()
                    SafetyState.shared.start()

                } else {
                    self.isAuthenticated = false
                    self.isEmailVerified = false
                    self.currentUserName = nil
                }
            }
        }
    }

    func refreshEmailVerification() {
        Auth.auth().currentUser?.reload { [weak self] _ in
            Task { @MainActor in
                self?.isEmailVerified = Auth.auth().currentUser?.isEmailVerified ?? false
            }
        }
    }

    func refreshTermsStatus() {
        AuthService.shared.hasAcceptedTerms { [weak self] accepted in
            Task { @MainActor in
                self?.hasAcceptedTerms = accepted
            }
        }
    }

    func signUp(email: String, password: String, name: String) {
        AuthService.shared.signUp(email: email, password: password, name: name) { [weak self] result in
            Task { @MainActor in
                if case let .failure(error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signIn(email: String, password: String) {
        AuthService.shared.signIn(email: email, password: password) { [weak self] result in
            Task { @MainActor in
                if case let .failure(error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signOut() {
        try? AuthService.shared.signOut()
        SafetyState.shared.stop()
    }


    // MARK: - Profile

    private func loadCurrentUserProfile() {
        AuthService.shared.fetchCurrentUser { [weak self] result in
            Task { @MainActor in
                if case let .success(user) = result {
                    self?.currentUserName = user.name
                }
            }
        }
    }

    func forgotPassword(email: String) {
        AuthService.shared.sendPasswordReset(email: email) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.errorMessage =
                        "Password reset email sent. If you reset your password, your email will be verified automatically."
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func deleteAccountAndSignOut() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid

        // Step 1: Delete Firestore data
        RideService.shared.deleteAccount(userId: uid) { [weak self] result in
            Task { @MainActor in
                switch result {

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription

                case .success:

                    // Step 2: Try deleting Auth user
                    AuthService.shared.deleteAuthUser { authResult in
                        Task { @MainActor in
                            switch authResult {

                            case .success:
                                try? AuthService.shared.signOut()
                                SafetyState.shared.stop()

                            case .failure(let error as NSError):

                                // If recent login required → force logout and show message
                                if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                                    try? AuthService.shared.signOut()
                                    SafetyState.shared.stop()

                                    self?.errorMessage =
                                    "For security reasons, please sign in again and delete your account once more to complete permanent removal."
                                } else {
                                    self?.errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                }
            }
        }
    }



    // Google Sign-In (kept)

    func signInWithGoogle() {
        guard
            let rootViewController = UIApplication.shared
                .connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        else {
            return
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            self.errorMessage = "Firebase clientID not found"
            return
        }

        GIDSignIn.sharedInstance.configuration =
        GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController
        ) { [weak self] signInResult, error in

            if let error {
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
                return
            }

            guard
                let user = signInResult?.user,
                let idToken = user.idToken?.tokenString
            else {
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { _, error in
                if let error {
                    Task { @MainActor in
                        self?.errorMessage = error.localizedDescription
                    }
                    return
                }

                Task { @MainActor in
                    self?.ensureUserDocumentExistsAfterFederatedLogin()
                }
            }
        }
    }

    // MARK: - Sign in with Apple (Guideline 4.8 fix)

    func startSignInWithApple() {
        errorMessage = nil

        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func ensureUserDocumentExistsAfterFederatedLogin() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        userRef.getDocument { snap, _ in
            if snap?.exists == true { return }

            // Minimal profile fields only: name + email (per review)
            let name = user.displayName ?? "User"
            let email = user.email ?? ""

            userRef.setData([
                "name": name,
                "email": email,
                "createdAt": FieldValue.serverTimestamp()
            ]) { _ in }
        }
    }

    // MARK: - Change Password (kept)

    func changePassword(
        currentPassword: String,
        newPassword: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            completion(.failure(NSError(domain: "Auth", code: -1)))
            return
        }

        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: currentPassword
        )

        user.reauthenticate(with: credential) { _, error in
            if let error {
                completion(.failure(error))
                return
            }

            user.updatePassword(to: newPassword) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}

// MARK: - Apple Sign-In Delegates

extension AuthViewModel: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            self.errorMessage = "Apple Sign-In failed"
            return
        }

        guard let nonce = currentNonce else {
            self.errorMessage = "Invalid state: no login request was sent."
            return
        }

        guard let appleIDToken = appleIDCredential.identityToken else {
            self.errorMessage = "Unable to fetch identity token"
            return
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            self.errorMessage = "Unable to serialize token string"
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                // If Apple provides name on first login, set displayName
                if let name = appleIDCredential.fullName?.givenName {
                    let family = appleIDCredential.fullName?.familyName ?? ""
                    let full = ([name, family].filter { !$0.isEmpty }).joined(separator: " ")

                    if !full.isEmpty {
                        let change = authResult?.user.createProfileChangeRequest()
                        change?.displayName = full
                        change?.commitChanges { _ in }
                    }
                }

                self?.ensureUserDocumentExistsAfterFederatedLogin()
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        self.errorMessage = error.localizedDescription
    }
}

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? UIWindow()
    }
}

// MARK: - Nonce helpers

extension AuthViewModel {

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
