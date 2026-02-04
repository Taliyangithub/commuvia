//
//  AuthViewModel.swift
//  Commuvia
//

import Foundation
import FirebaseAuth
import Combine
import FirebaseCore
import UIKit
import GoogleSignIn

final class AuthViewModel: ObservableObject {

    @Published var isAuthenticated = false
    @Published var isEmailVerified = false
    @Published var currentUserName: String?
    @Published var errorMessage: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        observeAuthState()
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    private func observeAuthState() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user {
                    self?.isAuthenticated = true
                    self?.isEmailVerified = user.isEmailVerified
                    self?.loadCurrentUserProfile()
                } else {
                    self?.isAuthenticated = false
                    self?.isEmailVerified = false
                    self?.currentUserName = nil
                }
            }
        }
    }

    func refreshEmailVerification() {
        Auth.auth().currentUser?.reload { [weak self] _ in
            DispatchQueue.main.async {
                self?.isEmailVerified =
                    Auth.auth().currentUser?.isEmailVerified ?? false
            }
        }
    }

    func signUp(email: String, password: String, name: String) {
        AuthService.shared.signUp(email: email, password: password, name: name) { [weak self] result in
            DispatchQueue.main.async {
                if case let .failure(error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signIn(email: String, password: String) {
        AuthService.shared.signIn(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                if case let .failure(error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadCurrentUserProfile() {
        AuthService.shared.fetchCurrentUser { [weak self] result in
            DispatchQueue.main.async {
                if case let .success(user) = result {
                    self?.currentUserName = user.name
                }
            }
        }
    }
    
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
            if let error = error {
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

    
    func forgotPassword(email: String) {
        AuthService.shared.sendPasswordReset(email: email) { [weak self] result in
            DispatchQueue.main.async {
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
        guard let uid = Auth.auth().currentUser?.uid else { return }

        RideService.shared.deleteAccount(userId: uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    try? AuthService.shared.signOut()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
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
               print("Firebase clientID not found")
               return
           }
        
        GIDSignIn.sharedInstance.configuration =
        GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController
        ) { [weak self] signInResult, error in

            if let error {
                DispatchQueue.main.async {
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
                    DispatchQueue.main.async {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func signOut() {
        try? AuthService.shared.signOut()
    }
}
