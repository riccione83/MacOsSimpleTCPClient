//
//  TCPClass.swift
//  TCPClient
//
//  Created by Riccardo Rizzo on 27/07/2023.
//

import Foundation

class TCP_Communicator: NSObject, StreamDelegate {

    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var outputDelegate: StreamDelegate?
    private var url: URL;
    private var port: UInt32;

    init(url: URL, port: UInt32) {
        self.url = url;
        self.port = port;
    }


    func connect() {
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (url.absoluteString as CFString), port, &readStream, &writeStream);
        print("Opening streams.")
        outputStream = writeStream?.takeRetainedValue()
        inputStream = readStream?.takeRetainedValue()
        outputStream?.delegate = outputDelegate ?? self;
        inputStream?.delegate = outputDelegate ?? self;
        outputStream?.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default);
        inputStream?.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default);
        outputStream?.open();
        inputStream?.open();
    }


    func disconnect(){
        print("Closing streams.");
        inputStream?.close();
        outputStream?.close();
        inputStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default);
        outputStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default);
        inputStream?.delegate = nil;
        outputStream?.delegate = nil;
        inputStream = nil;
        outputStream = nil;
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        print("stream event \(eventCode)")
        switch eventCode {
        case .openCompleted:
            print("Stream opened")
        case .hasBytesAvailable:
            if aStream == inputStream {
                var dataBuffer = Array<UInt8>(repeating: 0, count: 1024)
                var len: Int
                while (inputStream?.hasBytesAvailable)! {
                    len = (inputStream?.read(&dataBuffer, maxLength: 1024))!
                    if len > 0 {
                        let output = dataBuffer.map{ String(format:"%02X", $0) }.joined(separator: " ") //String(bytes: dataBuffer, encoding: .ascii)
                        if nil != output {
                            print("server said: \(output ?? "")")
                        }
                    }
                }
            }
        case .hasSpaceAvailable:
            print("Stream has space available now")
        case .errorOccurred:
            print("\(aStream.streamError?.localizedDescription ?? "")")
        case .endEncountered:
            aStream.close()
            aStream.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
            print("close stream")
        default:
            print("Unknown event")
        }
    }

    func send(message: String, useHex: Bool){

        let response = "msg:\(message)"
        var buff: [UInt8] = []
        var useHexDec = 0
        if(!useHex) {
            var currentChar = ""
            message.forEach { char in
                
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
            var msg = message.replacingOccurrences(of: " ", with: "") //remove spaces
            let s = msg.inserting(separator: " ", every: 2).split(separator: " ")
            s.forEach { hex in
                let code = UInt8(strtoul(String(hex), nil, 16))
                buff.append(code)
            }
        }
        
//        let buff = [UInt8](converted.utf8)
        if let _ = response.data(using: .ascii) {
            outputStream?.write(buff, maxLength: buff.count)
        }

    }
}

