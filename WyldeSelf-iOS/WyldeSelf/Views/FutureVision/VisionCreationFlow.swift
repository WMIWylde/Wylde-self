import SwiftUI

struct VisionCreationFlow: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var service = FutureVisionService.shared
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case categories
        case reflecting(Int)
        case generating
        case complete
    }

    @State private var phase: Phase = .categories
    @State private var selectedCategoryIds: Set<String> = []
    @State private var allAnswers: [String: [String]] = [:]
    @State private var generatedVisions: [FutureVision] = []
    @State private var generationIndex = 0
    @State private var errorText: String?

    var body: some View {
        ZStack {
            VisionTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                // Progress — fixed 5 segments
                if phase != .complete {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Capsule()
                                .fill(i < currentProgress ? VisionTheme.accent : VisionTheme.surface)
                                .frame(height: 3)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                }

                // Content
                ScrollView(showsIndicators: false) {
                    contentView
                        .padding(.horizontal, 22)
                        .padding(.top, 28)
                        .padding(.bottom, 40)
                }

                // Bottom button
                bottomButton
                    .padding(.horizontal, 22)
                    .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if case .reflecting = phase {
                Button("Back") { goBack() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VisionTheme.textMuted)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VisionTheme.textMuted)
                    .frame(width: 36, height: 36)
                    .background(VisionTheme.surface)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Progress

    private var currentProgress: Int {
        switch phase {
        case .categories: return 1
        case .reflecting(let i): return min(2 + i, 4)
        case .generating: return 4
        case .complete: return 5
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch phase {
        case .categories:
            VisionCategorySelector(selected: $selectedCategoryIds)
        case .reflecting(let index):
            reflectionContent(index: index)
        case .generating:
            generatingContent
        case .complete:
            completeContent
        }
    }

    @ViewBuilder
    private func reflectionContent(index: Int) -> some View {
        let cats = VisionCategory.all.filter { selectedCategoryIds.contains($0.id) }
        if index < cats.count {
            let cat = cats[index]
            FutureReflectionFlow(
                category: cat,
                answers: Binding(
                    get: { allAnswers[cat.id] ?? [] },
                    set: { allAnswers[cat.id] = $0 }
                )
            )
        }
    }

    private var generatingContent: some View {
        let cats = VisionCategory.all.filter { selectedCategoryIds.contains($0.id) }
        return VStack(spacing: 24) {
            Spacer().frame(height: 80)

            ProgressView()
                .tint(VisionTheme.accent)
                .scaleEffect(1.2)

            Text("Creating your future vision...")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(VisionTheme.text)

            if !cats.isEmpty {
                let current = min(generationIndex, cats.count - 1)
                Text(cats[current].name)
                    .font(.system(size: 13))
                    .foregroundColor(VisionTheme.textMuted)
                Text("\(generationIndex + 1) of \(cats.count)")
                    .font(.system(size: 12))
                    .foregroundColor(VisionTheme.textFaint)
            }

            Text("This may take a minute per category.")
                .font(.system(size: 12))
                .foregroundColor(VisionTheme.textFaint)

            if let error = errorText {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "C26B5A"))
                Button("Try Again") { Task { await generateAll() } }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VisionTheme.accent)
            }

            if !generatedVisions.isEmpty {
                Button("Continue with \(generatedVisions.count) vision\(generatedVisions.count == 1 ? "" : "s")") {
                    phase = .complete
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VisionTheme.textMuted)
            }

            Spacer()
        }
    }

    private var completeContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("YOUR FUTURE VISION")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.5)
                .foregroundColor(VisionTheme.accent)

            Text("This is the life you're building.")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(VisionTheme.text)

            ForEach(generatedVisions) { vision in
                VisionCard(vision: vision)
            }

            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VisionTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(VisionTheme.accent)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Bottom Button

    @ViewBuilder
    private var bottomButton: some View {
        switch phase {
        case .categories:
            Button {
                if !selectedCategoryIds.isEmpty {
                    phase = .reflecting(0)
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VisionTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedCategoryIds.isEmpty ? VisionTheme.accent.opacity(0.3) : VisionTheme.accent)
                    .clipShape(Capsule())
            }
            .disabled(selectedCategoryIds.isEmpty)

        case .reflecting(let i):
            let cats = VisionCategory.all.filter { selectedCategoryIds.contains($0.id) }
            let isLast = i >= cats.count - 1
            Button {
                if isLast {
                    phase = .generating
                    Task { await generateAll() }
                } else {
                    phase = .reflecting(i + 1)
                }
            } label: {
                Text(isLast ? "Create My Vision" : "Next")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VisionTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(VisionTheme.accent)
                    .clipShape(Capsule())
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Navigation

    private func goBack() {
        if case .reflecting(let i) = phase {
            if i > 0 { phase = .reflecting(i - 1) }
            else { phase = .categories }
        }
    }

    // MARK: - Generation

    private func generateAll() async {
        let cats = VisionCategory.all.filter { selectedCategoryIds.contains($0.id) }
        errorText = nil
        generationIndex = 0
        generatedVisions = []

        for (i, cat) in cats.enumerated() {
            generationIndex = i
            let answers = allAnswers[cat.id] ?? []
            do {
                let vision = try await service.generateVision(
                    category: cat,
                    answers: answers,
                    gender: appState.gender
                )
                generatedVisions.append(vision)
            } catch {
                print("[VisionFlow] Failed for \(cat.name): \(error.localizedDescription)")
                errorText = "\(cat.name) failed — continuing"
            }
        }

        if generatedVisions.isEmpty {
            errorText = "Generation failed. Check your connection and try again."
        } else {
            phase = .complete
        }
    }
}
