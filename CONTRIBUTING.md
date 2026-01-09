# Contributing to Stingray

We appreciate every contribution, and we're happy about every new contributor. So please feel invited to continue making Stingray best in class!

## Getting Started

1. Get a Mac and Apple TV. While an Apple TV is optional, it makes development significantly easier since the simulator doesn't support every feature an Apple TV does (Ex. PiP).
2. Download [Xcode](https://apps.apple.com/us/app/xcode/id497799835?mt=12) for development, which will allow you to connect to physical devices and simulators. We do use a couple packages which are already set up with the included Xcode project file.
3. Finally if you want to run Stingray on a physical device or simulator, you'll need to setup a team within Xcode:
    1. In Xcode, select the `Stingray` project from the sidebar.
    2. Select `Stingray` from the `TARGETS`.
    3. Select `Signing & Capabilities` from the top tab bar.
    4. Pick your team using your Apple ID.

## General

Please try to keep pull requests as focused as possible. A PR should do exactly one thing and not bleed into other, unrelated areas. The smaller a PR, the fewer changes are likely needed, and the quicker it will likely be merged. For larger/more impactful PRs, please reach out to us first to discuss your plans. The best way to do this is through our [discussions](https://github.com/benjaminRoberts01375/Stingray/discussions/new?category=ideas).

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
