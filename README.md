![Stingray Logo](https://github.com/user-attachments/assets/1909af68-b4af-42cf-b562-906cb80c8527)

# Stingray

### A super native, super fast Jellyfin client

![License](https://img.shields.io/badge/License-MIT-red)
![platforms](https://img.shields.io/badge/platforms-tvOS-green) ![tvOS](https://img.shields.io/badge/tvOS-18%2E0%2B-blue)

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

![Media details 1](https://github.com/user-attachments/assets/12886513-f69a-43fd-a4e9-15fdd714b04c)
A clean view of the content art with quick access to content metadata.

### Media Details

![Media Details 2](https://github.com/user-attachments/assets/cf0954fb-7d0d-4a03-a412-3b0050f2d8a4)
Extensive content metadata.

## v1.1.0 TODO List

### Bugs

- [ ] Fix connecting to local Jellyfin clients triggering App Transport Security policy.
- [x] Even out the padding around text in media posters.
- [x] Improve errors to show a stack trace with summary.
- [x] Prevent the `MediaModel` and `SlimMediaModel` from causing loading errors.
  - [x] Ideally they'd be highlighted in red.

### Code Quality

- [x] Abstract away Jellyfin's "tick" system.

### Features

- [x] Improve HDR support with tone mapping.
- [x] Show extras and BTS.
- [ ] Sort specials.
- [x] Display server name in system info.
- [x] Rework play buttons to be more consistent between media types, while allowing resume/restart.
- [x] Improve home screen performance.

## Long-Term TODO List

### Login

- [ ] Support Jellyfin's Quick Connect feature.

### Profiles

- [ ] Show all available profiles on Jellyfin server.
- [ ] Allow "locking" some profiles with a pin.
- [ ] Move profiles to home screen.
  - [ ] Repurpose existing profile screen for settings, continue to show profiles there.

### Settings

- [ ] Expose existing bitrate option.
- [ ] Custom background colors and gradients.
- [ ] Store preferred language per user based on last used audio track.

### Media Picker

- [ ] Unwatched media gets a blue background.

### Detail Media View

- [ ] Episode thumbnails where the thumbnail cannot fill the container should use the loaded thumbnail to blur background, instead of the unreliable blur hash.
- [ ] Continue watching can suggest wrong episode.
- [ ] Optionally blur unwatched TV episodes.
- [ ] Replace options for continuing and restarting episodes with an alert to be shared with movies for consistency.

### Playback

- [ ] Live TV.
- [ ] Add a "Streaming Stats" page in the player to show current playback status.
  - [ ] Is Transcoding & Reason.
  - [ ] HDR standard, tone mapping to SDR, or native SDR.
  - [ ] Current bitrate (could be variable).
  - [ ] Playback resolution.
- [ ] Restart (episode) button.

### Code Quality

- [ ] Move all JSON parsing to inside class declarations.
- [ ] Break up the Detail Media View into smaller pieces.
- [ ] Comment all class/struct/enum variables and functions.
