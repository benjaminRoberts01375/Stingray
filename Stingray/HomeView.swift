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
            .focusSection()
            
            DashboardRow(
                title: "Recently Added",
                streamingService: streamingService
            ) {
                await streamingService.retrieveRecentlyAdded(.all)
            }
            .focusSection()
            
            DashboardRow(
                title: "Latest Movies",
                streamingService: streamingService
            ) {
                await streamingService.retrieveRecentlyAdded(.movie)
            }
            .focusSection()
            
            DashboardRow(
                title: "Latest Shows",
                streamingService: streamingService
            ) {
                await streamingService.retrieveRecentlyAdded(.tv)
            }
            .focusSection()
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
                .task(id: title) {
                    let response = await fetchMedia()
                    status = response.isEmpty ? .empty : .complete(response)
                }
            
            switch status {
            case .unstarted, .retrieving:
                MediaNavigationLoadingPicker()
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
            MediaDetailLoader(mediaID: media.id, parentID: media.parentID, streamingService: streamingService)
        } label: {
            MediaCard(media: media, streamingService: streamingService)
                .frame(width: 200, height: 370)
        }
        .buttonStyle(.card)
    }
}

struct MediaDetailLoader: View {
    let mediaID: String
    let parentID: String
    let streamingService: StreamingServiceProtocol
    
    var body: some View {
        switch self.streamingService.lookup(mediaID: mediaID, parentID: parentID) {
        case .found(let foundMedia):
            DetailMediaView(media: foundMedia, streamingService: streamingService)
        case .temporarilyNotFound:
            ProgressView("Loading Libraries...")
        case .notFound:
            Text("Media Not Found")
            Text("It may not have been compatible with Stingray")
                .opacity(0.5)
        }
    }
}

fileprivate struct MediaNavigationLoadingPicker: View {
    private let numOfPlaceholders: Int = Int.random(in: 4..<8)
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(0..<numOfPlaceholders, id: \.self) { index in
                    MediaNavigationLoadingCard()
                        .opacity(Double(1 - (Double(index) / Double(numOfPlaceholders))))
                }
            }
        }
    }
}

fileprivate struct MediaNavigationLoadingCard: View {
    private let randomWordCount = Int.random(in: 3...5)
    
    var body: some View {
        Button {
            
        } label: {
            VStack {
                ZStack {
                    Color.gray.opacity(0.2)
                    ProgressView()
                }
                Text(
                    (3...5).map { _ in
                        String(repeating: "▀", count: Int.random(in: 2...5))
                    }
                        .joined(separator: " ")
                )
                .opacity(0.5)
                Spacer()
            }
            .frame(width: 200, height: 370)
        }
        .buttonStyle(.card)
        .focusable(false)
    }
}
