//
//  AuthView.swift
//  Commuvia
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {

    @ObservedObject var viewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoginMode = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .padding(.top, 40)

                Text(isLoginMode ? "Sign In" : "Create Account")
                    .font(.title)

                if !isLoginMode {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                Button {
                    if isLoginMode {
                        viewModel.signIn(email: email, password: password)
                    } else {
                        viewModel.signUp(email: email, password: password, name: name)
                    }
                } label: {
                    Text(isLoginMode ? "Sign In" : "Sign Up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    isLoginMode.toggle()
                } label: {
                    Text(isLoginMode ? "Need an account?" : "Already have an account?")
                }

                NavigationLink("Forgot Password?") {
                    ForgotPasswordView(authViewModel: viewModel)
                }
                .font(.footnote)
                .foregroundStyle(.red)

                Divider()
                    .padding(.vertical, 8)

                
                GoogleSignInButtonView()
                    .frame(height: 48)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray3), lineWidth: 1)
                    )
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.signInWithGoogle()
                    }
                
                // Sign in with Apple
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { _ in
                        viewModel.startSignInWithApple()
                    },
                    onCompletion: { _ in }
                )
                .frame(height: 48)


                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 10)
            }
            .padding()
        }
    }
}
