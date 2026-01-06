import SwiftUI

struct ContentView: View {

    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                RideListView(
                    onSignOut: authViewModel.signOut
                )
            } else {
                AuthView(viewModel: authViewModel)
            }
        }
    }
}

