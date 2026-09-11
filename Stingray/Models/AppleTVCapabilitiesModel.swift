//
//  AppleTVCapabilitiesModel.swift
//  Stingray
//
//  Created by Ben Roberts on 8/24/26.
//

import Foundation

/// HEVC/HDR decode capabilities for a specific Apple TV hardware generation, used to avoid requesting a codec/profile combination the
/// Apple TV can't actually play (ex. older Apple TVs lacking Dolby Vision or HDR10+ decode)
public struct AppleTVCapabilities {
    /// Whether the hardware has a HEVC/H.265 decoder at all
    public let supportsHEVC: Bool
    /// The highest Jellyfin `hevc-level` value (H.265 level x 30) the hardware decoder handles
    public let maxHEVCLevel: Int
    /// Whether the hardware decodes HDR10
    public let supportsHDR10: Bool
    /// Whether the hardware decodes HDR10+
    public let supportsHDR10Plus: Bool
    /// Whether the hardware decodes Dolby Vision
    public let supportsDolbyVision: Bool
    /// Apple TV generation id
    public let hardwareModel: String

    /// Capabilities for the Apple TV this app is currently running on
    public static var current: AppleTVCapabilities { AppleTVCapabilities(hardwareModel: Self.hardwareModelIdentifier()) }

    /// Get the capabilities of an Apple TV from an identifier
    /// - Parameter hardwareModel: A hardware identifier as returned by `uname`, ex. `"AppleTV14,1"`
    public init(hardwareModel: String) {

        switch hardwareModel {
        case "AppleTV5,3": // Apple TV HD (4th gen, 2015, A8): no HEVC hardware decoder
            supportsHEVC = false
            maxHEVCLevel = 0
            supportsHDR10 = false
            supportsHDR10Plus = false
            supportsDolbyVision = false
        case "AppleTV6,2": // Apple TV 4K (1st gen, 2017, A10X)
            supportsHEVC = true
            maxHEVCLevel = 150
            supportsHDR10 = true
            supportsHDR10Plus = false
            supportsDolbyVision = true
        case "AppleTV11,1": // Apple TV 4K (2nd gen, 2021, A12)
            supportsHEVC = true
            maxHEVCLevel = 153
            supportsHDR10 = true
            supportsHDR10Plus = false
            supportsDolbyVision = true
        case "AppleTV14,1": // Apple TV 4K (3rd gen, 2022, A15): first Apple TV with HDR10+ decode. Woo!
            supportsHEVC = true
            maxHEVCLevel = 153
            supportsHDR10 = true
            supportsHDR10Plus = true
            supportsDolbyVision = true
        default: // Unreleased hardware, or the Simulator: assume the newest known capability set
            supportsHEVC = true
            maxHEVCLevel = 153
            supportsHDR10 = true
            supportsHDR10Plus = true
            supportsDolbyVision = true
        }
        self.hardwareModel = hardwareModel
    }

    /// - Returns: The current device's hardware identifier, ex. `"AppleTV14,1"`.
    private static func hardwareModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}
