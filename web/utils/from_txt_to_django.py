from sys import path as sys_path
from pathlib import Path
from contextlib import contextmanager
from os import environ

@contextmanager
def django_context():
    try:
        django_dir = str(Path(__file__).parent.parent)
        sys_path.append(django_dir)
        from django.core.wsgi import get_wsgi_application
        environ["DJANGO_SETTINGS_MODULE"] = "easydict.settings"
        application = get_wsgi_application()
        yield
    finally:
        sys_path.remove(django_dir)
        del application

def remove_empty(line):
	dict_row = {}
	line_list = line.split("\t")
	dict_row["eng"] = line_list[0] # english translation will be here always
	dict_row["cze"] = line_list[1] # czech translation will be here always
	if line_list[2]:
		dict_row["notes_cze"] = line_list[2]
	if line_list[3]:
		dict_row["special_cze"] = line_list[3]
	removed_new_line = str(line_list[4]).replace("\n", "")
	if removed_new_line:
		dict_row["author"] = removed_new_line
	return dict_row

with django_context():
    from web.models import Record
    with open("utils/en-cs.txt", "rb") as file:
        for line in file:
            dict_row = remove_empty(line.decode())
            record = Record(**dict_row)
            record.save()
