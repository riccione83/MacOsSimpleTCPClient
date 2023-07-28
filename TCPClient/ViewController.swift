//
//  ViewController.swift
//  TCPClient
//
//  Created by Riccardo Rizzo on 27/07/2023.
//

import Cocoa
import Foundation

class ViewController: NSViewController, StreamDelegate, NSTextFieldDelegate {
    
    
    @IBOutlet weak var lblHost: NSTextField!
    @IBOutlet weak var lblPort: NSTextField!
    @IBOutlet weak var btnSend: NSButton!
    @IBOutlet weak var btnConnect: NSButton!
    @IBOutlet weak var lblText: NSTextField!
    @IBOutlet weak var lblData: NSTextField!
    @IBOutlet weak var useHEX: NSButton!
    
    
    var tcpClient: TCP_Communicator? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let port = UserDefaults().value(forKey: "tcp_port") as? Int64 ?? 0
        lblPort.stringValue = "\(String(describing: port))"
        lblHost.stringValue = UserDefaults().value(forKey: "tcp_host") as? String ?? ""
        lblData.delegate = self
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
        send(message: "00 00 00 00 00 00 00 FB 0C 01 06 00 00 00 F3 38 36 36 39 30 37 30 35 37 35 39 35 39 32 37 0D 0A 54 31 2D 34 2E 30 2D 35 34 38 2E 35 2D 31 2E 36 2D 39 30 2E 38 2D 30 2D 32 36 39 36 2D 30 2D 30 2D 30 2E 30 2D 37 30 2D 30 2E 30 2D 31 31 2D 46 33 2D 30 2E 30 2D 30 2E 30 2D 37 31 2E 39 2D 30 2E 30 2D 30 2E 30 2D 30 2D 30 2E 30 2D 32 2D 33 2D 30 2D 30 2D 30 2D 31 2D 30 2D 31 30 30 2E 30 2D 30 30 2D 30 2E 30 2D 30 2E 30 2D 30 2E 30 0D 0A 38 36 36 39 30 37 30 35 37 35 39 35 39 32 37 0D 0A 54 32 2D 36 33 36 36 2E 34 39 30 2D 31 38 32 32 2E 35 2D 30 2E 30 2D 30 2E 34 2D 30 2D 30 2D 31 34 33 2D 30 2D 30 2D 33 36 35 2D 38 37 2D 34 35 33 2D 30 2D 30 2D 30 2D 32 2D 34 30 35 33 33 33 2D 30 2D 30 2E 30 2D 30 2E 30 2D 30 2E 30 2D 34 38 34 2D 30 30 2D 32 2D 30 2D 30 2E 30 30 0D 0A 01 00 00 1C C8")
    }
    
    
    @IBAction func btnConnectClick(_ sender: Any) {
        if(tcpClient == nil) {
            let host = lblHost.stringValue
            let port = lblPort.intValue
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
    
    @IBAction func btnSendClick(_ sender: Any) {
        send(message: lblText.stringValue)
    }
    
    func send(message: String){
        if(tcpClient != nil) {
            tcpClient?.send(message: message, useHex: useHEX.state == .on)
            lblData.stringValue += "Sending : \(message)\n"
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
                            lblData.stringValue += dataBuffer[0...len-1].map{ String(format:"%02X", $0) }.joined(separator: " ")
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
            print("close stream")
        default:
            print("Unknown event")
        }
    }
    
}

