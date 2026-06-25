import SwiftUI

struct ExerciseCard: View {
    let exercise: WorkoutExercise
    let dayIndex: Int
    let exerciseIndex: Int
    let pr: PersonalRecord?
    let gender: String
    let fitnessLevel: String
    var onSetLogged: ((Int, Double, Int) -> Void)?
    var onWarmupTap: (() -> Void)?
    var onRestNeeded: (() -> Void)?

    @State private var weights: [Double] = []
    @State private var reps: [Double] = []
    @State private var showGuide = false
    @State private var lastOverloadTip: String?
    @State private var showAlternatives = false
    @State private var alternatives: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "F4F1E8"))
                    Text(exercise.cue)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .lineLimit(2)
                }
                Spacer()
                if !exercise.isWarmup && !exercise.isCardio {
                    Button {
                        showAlternatives.toggle()
                        if alternatives.isEmpty { loadAlternatives() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "6E6B65"))
                    }
                }
                Text(exercise.setsReps)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "C8A96E"))
            }
            .padding(16)

            // Alternatives panel
            if showAlternatives && !alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ALTERNATIVES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color(hex: "6E6B65"))
                    ForEach(alternatives, id: \.self) { alt in
                        Text("→ \(alt)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "A6A29A"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            // Warmup CTA
            if exercise.isWarmup {
                Button {
                    onWarmupTap?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                        Text("Begin Warmup")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "1A1816"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else if exercise.isCardio {
                // Cardio timer
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(Color(hex: "C8A96E"))
                    Text("\(exercise.timerMinutes) minutes")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "F4F1E8"))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else {

            // PR + suggested weight
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let pr = pr {
                        statBadge(label: "PR", value: "\(Int(pr.bestWeight))lb × \(pr.bestReps)", color: Color(hex: "C8A96E"))
                    }
                    let suggestion = LiftingCoach.suggestedWeight(exercise: exercise.name, gender: gender, level: fitnessLevel)
                    if pr == nil {
                        statBadge(label: "START", value: "\(Int(suggestion.weight))lb", color: Color(hex: "7FD0FF"))
                    }
                }

                // Coaching note
                let suggestion = LiftingCoach.suggestedWeight(exercise: exercise.name, gender: gender, level: fitnessLevel)
                if pr == nil {
                    Text(suggestion.note)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .padding(.horizontal, 4)
                }

                // Overload tip after logging
                if let tip = lastOverloadTip {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "C8A96E"))
                        Text(tip)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "C8A96E"))
                    }
                    .padding(.horizontal, 4)
                }

                // Beginner guide toggle
                if fitnessLevel.lowercased() == "beginner" {
                    Button {
                        withAnimation { showGuide.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                            Text(showGuide ? "Hide tips" : "How to lift")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: showGuide ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(Color(hex: "7FD0FF"))
                    }
                    .padding(.horizontal, 4)

                    if showGuide {
                        beginnerGuide
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Set rows
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, setLog in
                setRow(setIndex: setIndex, setLog: setLog)
            }
            } // close else
        }
        .background(Color(hex: "111111"))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { initState() }
    }

    private func setRow(setIndex: Int, setLog: SetLog) -> some View {
        HStack(spacing: 6) {
            // Set number
            Text("\(setIndex + 1)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(setLog.completed ? Color(hex: "C8A96E") : Color(hex: "6E6B65"))
                .frame(width: 18)

            // Reps stepper
            stepper(value: repBinding(setIndex), step: 1, label: "reps")

            // Weight stepper — hidden for bodyweight exercises
            if !LiftingCoach.isBodyweight(exercise.name) {
                stepper(value: weightBinding(setIndex), step: 5, label: "lb")
            } else {
                Text("BW")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "7FD0FF"))
                    .frame(minWidth: 30)
            }

            // Log button
            Button {
                let w = weights.indices.contains(setIndex) ? weights[setIndex] : 0
                let r = reps.indices.contains(setIndex) ? Int(reps[setIndex]) : 0
                onSetLogged?(setIndex, w, r)
                // Show progressive overload tip
                lastOverloadTip = LiftingCoach.overloadTip(
                    exercise: exercise.name,
                    completedWeight: w,
                    completedReps: r,
                    targetReps: exercise.parsedReps
                )
                // Rest timer after every set (except the last)
                let completedCount = exercise.sets.filter(\.completed).count + 1
                if completedCount < exercise.sets.count {
                    onRestNeeded?()
                }
            } label: {
                Image(systemName: setLog.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(setLog.completed ? Color(hex: "C8A96E") : Color(hex: "6E6B65"))
            }
            .disabled(setLog.completed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(setLog.completed ? Color(hex: "C8A96E").opacity(0.04) : .clear)
    }

    private func stepper(value: Binding<Double>, step: Double, label: String) -> some View {
        HStack(spacing: 0) {
            Button { value.wrappedValue = max(0, value.wrappedValue - step) } label: {
                Text("−").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "A6A29A"))
                    .frame(width: 24, height: 30)
            }
            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "F4F1E8"))
                .frame(minWidth: 30)
            Button { value.wrappedValue += step } label: {
                Text("+").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "A6A29A"))
                    .frame(width: 24, height: 30)
            }
        }
        .background(Color(hex: "1A1A1A"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statBadge(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).tracking(1)
            Text(value).font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
    }

    private var beginnerGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(LiftingCoach.beginnerConcepts.prefix(3).enumerated()), id: \.offset) { _, concept in
                VStack(alignment: .leading, spacing: 4) {
                    Text(concept.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "F4F1E8"))
                    Text(concept.explanation)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .lineSpacing(2)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "0B0B0B"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 4)
    }

    private func loadAlternatives() {
        // Find exercises targeting the same muscle group from the bundled library
        let repo = ExerciseRepository.shared
        let current = exercise.name.lowercased()

        // Find the current exercise's primary muscle
        let match = repo.all.first { $0.name.lowercased().contains(current.prefix(10)) }
        let muscle = match?.primaryMuscle ?? ""

        if !muscle.isEmpty {
            alternatives = repo.search(query: "", muscle: muscle, equipment: nil, level: nil)
                .filter { $0.name.lowercased() != current }
                .prefix(5)
                .map { $0.name }
        } else {
            // Fallback: search by keywords from exercise name
            let keywords = current.components(separatedBy: " ").filter { $0.count > 3 }
            for kw in keywords {
                let results = repo.search(query: kw, muscle: nil, equipment: nil, level: nil)
                    .filter { $0.name.lowercased() != current }
                if !results.isEmpty {
                    alternatives = results.prefix(5).map { $0.name }
                    break
                }
            }
        }

        if alternatives.isEmpty {
            alternatives = ["No alternatives found"]
        }
    }

    private func initState() {
        let suggestion = LiftingCoach.suggestedWeight(exercise: exercise.name, gender: gender, level: fitnessLevel)
        weights = exercise.sets.map { $0.weight > 0 ? $0.weight : suggestion.weight }
        reps = exercise.sets.map(\.reps).map(Double.init)
    }

    private func weightBinding(_ i: Int) -> Binding<Double> {
        Binding(
            get: { weights.indices.contains(i) ? weights[i] : 0 },
            set: { if weights.indices.contains(i) { weights[i] = $0 } }
        )
    }

    private func repBinding(_ i: Int) -> Binding<Double> {
        Binding(
            get: { reps.indices.contains(i) ? reps[i] : 0 },
            set: { if reps.indices.contains(i) { reps[i] = $0 } }
        )
    }
}
