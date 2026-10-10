"""Container start: bring the database schema up to date and refresh the static files
(served by the reverse proxy from a shared volume), then run the server command (CMD).

Python rather than a shell script, because the runtime image has no shell.
"""

import os
import sys

import django
from django.core.management import call_command

sys.path.insert(0, os.getcwd())  # the Django project is the working directory
django.setup()
call_command("migrate", interactive=False)
call_command("collectstatic", interactive=False, verbosity=0)
os.execvp(sys.argv[1], sys.argv[1:])
