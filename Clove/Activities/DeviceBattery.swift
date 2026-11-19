import Foundation
#if DIRECT
import IOBluetooth
#endif

/// The battery of a Bluetooth audio device that just connected: each earbud and the case for
/// AirPods and other earbuds, one level for headphones and speakers. Levels are percentages;
/// nil when the device doesn't report that part (a bud still in its case, say).
struct DeviceBattery: Equatable {
    var left: Int?
    var right: Int?
    var chargingCase: Int?
    var single: Int?

    var isEmpty: Bool { left == nil && right == nil && chargingCase == nil && single == nil }

    /// Only Macs' private Bluetooth API reports these, so the direct build reads them and the App
    /// Store build shows the device without its battery.
    static func of(audioDeviceUID uid: String?, name: String) -> DeviceBattery? {
        #if DIRECT
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return nil }
        let connected = paired.filter { $0.isConnected() }
        // Core Audio's ID for a Bluetooth output is the device's address; the name is the fallback.
        let address = uid.flatMap(hexAddress)
        let device = connected.first { address != nil && hexAddress($0.addressString) == address }
            ?? connected.first { $0.name == name }
        guard let device else { return nil }

        let battery = DeviceBattery(left: percent(device, "batteryPercentLeft"),
                                    right: percent(device, "batteryPercentRight"),
                                    chargingCase: percent(device, "batteryPercentCase"),
                                    single: percent(device, "batteryPercentSingle"))
        return battery.isEmpty ? nil : battery
        #else
        return nil
        #endif
    }

    #if DIRECT
    /// The 12 hex digits of a Bluetooth address, however it is written ("aa-bb-…:output",
    /// "aa:bb:…").
    private static func hexAddress(_ string: String?) -> String? {
        guard let string else { return nil }
        let hex = string.lowercased().filter(\.isHexDigit)
        return hex.count >= 12 ? String(hex.prefix(12)) : nil
    }

    /// A level from IOBluetoothDevice's undocumented battery properties, read only if this macOS
    /// has them. 0 means "not reported".
    private static func percent(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        guard device.responds(to: NSSelectorFromString(key)),
              let value = device.value(forKey: key) as? NSNumber else { return nil }
        let level = value.intValue
        return (1...100).contains(level) ? level : nil
    }
    #endif
}
