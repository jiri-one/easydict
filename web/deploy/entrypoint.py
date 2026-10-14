"""Python rather than a shell script, because the runtime image has no shell.

Neither the web app nor the dictionary import may fail the start: podman auto-update would roll
the image back and try again every night. The site then keeps the ones it had.
"""

import os
import shutil
import sys
import traceback
from pathlib import Path

import django
from django.conf import settings
from django.core.management import call_command

sys.path.insert(0, os.getcwd())  # the Django project is the working directory
django.setup()
call_command("migrate", interactive=False)
call_command("collectstatic", interactive=False, verbosity=0)


def publish_webapp() -> None:
    """Swapped at once, so that a page never loads files of two builds."""
    target = Path(settings.STATIC_ROOT) / "app"
    new, old = target.with_name("app.new"), target.with_name("app.old")
    for leftover in (new, old):
        shutil.rmtree(leftover, ignore_errors=True)
    shutil.copytree(settings.WEBAPP_DIR, new)
    if target.exists():
        target.rename(old)
    new.rename(target)
    shutil.rmtree(old, ignore_errors=True)


try:
    if settings.WEBAPP_DIR.is_dir():
        publish_webapp()
except Exception:
    traceback.print_exc()
    print("The web app was not published.", file=sys.stderr)
try:
    call_command("import_dictionary", auto=True)
except Exception:
    traceback.print_exc()
    print("The dictionary was not imported.", file=sys.stderr)
sys.stdout.flush()
os.execvp(sys.argv[1], sys.argv[1:])
