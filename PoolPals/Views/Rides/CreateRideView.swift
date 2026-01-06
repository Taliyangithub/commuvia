//
//  CreateRideView.swift
//  PoolPals
//
//  Created by Priya Taliyan on 2025-12-31.
//


import SwiftUI

struct CreateRideView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var route: String = ""
    @State private var time: Date = Date()
    @State private var seatsAvailable: Int = 1
    @State private var errorMessage: String?

    let onRideCreated: () -> Void

    var body: some View {
        Form {

            Section(header: Text("Route")) {
                TextField("Enter route", text: $route)
            }

            Section(header: Text("Time")) {
                DatePicker(
                    "Departure Time",
                    selection: $time,
                    displayedComponents: .hourAndMinute
                )
            }

            Section(header: Text("Seats")) {
                Stepper(value: $seatsAvailable, in: 1...6) {
                    Text("Seats Available: \(seatsAvailable)")
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            Button("Post Ride") {
                createRide()
            }
            .disabled(route.isEmpty)
        }
        .navigationTitle("Post Ride")
    }

    private func createRide() {
        RideService.shared.createRide(
            route: route,
            time: time,
            seatsAvailable: seatsAvailable
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    onRideCreated()
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
