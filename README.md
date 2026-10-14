# EasyDict

The first open-source translator that is completely open, dictionary data included.

EasyDict is an English–Czech and Czech–English dictionary that works offline on Linux, Windows, macOS and Android, and a website at [easydict.jiri.one](https://easydict.jiri.one). It contains more than 150,000 translations of the free English–Czech dictionary of the Svobodné slovníky project and also finds Czech words typed in other forms (*psa* → *pes*).

## Download

The builds of every release are on the [releases page](https://github.com/jiri-one/easydict/releases):

- **Linux** – `easydict-…-linux-x86_64.tar.gz` (or `aarch64`): unpack it and run `easydict`. The Flathub package is on its way.
- **Android** – `easydict-…-android.apk`, or the smaller `…-android-arm64-v8a.apk` for most phones. The F-Droid package is on its way.
- **Windows** – `easydict-…-windows-x64.zip`: unpack it and run `easydict.exe`.
- **macOS** – `easydict-…-macos.zip`: the app is not notarized, so the first start has to be allowed in *System Settings → Privacy & Security*.

Tips:

- On Android, select a word in any app and choose *Look up in EasyDict* from the menu.
- On the desktop, `easydict WORD` starts with WORD looked up. Bound to a keyboard shortcut, e.g. `sh -c 'easydict "$(wl-paste --primary)"'`, it translates the selected text.

## Repository

- `app/` – the Flutter app for Linux, Windows, macOS and Android
- `data/` – the dictionary data, a continuation of [Svobodné slovníky](https://github.com/lehrbuch/svobodneslovniky), and the tools that build the app database
- `web/` – the website (Django)
- `branding/` – the logo and the script that renders all icons from it
- `packaging/` – Linux metadata, the Flatpak and F-Droid recipes and how to make a release

## Building the app

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.47 and Python 3.9 or newer.

    cd app
    ./tool/build_dictionary.sh   # builds assets/dictionary/easydict.sqlite from data/
    flutter run

## Licences

- the app and the website: GNU GPL 3
- the dictionary (`data/en-cs/`): GNU FDL 1.1 or later
- Czech word forms (`data/cs-forms/`): GNU GPL 2 (Hunspell) and CC BY-SA 4.0 (Wiktionary)
- word frequencies (`data/frequency/`): CC BY-SA 4.0 (wordfreq)

## History

EasyDict started in 2020 as a desktop app in Python and GTK 3, published on PyPI and Flathub, followed by a GTK 4 and libadwaita rewrite in 2023–2024. Both live on in [easydict-gtk](https://github.com/jiri-one/easydict-gtk). The website went from CherryPy to Django. In 2026 the project moved into this repository, the dictionary data got their new home here after svobodneslovniky.cz went offline, and the app was rewritten in Flutter to run on phones too.

---

**Česky:** EasyDict je anglicko-český a česko-anglický slovník pro Linux, Windows, macOS a Android, který funguje bez internetu, a web [easydict.jiri.one](https://easydict.jiri.one). Obsahuje přes 150 000 překladů ze svobodného slovníku projektu Svobodné slovníky, jehož data se nyní spravují tady v adresáři `data/`, a česká slova najde i v jiných tvarech. Začínal v roce 2020 jako aplikace v Pythonu a GTK, jejíž poslední verze s GTK 4 zůstává v repozitáři [easydict-gtk](https://github.com/jiri-one/easydict-gtk).
