import SwiftUI

struct AddNoteView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var notes: [Note]
    @State private var title = ""
    @State private var content = ""
    @State private var appear = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea() // Terminal background

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("New Note")
                            .font(.largeTitle.monospaced())
                            .bold()
                            .foregroundColor(Color.green)
                            .shadow(color: Color.green.opacity(0.4), radius: 2)

                        // Title field
                        TextField("Title", text: $title)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(4)
                            .foregroundColor(Color.green)
                            .font(.title2.monospaced())
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.green, lineWidth: 1)
                            )

                        // Content editor
                        TextEditor(text: $content)
                            .frame(height: 200)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(4)
                            .foregroundColor(Color.green.opacity(0.9))
                            .font(.body.monospaced())
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.green, lineWidth: 1)
                    )
                    .shadow(color: Color.green.opacity(0.2), radius: 3, x: 0, y: 2)
                    .scaleEffect(appear ? 1 : 0.95)
                    .opacity(appear ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appear)

                    // Buttons
                    HStack(spacing: 20) {
                        MyButton(title: "Cancel", systemImage: "xmark") {
                            dismiss()
                        }
                        MyButton(title: "Save", systemImage: "checkmark") {
                            let newNote = Note(title: title, content: content)
                            notes.append(newNote)
                            dismiss()
                        }
                        .disabled(title.isEmpty || content.isEmpty)
                        .opacity((title.isEmpty || content.isEmpty) ? 0.6 : 1)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .onAppear { appear = true }
        }
    }
}

#Preview {
    NavigationStack {
        AddNoteView(notes: .constant([]))
    }
}
