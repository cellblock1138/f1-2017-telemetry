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
    
    let telemetry = Telemetry()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        telemetry.delegate = self
        speedLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 42, weight: .regular)
        setLabel(value: "0")
        telemetry.start()
    }
    
    private let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter = numberFormatter
        return formatter
    }()
    
    private func setLabel(value: String) {
        DispatchQueue.main.async {
            self.speedLabel.stringValue = value
        }
    }
}

extension ViewController: TelemetryDelegate {
    
    func packetUpdated(_ packet: UDPPacket, _ sender: Telemetry) {
        let kph = Measurement(value: Double(packet.m_speed * 3.6), unit: UnitSpeed.kilometersPerHour)
        self.setLabel(value: self.formatter.string(from: kph))
    }
}
