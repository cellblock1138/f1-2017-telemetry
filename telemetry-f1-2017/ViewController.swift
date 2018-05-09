//
//  ViewController.swift
//  telemetry-f1-2017
//
//  Created by Mitchell Holland on 4/5/18.
//  Copyright © 2018 Mitchell Holland. All rights reserved.
//

import AppKit

class ViewController: NSViewController {
    
    @IBOutlet weak var speedLabel: NSTextField!
    
    let refreshRate = 60.0
    
    lazy var timer: Timer = {
        return Timer(timeInterval: TimeInterval(exactly: 1.0/refreshRate)!, target: self, selector: #selector(go), userInfo: nil, repeats: true)
    }()
    
    var udp: UDPPacket? {
        didSet {
            guard let packet = udp else {
                return
            }
            let kph = Measurement(value: Double(packet.m_speed * 3.6), unit: UnitSpeed.kilometersPerHour)
            self.setLabel(value: self.formatter.string(from: kph))
        }
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(go), name: Notification.Name(rawValue: "MXHGo"), object: nil)
        DispatchQueue.global().async {
            NotificationCenter.default.post(Notification.init(name: Notification.Name(rawValue: "MXHGo")))
            
            RunLoop.main.add(self.timer, forMode: .commonModes)
        }
        
        speedLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 42, weight: .regular)
    }
    
    let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter = numberFormatter
        return formatter
    }()
    
    @objc func go() {
        let socket = boundSocket
        var packet = UDPPacket()
        read(fromSocket: socket, into: &packet)
        udp = packet
    }
    
    func setLabel(value: String) {
        DispatchQueue.main.async {
            self.speedLabel.stringValue = value
        }
    }
    
    private var address_len = socklen_t(MemoryLayout<sockaddr_in>.stride)
    
    lazy var boundSocket: Int32 = {
        let port = 20777
        
        let sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock != -1 else {
            fatalError("error creating socket: \(sock)")
        }
        
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(htons(value: CUnsignedShort(port)))
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        
        /// `int bind(int socket, const struct sockaddr *address, socklen_t address_len);`
        /// use `withUnsafePointer` because pointer of address is needed
        withUnsafePointer(to: &address) {
            
            /// cast `sockaddr_in` -> `sockaddr` with `withMemoryRebound`
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                let b = Darwin.bind(sock, $0, address_len)
                precondition(b == 0, "error binding socket. \(errno) \(String(utf8String: strerror(errno)) ?? "-")")
            }
        }
        return sock
    }()
    
    func read(fromSocket socket: Int32, into packet: UnsafeMutablePointer<UDPPacket>!) {
        var address = sockaddr()
        recvfrom(socket, packet, 2048, 0, &address, &address_len)
    }
    
    //    https://gist.github.com/neonichu/c504267a23ca3f3126bb
    func htons(value: CUnsignedShort) -> CUnsignedShort {
        return (value << 8) + (value >> 8)
    }
}
