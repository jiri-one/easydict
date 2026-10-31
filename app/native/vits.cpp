#include "vits.h"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <stdexcept>
#include <system_error>
#include <thread>

namespace {

constexpr int symbols = 256, hidden = 192, half = hidden / 2, heads = 2, head_size = hidden / heads;
constexpr int attention_layers = 6, relative_window = 4, relative_size = 2 * relative_window + 1;
constexpr int spline_bins = 10, spline_parameters = 3 * spline_bins - 1;
constexpr float spline_bound = 5, spline_minimum = 1e-3f;
constexpr int block = 1024;

// Without a pool: a few spawned threads per layer cost little next to the
// layer, and whole convolutions below the threshold stay on the caller.
template <class Body>
void parallel(int count, size_t work, const Body& body) {
  static const int threads = std::clamp(int(std::thread::hardware_concurrency()), 1, 4);
  if (threads == 1 || work < 2000000) {
    for (int i = 0; i < count; ++i) body(i);
    return;
  }
  // A shared counter, because the phone's slow cores would hold up an even split.
  std::atomic<int> next{0};
  const auto run = [&] {
    for (int i; (i = next++) < count;) body(i);
  };
  std::vector<std::thread> workers;
  try {
    for (int i = 1; i < threads; ++i) workers.emplace_back(run);
  } catch (const std::system_error&) {
    // The workers that did start and this thread finish the job.
  }
  run();
  for (auto& worker: workers) worker.join();
}

// [channels, frames]; the convolutions want each channel contiguous.
struct Tensor {
  int frames;
  std::vector<float> data;
  Tensor(int channels, int frames): frames(frames), data(size_t(channels) * frames) {}
  float* operator[](int channel) { return data.data() + size_t(channel) * frames; }
  const float* operator[](int channel) const { return data.data() + size_t(channel) * frames; }
};

class Weights {
public:
  explicit Weights(std::ifstream& file): file(file) {}
  void read(void* target, size_t size) {
    file.read(static_cast<char*>(target), std::streamsize(size));
    if (!file) throw std::runtime_error("voice too short");
  }
  std::vector<float> next(size_t count) {
    struct {
      uint32_t wide;
      float low, step;
    } header;
    read(&header, sizeof header);
    std::vector<float> values(count);
    if (header.wide) {
      expand<uint16_t>(values, header.low, header.step);
    } else {
      expand<uint8_t>(values, header.low, header.step);
    }
    return values;
  }

private:
  template <class Level>
  void expand(std::vector<float>& values, float low, float step) {
    std::vector<Level> levels(values.size());
    read(levels.data(), levels.size() * sizeof(Level));
    for (size_t i = 0; i < values.size(); ++i) values[i] = low + step * levels[i];
  }
  std::ifstream& file;
};

template <class Function>
void each(Tensor& x, const Function& function) {
  for (float& value: x.data) value = function(value);
}

void add(Tensor& x, const Tensor& y) {
  for (size_t i = 0; i < x.data.size(); ++i) x.data[i] += y.data[i];
}

Tensor slice(const Tensor& x, int first, int channels) {
  Tensor y(channels, x.frames);
  std::copy_n(x[first], y.data.size(), y.data.data());
  return y;
}

void leaky(Tensor& x, float slope) {
  for (float& value: x.data) value = value < 0 ? value * slope : value;
}

void gelu(Tensor& x) {
  each(x, [](float value) { return 0.5f * value * (1 + std::erf(value * 0.70710678f)); });
}

void softmax(float* values, int count) {
  const float top = *std::max_element(values, values + count);
  float total = 0;
  for (int i = 0; i < count; ++i) total += values[i] = std::exp(values[i] - top);
  for (int i = 0; i < count; ++i) values[i] /= total;
}

// Four sources at a time: on long tensors the passes over the target cost more
// than the multiplications.
template <class Weight>
void mix(float* __restrict target, const Tensor& x, int first, int sources, int offset, int count, const Weight& weight) {
  int source = 0;
  for (; source + 4 <= sources; source += 4) {
    const float* __restrict a = x[first + source] + offset;
    const float* __restrict b = x[first + source + 1] + offset;
    const float* __restrict c = x[first + source + 2] + offset;
    const float* __restrict d = x[first + source + 3] + offset;
    const float wa = weight(source), wb = weight(source + 1), wc = weight(source + 2), wd = weight(source + 3);
    for (int i = 0; i < count; ++i) target[i] += wa * a[i] + wb * b[i] + wc * c[i] + wd * d[i];
  }
  for (; source < sources; ++source) {
    const float* __restrict a = x[first + source] + offset;
    const float wa = weight(source);
    for (int i = 0; i < count; ++i) target[i] += wa * a[i];
  }
}

// Always padded to keep the length, as is every convolution of this network.
struct Conv {
  int sources, outputs, kernel, dilation;
  bool separable;
  std::vector<float> weight, bias;

  Conv(Weights& weights, int inputs, int outputs, int kernel = 1, int dilation = 1, bool separable = false, bool biased = true)
      : sources(separable ? 1 : inputs), outputs(outputs), kernel(kernel), dilation(dilation), separable(separable),
        weight(weights.next(size_t(outputs) * sources * kernel)) {
    if (biased) bias = weights.next(outputs);
  }

  // Onto y, because a residual layer would pay for a zeroed tensor and one more pass.
  void add_to(Tensor& y, const Tensor& x) const {
    const int frames = x.frames;
    parallel(outputs, size_t(outputs) * sources * kernel * frames, [&](int output) {
      float* target = y[output];
      const float* taps = &weight[size_t(output) * sources * kernel];
      // In blocks, or a long sentence would miss the cache on every pass.
      for (int begin = 0; begin < frames; begin += block) {
        const int end = std::min(begin + block, frames);
        for (int k = 0; k < kernel; ++k) {
          const int shift = (k - kernel / 2) * dilation;
          const int first = std::max(begin, -shift), last = std::min(end, frames - shift);
          if (first >= last) continue;
          mix(target + first, x, separable ? output : 0, sources, first + shift, last - first,
              [&](int source) { return taps[size_t(source) * kernel + k]; });
        }
      }
      if (!bias.empty())
        for (int t = 0; t < frames; ++t) target[t] += bias[output];
    });
  }

  Tensor operator()(const Tensor& x) const {
    Tensor y(outputs, x.frames);
    add_to(y, x);
    return y;
  }
};

struct Upsample {
  int inputs, outputs, kernel, stride;
  std::vector<float> weight, bias;

  Upsample(Weights& weights, int inputs, int outputs, int kernel, int stride)
      : inputs(inputs), outputs(outputs), kernel(kernel), stride(stride),
        weight(weights.next(size_t(inputs) * outputs * kernel)), bias(weights.next(outputs)) {}

  Tensor operator()(const Tensor& x) const {
    Tensor y(outputs, x.frames * stride);
    const int padding = (kernel - stride) / 2, length = y.frames;
    parallel(outputs, size_t(inputs) * outputs * kernel * x.frames, [&](int output) {
      float* target = y[output];
      std::vector<float> mixed(x.frames);
      for (int k = 0; k < kernel; ++k) {
        std::fill(mixed.begin(), mixed.end(), 0.f);
        mix(mixed.data(), x, 0, inputs, 0, x.frames,
            [&](int source) { return weight[(size_t(source) * outputs + output) * kernel + k]; });
        for (int t = 0; t < x.frames; ++t) {
          const int position = t * stride + k - padding;
          if (position >= 0 && position < length) target[position] += mixed[t];
        }
      }
      for (int t = 0; t < length; ++t) target[t] += bias[output];
    });
    return y;
  }
};

struct LayerNorm {
  std::vector<float> gamma, beta;

  explicit LayerNorm(Weights& weights): gamma(weights.next(hidden)), beta(weights.next(hidden)) {}

  void operator()(Tensor& x) const {
    for (int t = 0; t < x.frames; ++t) {
      float mean = 0, variance = 0;
      for (int c = 0; c < hidden; ++c) mean += x[c][t];
      mean /= hidden;
      for (int c = 0; c < hidden; ++c) {
        const float difference = x[c][t] - mean;
        variance += difference * difference;
      }
      const float scale = 1 / std::sqrt(variance / hidden + 1e-5f);
      for (int c = 0; c < hidden; ++c) x[c][t] = (x[c][t] - mean) * scale * gamma[c] + beta[c];
    }
  }
};

struct Attention {
  Conv query, key, value, output;
  std::vector<float> relative_key, relative_value;

  explicit Attention(Weights& weights)
      : query(weights, hidden, hidden), key(weights, hidden, hidden), value(weights, hidden, hidden),
        output(weights, hidden, hidden), relative_key(weights.next(relative_size * head_size)),
        relative_value(weights.next(relative_size * head_size)) {}

  Tensor operator()(const Tensor& x) const {
    const int frames = x.frames;
    Tensor y(hidden, frames);
    const auto by_frame = [&](const Tensor& tensor, int first) {
      std::vector<float> table(size_t(frames) * head_size);
      for (int d = 0; d < head_size; ++d)
        for (int t = 0; t < frames; ++t) table[size_t(t) * head_size + d] = tensor[first + d][t];
      return table;
    };
    const auto dot = [](const float* a, const float* b) {
      float sum = 0;
      for (int d = 0; d < head_size; ++d) sum += a[d] * b[d];
      return sum;
    };
    const Tensor q = query(x), k = key(x), v = value(x);
    std::vector<float> scores(frames), mixed(head_size);
    for (int head = 0; head < heads; ++head) {
      const int first = head * head_size;
      const std::vector<float> queries = by_frame(q, first), keys = by_frame(k, first), values = by_frame(v, first);
      for (int i = 0; i < frames; ++i) {
        const float* row = &queries[size_t(i) * head_size];
        const auto each_near = [&](const auto& body) {
          for (int r = 0; r < relative_size; ++r) {
            const int j = i + r - relative_window;
            if (j >= 0 && j < frames) body(r, j);
          }
        };
        for (int j = 0; j < frames; ++j) scores[j] = dot(row, &keys[size_t(j) * head_size]);
        each_near([&](int r, int j) { scores[j] += dot(row, &relative_key[size_t(r) * head_size]); });
        for (float& score: scores) score /= std::sqrt(float(head_size));
        softmax(scores.data(), frames);
        std::fill(mixed.begin(), mixed.end(), 0.f);
        const auto blend = [&](const float* source, float weight) {
          for (int d = 0; d < head_size; ++d) mixed[d] += weight * source[d];
        };
        for (int j = 0; j < frames; ++j) blend(&values[size_t(j) * head_size], scores[j]);
        each_near([&](int r, int j) { blend(&relative_value[size_t(r) * head_size], scores[j]); });
        for (int d = 0; d < head_size; ++d) y[first + d][i] = mixed[d];
      }
    }
    return output(y);
  }
};

struct EncoderLayer {
  Attention attention;
  LayerNorm norm1;
  Conv expand, contract;
  LayerNorm norm2;

  explicit EncoderLayer(Weights& weights)
      : attention(weights), norm1(weights), expand(weights, hidden, 4 * hidden, 3),
        contract(weights, 4 * hidden, hidden, 3), norm2(weights) {}

  void operator()(Tensor& x) const {
    add(x, attention(x));
    norm1(x);
    Tensor y = expand(x);
    each(y, [](float value) { return std::max(value, 0.f); });
    add(x, contract(y));
    norm2(x);
  }
};

struct Separable {
  struct Layer {
    Conv depthwise;
    LayerNorm norm1;
    Conv linear;
    LayerNorm norm2;
    Layer(Weights& weights, int dilation)
        : depthwise(weights, hidden, hidden, 3, dilation, true), norm1(weights), linear(weights, hidden, hidden),
          norm2(weights) {}
  };
  std::vector<Layer> layers;

  explicit Separable(Weights& weights) {
    for (int dilation: {1, 3, 9}) layers.emplace_back(weights, dilation);
  }

  void operator()(Tensor& x) const {
    for (const Layer& layer: layers) {
      Tensor y = layer.depthwise(x);
      layer.norm1(y);
      gelu(y);
      y = layer.linear(y);
      layer.norm2(y);
      gelu(y);
      add(x, y);
    }
  }
};

float softplus(float value) { return std::log1p(std::exp(value)); }

float invert_spline(float input, const float* parameters) {
  if (std::abs(input) > spline_bound) return input;
  const auto knots = [](const float* raw, float* cumulative, float* sizes) {
    float probabilities[spline_bins];
    for (int i = 0; i < spline_bins; ++i) probabilities[i] = raw[i] / std::sqrt(float(hidden));
    softmax(probabilities, spline_bins);
    float sum = 0;
    cumulative[0] = -spline_bound;
    for (int i = 0; i < spline_bins; ++i) {
      sum += spline_minimum + (1 - spline_minimum * spline_bins) * probabilities[i];
      cumulative[i + 1] = 2 * spline_bound * sum - spline_bound;
    }
    cumulative[spline_bins] = spline_bound;
    for (int i = 0; i < spline_bins; ++i) sizes[i] = cumulative[i + 1] - cumulative[i];
  };
  float cumulative_widths[spline_bins + 1], widths[spline_bins];
  float cumulative_heights[spline_bins + 1], heights[spline_bins];
  knots(parameters, cumulative_widths, widths);
  knots(parameters + spline_bins, cumulative_heights, heights);
  const auto derivative = [&](int i) {
    return i == 0 || i == spline_bins ? 1.f : spline_minimum + softplus(parameters[2 * spline_bins + i - 1]);
  };
  int bin = 0;
  while (bin + 1 < spline_bins && input >= cumulative_heights[bin + 1]) ++bin;
  const float slope = heights[bin] / widths[bin], first = derivative(bin), last = derivative(bin + 1);
  const float offset = input - cumulative_heights[bin], bend = first + last - 2 * slope;
  const float a = offset * bend + heights[bin] * (slope - first);
  const float b = heights[bin] * first - offset * bend;
  const float c = -slope * offset;
  const float root = 2 * c / (-b - std::sqrt(b * b - 4 * a * c));
  return root * widths[bin] + cumulative_widths[bin];
}

struct DurationFlow {
  Conv pre;
  Separable separable;
  Conv projection;

  explicit DurationFlow(Weights& weights)
      : pre(weights, 1, hidden), separable(weights), projection(weights, hidden, spline_parameters) {}

  void invert(Tensor& z, const Tensor& condition) const {
    Tensor h = pre(slice(z, 0, 1));
    add(h, condition);
    separable(h);
    const Tensor s = projection(h);
    float parameters[spline_parameters];
    for (int t = 0; t < z.frames; ++t) {
      for (int p = 0; p < spline_parameters; ++p) parameters[p] = s[p][t];
      z[1][t] = invert_spline(z[1][t], parameters);
    }
  }
};

struct WaveNet {
  std::vector<Conv> gates, outputs;

  explicit WaveNet(Weights& weights) {
    for (int layer = 0; layer < 4; ++layer) {
      gates.emplace_back(weights, hidden, 2 * hidden, 5);
      outputs.emplace_back(weights, hidden, layer < 3 ? 2 * hidden : hidden);
    }
  }

  Tensor operator()(Tensor x) const {
    Tensor total(hidden, x.frames);
    for (size_t layer = 0; layer < gates.size(); ++layer) {
      const Tensor in = gates[layer](x);
      Tensor activation(hidden, x.frames);
      for (size_t i = 0; i < activation.data.size(); ++i) {
        const float gate = 1 / (1 + std::exp(-in.data[i + activation.data.size()]));
        activation.data[i] = std::tanh(in.data[i]) * gate;
      }
      const Tensor out = outputs[layer](activation);
      if (layer + 1 < gates.size()) {
        add(x, slice(out, 0, hidden));
        add(total, slice(out, hidden, hidden));
      } else {
        add(total, out);
      }
    }
    return total;
  }
};

struct Coupling {
  Conv pre;
  WaveNet network;
  Conv post;

  explicit Coupling(Weights& weights): pre(weights, half, hidden), network(weights), post(weights, hidden, half) {}

  void invert(Tensor& z) const {
    for (int c = 0; c < half; ++c) std::swap_ranges(z[c], z[c] + z.frames, z[hidden - 1 - c]);
    const Tensor m = post(network(pre(slice(z, 0, half))));
    for (size_t i = 0; i < m.data.size(); ++i) z.data[i + m.data.size()] -= m.data[i];
  }
};

struct ResidualBlock {
  std::vector<Conv> convolutions;

  ResidualBlock(Weights& weights, int channels, int kernel, int first, int second) {
    convolutions.emplace_back(weights, channels, channels, kernel, first);
    convolutions.emplace_back(weights, channels, channels, kernel, second);
  }

  Tensor operator()(Tensor x, Tensor& scratch) const {
    for (const Conv& convolution: convolutions) {
      scratch = x;
      leaky(scratch, 0.1f);
      convolution.add_to(x, scratch);
    }
    return x;
  }
};

struct Stage {
  Upsample upsample;
  std::vector<ResidualBlock> blocks;

  Stage(Weights& weights, int channels, int stride): upsample(weights, 2 * channels, channels, 2 * stride, stride) {
    blocks.emplace_back(weights, channels, 3, 1, 2);
    blocks.emplace_back(weights, channels, 5, 2, 6);
    blocks.emplace_back(weights, channels, 7, 3, 12);
  }

  Tensor operator()(Tensor x) const {
    leaky(x, 0.1f);
    x = upsample(x);
    // Shared, because these are the longest tensors, and a phone's page faults on new ones add up.
    Tensor scratch = x;
    Tensor sum = blocks[0](x, scratch);
    add(sum, blocks[1](x, scratch));
    add(sum, blocks[2](std::move(x), scratch));
    each(sum, [](float value) { return value / 3; });
    return sum;
  }
};

// xorshift64* and Box-Muller: the standard distributions differ between libraries.
class Noise {
public:
  float next() {
    const auto uniform = [this] {
      state ^= state >> 12;
      state ^= state << 25;
      state ^= state >> 27;
      return float((state * 0x2545F4914F6CDD1Dull >> 40) + 1) * (1.f / (1 << 24));
    };
    const float radius = std::sqrt(-2 * std::log(uniform()));
    return radius * std::cos(6.28318530f * uniform());
  }

private:
  uint64_t state = 0x9E3779B97F4A7C15ull;
};

}  // namespace

struct Vits::Network {
  std::vector<float> embedding;
  std::vector<EncoderLayer> encoder;
  Conv statistics;
  Conv duration_pre;
  Separable duration_separable;
  Conv duration_projection;
  std::vector<DurationFlow> duration_flows;
  std::vector<float> affine_mean, affine_scale;
  std::vector<Coupling> couplings;
  Conv decoder_pre;
  std::vector<Stage> stages;
  Conv decoder_post;

  explicit Network(Weights& weights)
      : embedding(weights.next(size_t(symbols) * hidden)),
        encoder(stack<EncoderLayer>(weights, attention_layers)),
        statistics(weights, hidden, 2 * hidden),
        duration_pre(weights, hidden, hidden),
        duration_separable(weights),
        duration_projection(weights, hidden, hidden),
        duration_flows(stack<DurationFlow>(weights, 3)),
        affine_mean(weights.next(2)),
        affine_scale(weights.next(2)),
        couplings(stack<Coupling>(weights, 4)),
        decoder_pre(weights, hidden, 256, 7),
        stages(make_stages(weights)),
        decoder_post(weights, 32, 1, 7, 1, false, false) {}

  template <class Layer>
  static std::vector<Layer> stack(Weights& weights, int count) {
    std::vector<Layer> layers;
    for (int i = 0; i < count; ++i) layers.emplace_back(weights);
    return layers;
  }

  static std::vector<Stage> make_stages(Weights& weights) {
    std::vector<Stage> stages;
    stages.emplace_back(weights, 128, 8);
    stages.emplace_back(weights, 64, 8);
    stages.emplace_back(weights, 32, 4);
    return stages;
  }
};

Vits::Vits(const std::string& path) {
  std::ifstream file(path, std::ios::binary);
  Weights weights(file);
  struct {
    char magic[4];
    int sample_rate;
    float noise_scale, length_scale, noise_w;
    int phonemes;
  } header;
  weights.read(&header, sizeof header);
  if (std::memcmp(header.magic, "EDV1", 4)) throw std::runtime_error("not a voice");
  sample_rate_ = header.sample_rate;
  noise_scale_ = header.noise_scale;
  length_scale_ = header.length_scale;
  noise_w_ = header.noise_w;
  for (int i = 0; i < header.phonemes; ++i) {
    int entry[2];
    weights.read(entry, sizeof entry);
    if (entry[1] < 0 || entry[1] >= symbols) throw std::runtime_error("not a voice");
    phonemes_[char32_t(entry[0])] = entry[1];
  }
  network_ = std::make_unique<Network>(weights);
  if (file.peek() != std::ifstream::traits_type::eof()) throw std::runtime_error("voice too long");
}

Vits::~Vits() = default;

std::vector<float> Vits::synthesize(const std::u32string& phonemes, const std::function<bool()>& stopped) const {
  const Network& n = *network_;
  const int pad = phonemes_.at(U'_');
  std::vector<int> ids{phonemes_.at(U'^'), pad};
  for (const char32_t phoneme: phonemes) {
    const auto id = phonemes_.find(phoneme);
    if (id == phonemes_.end()) continue;
    ids.push_back(id->second);
    ids.push_back(pad);
  }
  if (ids.size() == 2) return {};
  ids.push_back(phonemes_.at(U'$'));
  const int length = int(ids.size());
  Noise noise;

  Tensor x(hidden, length);
  const float embedding_scale = std::sqrt(float(hidden));
  for (int t = 0; t < length; ++t)
    for (int c = 0; c < hidden; ++c) x[c][t] = n.embedding[size_t(ids[t]) * hidden + c] * embedding_scale;
  for (const EncoderLayer& layer: n.encoder) layer(x);
  const Tensor statistics = n.statistics(x);
  if (stopped()) return {};

  Tensor condition = n.duration_pre(x);
  n.duration_separable(condition);
  condition = n.duration_projection(condition);
  Tensor z(2, length);
  for (float& value: z.data) value = noise.next() * noise_w_;
  const auto swap = [&] { std::swap_ranges(z[0], z[0] + length, z[1]); };
  swap();
  for (const DurationFlow& flow: n.duration_flows) {
    flow.invert(z, condition);
    swap();
  }
  std::vector<int> durations(length);
  int frames = 0;
  for (int t = 0; t < length; ++t) {
    const float log_duration = (z[0][t] - n.affine_mean[0]) * std::exp(n.affine_scale[0]);
    frames += durations[t] = int(std::ceil(std::exp(log_duration) * length_scale_));
  }
  frames = std::max(frames, 1);
  if (stopped()) return {};

  Tensor latent(hidden, frames);
  for (int c = 0; c < hidden; ++c) {
    const float* mean = statistics[c];
    const float* log_deviation = statistics[hidden + c];
    float* target = latent[c];
    for (int t = 0, f = 0; t < length; ++t) {
      const float deviation = std::exp(log_deviation[t]) * noise_scale_;
      for (int repeat = 0; repeat < durations[t]; ++repeat) target[f++] = mean[t] + noise.next() * deviation;
    }
  }
  for (const Coupling& coupling: n.couplings) coupling.invert(latent);
  if (stopped()) return {};

  Tensor signal = n.decoder_pre(latent);
  for (const Stage& stage: n.stages) {
    signal = stage(std::move(signal));
    if (stopped()) return {};
  }
  leaky(signal, 0.01f);
  Tensor audio = n.decoder_post(signal);
  each(audio, [](float value) { return std::tanh(value); });
  return std::move(audio.data);
}
