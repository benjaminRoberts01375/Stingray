//
//  DashboardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import SwiftUI

struct DashboardView: View {
    @State var streamingService: StreamingServiceProtocol
    
    var body: some View {
        Text(streamingService.url?.absoluteString ?? "Missing URL")
    }
}
