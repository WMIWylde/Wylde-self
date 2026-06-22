import SwiftUI

struct CareMessagingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [CareMessage] = []
    @State private var inputText = ""
    @State private var isLoading = true
    @State private var relationshipId: String?
    @FocusState private var inputFocused: Bool

    private let baseURL = "https://www.wyldeself.com"
    private let templates = [
        "I missed a dose",
        "I'm having a side effect",
        "I need a refill",
        "Can we adjust my protocol?",
    ]

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CARE TEAM")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2.5)
                            .foregroundColor(Color(hex: "C8A96E"))
                        Text("Messages")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(Color(hex: "F4F1E8"))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "111111"))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if isLoading {
                    Spacer()
                    ProgressView().tint(Color(hex: "C8A96E"))
                    Spacer()
                } else if messages.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "6E6B65"))
                        Text("No messages yet")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "A6A29A"))
                        Text("Send your clinician a message below.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "6E6B65"))
                    }
                    Spacer()
                } else {
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { msg in
                                    messageBubble(msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .onChange(of: messages.count) { _ in
                            if let last = messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }

                // Quick templates
                if messages.count < 3 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(templates, id: \.self) { t in
                                Button {
                                    inputText = t
                                } label: {
                                    Text(t)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(hex: "C8A96E"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color(hex: "C8A96E").opacity(0.08))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color(hex: "C8A96E").opacity(0.15), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 6)
                }

                // Input
                HStack(spacing: 10) {
                    TextField("Message your clinician...", text: $inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "F4F1E8"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1))
                        .focused($inputFocused)
                        .tint(Color(hex: "C8A96E"))

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(hex: "6E6B65") : Color(hex: "C8A96E"))
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "0B0B0B"))
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadMessages() }
    }

    private func messageBubble(_ msg: CareMessage) -> some View {
        let isMe = msg.senderId.uuidString == AuthService.shared.userID
        return HStack {
            if isMe { Spacer() }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(msg.body)
                    .font(.system(size: 15))
                    .foregroundColor(isMe ? Color(hex: "070707") : Color(hex: "F4F1E8"))
                    .padding(14)
                    .background(isMe ? Color(hex: "C8A96E") : Color(hex: "111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(formatTime(msg.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "6E6B65"))
            }
            if !isMe { Spacer() }
        }
    }

    private func formatTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        let df = DateFormatter()
        df.dateFormat = "MMM d, h:mm a"
        return df.string(from: date)
    }

    private func loadMessages() async {
        guard let token = await AuthService.shared.accessToken,
              let url = URL(string: "\(baseURL)/api/consumer/messages") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[CareMessaging] Response: \(httpCode), bytes: \(data.count)")

            if httpCode == 403 || httpCode == 401 {
                print("[CareMessaging] Auth/relationship issue")
                isLoading = false
                return
            }

            struct Resp: Codable { let messages: [CareMessage]?; let relationship_id: String? }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            messages = resp.messages ?? []
            relationshipId = resp.relationship_id
            print("[CareMessaging] Loaded \(messages.count) messages")
        } catch {
            print("[CareMessaging] Load failed: \(error)")
            // Try to print raw response for debugging
            if let url = URL(string: "\(baseURL)/api/consumer/messages") {
                var req2 = URLRequest(url: url)
                if let t = await AuthService.shared.accessToken { req2.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
                if let (d, _) = try? await URLSession.shared.data(for: req2), let str = String(data: d, encoding: .utf8) {
                    print("[CareMessaging] Raw: \(str.prefix(300))")
                }
            }
        }
        isLoading = false
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        Task {
            guard let token = await AuthService.shared.accessToken,
                  let url = URL(string: "\(baseURL)/api/consumer/messages") else { return }

            var payload: [String: String] = ["body": text]
            if let rid = relationshipId { payload["relationship_id"] = rid }

            guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = body

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[CareMessaging] Send response: \(httpCode)")
                struct Resp: Codable { let message: CareMessage? }
                if let resp = try? JSONDecoder().decode(Resp.self, from: data), let msg = resp.message {
                    messages.append(msg)
                } else {
                    // Reload all messages as fallback
                    await loadMessages()
                }
            } catch {
                print("[CareMessaging] Send failed: \(error)")
            }
        }
    }
}
