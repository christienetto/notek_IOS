//
//  NoteCardView.swift
//  Learn
//
//  Created by Omakala on 12.10.2025.
//

import SwiftUI

struct NoteCardView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title)
                .font(.headline.monospaced())
                .foregroundColor(Color.green)
            Text(note.date, style: .date)
                .font(.caption.monospaced())
                .foregroundColor(Color.green.opacity(0.6))
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.green, lineWidth: 1)
        )
        .cornerRadius(4)
        .shadow(color: Color.green.opacity(0.2), radius: 3, x: 0, y: 2)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    NoteCardView(note: Note(title: "Sample Note", content: "Hello world!"))
        .padding()
        .previewLayout(.sizeThatFits)
        .background(Color.black)
}
