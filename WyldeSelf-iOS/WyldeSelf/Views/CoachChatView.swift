import SwiftUI

struct CoachChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = CoachService.shared
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    private var coachName: String {
        appState.userName.isEmpty ? "Future Self" : "Future \(appState.userName)"
    }

    var body: some View {
        ZStack {
            Theme.appBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            // Greeting if empty
                            if service.messages.isEmpty {
                                greeting
                            }

                            ForEach(service.messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)).animation(.easeOut(duration: 0.3)),
                                        removal: .opacity
                                    ))
                            }

                            if service.isTyping {
                                typingIndicator
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                    .onChange(of: service.messages.count) {
                        if let last = service.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Quick actions (show when chat is fresh)
                if service.messages.count < 3 {
                    quickActions
                }

                // Input
                inputBar
            }
        }
    }

    // MARK: - Header

    @Environment(\.dismiss) private var dismiss

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                        .frame(width: 36, height: 36)
                        .background(Theme.elevatedBG)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 4)

            Text(coachName)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(Color(hex: "C8A96E"))

            Text("The version of you\nthat already did it.")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(Theme.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Greeting

    private var greeting: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            Circle()
                .fill(Color(hex: "C8A96E").opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "C8A96E"))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(coachName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "C8A96E"))
                Text("I'm the version of you that's already walked this. What's actually going on?")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.primaryText)
                    .lineSpacing(3)
            }
            .padding(14)
            .background(Theme.elevatedBG)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ msg: CoachMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if msg.role == .user { Spacer() }

            if msg.role == .assistant {
                Circle()
                    .fill(Color(hex: "C8A96E").opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "C8A96E"))
                    )
            }

            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
                if msg.role == .assistant {
                    Text(coachName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "C8A96E"))
                }
                Text(msg.content)
                    .font(.system(size: 15))
                    .foregroundColor(msg.role == .user ? Theme.onAccent : Theme.primaryText)
                    .lineSpacing(3)
                    .padding(14)
                    .background(msg.role == .user ? Color(hex: "C8A96E") : Theme.elevatedBG)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if msg.role == .assistant { Spacer() }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: "C8A96E").opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "C8A96E"))
                )

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.secondaryText)
                        .frame(width: 6, height: 6)
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.elevatedBG)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickActionButton("Motivate me")
                quickActionButton("Fix my plan")
                quickActionButton("I'm off track")
                quickActionButton("Optimize everything")
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private func quickActionButton(_ label: String) -> some View {
        Button {
            Task { await service.quickAction(label, appState: appState) }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "C8A96E"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "C8A96E").opacity(0.08))
                .overlay(
                    Capsule().stroke(Color(hex: "C8A96E").opacity(0.2), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Speak plainly.", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundColor(Theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.elevatedBG)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.primaryText.opacity(0.06), lineWidth: 1)
                )
                .focused($inputFocused)
                .onSubmit { sendMessage() }
                .tint(Color(hex: "C8A96E"))

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.tertiaryText : Color(hex: "C8A96E"))
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isTyping)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.appBG)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await service.send(text, appState: appState) }
    }
}
