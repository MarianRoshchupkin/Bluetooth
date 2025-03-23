import Foundation
import CoreBluetooth

/// Менеджер периферийного устройства (GATT Server).
class BluetoothPeripheralManager: NSObject {
    
    private var peripheralManager: CBPeripheralManager!
    
    /// Сервис и характеристика, которые будем рекламировать
    let serviceUUID = CBUUID(string: "1234")
    let characteristicUUID = CBUUID(string: "ABCD")
    
    private var transferCharacteristic: CBMutableCharacteristic?
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    /// Запустить рекламу BLE
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {
            print("Peripheral Manager не в состоянии poweredOn")
            return
        }
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: "BLE-Peripheral",
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
        ]
        peripheralManager.startAdvertising(advertisementData)
        print("Начали рекламу с сервисом \(serviceUUID)")
    }
    
    /// Остановить рекламу
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        print("Остановили рекламу")
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothPeripheralManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("PeripheralManager: poweredOn")
            // Создадим GATT-сервис и характеристику
            setupServiceAndCharacteristics()
        case .poweredOff:
            print("PeripheralManager: poweredOff")
        case .resetting:
            print("PeripheralManager: resetting")
        case .unauthorized:
            print("PeripheralManager: unauthorized")
        case .unsupported:
            print("PeripheralManager: unsupported")
        case .unknown:
            print("PeripheralManager: unknown")
        @unknown default:
            print("PeripheralManager: неизвестное состояние")
        }
    }
    
    /// Создаём сервис и характеристику, добавляем в peripheralManager
    private func setupServiceAndCharacteristics() {
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Характеристика с возможностью записи от Central (.write)
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.write, .notify],
            value: nil,
            permissions: [.writeable]
        )
        
        service.characteristics = [characteristic]
        self.transferCharacteristic = characteristic
        
        peripheralManager.add(service)
        print("Добавили сервис \(serviceUUID) и характеристику \(characteristicUUID)")
    }
    
    // Когда сервисы добавлены в Peripheral Manager
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Ошибка при добавлении сервиса: \(error)")
            return
        }
        print("Сервис успешно добавлен. Готовы к рекламе.")
    }
    
    // Событие записи (Central записал данные в характеристику)
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            // Проверяем, что это наша характеристика
            guard let characteristic = transferCharacteristic,
                  request.characteristic.uuid == characteristic.uuid else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                return
            }
            
            // Сохраняем данные, если есть
            if let value = request.value {
                // Обрабатываем как строку
                let message = String(data: value, encoding: .utf8) ?? "unknown"
                print("Получено сообщение от Central: \(message)")
                
                // Если нужно уведомить других подписчиков (notify), меняем value
                characteristic.value = value
                peripheralManager.updateValue(value, for: characteristic, onSubscribedCentrals: nil)
            }
            
            // Подтверждаем успешную запись
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
