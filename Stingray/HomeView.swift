//
//  HomeView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/9/25.
//

import SwiftUI

public struct HomeView: View {
    public let streamingService: StreamingServiceProtocol
    
    @State private var dashboardCache: [String: [SlimMedia]] = [:]
    @Binding public var navigation: NavigationPath
    
    public var body: some View {
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
            
            VStack {
                SystemInfoView(streamingService: streamingService)
                LibrariesInfoView(streamingService: streamingService)
            }
            .frame(maxWidth: .infinity)
            .padding(.top)
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
            LazyHStack {
                ForEach(pickerMedia) { media in
                    MediaCard(media: media, streamingService: streamingService) { navigation.append(media) }
                }
            }
        }
    }
}

public struct MediaDetailLoader: View {
    public let mediaID: String
    public let parentID: String?
    public let streamingService: StreamingServiceProtocol
    
    @Binding public var navigation: NavigationPath
    
    public var body: some View {
        switch self.streamingService.lookup(mediaID: mediaID, parentID: parentID) {
        case .found(let foundMedia):
            DetailMediaView(media: foundMedia, streamingService: streamingService, navigation: $navigation)
        case .temporarilyNotFound:
            ProgressView("Loading libraries...")
        case .notFound:
            Text("Media Not Found")
            Text("It may not have been compatible with Stingray")
                .foregroundStyle(.tertiary)
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

public struct SystemInfoView: View {
    public let streamingService: any StreamingServiceProtocol
    
    public var body: some View {
        // Display Stingray and Jellyfin server versions
        HStack(alignment: .center, spacing: 0) {
            if let stingrayVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {  // Stingray
                Text("Stingray v\(stingrayVersion)")
            }
            else { Text("Unknown Stingray Version") }
            // Jellyfin
            Text(" • " + "Jellyfin Server ")
            if let name = self.streamingService.serverName { Text("\"\(name)\" ") }
            if let version = self.streamingService.serverVersion { Text("v\(version)") }
            // tvOS version
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            Text(" • " + "tvOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
            // Apple TV model
            if let model = getAppleTVModel() {
                Text(" • " + model)
            }
        }
        .foregroundStyle(.tertiary)
    }
    
    private func getAppleTVModel() -> String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? nil : identifier
    }
}

public struct LibrariesInfoView: View {
    /// Streaming service containing libraries
    public let streamingService: any StreamingServiceProtocol
    
    @State private var movieCount: Int = 0
    
    public var body: some View {
        switch self.streamingService.libraryStatus {
        case .waiting: Text("Waiting to get libraries...")
        case .retrieving: Text("Getting libraries...")
        case .available(let libraries), .complete(let libraries):
            let mediaCounts = countMedia(libraries: libraries)
            HStack(spacing: 0) {
                if case .complete = self.streamingService.libraryStatus {
                    Text("Libraries" + ": \(libraries.count)")
                        .foregroundStyle(.tertiary)
                } else {
                    ProgressView()
                    Text(" " + "Libraries" + ": \(libraries.count)")
                        .foregroundStyle(.tertiary)
                }
                ForEach(Array(mediaCounts.keys.sorted()), id: \.self) { key in
                    Text(" • " + "\(key): \(mediaCounts[key] ?? 0)")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 30)
        case .error(let rError): ErrorView(error: rError, summary: "Failed to load libraries")
        }
    }
    
    /// Counts all the media for each type.
    /// - Parameter libraries: Libraries to count with
    /// - Returns: Found media types and their associated counts
    public func countMedia(libraries: [LibraryModel]) -> [String : Int] {
        var counters: [String : Int] = [:]
        
        for library in libraries {
            switch library.media {
            case .unloaded, .waiting, .error:
                break
            case .available(let media), .complete(let media):
                counters[library.libraryType, default: 0] += media.count
            }
        }
        return counters
    }
}
