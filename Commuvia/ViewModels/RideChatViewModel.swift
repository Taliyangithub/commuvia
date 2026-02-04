//
//  RideChatViewModel.swift
//  Commuvia
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

final class RideChatViewModel: ObservableObject {

    @Published var messages: [RideMessage] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening(rideId: String) {
        stopListening()

        guard Auth.auth().currentUser != nil else { return }

        BlockService.shared.fetchBlockedUsers { [weak self] blockedUserIds in
            guard let self else { return }

            self.listener = self.db
                .collection("rides")
                .document(rideId)
                .collection("messages")
                .order(by: "timestamp")
                .addSnapshotListener { snapshot, _ in

                    guard let documents = snapshot?.documents else { return }

                    let messages = documents.compactMap { doc -> RideMessage? in
                        let data = doc.data()

                        guard
                            let senderId = data["senderId"] as? String,
                            let senderName = data["senderName"] as? String,
                            let text = data["text"] as? String
                        else { return nil }

                        if blockedUserIds.contains(senderId) {
                            return nil
                        }

                        if ContentFilter.containsObjectionableContent(text) {
                            return nil
                        }

                        let timestamp =
                            (data["timestamp"] as? Timestamp)?.dateValue()
                            ?? Date()

                        return RideMessage(
                            id: doc.documentID,
                            senderId: senderId,
                            senderName: senderName,
                            text: text,
                            timestamp: timestamp
                        )
                    }

                    DispatchQueue.main.async {
                        self.messages = messages
                    }
                }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        stopListening()
    }
}
