import SwiftUI

struct FutureTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = FutureVisionService.shared
    @State private var showCreationFlow = false
    @State private var showPhotoPicker = false
    @State private var newPhoto: UIImage?
    @State private var isRerendering = false
    @State private var rerenderError: String?
    @State private var refreshTick = 0
    @State private var showSavedToast = false

    private var transformationImage: UIImage? {
        _ = refreshTick
        guard let base64 = UserDefaults.standard.string(forKey: "wylde_future_rendering"),
              let data = Data(base64Encoded: base64),
              let img = UIImage(data: data) else { return nil }
        return img
    }

    private var beforePhoto: UIImage? {
        _ = refreshTick
        guard let base64 = UserDefaults.standard.string(forKey: "wylde_future_photo"),
              let data = Data(base64Encoded: base64),
              let img = UIImage(data: data) else { return nil }
        return img
    }

    var body: some View {
        ZStack {
            VisionTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FUTURE YOU")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.5)
                            .foregroundColor(VisionTheme.accent)
                            .padding(.top, 60)

                        Text("The life you're building.")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(VisionTheme.text)
                    }

                    // Transformation card — shows onboarding AI rendering
                    if let rendered = transformationImage {
                        transformationCard(rendered)
                    }

                    // Vision gallery
                    if !service.visions.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("YOUR VISIONS")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(2.5)
                                .foregroundColor(VisionTheme.accent)

                            ForEach(service.visions.filter(\.isActive)) { vision in
                                VisionCard(vision: vision)
                            }
                        }
                    }

                    // Empty-state imagery — when the user hasn't created any
                    // visions yet, ground the "Create Your Future Vision"
                    // CTA in a calm hero so the page doesn't feel blank.
                    if service.visions.isEmpty {
                        Image.wylde(.emptyStateCalm)
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .opacity(0.85)
                    }

                    // Create vision button
                    Button { showCreationFlow = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: service.visions.isEmpty ? "sparkles" : "plus")
                                .font(.system(size: 16, weight: .medium))
                            Text(service.visions.isEmpty ? "Create Your Future Vision" : "Add a Vision")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(VisionTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(VisionTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(VisionTheme.borderActive, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showCreationFlow) {
            NavigationStack {
                VisionCreationFlow()
                    .environmentObject(appState)
                    .navigationBarHidden(true)
            }
        }
    }

    // MARK: - Transformation Card

    private func transformationCard(_ rendered: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR TRANSFORMATION")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.5)
                .foregroundColor(VisionTheme.accent)

            // Before / After
            GeometryReader { geo in
                let halfWidth = (geo.size.width - 12) / 2
                HStack(spacing: 12) {
                    // Before
                    VStack(spacing: 6) {
                        if let before = beforePhoto {
                            Image(uiImage: before)
                                .resizable()
                                .scaledToFill()
                                .frame(width: halfWidth, height: 200)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(VisionTheme.surface)
                                .frame(width: halfWidth, height: 200)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(VisionTheme.textFaint)
                                )
                        }
                        Text("Now")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(VisionTheme.textMuted)
                    }

                    // After
                    VStack(spacing: 6) {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFill()
                            .frame(width: halfWidth, height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(hex: "C8A96E").opacity(0.4), Color(hex: "C8A96E").opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                        Text("Future You")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "C8A96E"))
                    }
                }
            }
            .frame(height: 230)

            // Actions: update the base photo, save the rendering
            HStack(spacing: 10) {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Update Photo", systemImage: "camera")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(VisionTheme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .disabled(isRerendering)

                Button {
                    UIImageWriteToSavedPhotosAlbum(rendered, nil, nil, nil)
                    showSavedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSavedToast = false }
                } label: {
                    Label(showSavedToast ? "Saved ✓" : "Save Image", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(VisionTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            if isRerendering {
                HStack(spacing: 8) {
                    ProgressView().tint(VisionTheme.accent)
                    Text("Rendering your future self…")
                        .font(.system(size: 12))
                        .foregroundColor(VisionTheme.textMuted)
                }
            }
            if let err = rerenderError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "C26B5A"))
            }
        }
        .padding(16)
        .background(VisionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(image: $newPhoto)
        }
        .onChange(of: newPhoto) { _, photo in
            guard let photo else { return }
            Task { await rerender(with: photo) }
        }
    }

    // MARK: - Re-render with a new photo

    private func rerender(with photo: UIImage) async {
        guard let jpegData = photo.jpegData(compressionQuality: 0.8) else { return }
        isRerendering = true
        rerenderError = nil
        UserDefaults.standard.set(jpegData.base64EncodedString(), forKey: "wylde_future_photo")
        refreshTick += 1

        let base64 = "data:image/jpeg;base64," + jpegData.base64EncodedString()
        let g = appState.gender.isEmpty ? "male" : appState.gender.lowercased()
        let userGoals = appState.goals.isEmpty ? ["Get lean & athletic"] : appState.goals

        guard let url = URL(string: "https://www.wyldeself.com/api/generate-image") else {
            isRerendering = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 90
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "mode": "physique",
            "timeline": "12weeks",
            "gender": g,
            "goals": userGoals,
            "image_base64": base64,
        ])

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Codable { let image_base64: String?; let error: String? }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            if let img = resp.image_base64,
               let clean = img.components(separatedBy: ",").last,
               let imgData = Data(base64Encoded: clean),
               UIImage(data: imgData) != nil {
                UserDefaults.standard.set(clean, forKey: "wylde_future_rendering")
                refreshTick += 1
            } else {
                rerenderError = resp.error ?? "Rendering failed. Try again."
            }
        } catch {
            rerenderError = "Rendering failed. Check your connection."
        }
        isRerendering = false
    }
}
