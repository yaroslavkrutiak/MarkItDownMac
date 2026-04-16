import SwiftUI

/// An indeterminate circular progress ring with continuous rotation animation.
struct ProgressRingView: View {
    var lineWidth: CGFloat = 3
    var color: Color = .accentColor
    var size: CGFloat = 48

    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.75)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
