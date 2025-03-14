//
//  BeaconView.swift
//  BeaconSyncAR-UWB-ARKit
//
//  Created by Maitree Hirunteeyakul on 11/3/2025.
//

import SwiftUI
import simd

struct BeaconView: View {
    
    @StateObject var beacon: Beacon
    @State var isAutoSchedulingOn: Bool
    @ObservedObject var uwbManager: UWBManager
    @ObservedObject var anchorsManager: AnchorsManager
    
    var uwbState: UWBManager.UWBState {
        uwbManager.uwbState
    }
    
    var showConnectButton: Bool {
        guard case .busy(let currentBeaconCommunication) = uwbState else { return true }
        return currentBeaconCommunication.beacon.id != beacon.id
    }
    
    var anchors: [AnchorsManager.Anchor]?{
        anchorsManager.beaconsAnchors[beacon]
    }
    
    
    var body: some View {
        ScrollView {
            HStack {
                Text("\(beacon.peripheral.name ?? "Unknown")").font(.title)
                Spacer()
            }
            if let lastCBScan = beacon.lastCBScan {
                Divider()
                HStack {
                    Spacer()
                    Text("RSSI: \(lastCBScan.rssi) dBm")
                }
                HStack {
                    Spacer()
                    Text("Last seen: \(DateFormatter.localizedString(from: lastCBScan.timestamp, dateStyle: .none, timeStyle: .medium))")
                }
            }
            
            if let lastRanging = beacon.lastRanging {
                Divider()
                if let location = lastRanging.location{
                    HStack {
                        Text("Distance")
                        Spacer()
                        let distanceString: String = (location.distance != nil) ? "\(String(format: "%.2f",location.distance!))" : "N/A"
                        Text("\(distanceString) m")
                    }
                    VStack {
                        HStack{
                            Text("Direction")
                            Spacer()
                        }
                        if let direction = location.direction{
                            HStack{
                                Spacer()
                                Text("\(String(format: "%.2f", direction.x))")
                                Spacer()
                                Text("\(String(format: "%.2f", direction.y))")
                                Spacer()
                                Text("\(String(format: "%.2f", direction.z))")
                                Spacer()
                            }
                        } else {
                            Text("N/A")
                        }
                    }
                    HStack {
                        Text("Horizontal Angle")
                        Spacer()
                        if let horizontalAngle = location.horizontalAngle {
                            let degree = horizontalAngle * 180 / Float.pi
                            Text("\(String(format: "%.0f", degree))°")
                        } else {
                            Text("N/A")
                        }
                    }
                }
                
                VStack {
                    HStack{
                        Text("World Map Position")
                        Spacer()
                    }
                    if let position = lastRanging.worldMapPosition {
                        HStack{
                            Spacer()
                            Text("\(String(format: "%.2f", position.x))")
                            Spacer()
                            Text("\(String(format: "%.2f", position.y))")
                            Spacer()
                            Text("\(String(format: "%.2f", position.z))")
                            Spacer()
                        }
                    } else {
                        Text("N/A")
                    }
                }
                HStack {
                    Spacer()
                    Text("Last ranging: \(DateFormatter.localizedString(from: lastRanging.timestamp, dateStyle: .none, timeStyle: .medium))")
                }
            }
            
            if let anchors = anchors {
                Divider()
                HStack{
                    Text("Hosted \(anchors.count) Anchor\(anchors.count>1 ? "s" : "")")
                    Spacer()
                }
                
                if anchors.count > 0{
                    VStack{
                        HStack{
                            Text("UUID (last 12 Digit)")
                            Spacer()
                            Text("Distace from beacon")
                        }.bold()
                        ForEach(anchors){ anchor in
                            let distance = distance(anchor.relativeTransform.translation, simd_float3(0, 0, 0))
                            HStack{
                                Text(String(anchor.id.uuidString.suffix(12)))
                                Spacer()
                                Text(String(format: "%.2f m", distance))
                            }
                        }
                    }
                }
            }
            
        }.padding().toolbar{
            VStack{
                if showConnectButton{
                    Button("Idle"){
                        uwbManager.connect(to: beacon)
                    }
                    .disabled(isAutoSchedulingOn)
                }
                else {
                    Button("Ranging"){
                        uwbManager.disconnect(from: beacon)
                    }
                    .foregroundColor(isAutoSchedulingOn ? nil : .red)
                    .disabled(isAutoSchedulingOn)
                }
            }
        }
    }
}





