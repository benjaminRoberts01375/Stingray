//
//  LibraryView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import SwiftUI

public struct LibraryView: View {
    @State var library: LibraryModel
    let streamingService: StreamingServiceProtocol
    
    public var body: some View {
        ScrollView {
            switch library.media {
            case .unloaded, .waiting:
                ProgressView()
            case .error(let err):
                Text("Error: \(err.localizedDescription)")
                    .foregroundStyle(.red)
                    .padding(.vertical)
            case .available(let allMedia):
                LazyVStack(spacing: 20) {
                    ForEach(allMedia) { media in
                        Button {
                            // This is just for demo purposes
                        } label: {
                            Text(media.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding()
            }
        }
    }
}
