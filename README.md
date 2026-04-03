![Stingray Logo](https://github.com/user-attachments/assets/1909af68-b4af-42cf-b562-906cb80c8527)

# Stingray

### A super native, super fast Jellyfin client

![License](https://img.shields.io/badge/License-MIT-red)
![platforms](https://img.shields.io/badge/platforms-tvOS-green) ![tvOS](https://img.shields.io/badge/tvOS-18%2E0%2B-blue)

[![Download on Apple TV](https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-apple-tv.svg)](https://apps.apple.com/us/app/stingray-streaming/id6756280505)&nbsp;&nbsp;&nbsp;<a href="https://testflight.apple.com/join/GSgjYB22"><img src="https://testflight.apple.com/images/testflight-iOS-400x400_1x_40.png" width="50pt" alt="Download on TestFlight"></a>

## Key Features

- Stream full or partial bitrate content.
- Pick and choose your video streams, audio streams, and subtitles.
- Compatible with movies and shows.
- Switch episodes within the player.
- PiP
- View content metadata like actors/directors, episode/series descriptions, and ratings.
- Resume movies and episodes.
- Multiple profiles.
- Integrates with optional loud noise reduction and voice boosting.
- Content fuzzy searching.
  - Search movies, show titles, and episode titles.
- Connect via HTTP or HTTPS

This is an unofficial Jellyfin companion app to make watching your content easier on your Apple TV.
To use Stingray, you must have a Jellyfin server setup either on your own network or in the cloud. Find out more at [jellyfin.org](https://jellyfin.org).

## Walkthrough

### Home

![Home](https://github.com/user-attachments/assets/6da1375b-a57c-4829-9e6b-827d47d146d9)
Quickly continue shows, and browse newly uploaded content.

### Player

![Player](https://github.com/user-attachments/assets/4ce92a94-8e14-4853-9515-7437c7202d6b)
Supports last episode, picking episodes, next episode, subtitles, audio streams, video streams, reduce loud noises & vocal boosting, and PiP.

### Media Preview

![Media Details 1](https://github.com/user-attachments/assets/fce61426-a6e3-4388-8060-52c20c1ea315)
A clean view of the content art with quick access to content metadata.

### Media Details

![Media Details 2](https://github.com/user-attachments/assets/cf0954fb-7d0d-4a03-a412-3b0050f2d8a4)
Extensive content metadata.

## v1.2.0 TODO

- [ ] Settings Page
  - [x] Max bitrate
  - [x] Auto play toggle
  - [ ] Connection Info
    - [x] User's name
    - [ ] Server address
    - [ ] Session ID
    - [ ] User's ID
    - [x] Server's name
    - [x] Server's version
    - [x] Stingray's version
    - [x] Total number of movies
    - [x] Total number of shows
    - [x] Total number of libraries
- [x] Streaming Stats in the player
  - [x] Observed bitrate
  - [x] Playback resolution
  - [x] Screen resolution
  - [x] Framerate
  - [x] Codecs
  - [x] Buffer's duration
  - [x] Playback session ID
  - [x] Media ID
  - [x] Media Source ID
  - [x] Video stream ID
  - [x] Audio stream ID
- [x] Profiles
  - [x] Sync between Apple TV users and Jellyfin users.
  - [x] Show all profiles on every Apple TV account, but remember last used profile.
  - [x] Ask for profile choice on launch (like most streaming services).
  - [x] Ask for profile whenever coming from background.
  - [x] Set PINs for certain profiles
- [x] Extend playback buffer
- [x] Lower priority of downloading media
- [x] Use the same view model across all player views
- [x] Improve trailing slashes on URLs.
- [x] Improve JSON decoding verbosity.
- [x] Fix labels appearing black.
- [x] Modernize Jellyfin token format [@darkweak](https://github.com/benjaminRoberts01375/Stingray/pull/75)
- [x] Improve usage of the `AVPlayer` type, allowing `PlayerViewModel.player` to no longer be optional.
  - [x] Slightly improve player loading speeds and massively improves reliability.
  - [x] Fix audio continuing to play after tracks have been switched
  - [x] Fix subtitle, audio, and video tracks randomly changing when changing a different track type
  - [x] Prevent old AVPlayers getting stuck on async threads
- [x] Extend the maximum configurable bitrate to 100 Mbps
- [x] Add the number of items in each library at the bottom of a library
- [x] Store the active user as an object in `UserModel.activeUser`.
- [x] Fix the wrong user being deleted.
- [x] Update security email.
- [x] Added theming support.
  - [x] Added light-mode theme "Notes App".
  - [x] Added light-mode theme "Beach"..
  - [x] Added dark-mode theme "Void"
- [x] Translation support.
- [x] Adjustable playback speed.
- [x] Enable the explicit access control SwiftLint rule

## Long-Term TODO List

### Login

- [ ] Support Jellyfin's Quick Connect feature.

### Media Picker

- [ ] Unwatched media gets a lighter blue background.

### Detail Media View

- [ ] Episode thumbnails where the thumbnail cannot fill the container should use the loaded thumbnail to blur background, instead of the unreliable blur hash.
- [ ] Replace options for continuing and restarting episodes with an alert to be shared with movies for consistency.
- [ ] Optionally blur unwatched TV episode thumbnails.

### Playback

- [ ] Live TV.
- [ ] Restart episode button in episode picker.
- [ ] Trickplay.

### Code Quality

- [ ] Break up the Detail Media View into smaller pieces.
- [ ] Comment all class/struct/enum variables and functions.
