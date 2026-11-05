import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

source = Path(sys.argv[1])
miniaudio = Path(sys.argv[2])
espeak = Path(sys.argv[3])
piper = Path(sys.argv[4])
lock = json.loads(Path('app/native/sources.lock.json').read_text())


def revision(path):
    return subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()


assert revision(source) == lock['RHVoice']
assert hashlib.sha256(miniaudio.read_bytes()).hexdigest() == lock['miniaudio']['sha256']
assert revision(espeak) == lock['espeak-ng']['commit']
for name, digest in lock['piper']['files'].items():
    assert hashlib.sha256((piper / name).read_bytes()).hexdigest() == digest
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
text = re.sub(r'^\s*register_language<(?!data_only_language_info)[^;]+;', '', text, flags=re.M)
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

target = Path('app/native/vendor/espeak-ng')
library = ['common', 'mnemonics', 'error', 'ieee80', 'compiledata', 'compiledict', 'dictionary', 'encoding',
           'intonation', 'langopts', 'numbers', 'phoneme', 'phonemelist', 'readclause', 'setlengths', 'soundicon',
           'spect', 'ssml', 'synthdata', 'synthesize', 'tr_languages', 'translate', 'translateword', 'voices',
           'wavegen', 'speech', 'espeak_api']
(target / 'src/libespeak-ng').mkdir(parents=True, exist_ok=True)
for name in library:
    shutil.copy(espeak / f'src/libespeak-ng/{name}.c', target / 'src/libespeak-ng')
for path in (espeak / 'src/libespeak-ng').glob('*.h'):
    shutil.copy(path, target / 'src/libespeak-ng')
for name in ['src/include', 'src/ucd-tools/src']:
    shutil.copytree(espeak / name, target / name, dirs_exist_ok=True)
for name in ['COPYING', 'COPYING.APACHE', 'COPYING.BSD2', 'COPYING.UCD']:
    shutil.copy(espeak / name, target)
path = target / 'src/libespeak-ng/speech.c'
text = path.read_text()
# The locale belongs to the app: speech.cpp sets one on its own thread.
text, count = re.subn(r'\tif \(setlocale\(LC_CTYPE, "C\.UTF-8"\) == NULL\) \{.*?\n\t\}\n', '', text, count=1, flags=re.S)
assert count == 1
path.write_text(text)

assets = Path('app/assets/speech')
data = assets / 'espeak-ng-data'
(data / 'lang/gmw').mkdir(parents=True, exist_ok=True)
for name in ['phontab', 'phonindex', 'phondata', 'intonations', 'en_dict']:
    shutil.copy(espeak / 'build/espeak-ng-data' / name, data)
shutil.copy(espeak / 'build/espeak-ng-data/lang/gmw/en', data / 'lang/gmw')
(assets / 'voices/ljspeech').mkdir(parents=True, exist_ok=True)
shutil.copy(piper / 'MODEL_CARD', assets / 'voices/ljspeech')
subprocess.check_call([sys.executable, 'app/tool/export_voice.py', piper / 'en_US-ljspeech-medium.onnx',
                       piper / 'en_US-ljspeech-medium.onnx.json', assets / 'voices/ljspeech/voice.bin'])
for name in ['languages/Czech', 'voices/radek']:
    shutil.copytree(source / 'data' / name, assets / name,
                    ignore=shutil.ignore_patterns('.git', '16000', 'CMakeLists.txt', 'SConscript'),
                    dirs_exist_ok=True)
files = {str(path.relative_to(assets)): hashlib.sha256(path.read_bytes()).hexdigest()
         for path in sorted(assets.rglob('*'))
         if path.is_file() and path.name not in ('manifest.json', 'checksum.txt')}
(assets / 'manifest.json').write_text(json.dumps(sorted(files), indent=2) + '\n')
(assets / 'checksum.txt').write_text(hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest() + '\n')
