//
//  HomeView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/9/25.
//

import SwiftUI

struct HomeView: View {
    let streamingService: StreamingServiceProtocol
    @State var upNextMedia: [SlimMedia] = []
    @State var recentlyAddedMedia: [SlimMedia] = []
    @State var recentlyAddedMovies: [SlimMedia] = []
    @State var recentlyAddedShows: [SlimMedia] = []
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Next Up")
                    .font(.title.bold())
                    .task {
                        self.upNextMedia = await streamingService.retrieveUpNext()
                    }
                MediaPicker(streamingService: streamingService, pickerMedia: upNextMedia)
            }
            .padding(.vertical)
            
            VStack(alignment: .leading) {
                Text("Recently Added")
                    .font(.title2.bold())
                    .task {
                        self.recentlyAddedMedia = await streamingService.retrieveRecentlyAdded(.all)
                    }
                MediaPicker(streamingService: streamingService, pickerMedia: recentlyAddedMedia)
            }
            .padding(.vertical)
            
            VStack(alignment: .leading) {
                Text("Latest Movies")
                    .font(.title2.bold())
                    .task {
                        self.recentlyAddedMovies = await streamingService.retrieveRecentlyAdded(.movie)
                    }
                MediaPicker(streamingService: streamingService, pickerMedia: recentlyAddedMovies)
            }
            .padding(.vertical)
            
            VStack(alignment: .leading) {
                Text("Latest Shows")
                    .font(.title2.bold())
                    .task {
                        self.recentlyAddedShows = await streamingService.retrieveRecentlyAdded(.tv)
                    }
                MediaPicker(streamingService: streamingService, pickerMedia: recentlyAddedShows)
            }
            .padding(.vertical)
        }
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
