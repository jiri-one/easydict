# Packaging and releases

- `linux/` – desktop entry, AppStream metadata and icon, used by the Flatpak and the release tarballs
- `screenshots/` – screenshots referenced by the AppStream metadata
- `flatpak/flatpak-flutter.yml` – the Flatpak manifest before [flatpak-flutter](https://github.com/TheAppgineer/flatpak-flutter) turns it into the offline manifest for Flathub
- `fdroid/one.jiri.easydict.yml` – the build recipe for [fdroiddata](https://gitlab.com/fdroid/fdroiddata)

## Making a release

All paths are relative to the root of the repository.

1. Raise the version in `app/pubspec.yaml` (`1.0.1+2`: the number after `+` must grow) and `app/lib/version.dart`.
2. Add the release with its date to `packaging/linux/one.jiri.easydict.metainfo.xml` and a changelog `app/fastlane/metadata/android/{en-US,cs-CZ}/changelogs/<number after +>.txt`.
3. Commit, tag and push: `git tag v1.0.1 && git push origin main v1.0.1`. The `Release` workflow builds Linux, Windows, macOS and Android and publishes a GitHub release.
4. Flathub: in `packaging/flatpak/flatpak-flutter.yml`, point the app source to the new tag (`tag: v1.0.1` instead of `branch`), then generate the offline manifest and check it:

       cd packaging/flatpak
       flatpak-flutter.py flatpak-flutter.yml
       flatpak run --command=flathub-build org.flatpak.Builder --install one.jiri.easydict.yml
       flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest one.jiri.easydict.yml
       flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo

   Copy the generated `one.jiri.easydict.yml` and `generated/` to the Flathub repository of the app.
5. F-Droid picks new tags up by itself (`UpdateCheckMode: Tags`).

## First submission

**Flathub:** fork `flathub/flathub`, branch off `new-pr`, add `one.jiri.easydict.yml` and `generated/`, and open a pull request against `new-pr` titled `Add one.jiri.easydict`. After approval, accept the invitation to the new repository within a week (GitHub 2FA is required). The app ID is under the jiri.one domain; Flathub verifies it with a token served at `https://jiri.one/.well-known/org.flathub.VerifiedApps.txt`.

**F-Droid:** fork `fdroid/fdroiddata` on GitLab, add `packaging/fdroid/one.jiri.easydict.yml` as `metadata/one.jiri.easydict.yml` and open a merge request. The descriptions and screenshots come from `app/fastlane/`.
