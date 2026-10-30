# Speech sources

The local CMake target builds RHVoice's core and C API, Czech's data-only language implementation, English, modified hts_engine, and miniaudio 0.11.23. Packaging tools compile it with their own toolchains. There are no binary libraries, build hooks or network steps in this target. Unused languages and packaging frontends are excluded from compilation, which also removes the need for Boost.

The exact RHVoice commit (tag 1.18.4), voice/language commits and miniaudio checksum are recorded in `sources.lock.json`. Voice selection is the two names in `speech.cpp`. Only 24000/ voice models are included; both voices were checked with that directory alone.

To reproduce the vendoring, from the repository root:

    git clone --branch 1.18.4 https://github.com/RHVoice/RHVoice /tmp/rhvoice
    git -C /tmp/rhvoice submodule update --init --depth 1 --jobs 8 -- data/languages/Czech data/languages/English data/voices/radek data/voices/slt
    curl -fL https://raw.githubusercontent.com/mackron/miniaudio/0.11.23/miniaudio.h -o /tmp/miniaudio.h
    python3 app/tool/vendor_speech.py /tmp/rhvoice /tmp/miniaudio.h

The script preserves upstream notices and applies three small adaptations: only English has a compiled language registration (Czech is data-only), generated configuration headers are used consistently on Android, and the voice name is lower-cased without Boost. libc++ builds enable its compatibility typedefs for RHVoice's C++17 use of unary_function and binary_function. Asset checksums are regenerated after copying. Keep `assets/licenses` notices when updating: RHVoice LGPL/GPL, language data GPL, Radek CC0, Slt CMU Arctic, hts_engine GPL/BSD, UTF8-CPP and RapidXML Boost, miniaudio public domain/MIT-0. Radek's named speaker is Radek Zalud; Slt is trained from CMU Arctic by the RHVoice team. The CMU licence is reproduced from the CMU Arctic report (https://festvox.org/cmu_arctic/cmu_arctic_report.pdf); Slt's upstream README identifies that licence.

For a server renderer, configure with `-DSPEECH_CLI=ON`. It writes WAV to the output path supplied as its fourth argument. It does not open an audio device. Django bounds its execution with a subprocess timeout. The shared library's replacement counter cancels both synthesis callbacks and native playback; callers must obtain a new counter before starting a request.
