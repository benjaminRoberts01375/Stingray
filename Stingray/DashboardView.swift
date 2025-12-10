//
//  DashboardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import SwiftUI

struct DashboardView: View {
    var streamingService: StreamingServiceProtocol
    @State private var selectedTab: String = "home"
    
    var body: some View {
        NavigationStack {
            VStack {
                switch streamingService.libraryStatus {
                case .waiting, .retrieving:
                    ProgressView()
                case .error(let err):
                    Text("Error loading libraries: \(err.localizedDescription)")
                        .foregroundStyle(.red)
                    
                case .available(let libraries), .complete(let libraries):
                    TabView(selection: $selectedTab) {
                        Tab(value: "home") {
                            ScrollView {
                                HomeView(streamingService: streamingService)
                                    .scrollClipDisabled()
                            }
                        } label: {
                            Text("Home")
                        }
                        ForEach(libraries.indices, id: \.self) { index in
                            Tab(value: libraries[index].id) {
                                LibraryView(library: libraries[index], streamingService: streamingService)
                            } label: {
                                Text(libraries[index].title)
                            }
                        }
                    }
                }
            }
        }
    }
}
