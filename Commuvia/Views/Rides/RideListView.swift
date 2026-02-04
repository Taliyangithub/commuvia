import SwiftUI

struct RideListView: View {

    // ViewModels
    @StateObject private var viewModel = RideViewModel()
    @ObservedObject var authViewModel: AuthViewModel

    // Pending requests flag
    @State private var hasPendingRequests = false

    // Logout confirmation
    @State private var showLogoutConfirm = false

    // Safety Notice
    @AppStorage("hasSeenSafetyNotice") private var hasSeenSafetyNotice = false
    @State private var showSafetyNotice = false

    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            List {

                if viewModel.visibleRides.isEmpty {
                    ContentUnavailableView(
                        "No rides available",
                        systemImage: "car",
                        description: Text("Create a ride or join one.")
                    )
                } else {
                    ForEach(viewModel.visibleRides) { ride in
                        NavigationLink {
                            RideDetailView(
                                ride: ride,
                                authViewModel: authViewModel
                            )
                        } label: {
                            RideRowView(ride: ride)
                        }
                    }
                }
            }
            .navigationTitle("My Rides")
            .toolbar {

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {

                        NavigationLink("Search") {
                            RideSearchView(authViewModel: authViewModel)
                        }

                        if hasPendingRequests {
                            NavigationLink("Pending Requests") {
                                PendingRequestsView()
                            }
                        }

                        NavigationLink("Post Ride") {
                            CreateRideView(
                                ownerName: authViewModel.currentUserName ?? "Unknown"
                            ) {
                                viewModel.loadRides()
                                loadPendingFlag()
                            }
                        }

                        NavigationLink("Settings") {
                            SettingsView(
                                authViewModel: authViewModel,
                                onSignOut: onSignOut
                            )
                        }

                        Divider()

                        //Logout directly from My Rides
                        Button(role: .destructive) {
                            showLogoutConfirm = true
                        } label: {
                            Label("Sign Out", systemImage: "arrow.backward.square")
                        }

                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .onAppear {
                viewModel.loadRides()
                loadPendingFlag()

                if !hasSeenSafetyNotice {
                    showSafetyNotice = true
                }
            }
            .onChange(of: authViewModel.isAuthenticated) { _, isAuth in
                if isAuth {
                    loadPendingFlag()
                }
            }
            .sheet(isPresented: $showSafetyNotice) {
                SafetyNoticeView {
                    hasSeenSafetyNotice = true
                    showSafetyNotice = false
                }
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    onSignOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    // MARK: - Helpers

    private func loadPendingFlag() {
        guard let uid = AuthService.shared.currentUserId() else { return }

        RideService.shared.hasActivePendingRequests(userId: uid) { hasPending in
            DispatchQueue.main.async {
                self.hasPendingRequests = hasPending
            }
        }
    }
}
