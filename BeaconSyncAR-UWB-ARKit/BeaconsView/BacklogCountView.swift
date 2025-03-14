//
//  BacklogCountView.swift
//  BeaconSyncAR-UWB-ARKit
//
//  Created by Maitree Hirunteeyakul on 14/3/2025.
//

import SwiftUI

struct BacklogCountView: View {
    var backlogCount: Int
    
    var plural: String {
        if backlogCount>1 {return "s"} else { return "" }
    }
    var body: some View {
        if backlogCount>0 {
            HStack{
                Spacer()
                Text("Hosting \(backlogCount) Anchor\(plural) to Server")
                Spacer()
            }.padding().background(.yellow.opacity(0.75)).foregroundStyle(.black).clipShape(.rect(cornerRadius: 12)).padding()
        }
    }
}

#Preview {
    BacklogCountView(backlogCount: 3)
}
