//
//  ViewController.swift
//  telemetry-f1-2017
//
//  Created by Mitchell Holland on 4/5/18.
//  Copyright © 2018 Mitchell Holland. All rights reserved.
//

import AppKit

class ViewController: NSViewController {
    
    @IBOutlet private weak var speedLabel: NSTextField!
    
    let communicationQueue = DispatchQueue(label: "MXHCommunicationQueue", qos: .userInteractive)
    
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
    
    private var timer: Timer?
    private func startTimer() {
        communicationQueue.async {
            self.timer = Timer(timeInterval: 1.0/self.refreshRate, target: self, selector: #selector(self.updateData), userInfo: nil, repeats: true)
            let runLoop = RunLoop.current
            runLoop.add(self.timer!, forMode: .commonModes)
            runLoop.run()
        }
    }
    
    private var udp: UDPPacket? {
        didSet {
            guard let packet = udp else {
                return
            }
            let kph = Measurement(value: Double(packet.m_speed * 3.6), unit: UnitSpeed.kilometersPerHour)
            self.setLabel(value: self.formatter.string(from: kph))
        }
    }
    
    private let startNotification = Notification.init(name: Notification.Name(rawValue: "MXHStartNotification"))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        speedLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 42, weight: .regular)
        setLabel(value: "0")
        NotificationCenter.default.addObserver(self, selector: #selector(start), name: startNotification.name, object: nil)
        NotificationCenter.default.post(startNotification)
    }
    
    @objc private func start() {
        startTimer()
    }
    
    private let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter = numberFormatter
        return formatter
    }()
    
    @objc private func updateData() {
        let socket = boundSocket
        // dont read into global `udp`, but read into `packet` then replace contents
        var packet = UDPPacket()
        read(fromSocket: socket, into: &packet)
        udp = packet
    }
    
    private func setLabel(value: String) {
        DispatchQueue.main.async {
            self.speedLabel.stringValue = value
        }
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
