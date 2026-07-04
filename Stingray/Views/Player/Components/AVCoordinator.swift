//
//  AVCoordinator.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import AVKit
import UIKit

public class AVPlayerCoordinator: NSObject, AVPlayerViewControllerDelegate {
    public let onStartPiP: () -> Void
    public let onRestoreFromPiP: () -> Void
    public let onStopFromPiP: () -> Void
    /// Used for PiP identification
    public let id: String

    // Maintain a reference to a PiP instance
    public weak var playerViewController: AVPlayerViewController?
    // Maintain a reference to this Coordinator while PiP is active
    public static var activePiPCoordinator: AVPlayerCoordinator?

    // Track whether we're restoring vs closing
    private var isRestoringFromPiP = false

    public init(
        id: String,
        onStartPiP: @escaping () -> Void,
        onRestoreFromPiP: @escaping () -> Void,
        onStopFromPiP: @escaping () -> Void,
    ) {
        self.id = id
        self.onStartPiP = onStartPiP
        self.onRestoreFromPiP = onRestoreFromPiP
        self.onStopFromPiP = onStopFromPiP
    }

    public func stopPlayer() {
        // On tvOS, stopping the player will end PiP automatically
        playerViewController?.player?.pause()
        playerViewController?.player?.replaceCurrentItem(with: nil)
    }

    public func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        Log.info("PiP starting")
        self.onStartPiP()
        Self.activePiPCoordinator = self // Keep self alive
    }

    public func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        Log.info("PiP stopped")
        if !isRestoringFromPiP {
            onStopFromPiP()
        }

        isRestoringFromPiP = false // Reset for next time
        Self.activePiPCoordinator = nil
    }

    public func playerViewController(
        _ playerViewController: AVPlayerViewController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Log.warning("PiP failed to start: \(error)")
        Self.activePiPCoordinator = nil
    }

    public func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
        _ playerViewController: AVPlayerViewController
    ) -> Bool {
        true
    }

    public func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Log.info("Restoring UI from PiP")
        isRestoringFromPiP = true // Flag that this is a restore, not a close
        onRestoreFromPiP()
        completionHandler(true)
    }
}
