//
//  TCPServer.swift
//  TCPClient
//
//  Created by Riccardo Rizzo on 28/07/2023.
//

import Foundation
import Network

protocol TCPServerDelegate {
    func tcpServerDidReceive(connection:NWConnection, data: Data) -> ()
    func tcpServerDidSent(connection:NWConnection, data: Data) -> ()
}

class TCPServer {
    let port: NWEndpoint.Port
        let listener: NWListener
        var delegate: TCPServerDelegate?

        private var connectionsByID: [Int: ServerConnection] = [:]

        init(port: UInt16) {
            self.port = NWEndpoint.Port(rawValue: port)!
            listener = try! NWListener(using: .tcp, on: self.port)
        }

        func start() throws {
            print("Server starting...")
            listener.stateUpdateHandler = self.stateDidChange(to:)
            listener.newConnectionHandler = self.didAccept(nwConnection:)
            listener.start(queue: .main)
        }

        func stateDidChange(to newState: NWListener.State) {
            switch newState {
            case .ready:
              print("Server ready.")
            case .failed(let error):
                print("Server failure, error: \(error.localizedDescription)")
                exit(EXIT_FAILURE)
            default:
                break
            }
        }

        private func didAccept(nwConnection: NWConnection) {
            let connection = ServerConnection(nwConnection: nwConnection)
            self.connectionsByID[connection.id] = connection
            connection.didStopCallback = { _ in
                self.connectionDidStop(connection)
            }
            connection.start()
            connection.delegate = self.delegate
//            connection.send(data: "Welcome you are connection: \(connection.id)".data(using: .utf8)!)
            print("server did open connection \(connection.id)")
        }

        private func connectionDidStop(_ connection: ServerConnection) {
            self.connectionsByID.removeValue(forKey: connection.id)
            print("server did close connection \(connection.id)")
        }

        func stop() {
            self.listener.stateUpdateHandler = nil
            self.listener.newConnectionHandler = nil
            self.listener.cancel()
            for connection in self.connectionsByID.values {
                connection.didStopCallback = nil
                connection.stop()
            }
            self.connectionsByID.removeAll()
        }
    
    func sendToAll(data: String, useHex: Bool) {
        var buff: [UInt8] = []
        var useHexDec = 0
        if(!useHex) {
            var currentChar = ""
            data.forEach { char in
                
                if (char == "\\" || useHexDec > 0) {  //we are passing hex
                    if(useHexDec < 3) {
                        if(useHexDec > 0) {
                            currentChar = currentChar + String(char)
                        }
                        useHexDec = useHexDec + 1
                    } else {
                        useHexDec = 0
                        currentChar = currentChar.replacingOccurrences(of: "\\", with: "")
                        let code = UInt8(strtoul(currentChar, nil, 16))
                        buff.append(code)
                        if(char != "\\") {
                            buff.append(contentsOf: char.utf8)
                        } else {
                            useHexDec = 1
                        }
                        currentChar = ""
                    }
                } else {
                    buff.append(contentsOf: char.utf8)
                }
                
            }
        } else {
            let msg = data.replacingOccurrences(of: " ", with: "") //remove spaces
            let s = msg.inserting(separator: " ", every: 2).split(separator: " ")
            s.forEach { hex in
                let code = UInt8(strtoul(String(hex), nil, 16))
                buff.append(code)
            }
        }
        
        
        for connection in self.connectionsByID.values {
            connection.send(data: Data(buff))
        }
    }
}



class ServerConnection {
    //The TCP maximum package size is 64K 65536
    let MTU = 65536
    var delegate: TCPServerDelegate?
    private static var nextID: Int = 0
    let  connection: NWConnection
    let id: Int

    init(nwConnection: NWConnection) {
        connection = nwConnection
        id = ServerConnection.nextID
        ServerConnection.nextID += 1
    }

    var didStopCallback: ((Error?) -> Void)? = nil

    func start() {
        print("connection \(id) will start")
        connection.stateUpdateHandler = self.stateDidChange(to:)
        setupReceive()
        connection.start(queue: .main)
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            print("connection \(id) ready")
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }

    private func setupReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: MTU) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                self.delegate?.tcpServerDidReceive(connection: self.connection, data: data)
            }
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                self.connectionDidFail(error: error)
            } else {
                self.setupReceive()
            }
        }
    }


    func send(data: Data) {
        self.connection.send(content: data, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            self.delegate?.tcpServerDidSent(connection: self.connection, data: data)
            print("connection \(self.id) did send, data: \(data as NSData)")
        }))
    }
    

    func stop() {
        print("connection \(id) will stop")
    }



    private func connectionDidFail(error: Error) {
        print("connection \(id) did fail, error: \(error)")
        stop(error: error)
    }

    private func connectionDidEnd() {
        print("connection \(id) did end")
        stop(error: nil)
    }

    private func stop(error: Error?) {
        connection.stateUpdateHandler = nil
        connection.cancel()
        connection.forceCancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
}
