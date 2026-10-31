#pragma once
#include <functional>
#include <map>
#include <memory>
#include <string>
#include <vector>

// A Piper medium voice. F-Droid and Flathub would have to build ONNX Runtime
// from source, a big job for the one small network the app needs from it.
class Vits {
public:
  explicit Vits(const std::string& path);
  ~Vits();
  int sample_rate() const { return sample_rate_; }
  // Empty when stopped() asked to give up. A voice skips symbols it was not trained on.
  std::vector<float> synthesize(const std::u32string& phonemes, const std::function<bool()>& stopped) const;

private:
  struct Network;
  std::unique_ptr<Network> network_;
  std::map<char32_t, int> phonemes_;
  int sample_rate_ = 0;
  float noise_scale_ = 0, length_scale_ = 0, noise_w_ = 0;
};
