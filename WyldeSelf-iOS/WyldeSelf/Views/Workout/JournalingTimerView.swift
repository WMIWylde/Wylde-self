import SwiftUI

struct JournalingTimerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMinutes: Int = 15
    @State private var remaining: Int = 15 * 60
    @State private var phase: Phase = .setup
    @State private var timer: Timer?
    @State private var isPaused = false

    enum Phase { case setup, active, complete }

    private var progress: CGFloat {
        let total = selectedMinutes * 60
        guard total > 0 else { return 0 }
        return 1.0 - CGFloat(remaining) / CGFloat(total)
    }

    private let accentColor = WyldeStyles.Colors.bronze

    var body: some View {
        ZStack {
            WyldeStyles.Colors.paper.ignoresSafeArea()

            // Subtle warm glow
            RadialGradient(
                colors: [accentColor.opacity(0.06), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()

            switch phase {
            case .setup: setupView
            case .active: activeView
            case .complete: completeView
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "pencil.line")
                .font(.system(size: 48))
                .foregroundColor(accentColor)

            Text("Journaling")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("Write what's on your mind.\nWhat you're grateful for.\nWhat you're building.")
                .font(.system(size: 15))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Duration picker
            VStack(spacing: 8) {
                Text("DURATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(WyldeStyles.Colors.stone)

                HStack(spacing: 10) {
                    ForEach([10, 15, 20], id: \.self) { mins in
                        Button {
                            selectedMinutes = mins
                            remaining = mins * 60
                        } label: {
                            Text("\(mins)m")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(selectedMinutes == mins ? WyldeStyles.Colors.paper : accentColor)
                                .frame(width: 52, height: 40)
                                .background(selectedMinutes == mins ? accentColor : WyldeStyles.Colors.sand)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(.top, 8)

            GoldButton(label: "Begin") {
                remaining = selectedMinutes * 60
                phase = .active
                startTimer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)

            Button("Skip") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.stone)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Active

    private var activeView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .frame(width: 36, height: 36)
                        .background(WyldeStyles.Colors.bone)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            // Timer
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 4)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 8) {
                    Text(timeString)
                        .font(.system(size: 44, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(WyldeStyles.Colors.ink)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: remaining)
                    Text("write")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(accentColor.opacity(0.6))
                }
            }

            Spacer().frame(height: 32)

            // Prompt
            Text(journalPrompt)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)
                .animation(.easeInOut(duration: 0.5), value: remaining / 60)

            Spacer()

            // Controls
            HStack(spacing: 24) {
                Button {
                    isPaused.toggle()
                    if isPaused { timer?.invalidate() }
                    else { startTimer() }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18))
                        .foregroundColor(WyldeStyles.Colors.ink)
                        .frame(width: 50, height: 50)
                        .background(accentColor.opacity(0.15))
                        .clipShape(Circle())
                }

                Button {
                    timer?.invalidate()
                    phase = .complete
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .frame(width: 56, height: 40)
                        .background(WyldeStyles.Colors.sand)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 50)
        }
    }

    // MARK: - Complete

    private var completeView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(WyldeStyles.Colors.sage)

            Text("Thoughts captured.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("Clarity comes from the page, not the screen.")
                .font(.system(size: 15))
                .foregroundColor(WyldeStyles.Colors.stone)

            GoldButton(label: "Continue") {
                dismiss()
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Timer

    private var timeString: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if remaining > 0 { remaining -= 1 }
                else {
                    timer?.invalidate()
                    phase = .complete
                }
            }
        }
    }

    // MARK: - Prompts
    //
    // Daily prompt sets (tester-requested): a specific prompt for TODAY,
    // stable all day, with two deepening follow-ups that surface as the
    // session progresses. 28-day cycle, identity-focused. Free-writing is
    // always allowed — the prompt is a door, not a wall.

    private static let dailySets: [[String]] = [
        ["Who did you prove yourself to be yesterday — in one small moment?",
         "What did that moment cost you? What did it give you?",
         "How does the man you're becoming handle that same moment?"],
        ["What's one promise you'll keep to yourself today, no matter what?",
         "What usually breaks that promise? Name the exact moment it slips.",
         "Write the sentence you'll say to yourself in that moment."],
        ["What are you avoiding right now?",
         "What's the real cost of avoiding it for another month?",
         "What's the smallest first move — today?"],
        ["What would your future self thank you for doing this week?",
         "What would he warn you about?",
         "What does he know about you that you keep forgetting?"],
        ["Where does your energy actually go in a normal day?",
         "Which of those drains did you choose? Which chose you?",
         "What gets the energy you take back?"],
        ["What did your body tell you this morning?",
         "When did you last override it? What happened?",
         "What would training WITH it look like today?"],
        ["What's one thing you're doing purely for appearance?",
         "Who are you performing it for?",
         "What would you do with that effort if nobody could see you?"],
        ["What made you feel strong this week?",
         "Strength for what? What does it let you carry?",
         "Where is that strength needed next?"],
        ["What's the conversation you've been putting off?",
         "What's the sentence you're afraid to say in it?",
         "What happens to you if it stays unsaid for a year?"],
        ["When did you last feel completely present?",
         "What was absent that's usually there?",
         "How do you build one pocket of that into today?"],
        ["What habit is quietly building you? What habit is quietly costing you?",
         "Which one gets more of your loyalty right now? Be honest.",
         "What would switching that loyalty look like this week?"],
        ["What are you grateful for that you earned?",
         "What are you grateful for that was given?",
         "What do you owe forward because of it?"],
        ["What does discipline feel like in your body when it's working?",
         "And what does drift feel like? How early can you catch it?",
         "Where's the drift right now?"],
        ["Who in your life gets your best? Who gets your leftovers?",
         "Is that the order you'd choose on paper?",
         "What's one exchange you'll flip this week?"],
        ["What's the story you tell about why you can't?",
         "Who sold you that story? When did you buy it?",
         "Write one paragraph of the counter-story."],
        ["What did you do yesterday that your 60-year-old self will still feel?",
         "Compounding works both ways. Which way was it?",
         "What's today's deposit?"],
        ["What are you holding that isn't yours to carry?",
         "What would setting it down actually require?",
         "Who do you become with your hands free?"],
        ["When are you most dangerous — in the best sense?",
         "What conditions produce that version of you?",
         "How many of those conditions did you build into today?"],
        ["What's one thing you know is true that you act like you don't?",
         "What's the gap costing you?",
         "What's one act today that closes it an inch?"],
        ["What would you attempt if failure stayed private?",
         "So the audience is the obstacle. Who's in the front row?",
         "What's the version you could start without telling anyone?"],
        ["What part of your day runs on autopilot?",
         "If you watched a stranger live that hour, what would you tell him?",
         "Redesign the hour in three sentences."],
        ["What's your body capable of that it wasn't a year ago?",
         "What paid for that? Keep the receipt visible.",
         "What's the next capability worth paying for?"],
        ["Who do you envy? Look closely.",
         "What exactly do they have — the thing itself, or the freedom it implies?",
         "What's your honest route to that freedom?"],
        ["What rule do you live by that you've never said out loud?",
         "Where did it come from? Does it still serve?",
         "Write the rule you'd replace it with."],
        ["What's the hardest thing you did this month?",
         "What did you find out about yourself inside it?",
         "Where does that finding get used next?"],
        ["What does 'enough' look like for you — actually?",
         "Who defined that number? You, or the feed?",
         "What changes the day you hit it?"],
        ["What would this week look like if you fully trusted yourself?",
         "Where does the trust break first?",
         "What's one rep of trust you can do today?"],
        ["What are you building that outlasts you?",
         "Who inherits it? What condition will it be in?",
         "What's today's brick?"],
    ]

    /// Today's prompt set — stable for the whole day, cycles every 28 days.
    private var todaySet: [String] {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return Self.dailySets[day % Self.dailySets.count]
    }

    /// The active prompt: today's main prompt first, deepening follow-ups
    /// as the session progresses (thirds of the selected duration).
    private var journalPrompt: String {
        let set = todaySet
        let total = selectedMinutes * 60
        let elapsed = total - remaining
        guard total > 0 else { return set[0] }
        let third = max(total / 3, 1)
        let index = min(elapsed / third, set.count - 1)
        return set[index]
    }
}
