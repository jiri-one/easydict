from django.core.management.utils import get_random_secret_key
from pathlib import Path

# secret_key.txt belongs to the Django project, one directory up
secret_key_file = str(Path((__file__)).parent.parent / "secret_key.txt")

with open(secret_key_file, "w+") as file:
    file.write(get_random_secret_key())
