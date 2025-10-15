//
//  IntialView.swift
//  Learn
//
//  Created by Omakala on 12.10.2025.
//

import SwiftUI

struct InitialView: View {
    @State private var notes: [Note] = []
    @State private var showingAddNote = false
    @Namespace private var animation

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark terminal background
                Color.black.ignoresSafeArea()

                VStack {
                    // Empty state
                    if notes.isEmpty {
                        Text("No notes yet")
                            .foregroundColor(Color.green.opacity(0.6))
                            .font(.title2.monospaced())
                            .padding()
                            .transition(.opacity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach($notes) { $note in
                                    NavigationLink(destination: NoteDetailView(note: $note)) {
                                        NoteCardView(note: note)
                                            .matchedGeometryEffect(id: note.id, in: animation)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete { indexSet in
                                    withAnimation { notes.remove(atOffsets: indexSet) }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Add Note Button
                    MyButton(title: "Add Note", systemImage: "plus") {
                        showingAddNote = true
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom))
                }
            }
            .sheet(isPresented: $showingAddNote) {
                AddNoteView(notes: $notes)
            }
            .navigationTitle("Notek")
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .foregroundColor(Color.green)
        }
    }
}

#Preview {
    InitialView()
}

