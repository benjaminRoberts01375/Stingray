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
- PiP.
- View content metadata like actors/directors, episode/series descriptions, and ratings.
- Resume movies and episodes.
- Multiple servers & profiles.
  - PIN Support.
  - Per-profile theming
- Integrates with optional loud noise reduction and voice boosting.
- Content fuzzy searching.
  - Search movies, show titles, and episode titles.
- Connect via HTTP or HTTPS.
- Quick Connect.
- Strong Accessibility Support.

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

### Settings

![Settings](https://github.com/user-attachments/assets/90a8dfb7-35ea-4bd3-bb44-acf37d9c754c)

Configure Stingray to look and feel how you want it.

## TO-DONE List

- Repo Organization
  - Rename "Other-Assets" to "Other Assets"
  - Have ErrorView be a component
  - Move all views into a Views folder
  - Move DetailMediaView into a dedicated Media Detail folder
  - Move the player files into a dedicated "player" folder
  - Abstract metadata and overview in the DetailMediaView to their own views
  - Abstract the MovieDetailView into a separate view
  - Rebrand the DetailMediaView to TVShowDetailView
- UI
  - Have the background around the title art only on the title
- Bug Fixes
  - Specify do not sleep while playing video
  - Allow moving from media metadata to play button
- Performance
  - Only store first blur hash for each type

## TODO List

### Media Picker

- [ ] Unwatched media gets a marker.

### Detail Media View

- [ ] Episode thumbnails where the thumbnail cannot fill the container should use the loaded thumbnail to blur background, instead of the unreliable blur hash.
- [ ] Optionally blur unwatched TV episode thumbnails.

### Libraries

- [ ] Rework library structure to support more library types, like collections and group by actor.
- [ ] Library filtering.
- [ ] Manual library refresh.

### Playback

- [ ] Live TV.
- [ ] Music Support.
- [ ] Trickplay.

### Code Quality

- [ ] Break up the Detail Media View into smaller pieces.
- [ ] Comment all class/struct/enum variables and functions.
