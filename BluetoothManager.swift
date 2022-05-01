//
//  BluetoothManager.swift
//  kkk
//
//  Created by Sirojiddinov Mirjalol on 21/02/22.
//

import UIKit
import CoreBluetooth


class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // set your UUIds
    let SERVICE_UUID = CBUUID.init(string: "")
    let CHARACTERISTIC_UUID_RX = CBUUID.init(string: "")
    let CHARACTERISTIC_UUID_TX = CBUUID.init(string: "")
    let CHARACTERISTIC_UUID_NY = CBUUID.init(string: "")
    var didReceiveData: ((String) -> Void)?
    var didConnectToBLE: ((Bool) -> Void)?
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    private var txCharacteristic: CBCharacteristic!
    private var rxCharacteristic: CBCharacteristic!
    private var nyCharacteristic: CBCharacteristic?
    private var timer: Timer?
    var token = ""
    static let shared = BluetoothManager()
 
    
    func connect(token: String) {
        self.token = token
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue(label: "BTQueue"));
        centralManager.delegate = self
        // that is used to send RSI
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.updateValue()
        })
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            print("Central is not powered on")
            didConnectToBLE?(false)
            invalidateTimer()
        } else {
            print("Central scanning for", SERVICE_UUID);
            centralManager.scanForPeripherals(withServices: [SERVICE_UUID])
            
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        self.peripheral.delegate = self
        self.centralManager.connect(self.peripheral)
        self.centralManager.stopScan()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("Found \(characteristics.count) characteristics.")
        
        for characteristic in characteristics {
            
            if characteristic.uuid.isEqual(CHARACTERISTIC_UUID_RX)  {
                rxCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            }
            
            if characteristic.uuid.isEqual(CHARACTERISTIC_UUID_TX){
                txCharacteristic = characteristic
            }
            
            if characteristic.uuid.isEqual(CHARACTERISTIC_UUID_NY){
                nyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: nyCharacteristic!)
            }
            
            
        }
        
        didConnectToBLE?(true)
        timer =  Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.updateValue()
        })
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        // if you do not send RSSI you can delete that method
        writeData(data: "DB\(RSSI)".calculateCRC(), readValue: false)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == self.peripheral {
            print("Connected to BLE device")
            peripheral.discoverServices([SERVICE_UUID]);
        }
    }
        
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        didConnectToBLE?(false)
        invalidateTimer()
        if peripheral == self.peripheral {
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print(String(decoding: characteristic.value!, as: UTF8.self))
        let string = String(decoding: characteristic.value!, as: UTF8.self)
        didReceiveData?(string)
    }
    
    // Handles discovery event
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == SERVICE_UUID {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }
    
    func writeData(data: String, readValue: Bool = true, peripheral: CBPeripheral? = BluetoothManager.shared.peripheral) {
        let data = data.description.data(using: String.Encoding.utf8)!
            guard let txChar = txCharacteristic else {return}
        if peripheral != nil {
            peripheral?.writeValue(data, for: txChar, type: .withResponse)
        }
            
            if readValue {
                readData()
            }
        
    }
    
 
    func readData() {
        peripheral.readValue(for: rxCharacteristic)
    }
    
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func updateValue() {
        BluetoothManager.shared.peripheral.readRSSI()
    }
    
}
