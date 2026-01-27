//
//  CreateRideView.swift
//  PoolPals
//

import SwiftUI
import MapKit

struct CreateRideView: View {

    @Environment(\.dismiss) private var dismiss

    // MARK: - Ride Inputs
    @State private var route: String = ""
    @State private var startLocationName: String = ""
    @State private var endLocationName: String = ""

    @State private var time: Date = Date()
    @State private var seatsAvailable: Int = 1

    // MARK: - Car Details
    @State private var carNumber: String = ""
    @State private var carModel: String = ""

    // MARK: - State
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    let ownerName: String
    let onRideCreated: () -> Void

    // MARK: - UI
    var body: some View {
        NavigationStack {
            Form {

                Section(header: Text("Route")) {
                    TextField("Short route description", text: $route)
                }

                Section(header: Text("Locations")) {
                    TextField("Start location", text: $startLocationName)
                    TextField("End location", text: $endLocationName)
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

                Section(header: Text("Car Details")) {
                    TextField("Car Model", text: $carModel)
                    TextField("Car Number", text: $carNumber)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }

                Button(isSubmitting ? "Posting..." : "Post Ride") {
                    createRide()
                }
                .disabled(
                    isSubmitting ||
                    route.isEmpty ||
                    startLocationName.isEmpty ||
                    endLocationName.isEmpty ||
                    carModel.isEmpty ||
                    carNumber.isEmpty
                )
            }
            .navigationTitle("Post Ride")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Create Ride Logic

    private func createRide() {
        errorMessage = nil
        isSubmitting = true

        Task {
            do {
                let coordinate = try await resolveLocation(name: startLocationName)

                RideService.shared.createRide(
                    route: route,
                    time: time,
                    seatsAvailable: seatsAvailable,
                    carNumber: carNumber,
                    carModel: carModel,
                    ownerName: ownerName,
                    startLocationName: startLocationName,
                    endLocationName: endLocationName,
                    startLatitude: coordinate.latitude,
                    startLongitude: coordinate.longitude
                ) { result in
                    DispatchQueue.main.async {
                        isSubmitting = false
                        switch result {
                        case .success:
                            onRideCreated()
                            dismiss()
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Unable to find start location"
                    isSubmitting = false
                }
            }
        }
    }

    // MARK: - MapKit Location Resolver (iOS 26 Safe)

    private func resolveLocation(name: String) async throws -> CLLocationCoordinate2D {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let coordinate = response.mapItems.first?.location.coordinate else {
            throw NSError(domain: "LocationError", code: 0)
        }

        return coordinate
    }
}
