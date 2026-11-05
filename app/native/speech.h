#pragma once
#include <stdint.h>
#ifdef _WIN32
#define ED_API __declspec(dllexport)
#else
#define ED_API __attribute__((visibility("default")))
#endif
#ifdef __cplusplus
extern "C" {
#endif
ED_API uint64_t ed_speech_replace(void);
ED_API int ed_speech(const char* data, const char* language, const char* text, uint64_t request, const char* wav);
#ifdef __cplusplus
}
#endif
