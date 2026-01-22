//
//  HDRBadgeView.swift
//  Stingray
//
//  HDR and Dolby Vision badge display for media content.
//

import SwiftUI

/// A badge view that displays the video range type (HDR10, Dolby Vision, etc.)
struct HDRBadgeView: View {
    let videoRangeType: VideoRangeType
    
    var body: some View {
        if videoRangeType.isHDR {
            HStack(spacing: 4) {
                if videoRangeType.isDolbyVision {
                    // Dolby Vision badge
                    HStack(spacing: 2) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("Vision")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                } else {
                    // HDR10/HDR10+/HLG badge
                    Text(videoRangeType.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(hdrGradient)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
    
    private var hdrGradient: LinearGradient {
        switch videoRangeType {
        case .hdr10, .hdr10Plus:
            // Golden HDR gradient
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.85, blue: 0.4), Color(red: 1.0, green: 0.7, blue: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .hlg:
            // Greenish HLG gradient
            return LinearGradient(
                colors: [Color(red: 0.6, green: 0.9, blue: 0.6), Color(red: 0.4, green: 0.8, blue: 0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
        }
    }
}

/// A compact badge for use in media cards and lists
struct HDRBadgeCompactView: View {
    let videoRangeType: VideoRangeType
    
    var body: some View {
        if videoRangeType.isHDR {
            Group {
                if videoRangeType.isDolbyVision {
                    Image(systemName: "sparkles")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Text(shortDisplayName)
                        .font(.caption2.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
    }
    
    private var shortDisplayName: String {
        switch videoRangeType {
        case .hdr10: return "HDR"
        case .hdr10Plus: return "HDR+"
        case .hlg: return "HLG"
        default: return "HDR"
        }
    }
}

#Preview("HDR Badges") {
    VStack(spacing: 20) {
        HDRBadgeView(videoRangeType: .dolbyVisionWithHDR10)
        HDRBadgeView(videoRangeType: .hdr10)
        HDRBadgeView(videoRangeType: .hdr10Plus)
        HDRBadgeView(videoRangeType: .hlg)
        
        Divider()
        
        HStack(spacing: 10) {
            HDRBadgeCompactView(videoRangeType: .dolbyVisionWithHDR10)
            HDRBadgeCompactView(videoRangeType: .hdr10)
            HDRBadgeCompactView(videoRangeType: .hdr10Plus)
            HDRBadgeCompactView(videoRangeType: .hlg)
        }
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
