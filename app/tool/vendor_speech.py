import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

source = Path(sys.argv[1])
miniaudio = Path(sys.argv[2])
lock = json.loads(Path('app/native/sources.lock.json').read_text())


def revision(path):
    return subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()


assert revision(source) == lock['RHVoice']
assert hashlib.sha256(miniaudio.read_bytes()).hexdigest() == lock['miniaudio']['sha256']
for name, commit in lock['submodules'].items():
    assert revision(source / name) == commit

vendor = Path('app/native/vendor/rhvoice')
for name in ['src/core', 'src/include', 'src/lib', 'src/hts_engine',
             'src/third-party/utf8', 'src/third-party/rapidxml']:
    shutil.copytree(source / name, vendor / name, dirs_exist_ok=True)
shutil.copy(source / 'LICENSE.md', vendor)
shutil.copy(miniaudio, 'app/native/vendor/miniaudio.h')

# Czech uses the data-only language implementation.
path = vendor / 'src/core/language.cpp'
text = path.read_text()
text = re.sub(r'^\s*register_language<(?!english_info|data_only_language_info)[^;]+;', '', text, flags=re.M)
path.write_text(text)
# Lower-casing the voice name is the only Boost left without the package client.
path = vendor / 'src/core/voice.cpp'
text = path.read_text()
text = text.replace('#include "boost/algorithm/string.hpp"', '#include <locale>')
text = text.replace('id=boost::replace_all_copy(boost::to_lower_copy(name.get(), std::locale::classic()), "-", "_");',
                    "id=name.get();\n      for(char& c: id) c=c=='-'?'_':std::tolower(c,std::locale::classic());")
path.write_text(text)
for name in ['src/core/engine.cpp', 'src/include/core/config.hpp']:
    path = vendor / name
    text = path.read_text().replace('#ifndef ANDROID\n#include "config.h"\n#endif', '#include "config.h"')
    if name.endswith('config.hpp'):
        text = text.replace('#include "config.h"', '#include "core/config.h"')
    path.write_text(text)

assets = Path('app/assets/speech')
for kind, names in [('languages', ['Czech', 'English']), ('voices', ['radek', 'slt'])]:
    for name in names:
        shutil.copytree(source / 'data' / kind / name, assets / kind / name,
                        ignore=shutil.ignore_patterns('.git', '16000', 'CMakeLists.txt', 'SConscript'),
                        dirs_exist_ok=True)
files = {str(path.relative_to(assets)): hashlib.sha256(path.read_bytes()).hexdigest()
         for path in sorted(assets.rglob('*'))
         if path.is_file() and path.name not in ('manifest.json', 'checksum.txt')}
(assets / 'manifest.json').write_text(json.dumps(sorted(files), indent=2) + '\n')
(assets / 'checksum.txt').write_text(hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest() + '\n')
