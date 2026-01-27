//
//  RideService.swift
//  PoolPals
//

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
        carNumber: String,
        carModel: String,
        ownerName: String,
        startLocationName: String,
        endLocationName: String,
        startLatitude: Double,
        startLongitude: Double,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "AuthError", code: -1)))
            return
        }

        let data: [String: Any] = [
            "ownerId": userId,
            "ownerName": ownerName,
            "route": route,
            "time": Timestamp(date: time),
            "seatsAvailable": max(seatsAvailable, 0),
            "carNumber": carNumber,
            "carModel": carModel,
            "startLocationName": startLocationName,
            "endLocationName": endLocationName,
            "startLatitude": startLatitude,
            "startLongitude": startLongitude
        ]

        db.collection("rides").addDocument(data: data) { error in
            error == nil ? completion(.success(())) : completion(.failure(error!))
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

                let rides: [Ride] = snapshot?.documents.compactMap { doc in
                    let data = doc.data()

                    guard
                        let ownerId = data["ownerId"] as? String,
                        let ownerName = data["ownerName"] as? String,
                        let route = data["route"] as? String,
                        let startLocationName = data["startLocationName"] as? String,
                        let endLocationName = data["endLocationName"] as? String,
                        let startLatitude = data["startLatitude"] as? Double,
                        let startLongitude = data["startLongitude"] as? Double,
                        let time = (data["time"] as? Timestamp)?.dateValue(),
                        let seats = data["seatsAvailable"] as? Int,
                        let carNumber = data["carNumber"] as? String,
                        let carModel = data["carModel"] as? String
                    else {
                        return nil
                    }

                    return Ride(
                        id: doc.documentID,
                        ownerId: ownerId,
                        ownerName: ownerName,
                        route: route,
                        startLocationName: startLocationName,
                        endLocationName: endLocationName,
                        startLatitude: startLatitude,
                        startLongitude: startLongitude,
                        time: time,
                        seatsAvailable: seats,
                        carNumber: carNumber,
                        carModel: carModel
                    )
                } ?? []

                completion(.success(rides))
            }
    }

    // MARK: - Fetch Requests (OWNER) ✅ RESTORED

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

                let requests: [RideRequest] = snapshot?.documents.compactMap { doc in
                    let data = doc.data()

                    guard
                        let userId = data["userId"] as? String,
                        let rawStatus = data["status"] as? String,
                        let status = RideRequestStatus(rawValue: rawStatus)
                    else {
                        return nil
                    }

                    return RideRequest(
                        id: doc.documentID,
                        userId: userId,
                        status: status,
                        userName: nil
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
                        status: status,
                        userName: nil
                    )
                )
            }
    }


    // MARK: - Approve Request

    func approveRequest(
        rideId: String,
        requestId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let rideRef = db.collection("rides").document(rideId)
        let requestRef = rideRef.collection("requests").document(requestId)

        db.runTransaction({ transaction, errorPointer in

            let rideSnap: DocumentSnapshot
            do {
                rideSnap = try transaction.getDocument(rideRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard
                let seats = rideSnap.data()?["seatsAvailable"] as? Int,
                seats > 0
            else {
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
    // MARK: - Withdraw Request
    func withdrawRequest(
        rideId: String,
        requestId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let rideRef = db.collection("rides").document(rideId)
        let requestRef = rideRef.collection("requests").document(requestId)

        db.runTransaction({ transaction, errorPointer in

            let rideSnap: DocumentSnapshot
            let requestSnap: DocumentSnapshot

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


    // MARK: - Delete Ride

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
            snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
            batch.deleteDocument(rideRef)

            batch.commit { error in
                error == nil ? completion(.success(())) : completion(.failure(error!))
            }
        }
    }
    
    // MARK: - Request to Join Ride (Duplicate Safe)

    func requestToJoinRide(
        rideId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "AuthError", code: -1)))
            return
        }

        let requestsRef = db
            .collection("rides")
            .document(rideId)
            .collection("requests")

        // Prevent duplicate requests by same user
        requestsRef
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    completion(
                        .failure(
                            NSError(
                                domain: "RideRequest",
                                code: 1,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                    "You have already requested this ride."
                                ]
                            )
                        )
                    )
                    return
                }

                let data: [String: Any] = [
                    "userId": userId,
                    "status": RideRequestStatus.pending.rawValue
                ]

                requestsRef.addDocument(data: data) { error in
                    error == nil
                        ? completion(.success(()))
                        : completion(.failure(error!))
                }
            }
    }
    
    // MARK: - Send Message (Ride Chat)

    func sendMessage(
        rideId: String,
        text: String,
        senderName: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "AuthError", code: -1))
            return
        }

        let data: [String: Any] = [
            "senderId": userId,
            "senderName": senderName,
            "text": text,
            "timestamp": FieldValue.serverTimestamp()
        ]

        db.collection("rides")
            .document(rideId)
            .collection("messages")
            .addDocument(data: data) { error in
                completion?(error)
            }
    }


}
