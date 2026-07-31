import SwiftUI

/// Always shows the workout picker so the user can choose daily.
/// Today's program session is the top option when a program exists.
struct WorkoutContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            WorkoutGeneratorView()
                .environmentObject(appState)

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.secondaryText)
                            .frame(width: 36, height: 36)
                            .background(Theme.elevatedBG)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
    }
}
