#include "speech.h"
int main(int argc, char** argv) {
  if (argc != 5) return 2;
  return ed_speech(argv[1], argv[2], argv[3], ed_speech_replace(), argv[4]) == 1 ? 0 : 1;
}
