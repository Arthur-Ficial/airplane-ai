#ifndef AIRPLANE_LLAMA_SHIM_H
#define AIRPLANE_LLAMA_SHIM_H

/* Single umbrella header for the CLlama SwiftPM target.
 * Pulls the public llama.cpp + ggml headers vendored at revision
 * ff5ef8278615a2462b79b50abdf3cc95cfb31c6f (release b8763). */

#include "llama.h"
#include "ggml.h"
#include "ggml-backend.h"
#include "ggml-cpu.h"

#endif
