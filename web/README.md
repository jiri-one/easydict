# EasyDict website
The website of the EasyDict project, [https://easydict.jiri.one](https://easydict.jiri.one): Django (Python) as the backend and some pure JavaScript as the frontend.

The dictionary data come from `data/en-cs/en-cs.txt` of this repository. To load them into the database, run `python utils/from_txt_to_django.py` in this directory.

The production image is built from `deploy/Containerfile` by the `Website image` workflow on every change of `web/` on `main` and published as `ghcr.io/jiri-one/easydict-web`.
