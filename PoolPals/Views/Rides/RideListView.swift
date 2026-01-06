//
//  RideListView.swift
//  PoolPals
//
//  Created by Priya Taliyan on 2025-12-30.
//


import SwiftUI

struct RideListView: View {

    @StateObject private var viewModel = RideViewModel()
    let onSignOut: () -> Void

    var body: some View {
        NavigationView {
            List(viewModel.rides) { ride in
                NavigationLink {
                    RideDetailView(ride: ride)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ride.route)
                            .font(.headline)

                        Text("Seats: \(ride.seatsAvailable)")
                            .font(.subheadline)

                        Text(ride.time, style: .time)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Available Rides")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out") {
                        onSignOut()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Post Ride") {
                        CreateRideView {
                            viewModel.loadRides()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadRides()
            }
        }
    }
}
