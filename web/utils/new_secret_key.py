from django.core.management.utils import get_random_secret_key
from pathlib import Path

# I assume, that this file is located in utils folder inside main django project folder
secret_key_file = str(Path((__file__)).parent.parent / "secret_key.txt")

with open(secret_key_file, "w+") as file:
    file.write(get_random_secret_key())
