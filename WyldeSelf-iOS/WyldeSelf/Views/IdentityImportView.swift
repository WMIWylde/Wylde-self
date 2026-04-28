import SwiftUI

// ════════════════════════════════════════════════════════════════════
//  IdentityImportView — Founding Members feature.
//  State machine:
//    .locked   → blurred preview + paywall CTA (default if !isPro)
//    .input    → URL/text form
//    .loading  → spinner + identity-driven copy
//    .result   → structured profile display
// ════════════════════════════════════════════════════════════════════

struct IdentityImportView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = IdentityAnalysisService.shared
    @Environment(\.dismiss) private var dismiss

    enum Phase { case locked, input, loading, result }

    @State private var phase: Phase = .input
    @State private var urls: [String] = [""]
    @State private var rawText: String = ""
    @State private var profile: IdentityProfile? = nil
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    closeButton
                    header
                    Group {
                        switch phase {
                        case .locked:   lockedView
                        case .input:    inputView
                        case .loading:  loadingView
                        case .result:   resultView
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .onAppear { resolvePhaseOnEntry() }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(appState)
        }
    }

    // MARK: - Top close

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "A6A29A"))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: "111111"))
                    .clipShape(Circle())
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("IDENTITY INTELLIGENCE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.5)
                .foregroundColor(Color(hex: "C8A96E"))
            Text("Import Your Identity")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color(hex: "F4F1E8"))
                .lineSpacing(1)
            Text("Connect the platforms where your current identity already lives. Wylde will analyze how you think, communicate, and show up — and adapt your coaching accordingly.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "A6A29A"))
                .lineSpacing(3)
        }
        .padding(.bottom, 28)
    }

    // MARK: - Locked

    private var lockedView: some View {
        ZStack {
            VStack(spacing: 10) {
                lockedMockCard(label: "Identity Archetype",
                               title: "The disciplined builder",
                               sub: "High confidence · Direct · Action-driven",
                               accent: true)
                lockedMockCard(label: "What drives you",
                               title: "Proving the version of you they didn't see coming.",
                               sub: nil)
                lockedMockCard(label: "How Wylde will coach you",
                               title: "Direct. Tactical. Numbers and reps over feelings.",
                               sub: nil)
            }
            .blur(radius: 8)
            .opacity(0.55)
            .allowsHitTesting(false)

            // Overlay CTA
            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "C8A96E")).frame(width: 5, height: 5)
                    Text("FOUNDING MEMBERS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color(hex: "C8A96E"))
                }
                Text("Unlock how Wylde sees you — and become who you're meant to be.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "F4F1E8"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Identity Import analyzes your real voice and tunes every coaching surface to match.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "A6A29A"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Button {
                    HapticManager.shared.impact(.light)
                    showPaywall = true
                } label: {
                    Text("Become a Founding Member")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundColor(Color(hex: "070707"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "C8A96E"))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "0F0F0F"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(hex: "C8A96E").opacity(0.40), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 24, y: 12)
        }
    }

    private func lockedMockCard(label: String, title: String, sub: String?, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.0)
                .foregroundColor(accent ? Color(hex: "C8A96E") : Color(hex: "A6A29A"))
            Text(title)
                .font(.system(size: accent ? 22 : 14, weight: accent ? .bold : .regular))
                .foregroundColor(Color(hex: "F4F1E8"))
            if let s = sub {
                Text(s)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "A6A29A"))
                    .italic()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accent
                      ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "C8A96E").opacity(0.10), Color(hex: "7D9275").opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color(hex: "111111")))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accent ? Color(hex: "C8A96E").opacity(0.35) : Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Input

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Privacy
            Text("Wylde only uses this data to personalize your coaching. We never post on your behalf. You can edit or delete this anytime.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "A6A29A"))
                .lineSpacing(2)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Color(hex: "161616"))
                )

            // Coming Soon platforms
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("CONNECT A PLATFORM", accent: false)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                    comingSoonCard(name: "Instagram", icon: "camera.fill")
                    comingSoonCard(name: "LinkedIn", icon: "briefcase.fill")
                    comingSoonCard(name: "Facebook", icon: "person.2.fill")
                    comingSoonCard(name: "Google", icon: "globe")
                }
            }

            // URL inputs
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("ADD PUBLIC PROFILE LINKS", accent: true)
                Text("Up to 5. Personal site, X/Twitter, public Substack — anywhere your voice lives.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "A6A29A"))
                ForEach(urls.indices, id: \.self) { idx in
                    HStack(spacing: 8) {
                        TextField("https://...", text: $urls[idx])
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "F4F1E8"))
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "161616"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "F4F1E8").opacity(0.08), lineWidth: 1)
                                    )
                            )
                        if idx > 0 {
                            Button { urls.remove(at: idx) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "A6A29A"))
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if urls.count < 5 {
                    Button {
                        urls.append("")
                    } label: {
                        Text("+ Add another link")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "F4F1E8").opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [3]))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Raw text
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("OR PASTE CONTENT DIRECTLY", accent: true)
                Text("Bio, recent posts, captions, an \"About\" section. Anything in your real voice.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "A6A29A"))
                TextEditor(text: $rawText)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "F4F1E8"))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 160)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "161616"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "F4F1E8").opacity(0.08), lineWidth: 1)
                            )
                    )
            }

            // CTAs
            VStack(spacing: 8) {
                Button(action: submit) {
                    Text("Build My Identity Profile")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundColor(Color(hex: "070707"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "C8A96E"))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.5)

                Button { dismiss() } label: {
                    Text("Skip for now")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
    }

    private var canSubmit: Bool {
        urls.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ||
        !rawText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 22) {
            // Subtle gold ring spinner
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color(hex: "C8A96E"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(loadingAngle))
                .onAppear { withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { loadingAngle = 360 } }

            VStack(spacing: 6) {
                Text("Reading you...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "F4F1E8"))
                Text("Wylde is studying how you communicate, what drives you, and what gets in your way.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "A6A29A"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    @State private var loadingAngle: Double = 0

    // MARK: - Result

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let p = profile {
                resultHeroCard(p)
                if !p.aspirationalIdentity.isEmpty {
                    resultSection(label: "Who you are becoming",
                                  body: p.aspirationalIdentity)
                }
                if !p.motivationTriggers.isEmpty {
                    resultListSection(label: "What drives you", items: p.motivationTriggers)
                }
                if !p.limitingPatterns.isEmpty {
                    resultListSection(label: "What holds you back", items: p.limitingPatterns)
                }
                resultSection(
                    label: "How Wylde will coach you",
                    body: coachingDescription(p)
                )

                HStack(spacing: 8) {
                    Button { phase = .input } label: {
                        Text("Edit responses")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "F4F1E8").opacity(0.10), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    Button {
                        HapticManager.shared.notification(.success)
                        dismiss()
                    } label: {
                        Text("Confirm Profile")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundColor(Color(hex: "070707"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "C8A96E"))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
            }
        }
    }

    private func resultHeroCard(_ p: IdentityProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("IDENTITY ARCHETYPE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.0)
                .foregroundColor(Color(hex: "C8A96E"))
            Text(p.identityArchetype)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "F4F1E8"))
                .lineSpacing(1)
            Text("\(p.confidenceLevel.uppercased()) confidence · \(p.communicationTone)")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "A6A29A"))
                .italic()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color(hex: "C8A96E").opacity(0.10), Color(hex: "7D9275").opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "C8A96E").opacity(0.40), lineWidth: 1)
                )
        )
    }

    private func resultSection(label: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.8)
                .foregroundColor(Color(hex: "A6A29A"))
            Text(body)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "F4F1E8"))
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "111111"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func resultListSection(label: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.8)
                .foregroundColor(Color(hex: "A6A29A"))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·")
                            .foregroundColor(Color(hex: "C8A96E"))
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "F4F1E8"))
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "111111"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func coachingDescription(_ p: IdentityProfile) -> String {
        var parts: [String] = [p.coachingStyleLabel + "."]
        if !p.languageToUse.isEmpty {
            parts.append("Speaks to you with words like: \(p.languageToUse.prefix(4).joined(separator: ", ")).")
        }
        if !p.languageToAvoid.isEmpty {
            parts.append("Avoids: \(p.languageToAvoid.prefix(3).joined(separator: ", ")).")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(2.0)
            .foregroundColor(accent ? Color(hex: "C8A96E") : Color(hex: "A6A29A"))
    }

    private func comingSoonCard(name: String, icon: String) -> some View {
        Button {
            HapticManager.shared.impact(.light)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "F4F1E8"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "F4F1E8"))
                    Text("COMING SOON")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(Color(hex: "6E6B65"))
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "111111"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - State transitions

    private func resolvePhaseOnEntry() {
        if !appState.isPro {
            phase = .locked
        } else if let p = appState.identityProfile {
            profile = p
            phase = .result
        } else {
            phase = .input
        }
    }

    private func submit() {
        guard appState.isPro else { phase = .locked; return }
        let cleanUrls = urls.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let cleanText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrls.isEmpty || !cleanText.isEmpty else { return }

        HapticManager.shared.impact(.medium)
        phase = .loading
        Task {
            do {
                let userId = "" // TODO: pass real Supabase user UUID once auth is wired
                let result = try await IdentityAnalysisService.shared.analyze(
                    userId: userId, urls: cleanUrls, rawText: cleanText
                )
                profile = result
                appState.identityProfile = result
                HapticManager.shared.notification(.success)
                phase = .result
            } catch {
                HapticManager.shared.notification(.error)
                phase = .input
            }
        }
    }
}
