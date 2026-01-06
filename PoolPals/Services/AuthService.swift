//
//  AuthService.swift
//  PoolPals
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {

    static let shared = AuthService()

    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Sign Up

    func signUp(
        email: String,
        password: String,
        name: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        auth.createUser(withEmail: email, password: password) { result, error in

            if let error = error {
                print("🔥 FIREBASE SIGNUP ERROR:", error.localizedDescription)
                completion(.failure(error))
                return
            }

            guard let userId = result?.user.uid else {
                completion(.failure(NSError(domain: "AuthError", code: -1)))
                return
            }

            let userData: [String: Any] = [
                "email": email,
                "name": name
            ]

            self.db.collection("users")
                .document(userId)
                .setData(userData) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
        }
    }

    // MARK: - Sign In

    func signIn(
        email: String,
        password: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        auth.signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                print("🔥 FIREBASE SIGNIN ERROR:", error.localizedDescription)
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        try auth.signOut()
    }

    // MARK: - Current User

    func currentUserId() -> String? {
        auth.currentUser?.uid
    }
}

