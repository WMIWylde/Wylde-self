import SwiftUI

struct FutureTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = FutureVisionService.shared
    @State private var showCreationFlow = false

    private var transformationImage: UIImage? {
        guard let base64 = UserDefaults.standard.string(forKey: "wylde_future_rendering"),
              let data = Data(base64Encoded: base64),
              let img = UIImage(data: data) else { return nil }
        return img
    }

    private var beforePhoto: UIImage? {
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
            HStack(spacing: 12) {
                // Before
                VStack(spacing: 6) {
                    if let before = beforePhoto {
                        Image(uiImage: before)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(VisionTheme.surface)
                            .frame(height: 220)
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
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 220)
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
        .padding(16)
        .background(VisionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
