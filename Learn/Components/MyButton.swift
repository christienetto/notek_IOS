import SwiftUI

struct MyButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.headline.monospaced())
                    .foregroundColor(Color.green)
                Text(title)
                    .font(.body.monospaced())
                    .foregroundColor(Color.green)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.8))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.green, lineWidth: 1)
            )
            .cornerRadius(4)
            .scaleEffect(isPressed ? 0.95 : 1)
            .shadow(color: Color.green.opacity(0.2), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation { isPressed = true } }
                .onEnded { _ in withAnimation { isPressed = false } }
        )
    }
}

#Preview {
    MyButton(title: "Tap me", systemImage: "plus") {}
        .padding()
        .previewLayout(.sizeThatFits)
        .background(Color.black)
}
