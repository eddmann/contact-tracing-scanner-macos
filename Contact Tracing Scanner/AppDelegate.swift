import Cocoa
import CoreBluetooth

struct Device: Codable {
    let uuid: String
    let rollingProximityId: String
    let metadata: String
    let rssi: String
    let lastSeen: Date

    func toRow() -> [String: String] {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .long
        
        return [
            "uuid": uuid,
            "rollingProximityId": rollingProximityId,
            "metadata": metadata,
            "rssi": rssi,
            "lastSeen": dateFormatter.string(from: lastSeen)
        ]
    }
}

class DeviceTable: NSObject, NSTableViewDataSource, NSTableViewDelegate, CBCentralManagerDelegate {
    public weak var tableView: NSTableView? {
        didSet {
            tableView?.delegate = self
            tableView?.dataSource = self
        }
    }
    
    let exposureNotificationServiceUuid = CBUUID(string: "FD6F")
    
    var centralManager: CBCentralManager!
    
    var devices: [Device] = []
    
    public override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            self.removeDevicesNotSeenInLastSeconds(10)
            self.tableView?.reloadData()
        }
    }
    
    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .poweredOn:
                central.scanForPeripherals(withServices: [exposureNotificationServiceUuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            case .poweredOff:
                central.stopScan()
            default:
                break
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let serviceAdvertisementData = advertisementData[CBAdvertisementDataServiceDataKey] as? NSDictionary {
            if let exposureNotificationServiceData = serviceAdvertisementData.object(forKey: exposureNotificationServiceUuid) as? Data {
                let hex = exposureNotificationServiceData.map { String(format: "%02hhx", $0) }.joined()
                updateDevice(Device(uuid: peripheral.identifier.uuidString, rollingProximityId: "\(hex.prefix(32))", metadata: "\(hex.suffix(8))", rssi: "\(RSSI)", lastSeen: Date()))
            }
        }
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return devices.count
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = devices[row]
        let columnIdentifier = tableColumn!.identifier
        let cell = tableView.makeView(withIdentifier: columnIdentifier, owner: self) as! NSTableCellView
        cell.textField!.stringValue = device.toRow()[columnIdentifier.rawValue] ?? ""
        return cell
    }
    
    private func updateDevice(_ device: Device) {
        if let index = devices.firstIndex(where: { $0.uuid == device.uuid }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
    }
    
    private func removeDevicesNotSeenInLastSeconds(_ seconds: Double) {
        devices = devices.filter({ Date().timeIntervalSince1970 - $0.lastSeen.timeIntervalSince1970 < seconds })
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var deviceTableView: NSTableView!
    
    let devicesTable = DeviceTable()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        devicesTable.tableView = deviceTableView
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
