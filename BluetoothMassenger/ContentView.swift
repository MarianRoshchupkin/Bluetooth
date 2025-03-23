import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        VStack {
            Text("Сканирование BLE")
                .font(.headline)
            
            List(viewModel.discoveredPeripherals, id: \.identifier) { peripheral in
                Button(action: {
                    viewModel.connect(to: peripheral)
                }) {
                    Text(peripheral.name ?? "Безымянное устройство")
                }
            }
            
            HStack {
                TextField("Введите сообщение", text: $viewModel.messageToSend)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Отправить") {
                    viewModel.sendMessage()
                }
                .padding(.horizontal, 8)
            }
            .padding()
            
            Divider().padding(.vertical, 8)
            
            Text("Управление периферией")
                .font(.headline)
            HStack {
                Button("Start Advertising") {
                    viewModel.startAdvertisingPeripheral()
                }
                Button("Stop") {
                    viewModel.stopAdvertisingPeripheral()
                }
            }
            
            Spacer()
            
            Text("Получено сообщение: \(viewModel.receivedMessage)")
                .padding()
                .foregroundColor(.blue)
        }
        .onAppear {
            viewModel.startScan()
        }
        .padding()
    }
}

class ContentViewModel: ObservableObject {
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var messageToSend: String = ""
    @Published var receivedMessage: String = ""
    
    private let scanner = BluetoothScanner()
    private let peripheralManager = BluetoothPeripheralManager()
    
    init() {
        // Подпишемся на события сканера
        scanner.delegate = self
    }
    
    func startScan() {
        scanner.startScan()
    }
    
    func connect(to peripheral: CBPeripheral) {
        scanner.connect(to: peripheral)
    }
    
    func sendMessage() {
        scanner.sendMessage(messageToSend)
        messageToSend = ""
    }
    
    // Управление периферией
    func startAdvertisingPeripheral() {
        peripheralManager.startAdvertising()
    }
    
    func stopAdvertisingPeripheral() {
        peripheralManager.stopAdvertising()
    }
}

extension ContentViewModel: BluetoothScannerDelegate {
    func didDiscoverPeripheral(_ peripheral: CBPeripheral, name: String?) {
        DispatchQueue.main.async {
            if !self.discoveredPeripherals.contains(peripheral) {
                self.discoveredPeripherals.append(peripheral)
            }
        }
    }
    
    func didConnectToPeripheral(_ peripheral: CBPeripheral) {
        print("ViewModel: подключились к \(peripheral.name ?? "Unknown")")
    }
    
    func didFailToConnect(_ peripheral: CBPeripheral, error: Error?) {
        print("ViewModel: ошибка подключения: \(String(describing: error))")
    }
    
    func didReceiveMessage(_ message: String) {
        DispatchQueue.main.async {
            self.receivedMessage = message
        }
    }
}
