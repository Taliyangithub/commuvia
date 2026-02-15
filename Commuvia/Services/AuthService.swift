//
//  AuthService.swift
//  Commuvia
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {

    static let shared = AuthService()

    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    private init() {}

    //Sign Up

    func signUp(
        email: String,
        password: String,
        name: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        auth.createUser(withEmail: email, password: password) { result, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let user = result?.user else {
                completion(.failure(NSError(domain: "AuthError", code: -1)))
                return
            }

            let userData: [String: Any] = [
                "email": email,
                "name": name
            ]

            self.db.collection("users")
                .document(user.uid)
                .setData(userData) { error in
                    if let error {
                        completion(.failure(error))
                    } else {
                        user.sendEmailVerification()
                        completion(.success(()))
                    }
                }
        }
    }

    //Sign In

    func signIn(
        email: String,
        password: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        auth.signIn(withEmail: email, password: password) { _, error in
            error == nil
                ? completion(.success(()))
                : completion(.failure(error!))
        }
    }
    // get current userid
    func currentUserId() -> String? {
        auth.currentUser?.uid
    }

    
    //Sign Out

    func signOut() throws {
        try auth.signOut()
    }

    //Email Verification

    func sendEmailVerification(
        completion: ((Error?) -> Void)? = nil
    ) {
        auth.currentUser?.sendEmailVerification(completion: completion)
    }

    func isEmailVerified() -> Bool {
        auth.currentUser?.isEmailVerified ?? false
    }

    //User Profile

    func fetchCurrentUser(
        completion: @escaping (Result<AppUser, Error>) -> Void
    ) {
        guard let uid = auth.currentUser?.uid else {
            completion(.failure(NSError(domain: "AuthError", code: -1)))
            return
        }

        db.collection("users")
            .document(uid)
            .getDocument { snapshot, error in

                if let error {
                    completion(.failure(error))
                    return
                }

                guard
                    let data = snapshot?.data(),
                    let email = data["email"] as? String,
                    let name = data["name"] as? String
                else {
                    completion(.failure(NSError(domain: "UserParseError", code: -1)))
                    return
                }

                completion(.success(
                    AppUser(id: uid, email: email, name: name)
                ))
            }
    }

    func fetchUserName(
        userId: String,
        completion: @escaping (String?) -> Void
    ) {
        db.collection("users")
            .document(userId)
            .getDocument { snapshot, _ in
                completion(snapshot?.data()?["name"] as? String)
            }
    }

    //Terms

    func hasAcceptedTerms(
        completion: @escaping (Bool) -> Void
    ) {
        guard let uid = auth.currentUser?.uid else {
            completion(false)
            return
        }

        db.collection("users")
            .document(uid)
            .getDocument { snap, _ in
                completion(snap?.data()?["termsAccepted"] as? Bool ?? false)
            }
    }

    //Delete Auth User
    
    func deleteAuthUser(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let user = auth.currentUser else {
            completion(.failure(NSError(domain: "Auth", code: -1)))
            return
        }

        user.delete { error in
            if let error = error as NSError? {

                // Requires recent login
                if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    completion(.failure(error))
                    return
                }

                completion(.failure(error))
                return
            }

            completion(.success(()))
        }
    }

    
    //Change Password

    func changePassword(
        currentPassword: String,
        newPassword: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let user = auth.currentUser,
              let email = user.email else {
            completion(.failure(NSError(domain: "AuthError", code: -1)))
            return
        }

        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: currentPassword
        )

        // Re-authenticate (required by Firebase)
        user.reauthenticate(with: credential) { _, error in
            if let error {
                completion(.failure(error))
                return
            }

            user.updatePassword(to: newPassword) { error in
                error == nil
                    ? completion(.success(()))
                    : completion(.failure(error!))
            }
        }
    }
    
    func sendPasswordReset(
        email: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        auth.sendPasswordReset(withEmail: email) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }


}
