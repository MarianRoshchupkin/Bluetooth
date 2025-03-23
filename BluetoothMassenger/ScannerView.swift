import SwiftUI
import CoreBluetooth

struct ScannerView: View {
    /// We create a ViewModel just for scanning/connecting
    @StateObject private var viewModel = ScannerViewModel()
    
    var body: some View {
        VStack {
            Text("Scan for BLE Devices")
                .font(.headline)
            
            List(viewModel.discoveredPeripherals, id: \.identifier) { peripheral in
                Button(action: {
                    viewModel.connect(to: peripheral)
                }) {
                    Text(peripheral.name ?? "Unknown device")
                }
            }
            
            HStack {
                TextField("Enter message", text: $viewModel.messageToSend)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    viewModel.sendMessage()
                }
                .padding(.horizontal, 8)
            }
            .padding()
            
            Spacer()
            
            Text("Received: \(viewModel.receivedMessage)")
                .padding()
                .foregroundColor(.blue)
        }
        .onAppear {
            viewModel.startScan()
        }
        .navigationTitle("Central Scanner")
        .padding()
    }
}

/// ViewModel for scanning/connecting
class ScannerViewModel: ObservableObject {
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var messageToSend: String = ""
    @Published var receivedMessage: String = ""
    
    private let scanner = BluetoothScanner()
    
    init() {
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
}

extension ScannerViewModel: BluetoothScannerDelegate {
    func didDiscoverPeripheral(_ peripheral: CBPeripheral, name: String?) {
        DispatchQueue.main.async {
            if !self.discoveredPeripherals.contains(peripheral) {
                self.discoveredPeripherals.append(peripheral)
            }
        }
    }
    
    func didConnectToPeripheral(_ peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
    }
    
    func didFailToConnect(_ peripheral: CBPeripheral, error: Error?) {
        print("Connection failed: \(String(describing: error))")
    }
    
    func didReceiveMessage(_ message: String) {
        DispatchQueue.main.async {
            self.receivedMessage = message
        }
    }
}
