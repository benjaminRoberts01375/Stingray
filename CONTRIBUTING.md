# Contributing to Stingray

We appreciate every contribution, and we're happy about every new contributor. So please feel invited to continue making Stingray best in class!

## Getting Started

1. Get a Mac and Apple TV. While an Apple TV is optional, it makes development significantly easier since the simulator doesn't support every feature an Apple TV does (Ex. PiP). One important note is that a developer account isn't needed to actually develop, though it can make life easier as it prolongs the amount of time an application (like Stingray) can be installed for. 1 Week -> 1 Year. Additionally, while Stingray doesn't require any of Apple's server APIs, if it one day does, an Apple Developer Account will be required.
2. Download [Xcode](https://apps.apple.com/us/app/xcode/id497799835?mt=12) for development, which will allow you to connect to physical devices and simulators. We do use a couple packages which are already set up with the included Xcode project file.
3. Finally if you want to run Stingray on a physical device or simulator, you'll need to setup a team within Xcode:
    1. In Xcode, open settings by either going to `Xcode > Settings...` or using `Command + ,`
    2. Open "Apple Accounts"
    3. Add your Apple Account.
    4. Close the settings panel.
    5. Back in the main Xcode window, select the `Stingray` project from the sidebar.
    6. Select `Stingray` from the `TARGETS`.
    7. Select `Signing & Capabilities` from the top tab bar.
    8. Pick your team using your Apple ID.
4. Pair your Apple TV to Xcode
    1. On your Apple TV, open `Settings > Remotes and Devices > Remote App and Devices`.
    2. On your Mac, open `Xcode > Product > Destination > Manage Run Destinations...`.
    3. Your Mac should appear as a new remote option on your Apple TV. Select it.
    4. Your Mac may start downloading debug symbols. This will take a little bit.
    5. Once setup, your Apple TV should appear as a run destination.

## General

1. Please try to keep pull requests as focused as possible. A PR should do exactly one thing and not bleed into other, unrelated areas. The smaller a PR, the fewer changes are likely needed, and the quicker it will likely be merged. For larger/more impactful PRs, please reach out to us first to discuss your plans. The best way to do this is through our [discussions](https://github.com/benjaminRoberts01375/Stingray/discussions/new?category=ideas).
2. Please ensure all class/struct/enum variables and functions are commented. With Xcode, you can generate a comment template with `Option + Command + /`.

## Finding Work
  
  Stingray is very young still, so feel free to tackle [open issues](https://github.com/benjaminRoberts01375/Stingray/issues).

## Use of Generative AI

LLMs often generate code very difficult to review and maintain, especially since some will change content it has no business changing. Thus we ask you put extra time and care into what the LLM is modifying or adding since it can often be done simpler and less verbose. Failure to do this can cause PRs to be delayed or outright rejected. See the citations section for how to cite your work with LLMs.

## Citations

If your work is heavily inspired by another project, forum post, LLM, or other source, please do your best to cite your work with a comment in the code (often a small sentence like "Implementation adapted from ..." will suffice). This helps to ensure that nobody goes uncredited, and we as a community can learn from other people's experiences.

## Code Style

SwiftLint is used with this project to ensure high quality Swift code that's readable and understandable. We're always looking for ways to improve the readability of our project, so don't hesitate to open a [discussion post](https://github.com/benjaminRoberts01375/Stingray/discussions/new?category=ideas) for improving code quality.

## Bug Reporting

Discussion posts should be used for everything that isn't directly related to a specific bug. If there's something that "feels off" and can't concretely be scoped into a single task, that's a [discussion post](https://github.com/benjaminRoberts01375/Stingray/discussions/new?category=ideas), not a bug report.
