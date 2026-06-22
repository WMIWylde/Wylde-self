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

    private var totalSteps: Int {
        1 + selectedCategories.count + 1  // categories + reflections + generate
    }

    private var currentStep: Int {
        switch phase {
        case .categories: return 1
        case .reflecting(let i): return 2 + i
        case .generating, .complete: return totalSteps
        }
    }

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
        HStack(spacing: 4) {
            ForEach(1...max(totalSteps, 2), id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? VisionTheme.accent : VisionTheme.surface)
                    .frame(height: 3)
            }
        }
    }

    // MARK: - Categories Phase

    private var categoriesPhase: some View {
        VisionCategorySelector(selected: $selectedCategoryIds)
    }

    // MARK: - Reflection Phase

    private func reflectionPhase(index: Int) -> some View {
        let cat = selectedCategories[index]
        let binding = Binding<[String]>(
            get: { allAnswers[cat.id] ?? [] },
            set: { allAnswers[cat.id] = $0 }
        )
        return FutureReflectionFlow(category: cat, answers: binding)
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

    private var actionButton: some View {
        let isDisabled: Bool = {
            switch phase {
            case .categories: return selectedCategoryIds.isEmpty
            case .reflecting(let i):
                let cat = selectedCategories[i]
                let answers = allAnswers[cat.id] ?? []
                return answers.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            default: return false
            }
        }()

        let label: String = {
            switch phase {
            case .categories: return "Continue"
            case .reflecting(let i):
                return i < selectedCategories.count - 1 ? "Next" : "Create My Vision"
            default: return "Continue"
            }
        }()

        return Button {
            advance()
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(VisionTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isDisabled ? VisionTheme.accent.opacity(0.3) : VisionTheme.accent)
                .clipShape(Capsule())
        }
        .disabled(isDisabled)
    }

    // MARK: - Navigation

    private func advance() {
        switch phase {
        case .categories:
            if !selectedCategoryIds.isEmpty {
                phase = .reflecting(0)
            }
        case .reflecting(let i):
            if i < selectedCategories.count - 1 {
                phase = .reflecting(i + 1)
            } else {
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
                errorText = error.localizedDescription
                return
            }
        }

        phase = .complete
    }
}
