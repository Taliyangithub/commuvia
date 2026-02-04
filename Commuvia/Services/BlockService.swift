//
//  BlockService.swift
//  Commuvia
//

import FirebaseFirestore
import FirebaseAuth

final class BlockService {

    static let shared = BlockService()
    private let db = Firestore.firestore()

    private init() {}

    func blockUser(
        blockedUserId: String,
        reason: String
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Block failed: no authenticated user")
            return
        }

        guard uid != blockedUserId else {
            print("Block failed: cannot block self")
            return
        }

        let blockRef = db
            .collection("users")
            .document(uid)
            .collection("blockedUsers")
            .document(blockedUserId)

        blockRef.setData([
            "blockedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error {
                print(" Block write failed:", error.localizedDescription)
            } else {
                print("Blocked user:", blockedUserId)
            }
        }

        db.collection("blockedReports").addDocument(data: [
            "reporterId": uid,
            "blockedUserId": blockedUserId,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchBlockedUsers(
        completion: @escaping (Set<String>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }

        db.collection("users")
            .document(uid)
            .collection("blockedUsers")
            .getDocuments { snap, _ in
                let ids = snap?.documents.map { $0.documentID } ?? []
                completion(Set(ids))
            }
    }
}
