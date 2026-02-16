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
  - [ ] Smaller profile icons
  - [ ] Max bitrate
  - [ ] Auto play toggle
  - [ ] Themes
  - [ ] Connection Info
    - [ ] User's name
    - [ ] Server address
    - [ ] Session ID
    - [ ] User's ID
    - [ ] Server's name
    - [ ] Server's version
    - [ ] Stingray's version
    - [ ] Total number of movies
    - [ ] Total number of shows
- [ ] Streaming Stats in the player
  - [ ] Observed bitrate
  - [ ] Playback resolution
  - [ ] Screen resolution
  - [ ] Framerate
  - [ ] Codecs
  - [ ] Buffer's duration
  - [ ] Playback session ID
  - [ ] Media ID
  - [ ] Media Source ID
  - [ ] Video stream ID
  - [ ] Audio stream ID
- [ ] Profiles
  - [ ] Integrate into Apple TV profiles
  - [ ] Show all profiles on every Apple TV account, but remember last used profile
  - [ ] Set PINs for certain profiles
- [x] Extend playback buffer
- [x] Lower priority of downloading media

### Long Shots

- [ ] Trickplay support
- [ ] Optionally blur unwatched TV episodes.

## Long-Term TODO List

### Login

- [ ] Support Jellyfin's Quick Connect feature.

### Media Picker

- [ ] Unwatched media gets a blue background.

### Detail Media View

- [ ] Episode thumbnails where the thumbnail cannot fill the container should use the loaded thumbnail to blur background, instead of the unreliable blur hash.
- [ ] Replace options for continuing and restarting episodes with an alert to be shared with movies for consistency.

### Playback

- [ ] Live TV.
- [ ] Restart episode button in episode picker.

### Code Quality

- [ ] Break up the Detail Media View into smaller pieces.
- [ ] Comment all class/struct/enum variables and functions.
