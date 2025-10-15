//
//  CollaborativeNoteView.swift
//  Learn
//
//  Real-time collaborative note editing view
//

import SwiftUI

struct CollaborativeNoteView: View {
    @StateObject private var collaborativeClient = CollaborativeClient()
    @State private var localText = ""
    @State private var isEditing = false
    @State private var showingConnectionInfo = false
    
    var body: some View {
        ZStack {
            // Terminal dark background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Connection status header
                HStack {
                    Circle()
                        .fill(collaborativeClient.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(collaborativeClient.connectionStatus)
                        .font(.caption.monospaced())
                        .foregroundColor(Color.green.opacity(0.8))
                    
                    Spacer()
                    
                    if !collaborativeClient.connectedUsers.isEmpty {
                        Text("\(collaborativeClient.connectedUsers.count) users")
                            .font(.caption.monospaced())
                            .foregroundColor(Color.green.opacity(0.6))
                    }
                    
                    Button(action: { showingConnectionInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Color.green.opacity(0.6))
                    }
                }
                .padding(.horizontal)
                
                // Collaborative text editor
                VStack(alignment: .leading, spacing: 10) {
                    Text("Collaborative Document")
                        .font(.title2.monospaced())
                        .bold()
                        .foregroundColor(Color.green)
                    
                    ZStack(alignment: .topLeading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                        
                        // Text editor
                        TextEditor(text: $localText)
                            .font(.body.monospaced())
                            .foregroundColor(Color.green.opacity(0.9))
                            .background(Color.clear)
                            .padding(12)
                            .onChange(of: localText) { newValue in
                                handleTextChange(newValue)
                            }
                            .onTapGesture {
                                isEditing = true
                            }
                    }
                    .frame(minHeight: 300)
                }
                .padding()
                .background(Color.black.opacity(0.85))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
                .shadow(color: Color.green.opacity(0.2), radius: 3, x: 0, y: 2)
                
                // Action buttons
                HStack(spacing: 20) {
                    MyButton(
                        title: collaborativeClient.isConnected ? "Disconnect" : "Connect",
                        systemImage: collaborativeClient.isConnected ? "wifi.slash" : "wifi"
                    ) {
                        if collaborativeClient.isConnected {
                            collaborativeClient.disconnect()
                        } else {
                            collaborativeClient.connect()
                        }
                    }
                    
                    MyButton(title: "Clear", systemImage: "trash") {
                        localText = ""
                    }
                    .disabled(!collaborativeClient.isConnected)
                    .opacity(collaborativeClient.isConnected ? 1 : 0.5)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Collaborative Editor")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(collaborativeClient.document.$displayText) { newText in
            // Update local text when document changes from remote users
            if !isEditing {
                localText = newText
            }
        }
        .onAppear {
            // Auto-connect when view appears
            collaborativeClient.connect()
        }
        .onDisappear {
            // Disconnect when view disappears
            collaborativeClient.disconnect()
        }
        .sheet(isPresented: $showingConnectionInfo) {
            ConnectionInfoView(client: collaborativeClient)
        }
    }
    
    private func handleTextChange(_ newText: String) {
        // Simple character-by-character sync
        // In a production app, you'd want more sophisticated diff handling
        let oldText = collaborativeClient.document.displayText
        
        if newText.count > oldText.count {
            // Characters were added
            let addedChars = String(newText.dropFirst(oldText.count))
            for char in addedChars {
                collaborativeClient.insertCharacter(char)
            }
        }
        
        // Reset editing flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isEditing = false
        }
    }
}

struct ConnectionInfoView: View {
    @ObservedObject var client: CollaborativeClient
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Connection Status")
                            .font(.headline.monospaced())
                            .foregroundColor(Color.green)
                        
                        HStack {
                            Circle()
                                .fill(client.isConnected ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            Text(client.connectionStatus)
                                .font(.body.monospaced())
                                .foregroundColor(Color.green.opacity(0.8))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Server")
                            .font(.headline.monospaced())
                            .foregroundColor(Color.green)
                        
                        Text("192.168.1.117:9001")
                            .font(.body.monospaced())
                            .foregroundColor(Color.green.opacity(0.8))
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Connected Users")
                            .font(.headline.monospaced())
                            .foregroundColor(Color.green)
                        
                        if client.connectedUsers.isEmpty {
                            Text("No other users")
                                .font(.body.monospaced())
                                .foregroundColor(Color.green.opacity(0.6))
                        } else {
                            ForEach(Array(client.connectedUsers).sorted(), id: \.self) { userId in
                                Text("User \(userId)")
                                    .font(.body.monospaced())
                                    .foregroundColor(Color.green.opacity(0.8))
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Connection Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.green)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CollaborativeNoteView()
    }
}