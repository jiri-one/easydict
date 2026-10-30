import fcntl
import subprocess
from pathlib import Path
from unittest import skipUnless
from unittest.mock import patch

from django.conf import settings
from django.test import SimpleTestCase

from web import speech


class SpeechTests(SimpleTestCase):
    @patch('web.speech.synthesize', return_value=b'RIFFtest')
    def test_audio(self, synthesize):
        for language in ('cze', 'eng'):
            response = self.client.get('/api/speech', {'q': 'hello', 'lang': language})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response['Content-Type'], 'audio/wav')
            self.assertIn('max-age=86400', response['Cache-Control'])
            self.assertEqual(response.content, b'RIFFtest')
            synthesize.assert_called_with('hello', language)

    @patch('web.speech.synthesize')
    def test_invalid(self, synthesize):
        for text, language in [('', 'eng'), ('x' * 301, 'eng'), ('word', 'xxx'), ('\x00', 'cze')]:
            self.assertEqual(self.client.get('/api/speech', {'q': text, 'lang': language}).status_code, 400)
        self.assertEqual(self.client.post('/api/speech').status_code, 405)
        synthesize.assert_not_called()

    @patch('web.speech.subprocess.run', side_effect=subprocess.TimeoutExpired('speech', 10))
    def test_timeout(self, _):
        self.assertEqual(self.client.get('/api/speech', {'q': 'hello', 'lang': 'eng'}).status_code, 503)

    @patch('web.speech.subprocess.run')
    def test_one_renderer_across_workers(self, run):
        with open(speech.LOCK, 'a') as other_worker:
            fcntl.flock(other_worker, fcntl.LOCK_EX)
            self.assertEqual(self.client.get('/api/speech', {'q': 'hello', 'lang': 'eng'}).status_code, 503)
        run.assert_not_called()

    @patch('web.speech.synthesize', return_value=b'RIFFtest')
    def test_limit_is_in_characters(self, synthesize):
        text = 'ř' * 300
        self.assertEqual(self.client.get('/api/speech', {'q': text, 'lang': 'cze'}).status_code, 200)
        synthesize.assert_called_once_with(text, 'cze')

    @patch('web.speech.subprocess.run')
    def test_renderer_uses_bounded_argument_list(self, run):
        run.return_value.stdout = b'RIFFtest'
        text = 'hello; $(false)'
        self.assertEqual(speech.synthesize(text, 'eng'), b'RIFFtest')
        arguments = run.call_args.args[0]
        self.assertEqual(arguments[:4], [settings.SPEECH_EXECUTABLE, settings.SPEECH_DATA, 'eng', text])
        self.assertEqual(run.call_args.kwargs['timeout'], 10)
        self.assertTrue(run.call_args.kwargs['check'])
        self.assertNotIn('shell', run.call_args.kwargs)

    @skipUnless(Path(settings.SPEECH_EXECUTABLE).exists(), 'the renderer is not built')
    def test_real_renderer(self):
        self.assertEqual(speech.synthesize('hello', 'eng')[:4], b'RIFF')
