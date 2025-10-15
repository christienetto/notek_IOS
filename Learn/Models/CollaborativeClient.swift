//
//  CollaborativeClient.swift
//  Learn
//
//  Collaborative editing client for real-time note synchronization
//

import Foundation
import Network

// MARK: - Core Data Structures

struct Position: Hashable, Comparable {
    let ident: UInt32
    let site: UInt8
    
    static func < (lhs: Position, rhs: Position) -> Bool {
        if lhs.ident != rhs.ident {
            return lhs.ident < rhs.ident
        }
        return lhs.site < rhs.site
    }
    
    func writeBytes(to data: inout Data) {
        data.append(contentsOf: withUnsafeBytes(of: ident.littleEndian) { Data($0) })
        data.append(site)
    }
}

struct PID: Hashable, Comparable {
    let positions: [Position]
    
    static func < (lhs: PID, rhs: PID) -> Bool {
        for (a, b) in zip(lhs.positions, rhs.positions) {
            if a != b {
                return a < b
            }
        }
        return lhs.positions.count < rhs.positions.count
    }
    
    func writeBytes(to data: inout Data) {
        for position in positions {
            position.writeBytes(to: &data)
        }
    }
}

class CollaborativeDocument: ObservableObject {
    @Published var content: [PID: Character] = [:]
    @Published var displayText: String = ""
    
    init() {}
    
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
    
    static func fromNewSessionPayload(_ data: Data) -> CollaborativeDocument {
        let doc = CollaborativeDocument()
        var offset = 9 // Skip message type (1) + site (1) + atom count (8)
        
        while offset < data.count {
            // Read character
            guard offset < data.count else { break }
            let charLength = Int(data[offset])
            offset += 1
            
            guard offset + charLength <= data.count else { break }
            let charData = data.subdata(in: offset..<offset+charLength)
            let character = String(data: charData, encoding: .utf8)?.first ?? " "
            offset += charLength
            
            // Read PID
            guard offset < data.count else { break }
            let pidDepth = Int(data[offset])
            offset += 1
            
            guard offset + (pidDepth * 5) <= data.count else { break }
            
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
            doc.content[pid] = character
        }
        
        doc.updateDisplayText()
        return doc
    }
}

enum PeerMessage {
    case greet
    case newSession(site: UInt8, doc: CollaborativeDocument)
    case insert(site: UInt8, pid: PID, character: Character)
    case delete(site: UInt8, pid: PID)
    
    func serialize() -> Data {
        var data = Data()
        
        switch self {
        case .greet:
            data.append(0)
            
        case .insert(let site, let pid, let character):
            data.append(2)
            data.append(site)
            
            let utf8Data = String(character).data(using: .utf8)!
            data.append(UInt8(utf8Data.count))
            data.append(utf8Data)
            data.append(UInt8(pid.positions.count))
            pid.writeBytes(to: &data)
            
        case .delete(let site, let pid):
            data.append(3)
            data.append(site)
            data.append(UInt8(pid.positions.count))
            pid.writeBytes(to: &data)
            
        case .newSession:
            break // We don't send this
        }
        
        return data
    }
    
    static func deserialize(from data: Data) -> PeerMessage? {
        guard !data.isEmpty else { return nil }
        
        let messageType = data[0]
        
        switch messageType {
        case 0:
            return .greet
            
        case 1: // NewSession
            guard data.count > 1 else { return nil }
            let site = data[1]
            let doc = CollaborativeDocument.fromNewSessionPayload(data)
            return .newSession(site: site, doc: doc)
            
        case 2: // Insert
            var offset = 1
            guard data.count > offset else { return nil }
            let site = data[offset]
            offset += 1
            
            guard data.count > offset else { return nil }
            let charLength = Int(data[offset])
            offset += 1
            
            guard data.count >= offset + charLength else { return nil }
            let charData = data.subdata(in: offset..<offset+charLength)
            let character = String(data: charData, encoding: .utf8)?.first ?? " "
            offset += charLength
            
            guard data.count > offset else { return nil }
            let pidDepth = Int(data[offset])
            offset += 1
            
            guard data.count >= offset + (pidDepth * 5) else { return nil }
            
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
            
        case 3: // Delete
            var offset = 1
            guard data.count > offset else { return nil }
            let site = data[offset]
            offset += 1
            
            guard data.count > offset else { return nil }
            let pidDepth = Int(data[offset])
            offset += 1
            
            guard data.count >= offset + (pidDepth * 5) else { return nil }
            
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
            return .delete(site: site, pid: pid)
            
        default:
            return nil
        }
    }
}

// MARK: - Collaborative Client

class CollaborativeClient: NSObject, ObservableObject {
    @Published var document = CollaborativeDocument()
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var connectedUsers: Set<UInt8> = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let serverHost = "192.168.1.117" // Hardcoded server IP
    private let serverPort = 9001
    
    private var mySiteId: UInt8 = 0
    private var isRunning = false
    
    func connect() {
        guard !isConnected else { return }
        
        connectionStatus = "Connecting..."
        
        let url = URL(string: "ws://\(serverHost):\(serverPort)")!
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = urlSession?.webSocketTask(with: url)
        
        webSocketTask?.resume()
        
        // Send initial greeting
        sendGreeting()
        
        // Start listening for messages
        receiveMessage()
    }
    
    func disconnect() {
        isRunning = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
            self.connectedUsers.removeAll()
        }
    }
    
    private func sendGreeting() {
        let greetData = Data([0])
        sendWebSocketMessage(greetData)
    }
    
    private func sendWebSocketMessage(_ data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.handleIncomingData(data)
                case .string(let text):
                    print("Received text: \(text)")
                @unknown default:
                    break
                }
                
                // Continue listening
                self?.receiveMessage()
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self?.connectionStatus = "Connection failed"
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func handleIncomingData(_ data: Data) {
        if let message = PeerMessage.deserialize(from: data) {
            DispatchQueue.main.async {
                self.handleMessage(message)
            }
        }
    }
    
    private func handleMessage(_ message: PeerMessage) {
        switch message {
        case .newSession(let site, let doc):
            mySiteId = site
            document = doc
            isConnected = true
            connectionStatus = "Connected (User \(site))"
            connectedUsers.insert(site)
            
        case .insert(let site, let pid, let character):
            if site != mySiteId {
                document.insert(character, at: pid)
                connectedUsers.insert(site)
            }
            
        case .delete(let site, let pid):
            if site != mySiteId {
                document.delete(at: pid)
                connectedUsers.insert(site)
            }
            
        case .greet:
            break
        }
    }
    
    func insertCharacter(_ character: Character) {
        guard isConnected else { return }
        
        let randomIdent = UInt32.random(in: 1000..<UInt32.max-1000)
        let pid = PID(positions: [Position(ident: randomIdent, site: mySiteId)])
        
        // Update local document immediately
        document.insert(character, at: pid)
        
        // Send to server
        let insertMsg = PeerMessage.insert(site: mySiteId, pid: pid, character: character)
        sendWebSocketMessage(insertMsg.serialize())
    }
    
    func deleteCharacter(at pid: PID) {
        guard isConnected else { return }
        
        // Update local document immediately
        document.delete(at: pid)
        
        // Send to server
        let deleteMsg = PeerMessage.delete(site: mySiteId, pid: pid)
        sendWebSocketMessage(deleteMsg.serialize())
    }
}

// MARK: - URLSessionWebSocketDelegate

extension CollaborativeClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isRunning = true
            self.connectionStatus = "Handshake complete"
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
            self.connectedUsers.removeAll()
        }
    }
}