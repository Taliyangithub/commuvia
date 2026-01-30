//
//  SettingsView.swift
//  PoolPals
//
//  Created by Priya Taliyan on 2026-01-30.
//


import SwiftUI

struct SettingsView: View {

    @ObservedObject var authViewModel: AuthViewModel
    let onSignOut: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {

                // Profile
                Section("Profile") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(authViewModel.currentUserName ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }

                // Safety
                Section("Safety") {
                    Text("Always meet in public places and confirm ride details before traveling.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                // Legal
                Section("Legal") {
                    Link(
                        "Privacy Policy",
                        destination: URL(string: "https://taliyangithub.github.io/poolPals/privacy-policy.html")!
                    )

                    Link(
                        "Terms of Service",
                        destination: URL(string: "https://taliyangithub.github.io/poolPals/terms.html")!
                    )
                }

                // Account Actions
                Section {
                    Button("Sign Out") {
                        onSignOut()
                    }
                }

                // Delete Account
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete Account")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    authViewModel.deleteAccountAndSignOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action is permanent. Your account and ride data will be deleted.")
            }
        }
    }
}
