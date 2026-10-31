# Speech sources

The local CMake target builds three things into one library: RHVoice's core and C API with Czech's data-only language implementation and modified hts_engine for the Czech voice; eSpeak NG and `vits.cpp` for the English voice; and miniaudio 0.11.23. Packaging tools compile it with their own toolchains. There are no binary libraries, build hooks or network steps in this target. Unused languages and packaging frontends are excluded from compilation, which also removes the need for Boost.

`sources.lock.json` records the exact RHVoice commit (tag 1.18.4), the voice and language commits, the miniaudio checksum, the eSpeak NG commit and the checksums of the Piper voice. Only Radek's 24000/ models are included; the voice was checked with that directory alone.

## The English voice

The voice is Piper's `en_US-ljspeech-medium`, trained from scratch on the public-domain LJ Speech Dataset. `vits.cpp` is a dependency-free implementation of that network, because F-Droid and Flathub would have to build ONNX Runtime from source, a big job for one small network. With its random noise switched off, the float weights gave the same result as ONNX Runtime to 97 dB.

`tool/export_voice.py` packs the 63 MB model into `voice.bin`: 8 bits for the text encoder and the flow, 12 bits in 16 for the duration predictor and the decoder, 18 MB on disk and 13 MB in an APK. The change this makes is half of what a different noise seed makes (1.4 against 2.9 dB of log-mel distance), and the quiet parts do not get noisier.

The voice was trained on eSpeak NG's phonemes, so the commit is the one Piper builds against. Of 40,000 dictionary entries, the phonemes differ from Piper 1.8.0's in two.

## Vendoring

From the repository root:

    git clone --branch 1.18.4 https://github.com/RHVoice/RHVoice /tmp/rhvoice
    git -C /tmp/rhvoice submodule update --init --depth 1 --jobs 8 -- data/languages/Czech data/voices/radek
    curl -fL https://raw.githubusercontent.com/mackron/miniaudio/0.11.23/miniaudio.h -o /tmp/miniaudio.h
    git clone https://github.com/espeak-ng/espeak-ng /tmp/espeak-ng
    git -C /tmp/espeak-ng checkout 212928b394a96e8fd2096616bfd54e17845c48f6
    cmake -S /tmp/espeak-ng -B /tmp/espeak-ng/build -DUSE_MBROLA=OFF -DUSE_LIBSONIC=OFF -DUSE_LIBPCAUDIO=OFF -DUSE_ASYNC=OFF -DUSE_KLATT=OFF -DUSE_SPEECHPLAYER=OFF
    cmake --build /tmp/espeak-ng/build
    mkdir /tmp/piper
    for name in en_US-ljspeech-medium.onnx en_US-ljspeech-medium.onnx.json MODEL_CARD; do curl -fL https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ljspeech/medium/$name -o /tmp/piper/$name; done
    python3 app/tool/vendor_speech.py /tmp/rhvoice /tmp/miniaudio.h /tmp/espeak-ng /tmp/piper

The script needs `numpy` and `onnx`. It preserves upstream notices and applies small adaptations: Czech is the only language left, and it is data-only; generated configuration headers are used consistently on Android; the voice name is lower-cased without Boost; and eSpeak NG no longer sets the process's locale, which its Unicode tables do not need. libc++ builds enable its compatibility typedefs for RHVoice's C++17 use of unary_function and binary_function. Asset checksums are regenerated after copying. Keep `assets/licenses` notices when updating: RHVoice LGPL/GPL, language data GPL, Radek CC0, eSpeak NG GPL with one Apache-2.0 header and Unicode data, Piper's voices MIT, LJ Speech public domain, hts_engine GPL/BSD, UTF8-CPP and RapidXML Boost, miniaudio public domain/MIT-0. Radek's named speaker is Radek Zalud.

For a server renderer, configure with `-DSPEECH_CLI=ON`. It writes WAV to the output path supplied as its fourth argument. It does not open an audio device. Django bounds its execution with a subprocess timeout. The shared library's replacement counter cancels both voices and native playback; callers must obtain a new counter before starting a request.
