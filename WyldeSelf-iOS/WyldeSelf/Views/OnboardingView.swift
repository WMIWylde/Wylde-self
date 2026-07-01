import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 1
    @State private var name = ""
    @State private var gender = ""
    @State private var goals: Set<String> = []
    @State private var level = ""
    @State private var days = ""
    @State private var equipment = ""
    @State private var gymAccess = ""
    @State private var gymName = ""
    @State private var classes: Set<String> = []
    @State private var ageRange = ""
    @State private var heightRange = ""
    @State private var weight = ""
    @State private var weightUnit = "lbs"
    @State private var healthConcerns: Set<String> = []
    @State private var healthNotes = ""
    @State private var dietaryPrefs: Set<String> = []
    @State private var dietNotes = ""
    @State private var nameError = false
    @State private var futurePhoto: UIImage? = nil
    @State private var showPhotoPicker = false
    @State private var futureRendering: UIImage? = nil
    @State private var isRendering = false
    @State private var renderError: String?

    private let totalSteps = 6

    var body: some View {
        ZStack {
            ZStack {
                WyldeStyles.Colors.paper.ignoresSafeArea()
                AmbientBackground(
                    glowColor: Color(hex: "D4A574"),
                    secondaryGlow: Color(hex: "B85540"),
                    baseColors: (Color(hex: "1F1814"), Color(hex: "16110F"), Color(hex: "0E0908"))
                ).opacity(0.5).clipped()
            }

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        switch step {
                        case 1: step1
                        case 2: step2
                        case 3: step3
                        case 4: step4
                        case 5: step5
                        case 6: step6
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }

                navButtons
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1...totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i < step ? WyldeStyles.Colors.sage : (i == step ? WyldeStyles.Colors.sage.opacity(0.5) : WyldeStyles.Colors.charcoal.opacity(0.08)))
                    .frame(height: 3)
            }
        }
    }

    // MARK: - Navigation

    private var navButtons: some View {
        HStack(spacing: 12) {
            if step > 1 {
                Button("Back") {
                    step -= 1
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.stone)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    Capsule().stroke(WyldeStyles.Colors.charcoal.opacity(0.12), lineWidth: 1)
                )
            }

            Button(step == totalSteps ? "See My Future Self" : "Continue") {
                advance()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(WyldeStyles.Colors.ink)
            .frame(minWidth: step > 1 ? 0 : nil, maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(WyldeStyles.Colors.bone)
            .clipShape(Capsule())
        }
    }

    private func advance() {
        if step == 1 {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { nameError = true; return }
            nameError = false
        }
        if step == 5 {
            // Moving to step 6 — save photo and start rendering
            if let photo = futurePhoto, let jpegData = photo.jpegData(compressionQuality: 0.8) {
                let base64 = jpegData.base64EncodedString()
                UserDefaults.standard.set(base64, forKey: "wylde_future_photo")
            }
            step = 6
            Task { await generateFutureSelf() }
            return
        }
        if step < totalSteps {
            step += 1
        } else {
            complete()
        }
    }

    private func complete() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.userName = trimmed
        appState.gender = gender
        appState.goals = Array(goals)
        appState.fitnessLevel = level
        appState.trainingDays = days
        appState.equipment = equipment
        appState.gymAccess = gymAccess
        appState.gymName = gymName
        appState.classPreferences = Array(classes).filter { $0 != "Not interested" }
        appState.ageRange = ageRange
        appState.heightRange = heightRange
        appState.weight = weight
        appState.weightUnit = weightUnit
        appState.healthConcerns = Array(healthConcerns)
        appState.healthNotes = healthNotes
        appState.dietaryPrefs = Array(dietaryPrefs)
        appState.dietNotes = dietNotes
        // Save rendered future self if generated
        if let rendering = futureRendering, let jpegData = rendering.jpegData(compressionQuality: 0.9) {
            let base64 = jpegData.base64EncodedString()
            UserDefaults.standard.set(base64, forKey: "wylde_future_rendering")
        }
        appState.onboardingComplete = true
        appState.awardXP(100, reason: "Profile created")
        // Sync profile to Supabase so clinician dashboard shows real data
        Task { await AuthService.shared.syncProfile(appState: appState) }
    }

    // MARK: - Step 1: Name & Gender

    private var step1: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader("What should we call you?", sub: "This is your journey. Let's make it personal.")

            fieldGroup("First name") {
                TextField("Your name", text: $name)
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(WyldeStyles.Colors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(nameError ? WyldeStyles.Colors.error.opacity(0.6) : WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .onChange(of: name) { nameError = false }
            }

            fieldGroup("I identify as") {
                singleSelect(options: ["Male", "Female"], selection: $gender)
            }
        }
    }

    // MARK: - Step 2: Goals, Level, Equipment, Gym, Classes

    private var step2: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader("What are you training for?", sub: "Select all that apply — we'll build around your goals.")

            fieldGroup("Your goals", optional: true) {
                multiSelect(options: ["Burn fat", "Build muscle", "Get lean & athletic", "Build confidence", "Improve endurance", "Increase flexibility"], selection: $goals)
            }

            fieldGroup("Current fitness level") {
                singleSelect(options: ["Beginner", "Intermediate", "Advanced"], selection: $level)
            }

            fieldGroup("Days per week") {
                singleSelect(options: ["3 days", "4 days", "5 days", "6 days"], selection: $days)
            }

            fieldGroup("Do you have equipment at home?") {
                singleSelect(options: ["Yes — full setup", "Some basics", "No equipment"], selection: $equipment)
            }

            fieldGroup("Do you have access to a gym?") {
                singleSelect(options: ["Yes", "No", "Sometimes"], selection: $gymAccess)
            }

            if gymAccess == "Yes" || gymAccess == "Sometimes" {
                fieldGroup("Which gym?") {
                    TextField("Equinox, LA Fitness, Anytime...", text: $gymName)
                        .font(.system(size: 15))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(WyldeStyles.Colors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(WyldeStyles.Colors.ink)
                }
            }

            fieldGroup("Open to workout classes?", optional: true) {
                multiSelect(options: ["Yoga", "Pilates", "Spin / Cycling", "HIIT classes", "Boxing", "Swimming", "Not interested"], selection: $classes)
            }
        }
    }

    // MARK: - Step 3: Body Details

    private var step3: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader("A few details", sub: "Helps us calibrate your program. Skip anything you'd rather not share.")

            fieldGroup("Age range") {
                singleSelect(options: ["18–24", "25–34", "35–44", "45–54", "55+"], selection: $ageRange)
            }

            fieldGroup("Height") {
                singleSelect(options: ["Under 5'4\"", "5'4\"–5'7\"", "5'8\"–5'11\"", "6'0\"–6'3\"", "Over 6'3\""], selection: $heightRange)
            }

            fieldGroup("Current weight") {
                HStack(spacing: 8) {
                    TextField("e.g. 180", text: $weight)
                        .keyboardType(.numberPad)
                        .font(.system(size: 15))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(WyldeStyles.Colors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(WyldeStyles.Colors.ink)
                        .frame(maxWidth: 140)

                    singleSelect(options: ["lbs", "kg"], selection: $weightUnit)
                }
            }

            fieldGroup("Health concerns", optional: true) {
                multiSelect(options: ["Lower back pain", "Knee issues", "Shoulder injury", "High blood pressure", "Diabetes", "Postpartum", "Heart condition", "Arthritis", "None"], selection: $healthConcerns)

                TextField("Anything else we should know...", text: $healthNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 14))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(WyldeStyles.Colors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Step 4: Dietary Preferences

    private var step4: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader("Almost there", sub: "Any dietary preferences? Then we'll build your future self.")

            fieldGroup("Dietary preferences", optional: true) {
                multiSelect(options: ["No restrictions", "Vegetarian", "Vegan", "Gluten-free", "Dairy-free", "Keto", "Paleo", "Halal", "Kosher", "Nut allergy", "Shellfish allergy"], selection: $dietaryPrefs)

                TextField("Any other dietary needs or allergies...", text: $dietNotes)
                    .font(.system(size: 14))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(WyldeStyles.Colors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Step 5: Future Self Photo

    private var step5: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader("See your future self", sub: "Upload a photo of yourself. We'll show you what you'll look like after following through.")

            // Photo display / upload area
            VStack(spacing: 16) {
                if let photo = futurePhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                        )

                    Button("Change photo") {
                        showPhotoPicker = true
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WyldeStyles.Colors.sage)
                } else {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        VStack(spacing: 14) {
                            Image(systemName: "person.crop.rectangle.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(WyldeStyles.Colors.stone)
                            Text("Tap to upload a photo")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(WyldeStyles.Colors.ink)
                            Text("Full body or waist-up works best")
                                .font(.system(size: 12))
                                .foregroundColor(WyldeStyles.Colors.stone)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .background(WyldeStyles.Colors.bone)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Skip option
            if futurePhoto == nil {
                Button("Skip for now") {
                    complete()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.stone)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(image: $futurePhoto)
        }
    }

    // MARK: - Step 6: Future Self Rendering

    private var step6: some View {
        VStack(spacing: 24) {
            if isRendering {
                // Generating
                Spacer().frame(height: 40)

                ZStack {
                    // Ambient glow while generating
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [WyldeStyles.Colors.gold.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 160
                            )
                        )
                        .frame(width: 280, height: 280)

                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(WyldeStyles.Colors.gold)
                            .scaleEffect(1.3)

                        Text("Building your future self...")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundColor(WyldeStyles.Colors.ink)

                        Text("AI is rendering what you'll look like\nafter following through.")
                            .font(.system(size: 13))
                            .foregroundColor(WyldeStyles.Colors.stone)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                }
            } else if let rendering = futureRendering {
                // Show the result
                Text("This is who you're becoming.")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(WyldeStyles.Colors.ink)

                Image(uiImage: rendering)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)

                Text("12-week transformation")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(WyldeStyles.Colors.gold)

                Text("This image evolves as you progress.\nEvery workout, every meal, every ritual moves you closer.")
                    .font(.system(size: 13))
                    .foregroundColor(WyldeStyles.Colors.stone)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Button {
                    complete()
                } label: {
                    Text("Let's Begin")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1816"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
            } else if let error = renderError {
                // Error state
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundColor(WyldeStyles.Colors.clay)

                Text("Couldn't generate your transformation")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(WyldeStyles.Colors.ink)

                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(WyldeStyles.Colors.stone)

                Button("Try Again") {
                    Task { await generateFutureSelf() }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.sage)

                Button("Skip for now") {
                    complete()
                }
                .font(.system(size: 13))
                .foregroundColor(WyldeStyles.Colors.stone)
            } else {
                // No photo was uploaded — skip rendering
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 44))
                        .foregroundColor(WyldeStyles.Colors.gold)

                    Text("Your journey starts now.")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)

                    Text("Upload a photo anytime from the Future tab\nto see your transformation.")
                        .font(.system(size: 13))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Button {
                        complete()
                    } label: {
                        Text("Let's Begin")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1816"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 40)
            }
        }
    }

    // MARK: - Future Self Generation

    private func generateFutureSelf() async {
        guard let photo = futurePhoto,
              let jpegData = photo.jpegData(compressionQuality: 0.6) else {
            // No photo — skip to complete state
            isRendering = false
            return
        }

        isRendering = true
        renderError = nil

        let base64 = "data:image/jpeg;base64," + jpegData.base64EncodedString()
        let g = gender.isEmpty ? "male" : gender.lowercased()
        let userGoals = goals.isEmpty ? ["Get lean & athletic"] : Array(goals)

        guard let url = URL(string: "https://www.wyldeself.com/api/generate-image") else {
            renderError = "Invalid URL"
            isRendering = false
            return
        }

        let payload: [String: Any] = [
            "mode": "physique",
            "timeline": "12weeks",
            "gender": g,
            "goals": userGoals,
            "image_base64": base64,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 90
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            #if DEBUG
            print("[Onboarding] Future Self response: \(httpCode)")
            #endif

            struct Resp: Codable { let success: Bool?; let image_base64: String?; let error: String? }
            let resp = try JSONDecoder().decode(Resp.self, from: data)

            if let imgBase64 = resp.image_base64,
               let cleanBase64 = imgBase64.components(separatedBy: ",").last,
               let imgData = Data(base64Encoded: cleanBase64),
               let image = UIImage(data: imgData) {
                futureRendering = image
                #if DEBUG
                print("[Onboarding] ✅ Future Self image generated")
                #endif
            } else {
                renderError = resp.error ?? "Image generation failed"
                #if DEBUG
                print("[Onboarding] ❌ Future Self failed: \(resp.error ?? "unknown")")
                #endif
            }
        } catch {
            renderError = error.localizedDescription
            #if DEBUG
            print("[Onboarding] ❌ Future Self error: \(error.localizedDescription)")
            #endif
        }

        isRendering = false
    }

    // MARK: - Shared Components

    private func stepHeader(_ title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)
                .lineSpacing(1)
            Text(sub)
                .font(.system(size: 15))
                .foregroundColor(WyldeStyles.Colors.stone)
                .lineSpacing(3)
        }
        .padding(.bottom, 8)
    }

    private func fieldGroup<Content: View>(_ label: String, optional: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .regular))
                    .tracking(1.1)
                    .foregroundColor(WyldeStyles.Colors.stone)
                if optional {
                    Text("(optional)")
                        .font(.system(size: 10))
                        .foregroundColor(WyldeStyles.Colors.stone.opacity(0.6))
                }
            }
            content()
        }
    }

    private func singleSelect(options: [String], selection: Binding<String>) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                PillButton(label: option, isSelected: selection.wrappedValue == option) {
                    selection.wrappedValue = option
                }
            }
        }
    }

    private func multiSelect(options: [String], selection: Binding<Set<String>>) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                PillButton(label: option, isSelected: selection.wrappedValue.contains(option)) {
                    if selection.wrappedValue.contains(option) {
                        selection.wrappedValue.remove(option)
                    } else {
                        selection.wrappedValue.insert(option)
                    }
                }
            }
        }
    }
}

// MARK: - Pill Button

struct PillButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .tracking(0.2)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .foregroundColor(isSelected ? WyldeStyles.Colors.sage : WyldeStyles.Colors.stone)
                .background(isSelected ? WyldeStyles.Colors.sage.opacity(0.12) : Color.clear)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? WyldeStyles.Colors.sage.opacity(0.3) : WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (wrapping pills)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (offsets, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Photo Picker (UIImagePickerController wrapper)

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
