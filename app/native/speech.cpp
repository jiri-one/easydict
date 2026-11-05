#include "speech.h"
#include "RHVoice.h"
#include "espeak-ng/speak_lib.h"
#include "utf8.h"
#include "vendor/miniaudio.h"
#include "vits.h"
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <algorithm>
#include <locale.h>
#ifdef __APPLE__
#include <xlocale.h>
#endif
// Last, because it defines a macro named L.
#include "vendor/espeak-ng/src/libespeak-ng/translate.h"

#ifdef _WIN32
// espeak opens its data with fopen, which takes UTF-8 only under a UTF-8
// locale, and the path can hold the user's name.
struct SpeechLocale {
  int previous = _configthreadlocale(_ENABLE_PER_THREAD_LOCALE);
  SpeechLocale() { setlocale(LC_CTYPE, ".UTF8"); }
  ~SpeechLocale() {
    setlocale(LC_CTYPE, "C");
    _configthreadlocale(previous);
  }
};
#else
// hts_engine reads voice parameters with atof, and GTK applies the user's
// LC_NUMERIC: with a decimal comma the voice is garbled without any error.
struct SpeechLocale {
  locale_t classic = newlocale(LC_ALL_MASK, "C", nullptr);
  locale_t previous = uselocale(classic);
  ~SpeechLocale() {
    uselocale(previous);
    freelocale(classic);
  }
};
#endif

static std::atomic<uint64_t> current{0};
static std::mutex synthesis;
struct Audio {
  uint64_t request;
  int rate = 0;
  std::vector<short> samples;
  std::atomic<size_t> position{0};
};
static int rate(int value, void* user) {
  static_cast<Audio*>(user)->rate = value;
  return 1;
}
static int collect(const short* samples, unsigned count, void* user) {
  auto& audio = *static_cast<Audio*>(user);
  if (current.load() != audio.request || audio.samples.size() + count > size_t(audio.rate) * 60) return 0;
  audio.samples.insert(audio.samples.end(), samples, samples + count);
  return 1;
}
static void playback(ma_device* device, void* output, const void*, ma_uint32 frames) {
  auto& audio = *static_cast<Audio*>(device->pUserData);
  const size_t position = audio.position;
  const auto count = std::min<size_t>(frames, audio.samples.size() - position);
  std::copy_n(audio.samples.data() + position, count, static_cast<short*>(output));
  audio.position = position + count;
}
static void little(std::ofstream& out, uint32_t n, int bytes) {
  for (int i = 0; i < bytes; ++i) out.put(static_cast<char>(n >> (i * 8)));
}
uint64_t ed_speech_replace() { return ++current; }
static bool speak_rhvoice(const char* data, const char* voice, const char* text, Audio& audio) {
  // Kept, because loading the language takes most of the time of a short word.
  static RHVoice_tts_engine engine = nullptr;
  if (!engine) {
    RHVoice_init_params init{};
    init.data_path = data;
    init.config_path = data;
    init.callbacks.set_sample_rate = rate;
    init.callbacks.play_speech = collect;
    engine = RHVoice_new_tts_engine(&init);
    if (!engine) return false;
  }
  RHVoice_synth_params params{};
  params.voice_profile = voice;
  params.relative_rate = params.relative_pitch = params.relative_volume = 1;
  auto message = RHVoice_new_message(engine, text, std::strlen(text), RHVoice_message_text, &params, &audio);
  int ok = message ? RHVoice_speak(message) : 0;
  if (message) RHVoice_delete_message(message);
  return ok;
}
// Piper's voices were trained on the marks.
static char clause_mark(int terminator) {
  switch (terminator & 0xFFFFF) {
    case CLAUSE_PERIOD: return '.';
    case CLAUSE_QUESTION: return '?';
    case CLAUSE_EXCLAMATION: return '!';
    case CLAUSE_COMMA: return ',';
    case CLAUSE_COLON: return ':';
    case CLAUSE_SEMICOLON: return ';';
    default: return 0;
  }
}
static bool speak_piper(const char* data, const char* name, const char* espeak_voice, const char* text, Audio& audio) {
  static bool ready = false;
  if (!ready && espeak_Initialize(AUDIO_OUTPUT_SYNCHRONOUS, 0, data, espeakINITIALIZE_DONT_EXIT) <= 0) return false;
  ready = true;
  if (espeak_SetVoiceByName(espeak_voice) != EE_OK) return false;
  // Not kept: reading it takes less than a word's silence, and it would hold 60 MB between words.
  const Vits voice(std::string(data) + "/voices/" + name + "/voice.bin");
  audio.rate = voice.sample_rate();
  const auto stopped = [&] { return current.load() != audio.request; };
  std::u32string phonemes;
  // Sentence by sentence, or a long text would hold its whole waveform at every layer.
  const auto render = [&] {
    const std::vector<float> wave = voice.synthesize(phonemes, stopped);
    phonemes.clear();
    std::vector<short> pcm(wave.size());
    ma_pcm_f32_to_s16(pcm.data(), wave.data(), wave.size(), ma_dither_mode_none);
    return collect(pcm.data(), unsigned(pcm.size()), &audio) != 0;
  };
  const void* cursor = text;
  while (cursor && !stopped()) {
    int terminator = 0;
    const char* clause = espeak_TextToPhonemesWithTerminator(&cursor, espeakCHARS_UTF8, espeakPHONEMES_IPA, &terminator);
    if (!clause) return false;
    const char* const stop = clause + std::strlen(clause);
    bool flag = false;  // (en) marks a language switch.
    while (clause != stop) {
      const char32_t symbol = utf8::next(clause, stop);
      if (symbol == '(' || symbol == ')') flag = symbol == '(';
      else if (!flag) phonemes += symbol;
    }
    const bool sentence = terminator & CLAUSE_TYPE_SENTENCE;
    if (const char mark = clause_mark(terminator)) {
      phonemes += char32_t(mark);
      if (!sentence) phonemes += U' ';
    }
    if (sentence && !render()) return false;
  }
  return render();
}
// Both voices stay near a third of full scale, which a phone's speaker leaves too quiet.
static void normalize(std::vector<short>& samples) {
  int peak = 1;
  for (const short sample: samples) peak = std::max(peak, std::abs(int(sample)));
  const float gain = 0.9f * 32767 / peak;
  for (short& sample: samples) sample = short(sample * gain);
}
int ed_speech(const char* data, const char* language, const char* text, uint64_t request, const char* wav) {
  try {
    [[maybe_unused]] SpeechLocale locale;
    std::lock_guard<std::mutex> lock(synthesis);
    if (current.load() != request) return 0;
    const bool czech = !std::strcmp(language, "cze"), english = !std::strcmp(language, "eng");
    if ((!czech && !english) || !*text || std::strlen(text) > 1200) return -1;
    Audio audio{request};
    // eSpeak's voice by its file: finding one by name lists a folder with FindFirstFileA, which cannot take UTF-8.
    const bool ok = czech ? speak_rhvoice(data, "Radek", text, audio) : speak_piper(data, "ljspeech", "gmw/en", text, audio);
    if (current.load() != request) return 0;
    if (!ok || audio.samples.empty() || audio.rate <= 0) return -1;
    normalize(audio.samples);
    if (wav) {
      std::ofstream out(wav, std::ios::binary);
      const auto bytes = static_cast<uint32_t>(audio.samples.size() * 2);
      out.write("RIFF", 4); little(out, bytes + 36, 4); out.write("WAVEfmt ", 8);
      little(out, 16, 4); little(out, 1, 2); little(out, 1, 2); little(out, audio.rate, 4);
      little(out, audio.rate * 2, 4); little(out, 2, 2); little(out, 16, 2);
      out.write("data", 4); little(out, bytes, 4);
      for (short sample: audio.samples) little(out, static_cast<uint16_t>(sample), 2);
      return out.good() ? 1 : -1;
    }
    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.format = ma_format_s16;
    config.playback.channels = 1;
    config.sampleRate = audio.rate;
    config.dataCallback = playback;
    config.pUserData = &audio;
    ma_device device;
    if (ma_device_init(nullptr, &config, &device) != MA_SUCCESS) return -1;
    // Stopping drops what the device still holds, so that part must be silence.
    const ma_uint64 held = ma_uint64(device.playback.internalPeriodSizeInFrames) * device.playback.internalPeriods;
    audio.samples.resize(audio.samples.size() + size_t(held * audio.rate / device.playback.internalSampleRate) + 1);
    if (ma_device_start(&device) != MA_SUCCESS) { ma_device_uninit(&device); return -1; }
    while (audio.position < audio.samples.size() && current.load() == request)
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
    ma_device_uninit(&device);
    return 1;
  } catch (...) { return -1; }
}
