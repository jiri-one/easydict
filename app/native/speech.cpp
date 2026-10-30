#include "speech.h"
#include "RHVoice.h"
#include "vendor/miniaudio.h"
#include <atomic>
#include <chrono>
#include <cstring>
#include <fstream>
#include <mutex>
#include <thread>
#include <vector>
#include <algorithm>
#ifndef _WIN32
#include <locale.h>
#ifdef __APPLE__
#include <xlocale.h>
#endif
#endif

#ifdef _WIN32
struct ClassicLocale {};
#else
// hts_engine reads voice parameters with atof, and GTK applies the user's
// LC_NUMERIC: with a decimal comma the voice is garbled without any error.
struct ClassicLocale {
  locale_t classic = newlocale(LC_ALL_MASK, "C", nullptr);
  locale_t previous = uselocale(classic);
  ~ClassicLocale() {
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
  size_t position = 0;
  std::atomic<bool> finished{false};
};
static int rate(int value, void* user) {
  static_cast<Audio*>(user)->rate = value;
  return 1;
}
static int collect(const short* samples, unsigned count, void* user) {
  auto& audio = *static_cast<Audio*>(user);
  if (current.load() != audio.request || audio.samples.size() + count > 24000 * 60) return 0;
  audio.samples.insert(audio.samples.end(), samples, samples + count);
  return 1;
}
static void playback(ma_device* device, void* output, const void*, ma_uint32 frames) {
  auto& audio = *static_cast<Audio*>(device->pUserData);
  auto* out = static_cast<short*>(output);
  if (current.load() != audio.request) { audio.finished = true; return; }
  const auto count = std::min<size_t>(frames, audio.samples.size() - audio.position);
  std::copy_n(audio.samples.data() + audio.position, count, out);
  audio.position += count;
  if (audio.position == audio.samples.size()) audio.finished = true;
}
static void little(std::ofstream& out, uint32_t n, int bytes) {
  for (int i = 0; i < bytes; ++i) out.put(static_cast<char>(n >> (i * 8)));
}
uint64_t ed_speech_replace() { return ++current; }
static const char* voice_for(const char* language) {
  if (!std::strcmp(language, "cze")) return "Radek";
  if (!std::strcmp(language, "eng")) return "Slt";
  return nullptr;
}
int ed_speech(const char* data, const char* language, const char* text, uint64_t request, const char* wav) {
  try {
    [[maybe_unused]] ClassicLocale locale;
    std::lock_guard<std::mutex> lock(synthesis);
    if (current.load() != request) return 0;
    const char* voice = voice_for(language);
    if (!voice || !*text || std::strlen(text) > 1200) return -1;
    // Kept, because loading the language takes most of the time of a short word.
    static RHVoice_tts_engine engine = nullptr;
    if (!engine) {
      RHVoice_init_params init{};
      init.data_path = data;
      init.config_path = data;
      init.callbacks.set_sample_rate = rate;
      init.callbacks.play_speech = collect;
      engine = RHVoice_new_tts_engine(&init);
      if (!engine) return -1;
    }
    Audio audio{request};
    RHVoice_synth_params params{};
    params.voice_profile = voice;
    params.relative_rate = params.relative_pitch = params.relative_volume = 1;
    auto message = RHVoice_new_message(engine, text, std::strlen(text), RHVoice_message_text, &params, &audio);
    int ok = message ? RHVoice_speak(message) : 0;
    if (message) RHVoice_delete_message(message);
    if (current.load() != request) return 0;
    if (!ok || audio.samples.empty() || audio.rate <= 0) return -1;
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
    if (ma_device_start(&device) != MA_SUCCESS) { ma_device_uninit(&device); return -1; }
    while (!audio.finished && current.load() == request) std::this_thread::sleep_for(std::chrono::milliseconds(10));
    // Let the final device buffer reach the speakers.
    if (current.load() == request) std::this_thread::sleep_for(std::chrono::milliseconds(100));
    ma_device_uninit(&device);
    return 1;
  } catch (...) { return -1; }
}
