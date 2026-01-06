import Foundation
import FirebaseFirestore
import FirebaseAuth

final class RideService {

    static let shared = RideService()
    private let db = Firestore.firestore()
    private init() {}

    // MARK: - Create Ride

    func createRide(
        route: String,
        time: Date,
        seatsAvailable: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "AuthError", code: -1)))
            return
        }

        let data: [String: Any] = [
            "ownerId": userId,
            "route": route,
            "time": Timestamp(date: time),
            "seatsAvailable": max(seatsAvailable, 0)
        ]

        db.collection("rides").addDocument(data: data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Fetch Rides

    func fetchRides(
        completion: @escaping (Result<[Ride], Error>) -> Void
    ) {
        db.collection("rides")
            .order(by: "time", descending: false)
            .getDocuments { snapshot, error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                let rides = snapshot?.documents.compactMap { doc -> Ride? in
                    let data = doc.data()
                    guard
                        let ownerId = data["ownerId"] as? String,
                        let route = data["route"] as? String,
                        let time = (data["time"] as? Timestamp)?.dateValue(),
                        let seats = data["seatsAvailable"] as? Int
                    else { return nil }

                    return Ride(
                        id: doc.documentID,
                        ownerId: ownerId,
                        route: route,
                        time: time,
                        seatsAvailable: seats
                    )
                } ?? []

                completion(.success(rides))
            }
    }

    // MARK: - Request to Join (Duplicate Safe)

    func requestToJoinRide(
        rideId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "AuthError", code: -1)))
            return
        }

        db.collection("rides")
            .document(rideId)
            .collection("requests")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                if !(snapshot?.documents.isEmpty ?? true) {
                    completion(.failure(
                        NSError(
                            domain: "RideRequest",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey:
                                "You have already requested this ride."]
                        )
                    ))
                    return
                }

                let data: [String: Any] = [
                    "userId": userId,
                    "status": RideRequestStatus.pending.rawValue
                ]

                self.db.collection("rides")
                    .document(rideId)
                    .collection("requests")
                    .addDocument(data: data) { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success(()))
                        }
                    }
            }
    }

    // MARK: - Approve Request (Seat Decrement)

    func approveRequest(
        rideId: String,
        requestId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let rideRef = db.collection("rides").document(rideId)
        let requestRef = rideRef.collection("requests").document(requestId)

        db.runTransaction({ transaction, errorPointer in

            var rideSnap: DocumentSnapshot
            do {
                rideSnap = try transaction.getDocument(rideRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard let seats = rideSnap.data()?["seatsAvailable"] as? Int, seats > 0 else {
                errorPointer?.pointee = NSError(
                    domain: "RideError",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No seats available"]
                )
                return nil
            }

            transaction.updateData(
                ["seatsAvailable": seats - 1],
                forDocument: rideRef
            )

            transaction.updateData(
                ["status": RideRequestStatus.approved.rawValue],
                forDocument: requestRef
            )

            return nil
        }) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }


    // MARK: - Withdraw / Remove (Seat Re-Increment)
    
    func withdrawRequest(
        rideId: String,
        requestId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let rideRef = db.collection("rides").document(rideId)
        let requestRef = rideRef.collection("requests").document(requestId)

        db.runTransaction({ transaction, errorPointer in

            var rideSnap: DocumentSnapshot
            var requestSnap: DocumentSnapshot

            do {
                rideSnap = try transaction.getDocument(rideRef)
                requestSnap = try transaction.getDocument(requestRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            let status = requestSnap.data()?["status"] as? String
            let seats = rideSnap.data()?["seatsAvailable"] as? Int ?? 0

            if status == RideRequestStatus.approved.rawValue {
                transaction.updateData(
                    ["seatsAvailable": seats + 1],
                    forDocument: rideRef
                )
            }

            transaction.deleteDocument(requestRef)
            return nil
        }) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }


    // MARK: - Fetch Requests (Owner)

    func fetchRequests(
        rideId: String,
        completion: @escaping (Result<[RideRequest], Error>) -> Void
    ) {
        db.collection("rides")
            .document(rideId)
            .collection("requests")
            .getDocuments { snapshot, error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                let requests = snapshot?.documents.compactMap { doc -> RideRequest? in
                    let data = doc.data()
                    guard
                        let userId = data["userId"] as? String,
                        let raw = data["status"] as? String,
                        let status = RideRequestStatus(rawValue: raw)
                    else { return nil }

                    return RideRequest(
                        id: doc.documentID,
                        userId: userId,
                        status: status
                    )
                } ?? []

                completion(.success(requests))
            }
    }

    // MARK: - Fetch Current User Request

    func fetchUserRequest(
        rideId: String,
        userId: String,
        completion: @escaping (RideRequest?) -> Void
    ) {
        db.collection("rides")
            .document(rideId)
            .collection("requests")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, _ in

                guard
                    let doc = snapshot?.documents.first,
                    let raw = doc.data()["status"] as? String,
                    let status = RideRequestStatus(rawValue: raw)
                else {
                    completion(nil)
                    return
                }

                completion(
                    RideRequest(
                        id: doc.documentID,
                        userId: userId,
                        status: status
                    )
                )
            }
    }
    
    func deleteRide(
        rideId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let rideRef = db.collection("rides").document(rideId)
        let requestsRef = rideRef.collection("requests")

        requestsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let batch = self.db.batch()

            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }

            batch.deleteDocument(rideRef)

            batch.commit { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}
