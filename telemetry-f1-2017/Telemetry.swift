//
//  Telemetry.swift
//  telemetry-f1-2017
//
//  Created by Mitchell Holland on 9/5/18.
//  Copyright © 2018 Mitchell Holland. All rights reserved.
//

import AppKit

class Telemetry {
    
    public weak var delegate: TelemetryDelegate?
    
    private let communicationQueue = DispatchQueue(label: "MXHCommunicationQueue", qos: .userInteractive)
    
    private let refreshRate = 60.0
    private var port: Int {
        let defaultPort = 20777
        let defaults = UserDefaults.standard
        
        guard let udpPortString = defaults.string(forKey: "UDPPort") else {
            return defaultPort
        }
        guard let udpPort = Int(udpPortString) else {
            return defaultPort
        }
        return udpPort
    }
    
    private var timer: Timer!
    
    
    /// Use `start` to start listening to port.
    /// When data is read from socket, the delegate method of
    /// `packetUpdated` will be called with a `UDPPacket`
    public func start() {
        communicationQueue.async {
            self.timer = Timer(timeInterval: 1.0/self.refreshRate, target: self, selector: #selector(self.updateData), userInfo: nil, repeats: true)
            let runLoop = RunLoop.current
            runLoop.add(self.timer, forMode: .commonModes)
            runLoop.run()
        }
    }
    
    private var udp: UDPPacket? {
        didSet {
            guard let packet = udp else {
                return
            }
            delegate?.packetUpdated(packet, self)
        }
    }
    
    @objc private func updateData() {
        let socket = boundSocket
        // dont read into global `udp`, but read into `packet` then replace contents
        var packet = UDPPacket()
        read(fromSocket: socket, into: &packet)
        udp = packet
    }
    
    private var address_len = socklen_t(MemoryLayout<sockaddr_in>.stride)
    
    private lazy var boundSocket: Int32 = {
        let sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock != -1 else {
            fatalError("error creating socket: \(sock)")
        }
        
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(htons(value: CUnsignedShort(port)))
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        
        /// `int bind(int socket, const struct sockaddr *address, socklen_t address_len);`
        /// use `withUnsafePointer` because old APIs are great
        withUnsafePointer(to: &address) {
            
            /// cast `sockaddr_in` -> `sockaddr` with `withMemoryRebound`
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                let b = Darwin.bind(sock, $0, address_len)
                precondition(b == 0, "error binding socket. \(errno) \(String(utf8String: strerror(errno)) ?? "-")")
            }
        }
        return sock
    }()
    
    private func read(fromSocket socket: Int32, into packet: UnsafeMutablePointer<UDPPacket>!) {
        var address = sockaddr()
        recvfrom(socket, packet, 2048, 0, &address, &address_len)
    }
    
    //    https://gist.github.com/neonichu/c504267a23ca3f3126bb
    private func htons(value: CUnsignedShort) -> CUnsignedShort {
        return (value << 8) + (value >> 8)
    }
}

protocol TelemetryDelegate: AnyObject {
    
    /// When a new valid packet is read, it this will be called
    ///
    /// - Parameters:
    ///   - packet: the newly read packet
    ///   - sender: the sender
    func packetUpdated(_ packet: UDPPacket, _ sender: Telemetry)
}
