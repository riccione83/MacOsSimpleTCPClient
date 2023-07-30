//
//  ViewController.swift
//  TCPClient
//
//  Created by Riccardo Rizzo on 27/07/2023.
//

import Cocoa
import Foundation
import Network

class ViewController: NSViewController, StreamDelegate, NSTextFieldDelegate,TCPServerDelegate {

    
    @IBOutlet weak var lblHost: NSTextField!
    @IBOutlet weak var lblPort: NSTextField!
    @IBOutlet weak var btnSend: NSButton!
    @IBOutlet weak var btnConnect: NSButton!
    @IBOutlet weak var lblText: NSTextField!
    @IBOutlet weak var lblData: NSTextField!
    @IBOutlet weak var useHEX: NSButton!
    @IBOutlet weak var checkServerMode: NSButton!
    
    
    var tcpClient: TCP_Communicator? = nil
    var isServer = false
    var server: TCPServer? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let port = UserDefaults().value(forKey: "tcp_port") as? Int64 ?? 0
        lblPort.stringValue = "\(String(describing: port))"
        lblHost.stringValue = UserDefaults().value(forKey: "tcp_host") as? String ?? ""
        lblData.delegate = self
        let serverMode = UserDefaults().value(forKey: "serverMode") as? Bool
        checkServerMode.state =  serverMode == nil || !(serverMode ?? false) ? .off : .on
        btnConnect.title = checkServerMode.state == .on ? "Listen" : "Connect"
    }
    
    @IBAction func checkServerModeClick(_ sender: Any) {
        btnConnect.title = checkServerMode.state == .on ? "Listen" : "Connect"
        UserDefaults().set(checkServerMode.state == .on, forKey: "serverMode")
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    @IBAction func btnIMEIClick(_ sender: Any) {
        send(message: "00 0F 33 35 36 33 30 37 30 34 32 34 34 31 30 31 33")
        
    }
    @IBAction func btnActivityClick(_ sender: Any) {
        send(message: "00 00 00 00 00 00 00 36 08 01 00 00 01 6B 40 D8 EA 30 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 05 02 15 03 01 01 01 42 5E 0F 01 F1 00 00 60 1A 01 4E 00 00 00 00 00 00 00 00 01 00 00 C7 CF")
    }
    
    @IBAction func btnCANClick(_ sender: Any) {
        send(message: "00 00 00 00 00 00 00 fb 0c 01 06 00 00 00 f3 54 31 2d 34 2e 30 2d 35 34 38 2e 35 2d 31 2e 36 2d 39 30 2e 38 2d 30 2d 32 36 39 36 2d 30 2d 30 2d 30 2e 30 2d 37 30 2d 30 2e 30 2d 31 31 2d 46 33 2d 30 2e 30 2d 30 2e 30 2d 37 31 2e 39 2d 30 2e 30 2d 30 2e 30 2d 30 2d 30 2e 30 2d 32 2d 33 2d 30 2d 30 2d 30 2d 31 2d 30 2d 31 30 30 2e 30 2d 30 30 2d 30 2e 30 2d 30 2e 30 2d 30 2e 30 0d 0a 38 36 36 39 30 37 30 35 37 35 39 35 39 32 37 0d 0a 54 32 2d 36 33 36 36 2e 34 39 30 2d 31 38 32 32 2e 35 2d 30 2e 30 2d 30 2e 34 2d 30 2d 30 2d 31 34 33 2d 30 2d 30 2d 33 36 35 2d 38 37 2d 34 35 33 2d 30 2d 30 2d 30 2d 32 2d 34 30 35 33 33 33 2d 30 2d 30 2e 30 2d 30 2e 30 2d 30 2e 30 2d 34 38 34 2d 30 30 2d 32 2d 30 2d 30 2e 30 30 0d 0a 01 0 0 1c c8")
    }
    
    
    @IBAction func btnConnectClick(_ sender: Any) {
        let host = lblHost.stringValue
        let port = lblPort.intValue
        
        if(checkServerMode.state == .on) {
            if(!isServer) {
                initServer(port: UInt16(port))
            } else {
                server?.stop()
                btnConnect.title = "Listen"
                isServer = false
            }
            
        } else {
            if(tcpClient == nil) {
                
                print("Starting with \(host):\(port)")
                tcpClient = TCP_Communicator(url: (URL(string:host) ?? URL(string: "localhost"))!, port: UInt32(port))
                tcpClient?.outputDelegate = self
                tcpClient?.connect()
                if(tcpClient?.outputStream != nil) {
                    btnConnect.title = "Disconnect"
                }
                UserDefaults().set(host, forKey: "tcp_host")
                UserDefaults().set(port, forKey: "tcp_port")
                
            } else {
                tcpClient?.disconnect();
                tcpClient = nil;
                btnConnect.title = "Connect"
            }
        }
    }
    
    @IBAction func btnSendClick(_ sender: Any) {
        send(message: lblText.stringValue)
    }
    
    func send(message: String){
        if(!isServer) {
            if(tcpClient != nil) {
                tcpClient?.send(message: message, useHex: useHEX.state == .on)
                lblData.stringValue += "Sending : \(message)\n "
            }
        } else {
            server?.sendToAll(data: message, useHex: useHEX.state == .on)
        }
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        print("stream event \(eventCode)")
        switch eventCode {
        case .openCompleted:
            print("Stream opened")
        case .hasBytesAvailable:
            if aStream == tcpClient?.inputStream {
                var dataBuffer = Array<UInt8>(repeating: 0, count: 1024)
                var len: Int
                while (tcpClient?.inputStream?.hasBytesAvailable)! {
                    len = (tcpClient?.inputStream?.read(&dataBuffer, maxLength: 1024))!
                    if len > 0 {
                        let output = String(bytes: dataBuffer, encoding: .ascii)
                        if output != nil {
                            lblData.stringValue += "Received: "
                            lblData.stringValue += useHEX.state == .on ? dataBuffer[0...len-1].map{ String(format:"%02X", $0) }.joined(separator: " ") : output!
                            lblData.stringValue += "\n"
                        }
                    }
                }
            }
        case .hasSpaceAvailable:
            print("Stream has space available now")
        case .errorOccurred:
            print("\(aStream.streamError?.localizedDescription ?? "")")
            tcpClient?.disconnect();
            tcpClient = nil;
            btnConnect.title = "Connect"
        case .endEncountered:
            aStream.close()
            aStream.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
            tcpClient?.disconnect();
            tcpClient = nil;
            btnConnect.title = "Connect"
            print("close stream")
        default:
            print("Unknown event")
        }
    }
    
    func tcpServerDidReceive(connection:NWConnection, data: Data) {
        let message = String(data: data, encoding: .utf8)
        print("connection from \(connection.endpoint) did receive, data: \(data as NSData) string: \(message ?? "-")")
        lblData.stringValue += "Received from \(connection.endpoint): "
        lblData.stringValue +=  useHEX.state == .on ? data.map{ String(format:"%02X", $0) }.joined(separator: " ") : message!
        lblData.stringValue += "\n"
    }
    
    func tcpServerDidSent(connection: NWConnection, data: Data) {
//        lblData.stringValue += "Sending : \(String(data.utg))\n "
    }
    
    
    func initServer(port: UInt16) {
        server = TCPServer(port: port)
        server?.delegate = self
        do {
            try server?.start()
            isServer = true
            btnConnect.title = "Stop"
        } catch {
            isServer = false
        }
    }
    
}

