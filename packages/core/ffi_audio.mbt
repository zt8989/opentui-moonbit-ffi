// 原生音频 ABI（audio-abi.zig 的 C 导出符号，不在 opentui.h 中）。
// 引擎按 Context 生命周期挂载：创建 → start（设备拉起）→ 流/声音播放。
// PCM 流格式为 f32 交错样本；设备错误经负数状态码返回，不抛异常。

///|
#borrow(context, options)
extern "C" fn createAudioEngine(context : Context, options : AudioCreateOptions) -> Int32 = "createAudioEngine"

///|
#borrow(context, options)
extern "C" fn audioStart(context : Context, options : AudioStartOptions) -> Int32 = "audioStart"

///|
extern "C" fn audioStop(context : Context) -> Int32 = "audioStop"

///|
#borrow(context, options, out_stream)
extern "C" fn audioCreateStream(
  context : Context,
  options : AudioStreamOptions,
  out_stream : FixedArray[UInt32],
) -> Int32 = "audioCreateStream"

///|
#borrow(context, data)
extern "C" fn audioWriteStream(
  context : Context,
  stream_id : UInt32,
  data : FixedArray[Byte],
  data_len : UInt32,
) -> Int32 = "audioWriteStream"

///|
extern "C" fn audioEndStream(context : Context, stream_id : UInt32) -> Int32 = "audioEndStream"

///|
extern "C" fn audioRestartStream(context : Context, stream_id : UInt32) -> Int32 = "audioRestartStream"

///|
extern "C" fn audioSetStreamVolume(context : Context, stream_id : UInt32, volume : Float) -> Int32 = "audioSetStreamVolume"

///|
extern "C" fn audioSetStreamPan(context : Context, stream_id : UInt32, pan : Float) -> Int32 = "audioSetStreamPan"

///|
#borrow(context, out_stats)
extern "C" fn audioGetStreamStats(
  context : Context,
  stream_id : UInt32,
  out_stats : AudioStreamStats,
) -> Int32 = "audioGetStreamStats"

///|
#borrow(context, data, out_sound)
extern "C" fn audioLoad(
  context : Context,
  data : FixedArray[Byte],
  data_len : UInt32,
  out_sound : FixedArray[UInt32],
) -> Int32 = "audioLoad"

///|
extern "C" fn audioUnload(context : Context, sound_id : UInt32) -> Int32 = "audioUnload"

///|
#borrow(context, options, out_voice)
extern "C" fn audioPlay(
  context : Context,
  sound_id : UInt32,
  options : AudioVoiceOptions,
  out_voice : FixedArray[UInt32],
) -> Int32 = "audioPlay"

///|
extern "C" fn audioStopVoice(context : Context, voice_id : UInt32) -> Int32 = "audioStopVoice"

///|
extern "C" fn audioSetMasterVolume(context : Context, volume : Float) -> Int32 = "audioSetMasterVolume"

///|
#borrow(context, out_stats)
extern "C" fn audioGetStats(context : Context, out_stats : AudioEngineStats) -> Int32 = "audioGetStats"

///|
#borrow(context, options)
extern "C" fn audioStartCapture(
  context : Context,
  options : AudioStartOptions,
  channels : UInt32,
  capacity_frames : UInt32,
) -> Int32 = "audioStartCapture"

///|
extern "C" fn audioStopCapture(context : Context) -> Int32 = "audioStopCapture"

///|
// Zig bool 返回走 shim 转成 u32。
extern "C" fn audio_is_capture_running_shim(context : Context) -> UInt32 = "audio_is_capture_running_shim"

///|
#borrow(context, out_samples, out_frames)
extern "C" fn audioReadCapture(
  context : Context,
  out_samples : FixedArray[Byte],
  out_sample_capacity : UInt32,
  frame_count : UInt32,
  out_frames : FixedArray[UInt32],
) -> Int32 = "audioReadCapture"

///|
#borrow(context, out_stats)
extern "C" fn audioGetCaptureStats(context : Context, out_stats : AudioCaptureStats) -> Int32 = "audioGetCaptureStats"
