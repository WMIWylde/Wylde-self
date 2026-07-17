import SwiftUI

struct SplashView: View {
    @State private var logoOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var finished = false

    var body: some View {
        if finished {
            Color.clear
        } else {
            ZStack {
                // Cinematic dark background with subtle glow
                WyldeStyles.Colors.paper.ignoresSafeArea()

                // Ambient gold glow — top right
                RadialGradient(
                    colors: [Color(hex: "D4A574").opacity(0.12), .clear],
                    center: .init(x: 0.8, y: 0.15),
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image("LogoMark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: WyldeStyles.Colors.bronze.opacity(0.6), radius: glowRadius, x: 0, y: 0)
                        .opacity(logoOpacity)

                    Text("WYLDE SELF")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(WyldeStyles.Colors.ink)
                        .opacity(textOpacity)
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 0.6)) {
                    logoOpacity = 1
                }
                withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                    glowRadius = 28
                }
                withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
                    textOpacity = 1
                }
                withAnimation(.easeInOut(duration: 0.6).delay(1.0)) {
                    glowRadius = 8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        logoOpacity = 0
                        textOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        finished = true
                    }
                }
            }
        }
    }
}
