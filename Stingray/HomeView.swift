//
//  HomeView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/9/25.
//

import SwiftUI

struct HomeView: View {
    let streamingService: StreamingServiceProtocol
    
    @State private var dashboardCache: [String: [SlimMedia]] = [:]
    @Binding var navigation: NavigationPath
    
    var body: some View {
        VStack(alignment: .leading) {
            DashboardRow(
                title: "Next Up",
                streamingService: streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await streamingService.retrieveUpNext()
            }
            .focusSection()
            
            DashboardRow(
                title: "Recently Added",
                streamingService: streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await streamingService.retrieveRecentlyAdded(.all)
            }
            .focusSection()
            
            DashboardRow(
                title: "Latest Movies",
                streamingService: streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await streamingService.retrieveRecentlyAdded(.movie)
            }
            .focusSection()
            
            DashboardRow(
                title: "Latest Shows",
                streamingService: streamingService,
                cache: $dashboardCache,
                navigation: $navigation
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
    @Binding var cache: [String: [SlimMedia]]
    @Binding var navigation: NavigationPath
    let fetchMedia: () async -> [SlimMedia]
    
    @State private var status: DashboardRowStatus = .unstarted
    
    var body: some View {
        VStack(alignment: .leading) {
            switch status {
            case .empty:
                EmptyView()
            default:
                Text(title)
                    .font(.title2.bold())
                    .task {
                        // Check if we already have cached data
                        if let cachedMedia = cache[title] {
                            status = cachedMedia.isEmpty ? .empty : .complete(cachedMedia)
                            return
                        }
                        
                        // Only fetch if not cached
                        let response = await fetchMedia()
                        cache[title] = response
                        status = response.isEmpty ? .empty : .complete(response)
                    }
            }
                
            switch status {
            case .unstarted, .retrieving:
                MediaNavigationLoadingPicker()
            case .complete(let newMedia):
                MediaPicker(streamingService: streamingService, pickerMedia: newMedia, navigation: $navigation)
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
    
    @Binding var navigation: NavigationPath
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 20) {
                ForEach(pickerMedia) { media in
                    MediaNavigation(media: media, streamingService: streamingService, navigation: $navigation)
                }
            }
        }
    }
}

fileprivate struct MediaNavigation: View {
    var media: SlimMedia
    var streamingService: StreamingServiceProtocol
    
    @Binding var navigation: NavigationPath
    
    var body: some View {
        Button {
            navigation.append(media)
        } label: {
            MediaCard(media: media, streamingService: streamingService)
                .frame(width: 200, height: 370)
        }
        .buttonStyle(.card)
    }
}

struct MediaDetailLoader: View {
    let mediaID: String
    let parentID: String?
    let streamingService: StreamingServiceProtocol
    
    @Binding var navigation: NavigationPath
    
    var body: some View {
        switch self.streamingService.lookup(mediaID: mediaID, parentID: parentID) {
        case .found(let foundMedia):
            DetailMediaView(media: foundMedia, streamingService: streamingService, navigation: $navigation)
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
            LazyHStack(spacing: 20) {
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
