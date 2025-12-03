//
//  DashboardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import SwiftUI

struct DashboardView: View {
    enum LibraryStatus {
        case waiting
        case available([LibraryModel])
        case error(Error)
    }
    
    @State var streamingService: StreamingServiceProtocol
    @State var libraryStatus: LibraryStatus = .waiting
    @State private var selectedTab: String = "home"
    
    var body: some View {
        NavigationStack {
            VStack {
                switch libraryStatus {
                case .waiting:
                    ProgressView()
                case .error(let err):
                    Text("Error loading libraries: \(err.localizedDescription)")
                        .foregroundStyle(.red)
                    
                case .available(let libraries):
                    TabView(selection: $selectedTab) {
                        Tab(value: "home") {
                            Text("Home")
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
        .task {
            guard case .waiting = libraryStatus else {
                print("No need for libraries")
                return
            }
            print("Getting libraries")
            do {
                let libraries = try await streamingService.getLibraries()
                libraryStatus = .available(libraries)
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for library in libraries {
                        group.addTask {
                            try await library.loadMedia(streamingService: streamingService)
                        }
                    }
                    try await group.waitForAll()
                }
                print("Finished loading media for all libraries")
            } catch {
                libraryStatus = .error(error)
                print("Failed to get libraries: \(error.localizedDescription)")
            }
        }
    }
}
