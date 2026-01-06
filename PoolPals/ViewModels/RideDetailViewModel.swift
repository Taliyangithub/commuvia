import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

final class RideDetailViewModel: ObservableObject {

    @Published var requests: [RideRequest] = []
    @Published var errorMessage: String?
    @Published var userRequestStatus: RideRequestStatus?
    @Published var userRequestId: String?

    let ride: Ride
    private let currentUserId = Auth.auth().currentUser?.uid

    init(ride: Ride) {
        self.ride = ride
        loadUserRequest()
    }

    var isOwner: Bool {
        ride.ownerId == currentUserId
    }

    // MARK: - User actions

    func requestToJoin() {
        RideService.shared.requestToJoinRide(rideId: ride.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadUserRequest()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func withdrawRequest(requestId: String) {
        RideService.shared.withdrawRequest(
            rideId: ride.id,
            requestId: requestId
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.userRequestStatus = nil
                    self?.userRequestId = nil
                    self?.loadRequests()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Owner actions

    func loadRequests() {
        guard isOwner else { return }

        RideService.shared.fetchRequests(rideId: ride.id) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let requests) = result {
                    self?.loadUserNames(for: requests)
                }
            }
        }
    }

    func approve(requestId: String) {
        RideService.shared.approveRequest(
            rideId: ride.id,
            requestId: requestId
        ) { [weak self] _ in
            self?.loadRequests()
        }
    }

    // MARK: - Helpers

    private func loadUserRequest() {
        guard let userId = currentUserId else { return }

        RideService.shared.fetchUserRequest(
            rideId: ride.id,
            userId: userId
        ) { [weak self] request in
            DispatchQueue.main.async {
                self?.userRequestStatus = request?.status
                self?.userRequestId = request?.id
            }
        }
    }
    private func loadUserNames(for requests: [RideRequest]) {
        let group = DispatchGroup()
        var updated = requests

        for index in updated.indices {
            group.enter()
            let userId = updated[index].userId

            Firestore.firestore()
                .collection("users")
                .document(userId)
                .getDocument { snapshot, _ in
                    if let name = snapshot?.data()?["name"] as? String {
                        updated[index].userName = name
                    }
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            self.requests = updated
        }
    }
    
    @Published var rideDeleted = false

    func deleteRide() {
        RideService.shared.deleteRide(rideId: ride.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.rideDeleted = true
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }



}
