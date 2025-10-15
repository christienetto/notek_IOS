import SwiftUI

struct NoteDetailView: View {
    @Binding var note: Note
    @State private var editMode = false
    @State private var editedTitle = ""
    @State private var editedContent = ""
    @State private var appear = false

    var body: some View {
        ZStack {
            // Terminal dark background
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    VStack(alignment: .leading, spacing: 10) {
                        if editMode {
                            // Edit mode fields
                            TextField("Title", text: $editedTitle)
                                .padding()
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(4)
                                .foregroundColor(Color.green)
                                .font(.title2.monospaced())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.green, lineWidth: 1)
                                )

                            TextEditor(text: $editedContent)
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
                        } else {
                            // Read-only mode
                            Text(note.title)
                                .font(.largeTitle.monospaced())
                                .bold()
                                .foregroundColor(Color.green)
                                .shadow(color: Color.green.opacity(0.4), radius: 2)

                            Text(note.date, style: .date)
                                .font(.caption.monospaced())
                                .foregroundColor(Color.green.opacity(0.6))

                            Divider()
                                .background(Color.green.opacity(0.6))

                            Text(note.content)
                                .font(.body.monospaced())
                                .foregroundColor(Color.green.opacity(0.9))
                        }
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
                        if editMode {
                            MyButton(title: "Cancel", systemImage: "xmark") {
                                editMode = false
                            }
                            MyButton(title: "Save", systemImage: "checkmark") {
                                note.title = editedTitle
                                note.content = editedContent
                                editMode = false
                            }
                        } else {
                            MyButton(title: "Edit", systemImage: "pencil") {
                                editedTitle = note.title
                                editedContent = note.content
                                editMode = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .navigationTitle(editMode ? "Edit Note" : "Note")
        .onAppear { appear = true }
    }
}

#Preview {
    NavigationStack {
        NoteDetailView(note: .constant(Note(title: "Sample Note", content: "This is some sample content.")))
    }
}
