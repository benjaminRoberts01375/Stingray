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
                let columns = [
                    GridItem(.adaptive(minimum: 80), spacing: 16)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
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
