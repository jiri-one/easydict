#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_NODE_GRAPH
#define MA_NO_ENGINE
// Without a sound device playback must fail, not succeed in a silent backend.
#define MA_NO_NULL
#include "vendor/miniaudio.h"
