import SwiftUI

struct RideDetailView: View {

    @StateObject private var viewModel: RideDetailViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Report Ride
    @State private var showReportConfirm = false
    @State private var showReportSuccess = false

    init(ride: Ride, authViewModel: AuthViewModel) {
        _viewModel = StateObject(wrappedValue: RideDetailViewModel(ride: ride))
        self.authViewModel = authViewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 6) {
                        Text(viewModel.ride.route)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Posted by \(viewModel.ride.ownerName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Ride Card
                    VStack(alignment: .leading, spacing: 12) {

                        infoRow(title: "Start", value: viewModel.ride.startLocationName)
                        infoRow(title: "End", value: viewModel.ride.endLocationName)

                        Divider()

                        infoRow(
                            title: "Departure",
                            value: viewModel.ride.startDateTime.formatted(
                                .dateTime.day().month().hour().minute()
                            )
                        )

                        infoRow(
                            title: "Seats Available",
                            value: "\(viewModel.ride.seatsAvailable)"
                        )

                        infoRow(
                            title: "Car",
                            value: "\(viewModel.ride.carModel) • \(viewModel.ride.carNumber)"
                        )
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

                    // Chat
                    if viewModel.canAccessChat {
                        NavigationLink {
                            RideChatView(
                                ride: viewModel.ride,
                                currentUserName: authViewModel.currentUserName ?? "Unknown"
                            )
                        } label: {
                            Label("Open Ride Chat", systemImage: "message")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("Chat is available after your request is approved.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }


                    // Actions
                    if viewModel.isOwner {
                        ownerSection
                    } else {
                        riderSection

                        // Report Ride (Non-owner only)
                        Button(role: .destructive) {
                            showReportConfirm = true
                        } label: {
                            Text("Report Ride")
                                .font(.footnote)
                        }
                        .padding(.top, 8)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Ride Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                viewModel.loadRequests()
            }
            .onChange(of: viewModel.rideDeleted) { _, deleted in
                if deleted { dismiss() }
            }

            // Report Confirmation
            .confirmationDialog(
                "Report Ride",
                isPresented: $showReportConfirm,
                titleVisibility: .visible
            ) {
                Button("Report for Safety Concern", role: .destructive) {
                    RideService.shared.reportRide(
                        ride: viewModel.ride,
                        reason: "Safety concern"
                    ) { _ in
                        showReportSuccess = true
                    }
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Reports are reviewed to help keep the community safe.")
            }

            // Report Success
            .alert(
                "Report Submitted",
                isPresented: $showReportSuccess
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Thank you for helping keep Commuvia safe.")
            }
        }
    }

    // MARK: - Rider Section
    private var riderSection: some View {
        VStack(spacing: 12) {
            if viewModel.ride.seatsAvailable <= 0 {
                Text("No seats available")
                    .foregroundColor(.secondary)

            } else if let status = viewModel.userRequestStatus {
                Text("Request status: \(status.rawValue.capitalized)")
                    .foregroundColor(.secondary)

                Button("Withdraw Request") {
                    viewModel.withdrawRequest()
                }

            } else {
                Button("Request to Join") {
                    viewModel.requestToJoin()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Owner Section
    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Update Seats
            VStack(alignment: .leading, spacing: 8) {
                Text("Seats Available")
                    .font(.headline)

                Stepper(
                    value: Binding(
                        get: { viewModel.ride.seatsAvailable },
                        set: { newValue in
                            viewModel.updateSeats(to: newValue)
                        }
                    ),
                    in: 0...20
                ) {
                    Text("\(viewModel.ride.seatsAvailable) seats")
                }

                Text("Seats cannot be reduced below the number of approved riders.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Delete Ride
            Button(role: .destructive) {
                viewModel.deleteRide()
            } label: {
                Label("Delete Ride", systemImage: "trash")
            }

            // Requests
            if !viewModel.requests.isEmpty {
                Text("Requests")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(viewModel.requests) { request in
                        HStack {
                            Text(request.userName ?? request.userId)
                                .font(.subheadline)

                            Spacer()

                            if request.status == .pending {
                                Button("Approve") {
                                    viewModel.approve(requestId: request.id)
                                }
                            } else if request.status == .approved {
                                Button(role: .destructive) {
                                    viewModel.removeRider(requestId: request.id)
                                } label: {
                                    Text("Remove")
                                }
                            } else {
                                Text(request.status.rawValue.capitalized)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Helper
    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

