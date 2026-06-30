import SwiftUI

struct FutureVisionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = FutureVisionService.shared
    @State private var showCreationFlow = false

    var body: some View {
        ZStack {
            VisionTheme.background.ignoresSafeArea()

            if service.visions.isEmpty {
                emptyState
            } else {
                gallery
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundColor(VisionTheme.accent.opacity(0.6))

            Text("Create Your Future Vision")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(VisionTheme.text)
                .multilineTextAlignment(.center)

            Text("Build a visual representation\nof the life you're becoming.")
                .font(.system(size: 15))
                .foregroundColor(VisionTheme.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                showCreationFlow = true
            } label: {
                Text("Begin")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VisionTheme.background)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(VisionTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Gallery

    private var gallery: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR FUTURE VISION")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.5)
                        .foregroundColor(VisionTheme.accent)

                    Text("The life you're building.")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(VisionTheme.text)
                }
                .padding(.top, 20)

                // Cards
                ForEach(service.visions.filter(\.isActive)) { vision in
                    VisionCard(vision: vision)
                }

                // Add more
                Button {
                    showCreationFlow = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                        Text("Add a vision")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(VisionTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(VisionTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(VisionTheme.borderActive, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}
