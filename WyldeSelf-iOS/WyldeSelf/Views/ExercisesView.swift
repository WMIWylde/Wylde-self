import SwiftUI

// MARK: - Exercises Browser
// Native screen that lists/searches/filters the bundled exercise library
// and shows a detail view (animated frames, muscles, instructions).

struct ExercisesView: View {
    @StateObject private var repo = ExerciseRepository.shared

    @State private var query = ""
    @State private var selectedMuscle: String? = nil
    @State private var selectedEquipment: String? = nil
    @State private var selectedLevel: String? = nil
    @State private var detailExercise: Exercise? = nil

    private var results: [Exercise] {
        repo.search(
            query: query,
            muscle: selectedMuscle,
            equipment: selectedEquipment,
            level: selectedLevel
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    searchBar
                    filterRow
                    countLabel

                    if let err = repo.loadError {
                        errorState(err)
                    } else if results.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .padding(.bottom, 80) // clear the custom bottom tab bar
            .sheet(item: $detailExercise) { ex in
                ExerciseDetailView(exercise: ex)
            }
        }
    }

    // MARK: Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Exercise Library")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.text)
                Text("\(repo.all.count) exercises · offline ready")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    // MARK: Search bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.muted)
                .font(.system(size: 15, weight: .medium))
            TextField("Search exercises…", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(size: 15))
            if !query.isEmpty {
                Button {
                    query = ""
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.muted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Theme.screenPadding)
    }

    // MARK: Filter chips
    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "Muscle",
                    selection: $selectedMuscle,
                    options: repo.allMuscles
                )
                FilterChip(
                    label: "Equipment",
                    selection: $selectedEquipment,
                    options: repo.allEquipment
                )
                FilterChip(
                    label: "Level",
                    selection: $selectedLevel,
                    options: repo.allLevels
                )
                if selectedMuscle != nil || selectedEquipment != nil || selectedLevel != nil {
                    Button {
                        selectedMuscle = nil
                        selectedEquipment = nil
                        selectedLevel = nil
                        HapticManager.shared.impact(.light)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Clear")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Theme.text3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .padding(.top, 12)
    }

    private var countLabel: some View {
        HStack {
            Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
            Spacer()
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: List
    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(results) { ex in
                    Button {
                        detailExercise = ex
                        HapticManager.shared.impact(.light)
                    } label: {
                        ExerciseRow(exercise: ex)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
    }

    // MARK: States
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 42, weight: .light))
                .foregroundColor(Theme.muted)
            Text("No exercises match")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.text)
            Text("Try a different search or clear your filters.")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 42))
            Text("Couldn't load exercises")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.text)
            Text(msg)
                .font(.system(size: 12))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    @Binding var selection: String?
    let options: [String]

    var body: some View {
        Menu {
            Button("All \(label.lowercased())") {
                selection = nil
                HapticManager.shared.impact(.light)
            }
            Divider()
            ForEach(options, id: \.self) { opt in
                Button {
                    selection = opt
                    HapticManager.shared.impact(.light)
                } label: {
                    HStack {
                        Text(opt.capitalized)
                        if selection == opt {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection?.capitalized ?? label)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(selection == nil ? Theme.text3 : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selection == nil ? Theme.surface : Theme.sage)
            .overlay(
                Capsule().stroke(Theme.border, lineWidth: selection == nil ? 1 : 0)
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Row

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail (first frame)
            AsyncImage(url: URL(string: exercise.images.first ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                case .empty:
                    ZStack {
                        Color(.systemGray6)
                        ProgressView().scaleEffect(0.7)
                    }
                case .failure:
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(Theme.muted)
                    }
                @unknown default:
                    Color(.systemGray6)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !exercise.primaryMuscle.isEmpty {
                        TagPill(text: exercise.primaryMuscle.capitalized, tone: .gold)
                    }
                    TagPill(text: exercise.displayEquipment, tone: .neutral)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.muted)
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

private struct TagPill: View {
    enum Tone { case gold, sage, neutral }
    let text: String
    let tone: Tone

    private var fg: Color {
        switch tone {
        case .gold: return Theme.gold
        case .sage: return Theme.sage
        case .neutral: return Theme.text3
        }
    }
    private var bg: Color {
        switch tone {
        case .gold: return Theme.gold.opacity(0.12)
        case .sage: return Theme.sage.opacity(0.12)
        case .neutral: return Color(.systemGray6)
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
}

// MARK: - Detail View

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @State private var frameIndex = 0
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Animated frame display
                    animatedFrames
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.top, 12)

                    // Title + meta
                    VStack(alignment: .leading, spacing: 10) {
                        Text(exercise.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.text)

                        HStack(spacing: 6) {
                            if !exercise.primaryMuscle.isEmpty {
                                TagPill(text: exercise.primaryMuscle.capitalized, tone: .gold)
                            }
                            TagPill(text: exercise.displayEquipment, tone: .sage)
                            TagPill(text: exercise.displayLevel, tone: .neutral)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)

                    // Muscles
                    if !exercise.secondaryMuscles.isEmpty {
                        section(title: "Secondary Muscles") {
                            FlowTags(items: exercise.secondaryMuscles.map { $0.capitalized })
                        }
                    }

                    // Instructions
                    if !exercise.instructions.isEmpty {
                        section(title: "How to Perform") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { idx, step in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Theme.gold)
                                            .frame(width: 22, height: 22)
                                            .background(Theme.gold.opacity(0.12))
                                            .clipShape(Circle())
                                        Text(step)
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.text)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    // Source attribution
                    Text("Data: free-exercise-db (open source)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.bottom, 24)
                }
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.sage)
                }
            }
            .onAppear { startTimer() }
            .onDisappear { stopTimer() }
        }
    }

    @ViewBuilder
    private var animatedFrames: some View {
        if exercise.images.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.muted)
                Text("Demo unavailable")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let url = URL(string: exercise.images[frameIndex % exercise.images.count])
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fit)
                case .empty:
                    ProgressView()
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(Theme.muted)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    private func startTimer() {
        guard exercise.images.count > 1 else { return }
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
            Task { @MainActor in
                frameIndex = (frameIndex + 1) % exercise.images.count
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundColor(Theme.muted)
            content()
        }
        .padding(.horizontal, Theme.screenPadding)
    }
}

// Simple flow layout for tag wrap
private struct FlowTags: View {
    let items: [String]
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 90), spacing: 6)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                TagPill(text: item, tone: .neutral)
            }
        }
    }
}

#Preview {
    ExercisesView()
        .environmentObject(AppState())
}
