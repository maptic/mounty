# STORY-024: Homebrew tap distribution

- Status: CLOSED
- Type: ci
- Date: 2026-08-10
- Commit: 05f64ac, 5a3d9da

## Intent

Ship Mounty through `brew install --cask maptic/tap/mounty` and keep the cask current without manual
steps: cutting a release must build the DMG, attach it to the GitHub Release, and bump the cask in
`maptic/homebrew-tap`.

## Acceptance criteria

- [x] Merging the release-please PR builds and attaches the DMG — previously the release build never
      ran, because a release created with the default `GITHUB_TOKEN` emits no `release: published`
      event.
- [x] Release tags are bare semver (`1.2.1`), matching the download URL the cask interpolates, and
      the existing `mounty-v1.2.0` tag and release are renamed to that scheme.
- [x] The release build asks `maptic/homebrew-tap` to bump the cask via a `cask-release`
      `repository_dispatch`, and skips that step (without failing) when `HOMEBREW_TAP_TOKEN` is absent.
- [x] `release-build.yml` can be re-run by hand for an existing tag.

## Validation

Release 1.2.1 ran the full chain in one workflow: `release-please` → `release-build / build-dmg`
(attached `Mounty-1.2.1.dmg` + `.dmg.sha256`) → `release-build / update-tap` (dispatch accepted).

The cask was seeded by hand at 1.2.1 because the tap had no `Casks/mounty.rb` for the workflow to
rewrite — `update-cask` failed that first run with `Casks/mounty.rb does not exist`, as intended
rather than inventing a checksum. Its sha256 matches the release's own `Mounty-1.2.1.dmg.sha256`,
and `brew audit --cask --online --strict maptic/tap/mounty` and
`brew livecheck --cask maptic/tap/mounty` (`1.2.1 ==> 1.2.1`) both pass. Subsequent releases bump
the cask automatically.

Note for consumers: `mounty` alone resolves to another cask in `homebrew/cask`, so the full
`maptic/tap/mounty` token is required.
