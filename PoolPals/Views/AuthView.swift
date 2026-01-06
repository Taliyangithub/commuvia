//
//  AuthView.swift
//  PoolPals
//
//  Created by Priya Taliyan on 2025-12-30.
//


import SwiftUI

struct AuthView: View {
    
    @ObservedObject var viewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoginMode = true
    
    var body: some View {
        VStack(spacing: 16) {
            
            Text(isLoginMode ? "Sign In" : "Create Account")
                .font(.title)
            
            if !isLoginMode {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button {
                if isLoginMode {
                    viewModel.signIn(
                        email: email,
                        password: password
                    )
                } else {
                    viewModel.signUp(
                        email: email,
                        password: password,
                        name: name
                    )
                }
            } label: {
                Text(isLoginMode ? "Sign In" : "Sign Up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button {
                isLoginMode.toggle()
            } label: {
                Text(
                    isLoginMode
                    ? "Need an account?"
                    : "Already have an account?"
                )
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}
