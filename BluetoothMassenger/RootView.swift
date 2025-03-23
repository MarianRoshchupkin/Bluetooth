import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink("Scan Devices (Central)", destination: ScannerView())
                NavigationLink("Act as Peripheral (Server)", destination: PeripheralView())
            }
            .navigationTitle("Bluetooth Demo")
        }
    }
}
