import SwiftUI

struct FutureTabView: View {
    @EnvironmentObject var appState: AppState

    enum Section: String, CaseIterable {
        case vision = "Vision"
        case transformation = "Transformation"
    }

    @State private var selectedSection: Section = .vision

    var body: some View {
        ZStack {
            VisionTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Segment control
                segmentPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Content
                switch selectedSection {
                case .vision:
                    FutureVisionView()
                        .environmentObject(appState)
                case .transformation:
                    WebViewScreen(path: "#future")
                }
            }
        }
    }

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(Section.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(selectedSection == section ? VisionTheme.text : VisionTheme.textFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedSection == section ? VisionTheme.surfaceElevated : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(VisionTheme.surface)
        .clipShape(Capsule())
    }
}
