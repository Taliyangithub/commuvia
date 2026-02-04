//
//  RideDetailViewModel.swift
//  Commuvia
//

import Foundation
import Combine
import FirebaseAuth

final class RideDetailViewModel: ObservableObject {

    //Published State

    @Published var ride: Ride
    @Published var requests: [RideRequest] = []
    @Published var errorMessage: String?
    @Published var userRequestStatus: RideRequestStatus?
    @Published var userRequestId: String?
    @Published var rideDeleted: Bool = false

    //Current User

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var canAccessChat: Bool {
        isOwner || userRequestStatus == .approved
    }

    var isOwner: Bool {
        ride.ownerId == currentUserId
    }

    //Init

    init(ride: Ride) {
        self.ride = ride
        loadUserRequest()
    }

    //Rider Actions

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

    func withdrawRequest() {
        guard let requestId = userRequestId else { return }

        RideService.shared.removeUserFromRide(
            rideId: ride.id,
            requestId: requestId
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.userRequestStatus = nil
                    self?.userRequestId = nil
                    self?.loadRequests()
                    self?.refreshRide()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    
    func removeRider(requestId: String) {
        RideService.shared.removeUserFromRide(
            rideId: ride.id,
            requestId: requestId
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadRequests()
                    self?.refreshRide()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }


    // MARK: - Owner Actions

    func loadRequests() {
        guard isOwner else { return }

        RideService.shared.fetchRequests(rideId: ride.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let requests):
                    self?.requests = requests
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func approve(requestId: String) {
        RideService.shared.approveRequest(
            rideId: ride.id,
            requestId: requestId
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadRequests()
                    self?.refreshRide()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
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

    private func refreshRide() {
        RideService.shared.fetchRides { [weak self] result in
            guard let self else { return }

            if case let .success(rides) = result,
               let updatedRide = rides.first(where: { $0.id == self.ride.id }) {
                DispatchQueue.main.async {
                    self.ride = updatedRide
                }
            }
        }
    }

    //Delete Ride

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
    
    func updateSeats(to newSeats: Int) {
        RideService.shared.updateSeatsAvailable(
            rideId: ride.id,
            newSeatsAvailable: newSeats
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.refreshRide()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

}
