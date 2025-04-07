# BeaconSyncAR-iBeacon-ARKit

iOS app for UWB-assisted AR synchronization using Apple ARKit with centimeter-precise positioning.

## 🚀 Quick Start

### Prerequisites
- Xcode 16+
- iOS device with UWB support (iPhone 11 or later)
- UWB Beacons (see [UWBScanner](https://github.com/ARBeacon/UWBScanner) for setup)
- Running [backend](https://github.com/ARBeacon/BeaconSyncAR-api)

### Local Setup

1. Clone the repository: 
```bash
git clone https://github.com/ARBeacon/BeaconSyncAR-UWB-ARKit.git
cd BeaconSyncAR-UWB-ARKit
```
2. Configure environment variables:
```bash
cp BeaconSyncAR-UWB-ARKit/Config.xcconfig.example BeaconSyncAR-UWB-ARKit/Config.xcconfig
```
Edit the Config.xcconfig file with your [backend](https://github.com/ARBeacon/BeaconSyncAR-api) endpoint url.

3. Run the app:

open the project in Xcode and click "Run".