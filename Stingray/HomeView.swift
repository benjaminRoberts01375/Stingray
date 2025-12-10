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
                    NavigationLink(destination: EmptyView()) {
                        MediaCard(media: media, streamingService: streamingService)
                            .frame(width: 200, height: 370)
                    }
                    .buttonStyle(.card)
                }
            }
        }
    }
}
