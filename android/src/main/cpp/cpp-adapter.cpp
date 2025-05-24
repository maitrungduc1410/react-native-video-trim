#include <jni.h>
#include "videotrimOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::videotrim::initialize(vm);
}
