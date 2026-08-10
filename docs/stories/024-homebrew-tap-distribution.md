# STORY-024: Homebrew tap distribution

- Status: IN_PROGRESS
- Type: ci
- Date: 2026-08-10
- Commit: _none_

## Intent

Ship Mounty through `brew install --cask maptic/tap/mounty` and keep the cask current without manual
steps: cutting a release must build the DMG, attach it to the GitHub Release, and bump the cask in
`maptic/homebrew-tap`.

## Acceptance criteria

- [ ] Merging the release-please PR builds and attaches the DMG — previously the release build never
      ran, because a release created with the default `GITHUB_TOKEN` emits no `release: published`
      event.
- [ ] Release tags are `vX.Y.Z`, matching the download URL the cask interpolates.
- [ ] The release build asks `maptic/homebrew-tap` to bump the cask via a `cask-release`
      `repository_dispatch`, and skips that step (without failing) when `HOMEBREW_TAP_TOKEN` is absent.
- [ ] `release-build.yml` can be re-run by hand for an existing tag.

## Validation

Record the release run that produced the DMG assets and the resulting cask bump commit in
`maptic/homebrew-tap`.
