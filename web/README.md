# EasyDict website
The website of the EasyDict project, [https://easydict.jiri.one](https://easydict.jiri.one): Django (Python) as the backend and some pure JavaScript as the frontend.

The dictionary data come from `data/en-cs/en-cs.txt` of this repository. To load them into an empty database, run `python utils/from_txt_to_django.py` in this directory. The script only adds records, it does not update existing ones; to refresh the data, delete the old records first:

    python manage.py shell -c "from web.models import Record; Record.objects.all().delete()"
    python utils/from_txt_to_django.py

The production image is built from `deploy/Containerfile` by the `Website image` workflow on every change of `web/` on `main` and published as `ghcr.io/jiri-one/easydict-web`.
