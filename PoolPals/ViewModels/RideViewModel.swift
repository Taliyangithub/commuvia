//
//  RideViewModel.swift
//  PoolPals
//
//  Created by Priya Taliyan on 2025-12-30.
//


import Foundation
import Combine

final class RideViewModel: ObservableObject {

    @Published var rides: [Ride] = []
    @Published var errorMessage: String?

    // MARK: - Load Rides

    func loadRides() {
        RideService.shared.fetchRides { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let rides):
                    self?.rides = rides
                    self?.errorMessage = nil
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Refresh Helper

    func refresh() {
        loadRides()
    }
}
