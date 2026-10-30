import fcntl
import logging
import subprocess
import tempfile
from pathlib import Path

from django.conf import settings

LOCK = Path(tempfile.gettempdir()) / 'easydict-speech.lock'
logger = logging.getLogger(__name__)


class Unavailable(Exception):
    pass


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
