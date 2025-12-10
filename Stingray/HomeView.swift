//
//  HomeView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/9/25.
//

import SwiftUI

struct HomeView: View {
    let streamingService: StreamingServiceProtocol
    
    var body: some View {
        VStack(alignment: .leading) {
            DashboardRow(
                title: "Next Up",
                streamingService: streamingService
            ) {
                await streamingService.retrieveUpNext()
            }
            
            DashboardRow(
                title: "Recently Added",
                streamingService: streamingService
            ) {
                await streamingService.retrieveRecentlyAdded(.all)
            }
            
            DashboardRow(
                title: "Latest Movies",
                streamingService: streamingService
            ) {
                await streamingService.retrieveRecentlyAdded(.movie)
            }
            
            DashboardRow(
                title: "Latest Shows",
                streamingService: streamingService
            ) {
                await streamingService.retrieveRecentlyAdded(.tv)
            }
        }
    }
}

fileprivate struct DashboardRow: View {
    let title: String
    let streamingService: StreamingServiceProtocol
    let fetchMedia: () async -> [SlimMedia]
    
    @State private var status: DashboardRowStatus = .unstarted
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2.bold())
                .task {
                    let response = await fetchMedia()
                    status = response.isEmpty ? .empty : .complete(response)
                }
            
            switch status {
            case .unstarted, .retrieving:
                ProgressView()
            case .complete(let newMedia):
                MediaPicker(streamingService: streamingService, pickerMedia: newMedia)
            case .empty:
                EmptyView()
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    enum DashboardRowStatus {
        case unstarted
        case retrieving
        case complete([SlimMedia])
        case empty
    }
}

fileprivate struct MediaPicker: View {
    var streamingService: StreamingServiceProtocol
    let pickerMedia: [SlimMedia]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(pickerMedia) { media in
                    MediaNavigation(media: media, streamingService: streamingService)
                }
            }
        }
    }
}

fileprivate struct MediaNavigation: View {
    var media: SlimMedia
    var streamingService: StreamingServiceProtocol
    
    var body: some View {
        NavigationLink {
            MediaDetailLoader(media: media, parentID: media.parentID, streamingService: streamingService)
        } label: {
            MediaCard(media: media, streamingService: streamingService)
                .frame(width: 200, height: 370)
        }
        .buttonStyle(.card)
    }
}

fileprivate struct MediaDetailLoader: View {
    let media: any SlimMediaProtocol
    let parentID: String
    let streamingService: StreamingServiceProtocol
    
    var body: some View {
        switch self.streamingService.lookup(mediaID: media.id, parentID: parentID) {
        case .found(let foundMedia):
            DetailMediaView(media: foundMedia, streamingService: streamingService)
        case .temporarilyNotFound:
            ProgressView("Loading Libraries...")
        case .notFound:
            Text("Failed to locate \(media.title).")
            Text("It may not have been compatible with Stingray")
                .opacity(0.5)
        }
    }
}
