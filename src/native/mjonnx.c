/* mjonnx.c — minimal ONNX Runtime shim for mj's local matting (Tier 2, IS-Net).
 *
 * The ONNX Runtime C API is reached through a big struct of function pointers (OrtApi), which is
 * miserable to bind from Crystal directly. So this shim does all the ORT calls in C and exposes ONE
 * flat function, mjonnx_matte(), that Crystal links.
 *
 * libonnxruntime.so is loaded at RUNTIME via dlopen (only the single symbol OrtGetApiBase is pulled;
 * everything else is function-pointers off the struct). That keeps onnxruntime an OPTIONAL dependency:
 * mj links only -ldl, and just `mj matte --isnet` needs the library present. If it's missing we return
 * a friendly error instead of the whole binary failing to load.
 *
 * Build: cc -O2 -fPIC -c mjonnx.c -o mjonnx.o -I<onnxruntime include dir>   (linked with -ldl)
 */
#include <dlfcn.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "onnxruntime_c_api.h"

static const OrtApi *g_ort = NULL;
static void *g_lib = NULL;

/* dlopen libonnxruntime and fetch the OrtApi. 0 on success. */
static int ensure_ort(char *err, int errlen) {
  if (g_ort) return 0;
  g_lib = dlopen("libonnxruntime.so", RTLD_LAZY | RTLD_LOCAL);
  if (!g_lib) g_lib = dlopen("libonnxruntime.so.1", RTLD_LAZY | RTLD_LOCAL);
  if (!g_lib) {
    snprintf(err, errlen, "cannot load libonnxruntime.so (install onnxruntime-cpu): %s", dlerror());
    return 1;
  }
  const OrtApiBase *(*get_base)(void) =
      (const OrtApiBase *(*)(void))dlsym(g_lib, "OrtGetApiBase");
  if (!get_base) { snprintf(err, errlen, "OrtGetApiBase missing from libonnxruntime"); return 1; }
  const OrtApiBase *base = get_base();
  g_ort = base->GetApi(ORT_API_VERSION);
  if (!g_ort) { snprintf(err, errlen, "ORT GetApi returned NULL (API version mismatch)"); return 1; }
  return 0;
}

#define ORT_CHECK(call)                                                    \
  do {                                                                     \
    OrtStatus *_st = (call);                                              \
    if (_st) {                                                             \
      snprintf(err, errlen, "%s", g_ort->GetErrorMessage(_st));           \
      g_ort->ReleaseStatus(_st);                                          \
      goto cleanup;                                                       \
    }                                                                      \
  } while (0)

/* Run the model at model_path on a single NCHW float input [1,3,in_h,in_w]; write the single-channel
 * mask [out_h*out_w] into mask_out (capacity mask_cap floats). *out_h/*out_w receive the mask dims
 * (last two dims of the output). Returns 0 on success, nonzero on error (message in err). */
int mjonnx_matte(const char *model_path,
                 const float *input, int64_t in_h, int64_t in_w,
                 float *mask_out, int64_t mask_cap,
                 int64_t *out_h, int64_t *out_w,
                 char *err, int errlen) {
  int rc = 1;
  if (ensure_ort(err, errlen)) return 1;

  OrtEnv *env = NULL;
  OrtSessionOptions *opts = NULL;
  OrtSession *session = NULL;
  OrtMemoryInfo *mem = NULL;
  OrtValue *in_val = NULL, *out_val = NULL;
  OrtAllocator *alloc = NULL;
  OrtTensorTypeAndShapeInfo *tsi = NULL;
  char *in_name = NULL, *out_name = NULL;

  ORT_CHECK(g_ort->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "mjonnx", &env));
  ORT_CHECK(g_ort->CreateSessionOptions(&opts));
  ORT_CHECK(g_ort->CreateSession(env, model_path, opts, &session));
  ORT_CHECK(g_ort->GetAllocatorWithDefaultOptions(&alloc));
  ORT_CHECK(g_ort->SessionGetInputName(session, 0, alloc, &in_name));
  ORT_CHECK(g_ort->SessionGetOutputName(session, 0, alloc, &out_name));

  ORT_CHECK(g_ort->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &mem));
  int64_t shape[4] = {1, 3, in_h, in_w};
  size_t in_bytes = (size_t)(3 * in_h * in_w) * sizeof(float);
  ORT_CHECK(g_ort->CreateTensorWithDataAsOrtValue(
      mem, (void *)input, in_bytes, shape, 4,
      ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &in_val));

  {
    const char *in_names[1] = {in_name};
    const char *out_names[1] = {out_name};
    ORT_CHECK(g_ort->Run(session, NULL, in_names,
                         (const OrtValue *const *)&in_val, 1,
                         out_names, 1, &out_val));
  }

  /* mask dims = last two dims of the output tensor */
  ORT_CHECK(g_ort->GetTensorTypeAndShape(out_val, &tsi));
  {
    size_t ndim = 0;
    ORT_CHECK(g_ort->GetDimensionsCount(tsi, &ndim));
    int64_t dims[8] = {0};
    if (ndim > 8) ndim = 8;
    ORT_CHECK(g_ort->GetDimensions(tsi, dims, ndim));
    int64_t oh = ndim >= 2 ? dims[ndim - 2] : 0;
    int64_t ow = ndim >= 1 ? dims[ndim - 1] : 0;
    int64_t n = oh * ow;
    if (n <= 0 || n > mask_cap) {
      snprintf(err, errlen, "unexpected output size %lldx%lld (cap %lld)",
               (long long)oh, (long long)ow, (long long)mask_cap);
      goto cleanup;
    }
    float *od = NULL;
    ORT_CHECK(g_ort->GetTensorMutableData(out_val, (void **)&od));
    memcpy(mask_out, od, (size_t)n * sizeof(float));
    *out_h = oh;
    *out_w = ow;
  }
  rc = 0;

cleanup:
  if (tsi) g_ort->ReleaseTensorTypeAndShapeInfo(tsi);
  if (in_name && alloc) alloc->Free(alloc, in_name);
  if (out_name && alloc) alloc->Free(alloc, out_name);
  if (out_val) g_ort->ReleaseValue(out_val);
  if (in_val) g_ort->ReleaseValue(in_val);
  if (mem) g_ort->ReleaseMemoryInfo(mem);
  if (session) g_ort->ReleaseSession(session);
  if (opts) g_ort->ReleaseSessionOptions(opts);
  if (env) g_ort->ReleaseEnv(env);
  return rc;
}
