import SwiftUI

struct FoodScannerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var tracker = MacroTrackerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var analysis: FoodAnalysis?
    @State private var selectedMealType: MealType = .lunch
    @State private var showCamera = false
    @State private var showPhotoPicker = false

    enum Phase { case capture, analyzing, result }
    @State private var phase: Phase = .capture

    var body: some View {
        ZStack {
            WyldeStyles.Colors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("LOG FOOD")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(WyldeStyles.Colors.bronze)
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
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        switch phase {
                        case .capture: capturePhase
                        case .analyzing: analyzingPhase
                        case .result: resultPhase
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(image: $capturedImage)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $capturedImage)
        }
        .onChange(of: capturedImage) {
            if let img = capturedImage {
                phase = .analyzing
                Task { await analyze(img) }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Capture Phase

    private var capturePhase: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundColor(WyldeStyles.Colors.bronze.opacity(0.5))

            Text("Snap your meal")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("Take a photo or choose from your library.\nAI will estimate the macros.")
                .font(.system(size: 14))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Meal type selector
            VStack(spacing: 8) {
                Text("MEAL")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(WyldeStyles.Colors.stone)

                HStack(spacing: 8) {
                    ForEach(MealType.allCases, id: \.self) { type in
                        mealTypeButton(type)
                    }
                }
            }
            .padding(.top, 8)

            // Action buttons
            VStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    GoldButton(label: "Take Photo") {
                        showCamera = true
                    }
                }

                Button {
                    showPhotoPicker = true
                } label: {
                    Text("Choose from library")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WyldeStyles.Colors.bronze)
                }
            }
            .padding(.top, 8)
        }
    }

    private func mealTypeButton(_ type: MealType) -> some View {
        let isSelected = selectedMealType == type
        return Button { selectedMealType = type } label: {
            Text(type.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? WyldeStyles.Colors.paper : WyldeStyles.Colors.stone)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? WyldeStyles.Colors.bronze : WyldeStyles.Colors.sand)
                .clipShape(Capsule())
        }
    }

    // MARK: - Analyzing Phase

    private var analyzingPhase: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.3))
                    )
            }

            ProgressView()
                .tint(WyldeStyles.Colors.bronze)
                .scaleEffect(1.2)

            Text("Analyzing your meal...")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("Estimating calories, protein, carbs, and fat")
                .font(.system(size: 13))
                .foregroundColor(WyldeStyles.Colors.stone)
        }
    }

    // MARK: - Result Phase

    private var resultPhase: some View {
        VStack(spacing: 16) {
            // Photo
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if let analysis = analysis {
                // Description
                Text(analysis.description)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WyldeStyles.Colors.ink)

                // Macro summary
                HStack(spacing: 0) {
                    macroBox(label: "Calories", value: "\(analysis.calories)", color: WyldeStyles.Colors.bronze)
                    macroBox(label: "Protein", value: "\(analysis.protein)g", color: WyldeStyles.Colors.vitalTeal)
                    macroBox(label: "Carbs", value: "\(analysis.carbs)g", color: WyldeStyles.Colors.vitalOrange)
                    macroBox(label: "Fat", value: "\(analysis.fat)g", color: WyldeStyles.Colors.vitalPurple)
                }
                .background(WyldeStyles.Colors.bone)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Items breakdown
                if !analysis.items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BREAKDOWN")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(WyldeStyles.Colors.stone)

                        ForEach(Array(analysis.items.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(WyldeStyles.Colors.ink)
                                Spacer()
                                Text("\(item.calories) cal · \(item.protein)g P")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(WyldeStyles.Colors.stone)
                            }
                        }
                    }
                    .padding(14)
                    .background(WyldeStyles.Colors.bone)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Log button
                GoldButton(label: "Log \(selectedMealType.rawValue)") {
                    tracker.addMeal(name: analysis.description, analysis: analysis, mealType: selectedMealType)
                    // Sync to AppState
                    appState.proteinLogged = tracker.totalProtein
                    appState.caloriesLogged = tracker.totalCalories
                    appState.carbsLogged = tracker.totalCarbs
                    appState.fatLogged = tracker.totalFat
                    dismiss()
                }
                .padding(.top, 8)

                // Retake
                Button {
                    capturedImage = nil
                    self.analysis = nil
                    phase = .capture
                } label: {
                    Text("Retake photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WyldeStyles.Colors.stone)
                }
            }

            if let error = tracker.analysisError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(WyldeStyles.Colors.clay)

                GoldButton(label: "Try Again") {
                    if let img = capturedImage {
                        phase = .analyzing
                        Task { await analyze(img) }
                    }
                }
            }
        }
    }

    private func macroBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.stone)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: - Analysis

    private func analyze(_ image: UIImage) async {
        let result = await tracker.analyzePhoto(image)
        if let r = result {
            analysis = r
            phase = .result
        } else {
            phase = .capture
        }
    }
}
