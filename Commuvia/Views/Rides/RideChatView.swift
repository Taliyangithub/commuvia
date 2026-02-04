//
//  RideChatView.swift
//  Commuvia
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RideChatView: View {

    // MARK: - Inputs
    let ride: Ride
    let currentUserName: String

    // MARK: - State
    @StateObject private var viewModel = RideChatViewModel()
    @State private var messageText: String = ""

    @State private var showActionSheet = false
    @State private var selectedMessage: RideMessage?
    @State private var showReportConfirmation = false
    @State private var showBlockConfirmation = false

    // Moderation feedback
    @State private var moderationError: String?
    @State private var showModerationAlert = false

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Body
    var body: some View {
        VStack {

            ScrollViewReader { proxy in
                List(viewModel.messages) { message in
                    chatBubble(for: message)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .id(message.id)
                }
                .listStyle(.plain)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Message", text: $messageText)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    sendMessage()
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Ride Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListening(rideId: ride.id)
        }
        .onDisappear {
            viewModel.stopListening()
        }

        // MARK: - Message Actions
        .confirmationDialog(
            "Message Actions",
            isPresented: $showActionSheet,
            titleVisibility: .visible
        ) {
            Button("Report Message", role: .destructive) {
                showReportConfirmation = true
            }

            Button("Block User", role: .destructive) {
                showBlockConfirmation = true
            }

            Button("Cancel", role: .cancel) { }
        }

        // MARK: - Report
        .alert(
            "Report Message",
            isPresented: $showReportConfirmation
        ) {
            Button("Report", role: .destructive) {
                reportSelectedMessage()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This message will be reviewed and appropriate action will be taken within 24 hours.")
        }

        // MARK: - Block
        .alert(
            "Block User",
            isPresented: $showBlockConfirmation
        ) {
            Button("Block", role: .destructive) {
                blockSelectedUser()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Blocked users will no longer appear in your chat or ride activity.")
        }

        // MARK: - Moderation Feedback
        .alert(
            "Message Not Sent",
            isPresented: $showModerationAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(moderationError ?? "")
        }
    }

    // MARK: - Chat Bubble
    private func chatBubble(for message: RideMessage) -> some View {
        let isCurrentUser = message.senderId == currentUserId

        return HStack {
            if isCurrentUser { Spacer() }

            VStack(alignment: .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(message.text)
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isCurrentUser ? Color.blue : Color(.systemGray5))
                    )
            }

            if !isCurrentUser {
                Button {
                    selectedMessage = message
                    showActionSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }

            if !isCurrentUser { Spacer() }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Actions
    private func sendMessage() {
        RideService.shared.sendMessage(
            rideId: ride.id,
            text: messageText,
            senderName: currentUserName
        ) { error in
            DispatchQueue.main.async {
                if let error {
                    moderationError = error.localizedDescription
                    showModerationAlert = true
                } else {
                    messageText = ""
                }
            }
        }
    }

    private func reportSelectedMessage() {
        guard
            let message = selectedMessage,
            let reporterId = Auth.auth().currentUser?.uid
        else { return }

        Firestore.firestore()
            .collection("rides")
            .document(ride.id)
            .collection("messages")
            .document(message.id)
            .collection("reports")
            .addDocument(data: [
                "reportedBy": reporterId,
                "senderId": message.senderId,
                "reason": "Abusive or objectionable content",
                "createdAt": FieldValue.serverTimestamp()
            ])
    }

    private func blockSelectedUser() {
        guard let message = selectedMessage else { return }

        BlockService.shared.blockUser(
            blockedUserId: message.senderId,
            reason: "Abusive chat behavior"
        )

        viewModel.messages.removeAll {
            $0.senderId == message.senderId
        }
    }
}
