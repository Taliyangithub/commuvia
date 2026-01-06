import SwiftUI

struct RideDetailView: View {

    @StateObject private var viewModel: RideDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(ride: Ride) {
        _viewModel = StateObject(
            wrappedValue: RideDetailViewModel(ride: ride)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            
            Text(viewModel.ride.route)
                .font(.title2)
            
            Text("Seats available: \(viewModel.ride.seatsAvailable)")
            Text(viewModel.ride.time, style: .time)
            
            if viewModel.isOwner {
                ownerSection
            } else {
                nonOwnerSection
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Ride Details")
        .onAppear {
            viewModel.loadRequests()
        }
        .onChange(of: viewModel.rideDeleted) { _, deleted in
            if deleted {
                dismiss()
            }
        }
    }

    // MARK: - Non Owner (Requester)

    private var nonOwnerSection: some View {
        Group {
            if viewModel.ride.seatsAvailable <= 0 {
                Text("No seats available")
                    .foregroundColor(.gray)
            }
            else if let status = viewModel.userRequestStatus,
                    let requestId = viewModel.userRequestId {

                VStack(spacing: 8) {
                    Text("Request status: \(status.rawValue.capitalized)")
                        .foregroundColor(.gray)

                    if status == .pending {
                        Button("Withdraw Request") {
                            viewModel.withdrawRequest(requestId: requestId)
                        }
                    }
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
        VStack(alignment: .leading, spacing: 12) {

            Button(role: .destructive) {
                viewModel.deleteRide()
            } label: {
                Text("Delete Ride")
            }

            Text("Requests")
                .font(.headline)

            List(viewModel.requests) { request in
                HStack {
                    Text(request.userName ?? request.userId)
                        .font(.caption)

                    Spacer()

                    if request.status == .pending {
                        Button("Approve") {
                            viewModel.approve(requestId: request.id)
                        }
                    } else if request.status == .approved {
                        Button("Remove") {
                            viewModel.withdrawRequest(requestId: request.id)
                        }
                    } else {
                        Text(request.status.rawValue.capitalized)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

