//
//  AnchorsManager.swift
//  BeaconSyncAR-UWB-ARKit
//
//  Created by Maitree Hirunteeyakul on 12/3/2025.
//
import Foundation
import Combine
import ARKit
import Spatial

class AnchorsManager : ObservableObject {
    private var uwbManager: UWBManager
    private var arViewModel: ARViewModel
    private var subscriptions = Set<AnyCancellable>()
    init(uwbManager: UWBManager, arViewModel: ARViewModel) {
        Logger.addLog(label: "Initialize AnchorManager")
        self.uwbManager = uwbManager
        self.arViewModel = arViewModel
        setupBindings()
        Logger.addLog(label: "Fininshed Initialize AnchorManager")
    }
    
    private var beacons: [Beacon] = []
    private var beaconARAnchor: [Beacon: SCNNode] = [:]
    private var doneAutoRanging: Set<Beacon> = []
    
    class Anchor: Identifiable {
        let id: UUID
        let relativeTransform: simd_float4x4
        var arAnchor: ARAnchor?
        
        init(id: UUID, relativeTransform: simd_float4x4, arAnchor: ARAnchor? = nil) {
            self.id = id
            self.relativeTransform = relativeTransform
            self.arAnchor = arAnchor
        }
    }
    @Published private(set) var beaconsAnchors: [Beacon: [Anchor]] = [:]
    @Published private(set) var backlogAnchors: [BacklogAnchor] = []
}

// MARK: Binding
extension AnchorsManager {
    
    private func setupBindings() {
        uwbManager.$beacons
            .compactMap { $0 }
            .sink { [weak self] beacons in
                self?.handleBeaconsUpdates(in: beacons)
            }
            .store(in: &subscriptions)
        
        uwbManager.$beaconARAnchor
            .compactMap { $0 }
            .sink { [weak self] beaconARAnchor in
                Task {
                    await self?.handleBeaconARAnchorUpdates(in: beaconARAnchor)
                }
            }
            .store(in: &subscriptions)
        
        uwbManager.$doneAutoRanging
            .compactMap { $0 }
            .sink { [weak self] doneAutoRanging in
                Task {
                    await self?.handleDoneAutoRangingUpdates(in: doneAutoRanging)
                }
            }
            .store(in: &subscriptions)
        
    }
    
    private func downloadAndTryResloveAnchors(for beacon: Beacon){
        Task {
            print("downloadAndTryResloveAnchors")
            if beaconsAnchors[beacon] == nil {
                print("downloadAndTryResloveAnchors in if")
                do {
                    let anchors = try await self.download(for: beacon)
                    DispatchQueue.main.async {
                        self.beaconsAnchors[beacon] = anchors
                    }
                }
            }
            tryToResloveAnchors(for: beacon)
        }
    }
    
    private func handleBeaconsUpdates(in beacons: [Beacon]) {
        let newBeacons = beacons.filter { !self.beacons.contains($0) }
        self.beacons = beacons
        newBeacons.forEach({ beacon in
            downloadAndTryResloveAnchors(for: beacon)
        })
    }
    
    private func handleBeaconARAnchorUpdates(in beaconARAnchor: [Beacon: SCNNode]) async {
        print("handleBeaconARAnchorUpdates")
        self.beaconARAnchor = beaconARAnchor
    }
    
    private func handleDoneAutoRangingUpdates(in doneAutoRanging: Set<Beacon>) async {
        let newBeacons = doneAutoRanging.filter { !self.doneAutoRanging.contains($0) }
        print("newBeacons: \(newBeacons.count)")
        self.doneAutoRanging = doneAutoRanging
        newBeacons.forEach({ beacon in
            downloadAndTryResloveAnchors(for: beacon)
        })
        tryToHostBacklogAnchors()
    }
    
}

// MARK: Network Facing Module
extension AnchorsManager {
    
    struct BackendSimdFloat4x4: Codable {
        let matrix: simd_float4x4
        
        private enum CodingKeys: String, CodingKey {
            case col0, col1, col2, col3
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(matrix.columns.0, forKey: .col0)
            try container.encode(matrix.columns.1, forKey: .col1)
            try container.encode(matrix.columns.2, forKey: .col2)
            try container.encode(matrix.columns.3, forKey: .col3)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let col0 = try container.decode(simd_float4.self, forKey: .col0)
            let col1 = try container.decode(simd_float4.self, forKey: .col1)
            let col2 = try container.decode(simd_float4.self, forKey: .col2)
            let col3 = try container.decode(simd_float4.self, forKey: .col3)
            self.matrix = simd_float4x4(columns: (col0, col1, col2, col3))
        }
        
        init(_ matrix: simd_float4x4) {
            self.matrix = matrix
        }
    }
    
    enum AnchorsManagerUploadError: Error {
        case notReadyToUpload
        case missingBeaconName
    }
    private func upload(_ worldTransform: simd_float4x4, to beacon: Beacon) async throws {
        if !doneAutoRanging.contains(beacon) {throw AnchorsManagerUploadError.notReadyToUpload}
        guard let beaconName = beacon.peripheral.name else {throw AnchorsManagerUploadError.missingBeaconName}
        guard let beaconTransform = beaconARAnchor[beacon]?.simdWorldTransform else {throw AnchorsManagerUploadError.notReadyToUpload}
        let relativeTransform = beaconTransform.inverse * worldTransform
        
        
        struct UploadAnchorParams: Encodable {
            let relativeTransform: BackendSimdFloat4x4
        }
        let body = UploadAnchorParams(relativeTransform: BackendSimdFloat4x4(relativeTransform))
        
        let urlString = "\(API_ENDPOINT)/UWBAnchor/\(beaconName)/new"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct UploadAnchorResponse: Codable{
            let id: UUID
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "NetworkError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Upload failed"]
            )
        }
        
        let uploadAnchorRespond = try JSONDecoder().decode(UploadAnchorResponse.self, from: data)
        DispatchQueue.main.async {
            self.beaconsAnchors[beacon]?.append(Anchor(id: uploadAnchorRespond.id, relativeTransform: relativeTransform))
        }
    }
    
    enum AnchorsManagerDownloadError: Error {
        case missingBeaconName
    }
    private func download(for beacon: Beacon) async throws -> [Anchor] {
        guard let beaconName = beacon.peripheral.name else {throw AnchorsManagerDownloadError.missingBeaconName}
        
        let urlString = "\(API_ENDPOINT)/UWBAnchor/\(beaconName)/list"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        struct DownloadAnchorResponse: Codable {
            let id: UUID
            let relativeTransform: BackendSimdFloat4x4
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "NetworkError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Upload failed"]
            )
        }
        
        let downloadAnchorsRespond = try JSONDecoder().decode([DownloadAnchorResponse].self, from: data)
        
        return downloadAnchorsRespond.map({ anchorRespond in
            Anchor(id: anchorRespond.id, relativeTransform: anchorRespond.relativeTransform.matrix)
        })
    }
}

// MARK: ARViewModel Facing Module
extension AnchorsManager {
    public func place(_ worldTransform: simd_float4x4){
        let bunnyAnchor = ARAnchor(name: "bunny", transform: worldTransform)
        arViewModel.sceneView?.session.add(anchor: bunnyAnchor)
        backlogAnchors.append(BacklogAnchor(worldTransform: worldTransform, arAnchor: bunnyAnchor))
        tryToHostBacklogAnchors()
    }
}

// MARK: Try Host/Reslove Logic
extension AnchorsManager {
    private func tryToResloveAnchors(for beacon: Beacon){
        if !doneAutoRanging.contains(beacon) {return}
        guard let beaconTransform = beaconARAnchor[beacon]?.simdWorldTransform else {return}
        guard let anchors = beaconsAnchors[beacon] else {return}
        guard let arSession = arViewModel.sceneView?.session else {return}
        anchors.forEach({ anchor in
            if anchor.arAnchor == nil {
                let anchorTransform = beaconTransform * anchor.relativeTransform
                let bunnyAnchor = ARAnchor(name: "bunny", transform: anchorTransform)
                arSession.add(anchor: bunnyAnchor)
                anchor.arAnchor = bunnyAnchor
            }
        })
    }
    
    class BacklogAnchor{
        let worldTransform: simd_float4x4
        let arAnchor: ARAnchor
        init(worldTransform: simd_float4x4, arAnchor: ARAnchor) {
            self.worldTransform = worldTransform
            self.arAnchor = arAnchor
        }
    }
    private func tryToHostBacklogAnchors(){
        let beaconsWorldTransform: [Beacon: simd_float4x4] = beaconARAnchor.mapValues { node in
            return node.simdWorldTransform
        }
        backlogAnchors.forEach({ backlogAnchor in
            let beaconDistaceToAnchor: [Beacon: Float] = beaconsWorldTransform.mapValues { worldTransform in
                return distance(worldTransform.translation, backlogAnchor.worldTransform.translation)
            }
            let nearestBeacon = beaconDistaceToAnchor.min(by: { $0.value < $1.value })?.key
            if let nearestBeacon = nearestBeacon {
                Task{
                    do {
                        try await upload(backlogAnchor.worldTransform, to: nearestBeacon)
                        DispatchQueue.main.async {
                            self.backlogAnchors.removeAll{ $0 === backlogAnchor}
                        }
                    }
                }
            }
        })
    }
}
