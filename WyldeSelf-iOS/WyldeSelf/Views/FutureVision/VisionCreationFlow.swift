import SwiftUI

struct VisionCreationFlow: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = FutureVisionService.shared
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case categories
        case reflecting(Int)   // index into selectedCategories
        case generating
        case complete
    }

    @State private var phase: Phase = .categories
    @State private var selectedCategoryIds: Set<String> = []
    @State private var allAnswers: [String: [String]] = [:]  // categoryId -> answers
    @State private var generatedVisions: [FutureVision] = []
    @State private var generationIndex = 0
    @State private var errorText: String?

    private var selectedCategories: [VisionCategory] {
        VisionCategory.all.filter { selectedCategoryIds.contains($0.id) }
    }

    // totalSteps and currentStep removed — caused re-render loop
    // Progress is now handled by fixed 5-segment progressBar

    var body: some View {
        ZStack {
            VisionTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    if phase != .categories && phase != .generating && phase != .complete {
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
                .padding(.horizontal, 22)
                .padding(.top, 12)

                // Progress
                if phase != .complete {
                    progressBar
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                }

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        switch phase {
                        case .categories:
                            categoriesPhase
                        case .reflecting(let index):
                            reflectionPhase(index: index)
                        case .generating:
                            generatingPhase
                        case .complete:
                            completePhase
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                }

                // Bottom action
                if phase != .generating && phase != .complete {
                    actionButton
                        .padding(.horizontal, 22)
                        .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress

    private var progressBar: some View {
        // Fixed 5-segment bar to avoid ForEach range crash
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i < progressFilled ? VisionTheme.accent : VisionTheme.surface)
                    .frame(height: 3)
            }
        }
    }

    private var progressFilled: Int {
        switch phase {
        case .categories: return 1
        case .reflecting(let i): return min(2 + i, 4)
        case .generating: return 4
        case .complete: return 5
        }
    }

    // MARK: - Categories Phase

    private var categoriesPhase: some View {
        VisionCategorySelector(selected: $selectedCategoryIds)
    }

    // MARK: - Reflection Phase

    @ViewBuilder
    private func reflectionPhase(index: Int) -> some View {
        if index < selectedCategories.count {
            let cat = selectedCategories[index]
            let binding = Binding<[String]>(
                get: { allAnswers[cat.id] ?? [] },
                set: { allAnswers[cat.id] = $0 }
            )
            FutureReflectionFlow(category: cat, answers: binding)
        } else {
            Text("Loading...").foregroundColor(VisionTheme.textMuted)
        }
    }

    // MARK: - Generating Phase

    private var generatingPhase: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)

            ProgressView()
                .tint(VisionTheme.accent)
                .scaleEffect(1.2)

            Text("Creating your future vision...")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(VisionTheme.text)

            if !selectedCategories.isEmpty {
                let current = min(generationIndex, selectedCategories.count - 1)
                Text(selectedCategories[current].name)
                    .font(.system(size: 13))
                    .foregroundColor(VisionTheme.textMuted)

                Text("\(generationIndex + 1) of \(selectedCategories.count)")
                    .font(.system(size: 12))
                    .foregroundColor(VisionTheme.textFaint)
            }

            Text("This may take a minute per category.\nThe AI is creating a cinematic scene for you.")
                .font(.system(size: 12))
                .foregroundColor(VisionTheme.textFaint)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            if let error = errorText {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8B3A2F"))
                    .padding(.top, 8)

                Button("Try Again") {
                    Task { await generateAll() }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(VisionTheme.accent)
            }

            // Skip to complete with whatever we have so far
            if generatedVisions.count > 0 {
                Button("Continue with \(generatedVisions.count) vision\(generatedVisions.count == 1 ? "" : "s")") {
                    phase = .complete
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VisionTheme.textMuted)
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Complete Phase

    private var completePhase: some View {
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

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VisionTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(VisionTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Action Button

    private var actionButtonDisabled: Bool {
        if case .categories = phase { return selectedCategoryIds.isEmpty }
        return false
    }

    private var actionButtonLabel: String {
        switch phase {
        case .categories: return "Continue"
        case .reflecting(let i):
            return i < selectedCategories.count - 1 ? "Next" : "Create My Vision"
        default: return "Continue"
        }
    }

    private var actionButton: some View {
        Button {
            advance()
        } label: {
            Text(actionButtonLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(VisionTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(actionButtonDisabled ? VisionTheme.accent.opacity(0.3) : VisionTheme.accent)
                .clipShape(Capsule())
        }
        .disabled(actionButtonDisabled)
    }

    // MARK: - Navigation

    private func advance() {
        print("[VisionFlow] advance() called, phase: \(phase), categories: \(selectedCategoryIds.count)")
        switch phase {
        case .categories:
            if !selectedCategoryIds.isEmpty {
                print("[VisionFlow] → reflecting(0)")
                phase = .reflecting(0)
            }
        case .reflecting(let i):
            if i < selectedCategories.count - 1 {
                print("[VisionFlow] → reflecting(\(i + 1))")
                phase = .reflecting(i + 1)
            } else {
                print("[VisionFlow] → generating")
                phase = .generating
                Task { await generateAll() }
            }
        default: break
        }
    }

    private func goBack() {
        switch phase {
        case .reflecting(let i):
            if i > 0 { phase = .reflecting(i - 1) }
            else { phase = .categories }
        default: break
        }
    }

    // MARK: - Generation

    private func generateAll() async {
        errorText = nil
        generationIndex = 0
        generatedVisions = []

        for (i, cat) in selectedCategories.enumerated() {
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
                errorText = "\(cat.name) failed — continuing with others"
                // Continue to next category instead of stopping
            }
        }

        if generatedVisions.isEmpty {
            errorText = "Generation failed. Check your connection and try again."
        } else {
            phase = .complete
        }
    }
}
