# Changelog

## [1.2.1](https://github.com/maptic/mounty/compare/1.2.0...1.2.1) (2026-08-10)


### Bug Fixes

* publish release artifacts and the Homebrew cask ([8af619f](https://github.com/maptic/mounty/commit/8af619fd0591f91f4f5ae1efc9b69bf92773a74b))
* publish release artifacts and the Homebrew cask ([05f64ac](https://github.com/maptic/mounty/commit/05f64ac45ea8138e5d2e6717a6daf1dab81a222a))
* tag releases with bare semver ([5a3d9da](https://github.com/maptic/mounty/commit/5a3d9da8fc51db570d53586d90f58e0281e5f05a))

## [1.2.0](https://github.com/maptic/mounty/compare/mounty-v1.1.0...mounty-v1.2.0) (2026-08-10)


### Features

* add custom menu bar logo ([002dfdc](https://github.com/maptic/mounty/commit/002dfdc72b10697ddbb6828fdb0594e37dddced7))
* add global network check ([8c2f5d2](https://github.com/maptic/mounty/commit/8c2f5d2be9737445e19a6a6a68fb7f26a8eed1bb))
* add logo ([da9189f](https://github.com/maptic/mounty/commit/da9189fc0c014da7dbf6572cacba7a633d531a99))
* add repository link and asset sources ([a06292e](https://github.com/maptic/mounty/commit/a06292e4b8a0382799c0698fe48f64832a06948a))
* add tooltips ([1d7a634](https://github.com/maptic/mounty/commit/1d7a63476bbaa38bca926ba6ad4a5ae399d50182))
* add transparent logo ([8047246](https://github.com/maptic/mounty/commit/8047246ad2575c073dbf4fde41b1d7f53e7f73aa))
* avoid memory leak ([35abff6](https://github.com/maptic/mounty/commit/35abff603c9395516910579cfe735e421ed01a1c))
* improve logging ([7b1a2c3](https://github.com/maptic/mounty/commit/7b1a2c3a9b0ae89fcefff418c69a0e1d8e122228))
* improve menu bar workflows ([20de4bb](https://github.com/maptic/mounty/commit/20de4bb4f2c803a04015533cad765d2d35aef8d6))
* increase size of logo ([30b375f](https://github.com/maptic/mounty/commit/30b375f58617ba7e0f4301955c7b09275052a2da))
* initial mounting and unmounting feature ([9be3b7d](https://github.com/maptic/mounty/commit/9be3b7dbd1ed4573c9f8ff07199090a54c163689))
* introduce seprate overlays, style searchbar ([ecc1703](https://github.com/maptic/mounty/commit/ecc1703d601d1cf40c0ce25d70dcc39d843aac6e))
* monitor netowrk events instead of constant polling ([bc17e70](https://github.com/maptic/mounty/commit/bc17e707f3c7b7d721820755db62e0e130ab7f90))
* quit button ([ccf8907](https://github.com/maptic/mounty/commit/ccf89071ec92cdf8b0e2e93be554faf20fdfa587))
* rename to volumes, add search bar ([c860f12](https://github.com/maptic/mounty/commit/c860f12ba1fc643c1840c1a925c51cd9a86556dc))
* searchbar ([f5736fc](https://github.com/maptic/mounty/commit/f5736fc6841ef0afdf82403bd5e8f2e918c8ace2))
* simplify import and export logic ([cdce80a](https://github.com/maptic/mounty/commit/cdce80a5d60f7d9a16b6aae24d8f72485f15fb49))
* streamline UI ([2ee9a9a](https://github.com/maptic/mounty/commit/2ee9a9a8b13e5a1384b8733b845a0689a79f8376))
* style header ([00be00c](https://github.com/maptic/mounty/commit/00be00c8260300f0e3e31c722970b974f2ec5b47))
* **ui:** add in-app log viewer and one-shot volume speed test ([c38807a](https://github.com/maptic/mounty/commit/c38807a76f3ea9c75358a6fdb487aaf888bd3669))
* **ui:** modernise all views to macOS-native design standards ([3f7596b](https://github.com/maptic/mounty/commit/3f7596bcace40f8544acc8e6a46fc089255e4810))
* **ui:** replace custom icon buttons in Settings with native Form rows ([bd7e248](https://github.com/maptic/mounty/commit/bd7e248602f2ffe5c24a94a73d4603571593b480))


### Bug Fixes

* always open new terminal, confirm before reset, open folder not volumes ([78ce5e4](https://github.com/maptic/mounty/commit/78ce5e45c316bb25a4a28663134cedbe8ddae9cc))
* **automount:** restore reliable mounting and logging ([7680013](https://github.com/maptic/mounty/commit/76800130ead77026335f47ef67d69e1dfa2e7fb0))
* **automount:** restore VolumeManager lifecycle to menu-bar open ([82eb8bf](https://github.com/maptic/mounty/commit/82eb8bf7f92301f06685fcffb20e2c0e523a2700))
* **concurrency:** resolve Swift 6 actor-isolation warnings to zero ([d48071e](https://github.com/maptic/mounty/commit/d48071ef4ce225a7424b2bc6440cbd11ecf9acca))
* detect vpn connects and disconnects ([b635be1](https://github.com/maptic/mounty/commit/b635be1b96bf09bc8d5eae94c60fc5e2489b2c7d))
* ensure responsiveness on reconnect ([caaeeb9](https://github.com/maptic/mounty/commit/caaeeb92fe3855d657325e53245f8cbdcb87bc79))
* handle mount lifecycle cleanup ([583cc8d](https://github.com/maptic/mounty/commit/583cc8da57ff2fbb360d718f4f81eba0d4cdf49d))
* harden volume lifecycle and imports ([59f38fc](https://github.com/maptic/mounty/commit/59f38fcad9a570178a6b07c03eab670dcd2992ab))
* keep speed tests and footer responsive ([68130dc](https://github.com/maptic/mounty/commit/68130dcbfecdb04b730eedbd48f320b5bbfbf039))
* **mount:** replace substring host match with exact extractHost equality ([51caae7](https://github.com/maptic/mounty/commit/51caae7c7c4deda7aa17d55202087d739781b1a1))
* **perf:** honest speed test measurements and robust cleanup ([ef2a37f](https://github.com/maptic/mounty/commit/ef2a37f83d69788f97df9887a13868f2cf07f448))
* preserve SMB volume identity and lifecycle ([f0df511](https://github.com/maptic/mounty/commit/f0df511c1767274f582707a54dfb34aaf09a65c7))
* **reachability:** replace contentsOfDirectory with statfs to stop TCC prompts ([6be4024](https://github.com/maptic/mounty/commit/6be4024f14d2ed54487830d44baeaab6a41d60b0))
* remove logger warnings ([2de63e1](https://github.com/maptic/mounty/commit/2de63e1ad4227835919119d66fd5e85b0ff85b4c))
* **services:** loop read(2) to completion and log force-unmount result ([ed678aa](https://github.com/maptic/mounty/commit/ed678aaa7981c6edd5293c017c29389569ec2c13))
* **ui:** back button always returns to main list, not settings ([ace1472](https://github.com/maptic/mounty/commit/ace1472ff6e3505de46582925f366443212decf3))
* **ui:** eliminate button-click delay in VolumeRow with simultaneousGesture ([4645639](https://github.com/maptic/mounty/commit/46456398bca62c731178835bba30d8bc2938276f))
* **ui:** full-width hover buttons for settings volume actions ([b9f2646](https://github.com/maptic/mounty/commit/b9f26465f773f1815102181f87ec3f909e61755a))
* **ui:** logs button in header, reliable hit areas, consistent hover ([f11cf2a](https://github.com/maptic/mounty/commit/f11cf2afe064c8e4f9a826a6325cd2b07a15ad62))
* **ui:** reduce settings volume buttons to native small control size ([5f79f55](https://github.com/maptic/mounty/commit/5f79f555ce77fba362cc65a13e41833f37fb530d))
* **ui:** reliable animations, drag-to-resize, no main-thread blocking ([82c28cf](https://github.com/maptic/mounty/commit/82c28cffbb251a501544951e439c2bc2c152102e))
* **ui:** replace iconButtonHover ViewModifier with ButtonStyle to fix hit areas ([b6e24ec](https://github.com/maptic/mounty/commit/b6e24ec4df9feabf5061f256c0551904e5b4bc2d))
* **ui:** restore icon-only row layout in Settings with proper hover ([16f94d6](https://github.com/maptic/mounty/commit/16f94d6f213abb8b37679da3f167459f1e8420a9))
* **ui:** use icon hover style for settings volume buttons ([68485f4](https://github.com/maptic/mounty/commit/68485f47566bd4f47195080990f4c22b83cc775a))
* validate SMB endpoints ([b723267](https://github.com/maptic/mounty/commit/b72326796de39d31aca446227c1fc19d4b1545f6))


### Performance Improvements

* **concurrency:** parallelize automount and move blocking work off main actor ([705ee42](https://github.com/maptic/mounty/commit/705ee42f8321e67c24a97e136c06525f5583ac14))


### Reverts

* align README title row ([ed5ffc2](https://github.com/maptic/mounty/commit/ed5ffc2f2cf5d05663f122d44ed2699370341668))
