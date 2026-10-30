import fcntl
import logging
import re
import subprocess
import tempfile
from pathlib import Path

from django.conf import settings

LOCK = Path(tempfile.gettempdir()) / 'easydict-speech.lock'
logger = logging.getLogger(__name__)
_PLACEHOLDER = re.compile(r'\b(sb|sth|st)\b\.?', re.ASCII)
_ALTERNATIVE = re.compile(r'(\S)\s*/\s*(?=(\S))')
_DIGIT = re.compile('[0-9]')


class Unavailable(Exception):
    pass


def spoken_text(text, language):
    """A port of app/lib/data/speech_text.dart; a change belongs to both."""
    depth = 0
    kept = []
    for character in text:
        if character == '(':
            depth += 1
            kept.append(' ')
        elif character == ')' and depth > 0:
            depth -= 1
        elif depth == 0 and character not in '[]':
            kept.append(character)
    spoken = ''.join(kept)
    if language == 'eng':
        # Lowercase only: St. Paul is a saint.
        spoken = _PLACEHOLDER.sub(lambda match: 'somebody' if match[1] == 'sb' else 'something', spoken)

    def separated(match):
        numeric = _DIGIT.search(match[1]) and _DIGIT.search(match[2])
        return match[0] if numeric else f'{match[1]} '

    spoken = _ALTERNATIVE.sub(separated, spoken)
    return re.sub(r'[\s/]+$|\s+', ' ', spoken).strip()


def synthesize(text, language):
    try:
        with open(LOCK, 'a') as lock:
            # One renderer across all workers, so speech cannot take them from searching.
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return subprocess.run(
                [settings.SPEECH_EXECUTABLE, settings.SPEECH_DATA, language, text, '/dev/stdout'],
                check=True, timeout=10, stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            ).stdout
    except BlockingIOError as error:
        raise Unavailable from error
    except (OSError, subprocess.SubprocessError) as error:
        logger.exception('The speech renderer failed')
        raise Unavailable from error
