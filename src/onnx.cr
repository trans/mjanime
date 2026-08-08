# Crystal binding to the mjonnx C shim (src/native/mjonnx.c). The shim dlopen's libonnxruntime at
# runtime, so we link only the shim object + libdl here — NOT -lonnxruntime. That keeps onnxruntime an
# optional dependency: mj builds and runs without it, and only `mj matte --isnet` requires it present.
#
# The shim object must be compiled first (`just build` — see the justfile). The path is resolved at
# compile time relative to this source file.
@[Link(ldflags: "#{__DIR__}/native/mjonnx.o -ldl")]
lib LibMjOnnx
  # int mjonnx_matte(model_path, input[1,3,h,w], in_h, in_w, mask_out, mask_cap, *out_h, *out_w, err, errlen)
  fun matte = mjonnx_matte(model_path : UInt8*, input : Float32*, in_h : Int64, in_w : Int64,
                           mask_out : Float32*, mask_cap : Int64,
                           out_h : Int64*, out_w : Int64*,
                           err : UInt8*, errlen : Int32) : Int32
end

module MJ
  # Thin wrapper over the ONNX Runtime shim for matting models (IS-Net / U2Net family).
  module Onnx
    # Run a matting model. `input` is an NCHW float tensor [1,3,h,w] (channels R,G,B). Returns the
    # single-channel mask as a float Slice plus its dims. Raises with the ORT error message on failure.
    def self.matte(model_path : String, input : Slice(Float32), h : Int32, w : Int32) : {Slice(Float32), Int32, Int32}
      cap = (h.to_i64 * w.to_i64)
      mask = Slice(Float32).new(cap.to_i)
      out_h = 0_i64
      out_w = 0_i64
      err = Bytes.new(512)
      rc = LibMjOnnx.matte(model_path.to_unsafe, input.to_unsafe, h.to_i64, w.to_i64,
                           mask.to_unsafe, cap, pointerof(out_h), pointerof(out_w),
                           err.to_unsafe, 512)
      unless rc == 0
        raise "onnx matte failed: #{String.new(err.to_unsafe)}"
      end
      {mask, out_h.to_i, out_w.to_i}
    end
  end
end
