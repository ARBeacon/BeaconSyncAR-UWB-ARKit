//
//  ContentView.swift
//  BeaconSyncAR-UWB-ARKit
//
//  Created by Maitree Hirunteeyakul on 10/3/2025.
//
import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var uwbManager: UWBManager
    @StateObject private var arViewModel: ARViewModel = ARViewModel()
    @StateObject private var anchorsManager: AnchorsManager
    
    @ObservedObject var logger: Logger = Logger.get()
    @State private var showingSheet = false
    @State private var navigateToLogView: Bool = false
    
    init(logger: Logger? = nil) {
        let arViewModel = ARViewModel()
        let uwbManager = UWBManager(arViewModel: arViewModel)
        let anchorsManager: AnchorsManager = AnchorsManager(uwbManager: uwbManager, arViewModel: arViewModel)
        arViewModel.setAnchorsManager(anchorsManager)
        
        _anchorsManager = StateObject(wrappedValue: anchorsManager)
        _uwbManager = StateObject(wrappedValue: uwbManager)
        _arViewModel = StateObject(wrappedValue: arViewModel)
        
        if let logger {
            logger.addLog(label: "ContentView Initialize", content: "Mocked Logger")
            _logger = ObservedObject(wrappedValue: logger)
        }
        else {
            let logger = Logger.get()
            logger.addLog(label: "ContentView Initialize")
            _logger = ObservedObject(wrappedValue:logger)
        }
        
        if !uwbManager.isAutoSchedulingOn { uwbManager.toggleAutoScheduling() }
    }
    
    var session:ARSession? { arViewModel.sceneView?.session }
    
    var body: some View {
        ZStack {
            ARViewContainer(arViewModel: arViewModel)
            VStack{
                Spacer()
                
                Button(action: {
                    showingSheet = true
                }, label: {
                    HStack {
                        Spacer()
                        Text("UWB Beacons Lookup")
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .padding(.bottom)
                }).buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.green.opacity(0.9))
            }
        }.ignoresSafeArea(.all)
            .sheet(isPresented: $showingSheet) {
                NavigationStack {
                    BeaconsView(uwbManager: uwbManager, anchorsManager: anchorsManager)
                        .navigationTitle("UWB Beacons")
                        .toolbar {
                            Toggle(isOn:
                                    Binding(
                                        get:{uwbManager.isAutoSchedulingOn},
                                        set:{_ in }
                                    )
                            )
                            { Text("Auto Scheduling") }
                                .tint(.green)
                            Button(action: {
                                navigateToLogView = true
                            }) {
                                Text("Log")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .navigationDestination(isPresented: $navigateToLogView) {
                            LogView(logger: logger)
                        }
                }
            }
        
        
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let logger = Logger.sampleLogger()
        return ContentView(logger: logger)
    }
}
