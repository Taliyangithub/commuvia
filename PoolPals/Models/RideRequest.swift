import Foundation

struct RideRequest: Identifiable {
    let id: String
    let userId: String
    let status: RideRequestStatus
    var userName: String?
}
