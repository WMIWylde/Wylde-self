import SwiftUI

/// Observes WorkoutService and switches between generator and program views.
struct WorkoutContainerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var service = WorkoutService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if service.program != nil {
                NavigationStack {
                    ProgramView()
                        .environmentObject(appState)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button { dismiss() } label: {
                                    Image(systemName: "xmark")
                                        .foregroundColor(Color(hex: "A6A29A"))
                                }
                            }
                        }
                }
            } else {
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
                                    .foregroundColor(Color(hex: "A6A29A"))
                                    .frame(width: 36, height: 36)
                                    .background(Color(hex: "111111"))
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
    }
}
