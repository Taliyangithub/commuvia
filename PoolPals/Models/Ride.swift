//
//  Ride.swift
//  PoolPals
//
//  Created by Priya Taliyan on 2025-12-30.
//


import Foundation

struct Ride: Identifiable {
    let id: String
    let ownerId: String
    let route: String
    let time: Date
    let seatsAvailable: Int
}
