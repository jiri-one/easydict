"""CI has no audio device, so inspect the synthesized PCM directly."""
import ctypes
import locale
import math
import os
import struct
import sys
import tempfile
import wave
from pathlib import Path

library = ctypes.CDLL(str(Path(sys.argv[1]).resolve()))
library.ed_speech_replace.restype = ctypes.c_uint64
library.ed_speech.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint64, ctypes.c_char_p]
data = str(Path(sys.argv[2]).resolve()).encode()


def render(language, word, output, request=None):
    return library.ed_speech(data, language, word, request or library.ed_speech_replace(), str(output).encode())


with tempfile.TemporaryDirectory() as directory:
    # The app runs in the user's locale, where a decimal comma garbled the voice.
    # In a child, because the engine parses the voice once per process.
    comma = Path(directory) / 'comma.wav'
    child = os.fork()
    if child == 0:
        locale.setlocale(locale.LC_NUMERIC, 'cs_CZ.UTF-8')
        os._exit(0 if render(b'eng', b'hello', comma) == 1 else 1)
    assert os.waitstatus_to_exitcode(os.waitpid(child, 0)[1]) == 0
    for language, word in [(b'cze', b'ahoj'), (b'eng', b'hello')]:
        output = Path(directory) / f'{language.decode()}.wav'
        assert render(language, word, output) == 1, language
        with wave.open(str(output)) as audio:
            assert audio.getnchannels() == 1 and audio.getsampwidth() == 2
            duration = audio.getnframes() / audio.getframerate()
            assert audio.getframerate() == 24000
            samples = struct.unpack(f'<{audio.getnframes()}h', audio.readframes(audio.getnframes()))
            rms = math.sqrt(sum(n*n for n in samples) / len(samples))
            assert 0.15 < duration < 10 and rms > 10
            print(f'{language.decode()}: 24000 Hz, {duration:.3f} s, RMS {rms:.1f}, peak {max(map(abs, samples))}')
    assert comma.read_bytes() == output.read_bytes(), 'the voice depends on LC_NUMERIC'
    print('decimal comma: identical output')
    stale = library.ed_speech_replace()
    library.ed_speech_replace()
    assert render(b'eng', b'hello', output, stale) == 0
