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
    @State var libraries: LibraryStatus = .waiting
    
    
    var body: some View {
        VStack {
            switch libraries {
            case .waiting:
                ProgressView()
            case .error(let err):
                Text("Error loading libraries: \(err.localizedDescription)")
                    .foregroundStyle(.red)
                
            case .available(let libraries):
                ForEach(libraries.indices, id: \.self) { index in
                    Text(libraries[index].title)
                }
            }
        }
        .onAppear {
            Task {
                do {
                    libraries = .available(try await streamingService.getLibraries())
                } catch {
                    libraries = .error(error)
                }
            }
        }
    }
}
