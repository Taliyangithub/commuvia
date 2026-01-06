import Foundation
import FirebaseAuth
import Combine

final class AuthViewModel: ObservableObject {
    
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    
    init() {
        self.isAuthenticated = Auth.auth().currentUser != nil
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, name: String) {
        AuthService.shared.signUp(
            email: email,
            password: password,
            name: name
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isAuthenticated = true
                    self?.errorMessage = nil
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) {
        AuthService.shared.signIn(
            email: email,
            password: password
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isAuthenticated = true
                    self?.errorMessage = nil
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try AuthService.shared.signOut()
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
