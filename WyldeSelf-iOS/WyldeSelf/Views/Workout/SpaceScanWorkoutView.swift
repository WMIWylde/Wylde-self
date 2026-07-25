import SwiftUI
import PhotosUI

/// Take a photo of your space + available equipment → AI generates a
/// bodyweight-focused workout tailored to what it sees.
struct SpaceScanWorkoutView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = WorkoutService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    var body: some View {
        ZStack {
            WyldeStyles.Colors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
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
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        if isAnalyzing {
                            generatingView
                        } else if capturedImage != nil {
                            photoPreview
                        } else {
                            capturePrompt
                        }

                        if let error = analysisError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                capturedImage = image
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    capturedImage = img
                }
            }
        }
    }

    // MARK: - Capture Prompt

    private var capturePrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 44))
                .foregroundColor(WyldeStyles.Colors.vitalTeal.opacity(0.6))

            Text("Scan Your Space")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("Take a photo of where you're training and any equipment you have. We'll build a bodyweight-focused workout for your setup.")
                .font(.system(size: 14))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            VStack(spacing: 12) {
                Button { showCamera = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                        Text("Take Photo")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(WyldeStyles.Colors.vitalTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 14))
                        Text("Choose from Library")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(WyldeStyles.Colors.bone)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Photo Preview

    private var photoPreview: some View {
        VStack(spacing: 20) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(WyldeStyles.Colors.vitalTeal.opacity(0.3), lineWidth: 1)
                    )
            }

            Text("Your Space")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("We'll analyze the space and any equipment visible, then build a workout prioritizing bodyweight movements.")
                .font(.system(size: 13))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            GoldButton(label: "Generate Workout", action: {
                generateWorkout()
            })

            Button {
                capturedImage = nil
                selectedPhotoItem = nil
                analysisError = nil
            } label: {
                Text("Retake Photo")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WyldeStyles.Colors.stone)
            }
        }
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            ProgressView()
                .tint(WyldeStyles.Colors.vitalTeal)
                .scaleEffect(1.3)

            Text("Analyzing your space...")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("Building a bodyweight-focused workout for your setup")
                .font(.system(size: 13))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Generate

    private func generateWorkout() {
        guard let image = capturedImage else { return }
        isAnalyzing = true
        analysisError = nil

        Task {
            await service.generateFromSpacePhoto(image, appState: appState)
            isAnalyzing = false

            if service.program != nil {
                dismiss()
            } else {
                analysisError = service.generationError ?? "Couldn't generate a workout. Try again or take a clearer photo."
            }
        }
    }
}

