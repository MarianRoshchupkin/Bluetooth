import Foundation
import CoreBluetooth

/// Делегат протокола, чтобы передавать события наружу (например, в SwiftUI View).
protocol BluetoothScannerDelegate: AnyObject {
    func didDiscoverPeripheral(_ peripheral: CBPeripheral, name: String?)
    func didConnectToPeripheral(_ peripheral: CBPeripheral)
    func didFailToConnect(_ peripheral: CBPeripheral, error: Error?)
    func didReceiveMessage(_ message: String)
}

/// Central Manager для сканирования и подключения к BLE-устройствам.
class BluetoothScanner: NSObject {
    
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [CBPeripheral] = []
    
    /// Сервис и характеристика, которые мы ищем (должны совпадать с Peripheral)
    let targetServiceUUID = CBUUID(string: "1234")
    let targetCharacteristicUUID = CBUUID(string: "ABCD")
    
    /// Выбранное для подключения периферийное устройство
    private var connectedPeripheral: CBPeripheral?
    private var targetCharacteristic: CBCharacteristic?
    
    weak var delegate: BluetoothScannerDelegate?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    /// Начать сканирование всех устройств (или только нужного сервиса).
    func startScan() {
        // Убеждаемся, что Bluetooth включен (state == .poweredOn)
        if centralManager.state == .poweredOn {
            print("Start scanning for peripherals...")
            // Если ищем только конкретный сервис:
            // centralManager.scanForPeripherals(withServices: [targetServiceUUID], options: nil)
            // Если хотим искать все:
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth не включен или недоступен.")
        }
    }
    
    /// Остановить сканирование
    func stopScan() {
        centralManager.stopScan()
    }
    
    /// Подключиться к выбранному устройству
    func connect(to peripheral: CBPeripheral) {
        stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Отправить сообщение на подключённую периферию (через нашу характеристику).
    func sendMessage(_ message: String) {
        guard let characteristic = targetCharacteristic,
              let peripheral = connectedPeripheral else {
            print("Характеристика или периферия не найдены")
            return
        }
        if let data = message.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("CBCentralManager: poweredOn")
            // Как только Bluetooth включён, начинаем сканирование
            startScan()
        case .poweredOff:
            print("CBCentralManager: poweredOff")
        case .resetting:
            print("CBCentralManager: resetting")
        case .unauthorized:
            print("CBCentralManager: unauthorized")
        case .unsupported:
            print("CBCentralManager: unsupported")
        case .unknown:
            print("CBCentralManager: unknown")
        @unknown default:
            print("CBCentralManager: неизвестное состояние")
        }
    }
    
    // Вызывается при обнаружении периферии
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any],
                       rssi RSSI: NSNumber) {
        
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        print("Найдено устройство: \(name ?? "Безымянное") | UUID = \(peripheral.identifier)")
        
        // Сохраним периферию в массив (если хотим отобразить список)
        if discoveredPeripherals.first(where: { $0.identifier == peripheral.identifier }) == nil {
            discoveredPeripherals.append(peripheral)
        }
        
        // Уведомим делегата (например, View), чтобы обновить UI
        delegate?.didDiscoverPeripheral(peripheral, name: name)
    }
    
    // Успешное подключение
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Подключились к \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([targetServiceUUID])  // Ищем нужный сервис
        delegate?.didConnectToPeripheral(peripheral)
    }
    
    // Ошибка подключения
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Не удалось подключиться к \(peripheral.name ?? "Unknown"), ошибка: \(String(describing: error))")
        delegate?.didFailToConnect(peripheral, error: error)
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothScanner: CBPeripheralDelegate {
    // Когда нашли сервисы
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Ошибка при discoverServices: \(error)")
            return
        }
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == targetServiceUUID {
                // Ищем характеристику
                peripheral.discoverCharacteristics([targetCharacteristicUUID], for: service)
            }
        }
    }
    
    // Когда нашли характеристики
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Ошибка при discoverCharacteristics: \(error)")
            return
        }
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == targetCharacteristicUUID {
                targetCharacteristic = characteristic
                print("Найдена целевая характеристика: \(characteristic.uuid)")
                
                // Можно подписаться на уведомления, если хотим при получении данных
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    // При получении обновлений характеристики (notify/indicate)
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Ошибка при didUpdateValue: \(error)")
            return
        }
        
        guard let data = characteristic.value,
              let message = String(data: data, encoding: .utf8) else { return }
        
        print("Получено сообщение: \(message)")
        delegate?.didReceiveMessage(message)
    }
    
    // Подтверждение записи (type: .withResponse)
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Ошибка записи: \(error)")
        } else {
            print("Сообщение успешно отправлено!")
        }
    }
}
