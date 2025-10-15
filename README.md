# Notek iOS - Collaborative Real-Time Note Editor

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Collaborative Editing Theory](#collaborative-editing-theory)
4. [Binary Protocol & Serialization](#binary-protocol--serialization)
5. [WebSocket Communication](#websocket-communication)
6. [CRDT Implementation](#crdt-implementation)
7. [iOS Integration](#ios-integration)
8. [Code Structure](#code-structure)
9. [Testing & Debugging](#testing--debugging)
10. [Troubleshooting](#troubleshooting)

---

## Overview

Notek iOS is a real-time collaborative note-taking application that allows multiple users to edit the same document simultaneously across different platforms (iOS, desktop TUI, Kotlin). The app uses a sophisticated **Conflict-free Replicated Data Type (CRDT)** algorithm to ensure that all users see consistent document state without conflicts, even when editing simultaneously.

### Key Features
- **Real-time collaboration**: Multiple users can edit the same document simultaneously
- **Cross-platform compatibility**: Works with Rust TUI client and Kotlin clients
- **Conflict-free editing**: Uses CRDT algorithms to handle concurrent edits
- **Binary protocol**: Efficient custom serialization for fast communication
- **WebSocket communication**: Real-time bidirectional communication with server
- **iOS native**: Built with SwiftUI and URLSessionWebSocketTask

---

## Architecture

The system consists of three main components:

```
┌─────────────────┐    WebSocket     ┌─────────────────┐    WebSocket     ┌─────────────────┐
│   iOS Client    │◄────────────────►│  Rust Server    │◄────────────────►│  TUI Client     │
│   (Swift)       │   Binary Protocol│   (WebSocket)   │   Binary Protocol│   (Rust)        │
└─────────────────┘                  └─────────────────┘                  └─────────────────┘
        ▲                                      ▲                                      ▲
        │                                      │                                      │
        ▼                                      ▼                                      ▼
┌─────────────────┐                  ┌─────────────────┐                  ┌─────────────────┐
│ CRDT Document   │                  │ Shared Document │                  │ CRDT Document   │
│ Local State     │                  │ Server State    │                  │ Local State     │
└─────────────────┘                  └─────────────────┘                  └─────────────────┘
```

### Component Responsibilities

1. **iOS Client**: 
   - Manages local document state using CRDT
   - Handles user input and UI updates
   - Communicates with server via WebSocket
   - Serializes/deserializes binary messages

2. **Rust Server**:
   - Maintains authoritative document state
   - Broadcasts changes to all connected clients
   - Assigns unique site IDs to clients
   - Handles WebSocket connections

3. **Other Clients** (TUI, Kotlin):
   - Same CRDT logic as iOS client
   - Compatible binary protocol
   - Real-time synchronization

---

## Collaborative Editing Theory

### The Problem

Traditional collaborative editing faces several challenges:

1. **Race Conditions**: When two users edit simultaneously, whose change wins?
2. **Consistency**: How do we ensure all users see the same document?
3. **Network Delays**: Changes arrive out of order
4. **Conflicts**: Users edit the same part of the document

### The Solution: CRDTs

**Conflict-free Replicated Data Types (CRDTs)** solve these problems by:

1. **Unique Identifiers**: Every character has a unique position ID (PID)
2. **Deterministic Ordering**: PIDs can be sorted consistently across all clients
3. **Commutative Operations**: Operations can be applied in any order
4. **No Central Coordination**: Clients can operate independently

### How It Works

Instead of storing text as a simple string like `"Hello"`, we store it as:

```
Position ID          Character
─────────────────    ─────────
PID(ident: 1000, site: 1)  →  'H'
PID(ident: 2000, site: 1)  →  'e'
PID(ident: 3000, site: 1)  →  'l'
PID(ident: 4000, site: 1)  →  'l'
PID(ident: 5000, site: 1)  →  'o'
```

When a user inserts a character between 'H' and 'e', we generate a new PID with an identifier between 1000 and 2000, like `PID(ident: 1500, site: 2)`.

### Position ID (PID) Structure

Each PID consists of:
- **Identifier (ident)**: A 32-bit number indicating position
- **Site ID**: Unique identifier for each client (assigned by server)
- **Depth**: For handling complex insertions (vector of positions)

```swift
struct Position {
    let ident: UInt32    // Position in document (0 to 4,294,967,295)
    let site: UInt8      // Client ID (0 to 255)
}

struct PID {
    let positions: [Position]  // Vector for complex positioning
}
```

---

## Binary Protocol & Serialization

The app uses a custom binary protocol for efficient communication. This is much faster than JSON and uses less bandwidth.

### Message Types

The protocol supports four message types:

```
Message Type    Byte Value    Description
────────────    ──────────    ───────────
Greet           0x00          Initial handshake
NewSession      0x01          Server sends document state
Insert          0x02          Add a character
Delete          0x03          Remove a character
```

### Serialization Format

#### 1. Greet Message
```
Byte 0: 0x00
```
Simple one-byte message to initiate connection.

#### 2. Insert Message
```
Byte 0:     0x02                    (Message type)
Byte 1:     Site ID                 (Client identifier)
Byte 2:     Character length        (UTF-8 byte count)
Bytes 3-N:  Character data          (UTF-8 encoded)
Byte N+1:   PID depth               (Number of positions)
Bytes N+2+: PID data                (5 bytes per position)
```

**PID Serialization** (5 bytes per position):
```
Bytes 0-3:  Identifier (UInt32, little-endian)
Byte 4:     Site ID (UInt8)
```

#### 3. Delete Message
```
Byte 0:     0x03                    (Message type)
Byte 1:     Site ID                 (Client identifier)
Byte 2:     PID depth               (Number of positions)
Bytes 3+:   PID data                (5 bytes per position)
```

#### 4. NewSession Message (Server → Client)
```
Byte 0:     0x01                    (Message type)
Byte 1:     Assigned Site ID        (Client's new ID)
Bytes 2-9:  Atom count              (UInt64, little-endian)
Bytes 10+:  Document atoms          (Variable length)
```

**Document Atom Format**:
```
Byte 0:     Character length        (UTF-8 byte count)
Bytes 1-N:  Character data          (UTF-8 encoded)
Byte N+1:   PID depth               (Number of positions)
Bytes N+2+: PID data                (5 bytes per position)
```

### Serialization Implementation

```swift
func serialize() -> Data {
    var data = Data()
    
    switch self {
    case .greet:
        data.append(0)
        
    case .insert(let site, let pid, let character):
        data.append(2)                              // Message type
        data.append(site)                           // Site ID
        
        let utf8Data = String(character).data(using: .utf8)!
        data.append(UInt8(utf8Data.count))          // Character length
        data.append(utf8Data)                       // Character bytes
        data.append(UInt8(pid.positions.count))     // PID depth
        pid.writeBytes(to: &data)                   // PID data
        
    // ... other cases
    }
    
    return data
}
```

### Deserialization Implementation

```swift
static func deserialize(from data: Data) -> PeerMessage? {
    guard !data.isEmpty else { return nil }
    
    let messageType = data[0]
    var offset = 1
    
    switch messageType {
    case 2: // Insert
        let site = data[offset]
        offset += 1
        
        let charLength = Int(data[offset])
        offset += 1
        
        let charData = data.subdata(in: offset..<offset+charLength)
        let character = String(data: charData, encoding: .utf8)?.first ?? " "
        offset += charLength
        
        let pidDepth = Int(data[offset])
        offset += 1
        
        // Parse PID positions
        var positions: [Position] = []
        for _ in 0..<pidDepth {
            let ident = data.subdata(in: offset..<offset+4).withUnsafeBytes {
                $0.load(as: UInt32.self).littleEndian
            }
            offset += 4
            let site = data[offset]
            offset += 1
            positions.append(Position(ident: ident, site: site))
        }
        
        let pid = PID(positions: positions)
        return .insert(site: site, pid: pid, character: character)
        
    // ... other cases
    }
}
```

---

## WebSocket Communication

The app uses WebSocket for real-time bidirectional communication with the server.

### WebSocket Protocol Requirements

1. **Client-to-Server frames MUST be masked** (WebSocket specification)
2. **Server-to-Client frames MUST NOT be masked**
3. **Binary frames** are used (not text frames)
4. **Proper handshake** with HTTP upgrade

### WebSocket Frame Structure

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
|     Extended payload length continued, if payload len == 127  |
+ - - - - - - - - - - - - - - - +-------------------------------+
|                               |Masking-key, if MASK set to 1  |
+-------------------------------+-------------------------------+
| Masking-key (continued)       |          Payload Data         |
+-------------------------------- - - - - - - - - - - - - - - - +
:                     Payload Data continued ...                :
+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
|                     Payload Data continued ...                |
+---------------------------------------------------------------+
```

### iOS WebSocket Implementation

```swift
// Create WebSocket connection
let url = URL(string: "ws://192.168.1.117:9001")!
urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
webSocketTask = urlSession?.webSocketTask(with: url)
webSocketTask?.resume()

// Send message
let message = URLSessionWebSocketTask.Message.data(serializedData)
webSocketTask?.send(message) { error in
    if let error = error {
        print("Send error: \(error)")
    }
}

// Receive messages
webSocketTask?.receive { result in
    switch result {
    case .success(let message):
        switch message {
        case .data(let data):
            self.handleIncomingData(data)
        case .string(let text):
            print("Received text: \(text)")
        }
        self.receiveMessage() // Continue listening
        
    case .failure(let error):
        print("Receive error: \(error)")
    }
}
```

### Connection Flow

1. **HTTP Handshake**: Client sends HTTP upgrade request
2. **WebSocket Upgrade**: Server responds with 101 Switching Protocols
3. **Greet Message**: Client sends initial greeting
4. **NewSession Response**: Server sends document state and assigns site ID
5. **Real-time Messages**: Bidirectional insert/delete messages

---

## CRDT Implementation

### Document Structure

The collaborative document is implemented as a sorted map of PIDs to characters:

```swift
class CollaborativeDocument: ObservableObject {
    @Published var content: [PID: Character] = [:]
    @Published var displayText: String = ""
    
    func insert(_ character: Character, at pid: PID) {
        content[pid] = character
        updateDisplayText()
    }
    
    func delete(at pid: PID) {
        content.removeValue(forKey: pid)
        updateDisplayText()
    }
    
    private func updateDisplayText() {
        displayText = content.sorted { $0.key < $1.key }
            .compactMap { $0.value != "_" ? $0.value : nil }
            .map(String.init)
            .joined()
    }
}
```

### PID Generation

When inserting a character, we generate a unique PID:

```swift
func insertCharacter(_ character: Character) {
    // Generate random identifier between existing positions
    let randomIdent = UInt32.random(in: 1000..<UInt32.max-1000)
    let pid = PID(positions: [Position(ident: randomIdent, site: mySiteId)])
    
    // Update local document immediately (optimistic update)
    document.insert(character, at: pid)
    
    // Send to server for synchronization
    let insertMsg = PeerMessage.insert(site: mySiteId, pid: pid, character: character)
    sendWebSocketMessage(insertMsg.serialize())
}
```

### Conflict Resolution

The CRDT algorithm ensures conflicts are resolved deterministically:

1. **Lexicographic Ordering**: PIDs are compared position by position
2. **Site ID Tiebreaker**: If identifiers are equal, site ID determines order
3. **Depth Handling**: Longer PIDs come after shorter ones with same prefix

```swift
struct PID: Comparable {
    static func < (lhs: PID, rhs: PID) -> Bool {
        // Compare each position in the vector
        for (a, b) in zip(lhs.positions, rhs.positions) {
            if a != b {
                return a < b  // First difference determines order
            }
        }
        // If all common positions are equal, shorter PID comes first
        return lhs.positions.count < rhs.positions.count
    }
}

struct Position: Comparable {
    static func < (lhs: Position, rhs: Position) -> Bool {
        if lhs.ident != rhs.ident {
            return lhs.ident < rhs.ident  // Compare identifiers first
        }
        return lhs.site < rhs.site        // Site ID as tiebreaker
    }
}
```

### Example Conflict Resolution

Consider two users inserting simultaneously:

```
Initial document: "Hello"
User A (site 1): Inserts 'X' at position 2 → PID(ident: 1500, site: 1)
User B (site 2): Inserts 'Y' at position 2 → PID(ident: 1500, site: 2)
```

Resolution:
1. Both PIDs have same identifier (1500)
2. Site 1 < Site 2, so 'X' comes before 'Y'
3. Final result: "HeXYllo" (consistent across all clients)

---

## iOS Integration

### SwiftUI Architecture

The app uses SwiftUI with the MVVM pattern:

```
┌─────────────────────────────────────────────────────────────┐
│                        Views                                │
├─────────────────────────────────────────────────────────────┤
│  CollaborativeNoteView  │  InitialView  │  ConnectionInfo   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                    View Models                              │
├─────────────────────────────────────────────────────────────┤
│           CollaborativeClient (ObservableObject)            │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                      Models                                 │
├─────────────────────────────────────────────────────────────┤
│  CollaborativeDocument  │  PeerMessage  │  Position  │ PID │
└─────────────────────────────────────────────────────────────┘
```

### Reactive Updates

The app uses SwiftUI's reactive system for real-time updates:

```swift
class CollaborativeClient: NSObject, ObservableObject {
    @Published var document = CollaborativeDocument()
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var connectedUsers: Set<UInt8> = []
}

class CollaborativeDocument: ObservableObject {
    @Published var content: [PID: Character] = [:]
    @Published var displayText: String = ""
}
```

### View Updates

The UI automatically updates when the document changes:

```swift
struct CollaborativeNoteView: View {
    @StateObject private var collaborativeClient = CollaborativeClient()
    @State private var localText = ""
    
    var body: some View {
        TextEditor(text: $localText)
            .onReceive(collaborativeClient.document.$displayText) { newText in
                // Update UI when document changes from remote users
                if !isEditing {
                    localText = newText
                }
            }
    }
}
```

### Threading Model

- **Main Thread**: UI updates, user interaction
- **Background Thread**: WebSocket communication, message processing
- **Dispatch Queues**: Coordinate between threads

```swift
// WebSocket receives on background thread
webSocketTask?.receive { result in
    // Process message on background thread
    if let message = PeerMessage.deserialize(from: data) {
        // Update UI on main thread
        DispatchQueue.main.async {
            self.handleMessage(message)
        }
    }
}
```

---

## Code Structure

### File Organization

```
notek_IOS/Learn/
├── Models/
│   ├── Note.swift                      # Local note model
│   └── CollaborativeClient.swift       # CRDT + WebSocket client
├── Views/
│   ├── InitialView.swift              # Main note list
│   ├── CollaborativeNoteView.swift    # Real-time editor
│   ├── NoteDetailsView.swift          # Local note editor
│   └── AddNoteView.swift              # Create new note
├── Components/
│   ├── MyButton.swift                 # Custom button component
│   └── NoteCardView.swift             # Note list item
├── ContentView.swift                  # Root navigation
└── LearnApp.swift                     # App entry point
```

### Key Classes

#### CollaborativeClient
- **Purpose**: Manages WebSocket connection and CRDT synchronization
- **Responsibilities**:
  - WebSocket communication
  - Message serialization/deserialization
  - Document state management
  - User presence tracking

#### CollaborativeDocument
- **Purpose**: CRDT document implementation
- **Responsibilities**:
  - Character storage with PIDs
  - Conflict-free operations
  - Text rendering
  - Change notifications

#### PeerMessage
- **Purpose**: Protocol message representation
- **Responsibilities**:
  - Binary serialization
  - Message type handling
  - Data validation

### Data Flow

```
User Types → Local Update → Serialize → WebSocket → Server
                ↓
            UI Update ← Deserialize ← WebSocket ← Broadcast
```

1. **User Input**: User types in TextEditor
2. **Local Update**: Document updated immediately (optimistic)
3. **Serialization**: Change converted to binary message
4. **WebSocket Send**: Message sent to server
5. **Server Broadcast**: Server sends to all other clients
6. **Remote Receive**: Other clients receive and deserialize
7. **Document Update**: Remote clients update their documents
8. **UI Refresh**: SwiftUI automatically updates interface

---

## Testing & Debugging

### Local Testing

1. **Start Rust Server**:
   ```bash
   cd server && cargo run
   ```

2. **Run iOS Simulator**:
   - Build and run in Xcode
   - Use localhost (127.0.0.1) for simulator testing

3. **Test with TUI Client**:
   ```bash
   cd tui && cargo run
   ```

### Network Testing (iPhone)

1. **Update Server IP**: Change to your Mac's IP address
2. **Ensure Network Access**: Same WiFi network
3. **Check Firewall**: Allow port 9001 on Mac
4. **USB Tethering**: For development builds

### Debug Tools

#### Connection Status
```swift
@Published var connectionStatus = "Disconnected"
```
Shows current connection state in UI.

#### Message Logging
```swift
print("📥 Received message: \(message)")
print("📤 Sending: \(data.map { String(format: "%02x", $0) })")
```

#### Document State
```swift
print("Document atoms: \(document.content.count)")
print("Display text: '\(document.displayText)'")
```

### Common Issues

1. **Connection Refused**: Check server is running and IP is correct
2. **No Messages**: Verify WebSocket handshake completed
3. **Deserialization Errors**: Check binary format compatibility
4. **UI Not Updating**: Ensure @Published properties are used

---

## Troubleshooting

### Connection Issues

**Problem**: Cannot connect to server
**Solutions**:
- Verify server is running: `cargo run` in server directory
- Check IP address: Use `ifconfig` to find Mac's IP
- Test network: Ping from iPhone to Mac
- Check firewall: Allow port 9001

**Problem**: Connection drops frequently
**Solutions**:
- Check WiFi stability
- Implement reconnection logic
- Add connection timeout handling

### Synchronization Issues

**Problem**: Changes not appearing on other clients
**Solutions**:
- Check message serialization format
- Verify PID generation is unique
- Ensure site IDs are different

**Problem**: Document corruption or inconsistency
**Solutions**:
- Validate CRDT ordering logic
- Check for race conditions
- Verify all clients use same algorithm

### Performance Issues

**Problem**: Slow typing response
**Solutions**:
- Optimize local updates (optimistic UI)
- Reduce message size
- Batch multiple changes

**Problem**: High memory usage
**Solutions**:
- Implement document compaction
- Limit history retention
- Profile memory allocations

### iOS-Specific Issues

**Problem**: App crashes on background
**Solutions**:
- Handle app lifecycle events
- Pause WebSocket when backgrounded
- Implement proper cleanup

**Problem**: UI not updating
**Solutions**:
- Use @Published properties
- Ensure main thread updates
- Check ObservableObject conformance

---

## Advanced Topics

### Optimizations

1. **Delta Compression**: Send only changes, not full document
2. **Operational Transform**: More sophisticated conflict resolution
3. **Presence Awareness**: Show cursor positions of other users
4. **Offline Support**: Queue changes when disconnected

### Security Considerations

1. **Authentication**: Add user authentication
2. **Authorization**: Control document access
3. **Encryption**: Encrypt WebSocket communication
4. **Input Validation**: Sanitize all user input

### Scalability

1. **Document Sharding**: Split large documents
2. **Connection Pooling**: Optimize server resources
3. **Caching**: Cache frequently accessed documents
4. **Load Balancing**: Distribute across multiple servers

---

## Conclusion

This collaborative editing system demonstrates several advanced concepts:

- **CRDT algorithms** for conflict-free synchronization
- **Binary protocols** for efficient communication
- **WebSocket** real-time networking
- **SwiftUI** reactive user interfaces
- **Cross-platform compatibility**

The implementation provides a solid foundation for building collaborative applications and can be extended with additional features like user authentication, document persistence, and advanced editing capabilities.

The key insight is that by giving each character a unique, globally-ordered identifier (PID), we can allow multiple users to edit simultaneously without conflicts, creating a seamless collaborative experience across all platforms.