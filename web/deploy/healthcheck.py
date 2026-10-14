"""GET / the way the reverse proxy forwards it, so that ALLOWED_HOSTS and the HTTPS redirect
let it through.

usage: python healthcheck.py <host name>
"""

import sys
import urllib.request

request = urllib.request.Request(
    "http://127.0.0.1:8000/",
    headers={"Host": sys.argv[1], "X-Forwarded-Proto": "https"},
)
try:
    with urllib.request.urlopen(request, timeout=10) as response:
        sys.exit(0 if response.status == 200 else 1)
except Exception as error:
    print(error)
    sys.exit(1)
