import SwiftUI
import AudioToolbox

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
    @State private var cardioRunning = false
    @State private var cardioRemaining: Int = 0
    @State private var cardioTimer: Timer?
    @State private var cardioComplete = false
    // Interval mode
    @State private var isInterval = false
    @State private var intervalWork: Int = 30
    @State private var intervalRest: Int = 30
    @State private var intervalRounds: Int = 8
    @State private var currentRound: Int = 1
    @State private var isWorkPhase = true
    @State private var intervalRemaining: Int = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.primaryText)
                    Text(exercise.cue)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.secondaryText)
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
                            .foregroundColor(Theme.tertiaryText)
                    }
                }
                Text(exercise.setsReps)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(WyldeStyles.Colors.bronze)
            }
            .padding(16)

            // Alternatives panel
            if showAlternatives && !alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ALTERNATIVES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Theme.tertiaryText)
                    ForEach(alternatives, id: \.self) { alt in
                        Text("→ \(alt)")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.secondaryText)
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
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [WyldeStyles.Colors.gold, Color(hex: "A6834A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else if exercise.isCardio {
                // Cardio / Interval timer
                VStack(spacing: 10) {
                    if cardioComplete {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(WyldeStyles.Colors.sage)
                            Text("Complete")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(WyldeStyles.Colors.sage)
                        }
                    } else if cardioRunning && isInterval {
                        // Interval mode — work/rest phases
                        Text(isWorkPhase ? "WORK" : "REST")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(isWorkPhase ? WyldeStyles.Colors.vitalPink : WyldeStyles.Colors.vitalTeal)

                        Text("\(intervalRemaining)")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.primaryText)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: intervalRemaining)

                        Text("Round \(currentRound) of \(intervalRounds)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Theme.secondaryText)

                        // Progress dots
                        HStack(spacing: 4) {
                            ForEach(1...intervalRounds, id: \.self) { r in
                                Circle()
                                    .fill(r < currentRound ? WyldeStyles.Colors.sage : (r == currentRound ? (isWorkPhase ? WyldeStyles.Colors.vitalPink : WyldeStyles.Colors.vitalTeal) : Theme.chipBG))
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Button {
                            cardioTimer?.invalidate()
                            cardioComplete = true
                            AudioServicesPlaySystemSound(1025)
                        } label: {
                            Text("Complete")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(WyldeStyles.Colors.sage)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                    } else if cardioRunning {
                        // Standard cardio timer
                        let mins = cardioRemaining / 60
                        let secs = cardioRemaining % 60
                        Text(String(format: "%d:%02d", mins, secs))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.primaryText)
                            .contentTransition(.numericText())

                        HStack(spacing: 12) {
                            Button {
                                cardioTimer?.invalidate()
                                cardioRunning = false
                            } label: {
                                Text("Pause")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.chipBG)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            Button {
                                cardioTimer?.invalidate()
                                cardioComplete = true
                                AudioServicesPlaySystemSound(1025)
                            } label: {
                                Text("Complete")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.onAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(WyldeStyles.Colors.sage)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    } else {
                        // Start buttons — detect if interval or standard
                        let hasInterval = exercise.cue.lowercased().contains("seconds") || exercise.cue.lowercased().contains("sec on") || exercise.cue.lowercased().contains("sec work") || exercise.name.lowercased().contains("hiit") || exercise.name.lowercased().contains("tabata") || exercise.name.lowercased().contains("interval")

                        if hasInterval {
                            Button { startIntervalTimer() } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 12))
                                    Text("Start Intervals")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(Theme.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(WyldeStyles.Colors.vitalPink)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        Button { startCardioTimer() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                Text("Start \(exercise.timerMinutes) min")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(hasInterval ? Theme.secondaryText : Theme.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(hasInterval ? Theme.chipBG : WyldeStyles.Colors.vitalTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else {

            // PR + suggested weight
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let pr = pr {
                        statBadge(label: "PR", value: "\(Int(pr.bestWeight))lb × \(pr.bestReps)", color: WyldeStyles.Colors.bronze)
                    }
                    let suggestion = LiftingCoach.suggestedWeight(exercise: exercise.name, gender: gender, level: fitnessLevel)
                    if pr == nil {
                        statBadge(label: "START", value: "\(Int(suggestion.weight))lb", color: WyldeStyles.Colors.vitalBlue)
                    }
                }

                // Coaching note
                let suggestion = LiftingCoach.suggestedWeight(exercise: exercise.name, gender: gender, level: fitnessLevel)
                if pr == nil {
                    Text(suggestion.note)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.secondaryText)
                        .padding(.horizontal, 4)
                }

                // Overload tip after logging
                if let tip = lastOverloadTip {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(WyldeStyles.Colors.bronze)
                        Text(tip)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WyldeStyles.Colors.bronze)
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
                        .foregroundColor(WyldeStyles.Colors.vitalBlue)
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
        .background(Theme.elevatedBG)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.primaryText.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { initState() }
    }

    private func setRow(setIndex: Int, setLog: SetLog) -> some View {
        HStack(spacing: 6) {
            // Set number
            Text("\(setIndex + 1)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(setLog.completed ? WyldeStyles.Colors.bronze : Theme.tertiaryText)
                .frame(width: 18)

            // Reps stepper
            stepper(value: repBinding(setIndex), step: 1, label: "reps")

            // Weight stepper — hidden for bodyweight exercises
            if !LiftingCoach.isBodyweight(exercise.name) {
                stepper(value: weightBinding(setIndex), step: 5, label: "lb")
            } else {
                Text("BW")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(WyldeStyles.Colors.vitalBlue)
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
                    .foregroundColor(setLog.completed ? WyldeStyles.Colors.bronze : Theme.tertiaryText)
            }
            .disabled(setLog.completed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(setLog.completed ? WyldeStyles.Colors.bronze.opacity(0.04) : .clear)
    }

    private func stepper(value: Binding<Double>, step: Double, label: String) -> some View {
        HStack(spacing: 0) {
            Button { value.wrappedValue = max(0, value.wrappedValue - step) } label: {
                Text("−").font(.system(size: 14, weight: .medium)).foregroundColor(Theme.secondaryText)
                    .frame(width: 24, height: 30)
            }
            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.primaryText)
                .frame(minWidth: 30)
            Button { value.wrappedValue += step } label: {
                Text("+").font(.system(size: 14, weight: .medium)).foregroundColor(Theme.secondaryText)
                    .frame(width: 24, height: 30)
            }
        }
        .background(Theme.chipBG)
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
                        .foregroundColor(Theme.primaryText)
                    Text(concept.explanation)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.secondaryText)
                        .lineSpacing(2)
                }
            }
        }
        .padding(14)
        .background(Theme.appBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 4)
    }

    private func startCardioTimer() {
        cardioRemaining = exercise.timerMinutes * 60
        cardioRunning = true
        isInterval = false
        cardioTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if cardioRemaining > 0 {
                    cardioRemaining -= 1
                    if cardioRemaining <= 3 && cardioRemaining > 0 { AudioServicesPlaySystemSound(1057) }
                } else {
                    cardioTimer?.invalidate()
                    cardioComplete = true
                    AudioServicesPlaySystemSound(1025)
                    HapticManager.shared.notification(.success)
                }
            }
        }
    }

    private func startIntervalTimer() {
        // Parse intervals from cue — default 30/30 x 8
        let cue = exercise.cue.lowercased()
        if cue.contains("tabata") || cue.contains("20 sec") {
            intervalWork = 20; intervalRest = 10; intervalRounds = 8
        } else if cue.contains("30 sec") {
            intervalWork = 30; intervalRest = 30
            // Try to parse rounds
            if let match = cue.firstMatch(of: /(\d+)\s*round/) {
                intervalRounds = Int(match.1) ?? 8
            } else {
                intervalRounds = Int(exercise.timerMinutes * 60 / (intervalWork + intervalRest))
                if intervalRounds < 1 { intervalRounds = 8 }
            }
        } else {
            intervalWork = 30; intervalRest = 30; intervalRounds = 8
        }

        isInterval = true
        isWorkPhase = true
        currentRound = 1
        intervalRemaining = intervalWork
        cardioRunning = true

        cardioTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if intervalRemaining > 0 {
                    intervalRemaining -= 1
                    if intervalRemaining <= 3 && intervalRemaining > 0 {
                        AudioServicesPlaySystemSound(1057)
                    }
                } else {
                    // Phase complete
                    AudioServicesPlaySystemSound(1025)
                    HapticManager.shared.impact(.medium)

                    if isWorkPhase {
                        // Switch to rest
                        isWorkPhase = false
                        intervalRemaining = intervalRest
                    } else {
                        // Switch to work, next round
                        currentRound += 1
                        if currentRound > intervalRounds {
                            // All rounds done
                            cardioTimer?.invalidate()
                            cardioComplete = true
                            HapticManager.shared.notification(.success)
                            return
                        }
                        isWorkPhase = true
                        intervalRemaining = intervalWork
                    }
                }
            }
        }
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
