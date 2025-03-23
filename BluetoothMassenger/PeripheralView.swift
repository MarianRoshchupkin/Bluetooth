import SwiftUI
import CoreBluetooth

struct PeripheralView: View {
    /// A separate ViewModel for the peripheral
    @StateObject private var viewModel = PeripheralViewModel()
    
    var body: some View {
        VStack {
            Text("Peripheral (Server)")
                .font(.headline)
            
            HStack {
                Button("Start Advertising") {
                    viewModel.startAdvertising()
                }
                .padding()
                
                Button("Stop Advertising") {
                    viewModel.stopAdvertising()
                }
                .padding()
            }
            
            Spacer()
        }
        .navigationTitle("Peripheral")
        .padding()
    }
}

/// ViewModel for the peripheral side
class PeripheralViewModel: ObservableObject {
    private let peripheralManager = BluetoothPeripheralManager()
    
    func startAdvertising() {
        peripheralManager.startAdvertising()
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }
}
