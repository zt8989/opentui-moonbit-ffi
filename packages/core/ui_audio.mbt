// 音频引擎封装（TS 兼容层：对应 @opentui/core 的 native audio 管线）。
// 状态码不抛异常：负值 = err_invalid(-1)/err_no_space(-2)/err_decode(-3)/
// err_not_found(-4)/err_device(-5)，由调用方按需处理（无音频设备的
// headless 环境返回 err_device）。

///|
/// 音频引擎句柄（挂载在 Context 上，全局单例）。
pub struct AudioEngine {
  context : Context
}

///|
/// 创建引擎（默认 48kHz 立体声播放）。
pub fn AudioEngine::create(
  renderer : Renderer,
  sample_rate~ : Int = 48000,
  playback_channels~ : Int = 2,
) -> AudioEngine raise {
  let options : AudioCreateOptions = {
    sample_rate: sample_rate.reinterpret_as_uint(),
    playback_channels: playback_channels.reinterpret_as_uint(),
  }
  let status = createAudioEngine(renderer.context, options)
  if status != 0 {
    raise Failure("createAudioEngine failed: \{status}")
  }
  { context: renderer.context }
}

///|
/// 拉起播放设备（默认周期配置）。
pub fn AudioEngine::start(self : AudioEngine) -> Unit raise {
  let options : AudioStartOptions = {
    period_size_in_frames: 0,
    period_size_in_milliseconds: 0,
    periods: 0,
    bools0_3: 0,
    bools4_7: 0,
    bools8_11: 0,
  }
  let status = audioStart(self.context, options)
  if status != 0 {
    raise Failure("audioStart failed: \{status}")
  }
}

///|
/// 停止引擎（释放设备）。
pub fn AudioEngine::stop(self : AudioEngine) -> Unit raise {
  let status = audioStop(self.context)
  if status != 0 {
    raise Failure("audioStop failed: \{status}")
  }
}

///|
/// 打开 PCM 写入流（f32 交错样本；capacity_ms 决定缓冲上限）。
/// 返回 stream id（0 失败）。
pub fn AudioEngine::create_pcm_stream(
  self : AudioEngine,
  capacity_ms~ : Int = 500,
  channels~ : Int = 2,
  sample_rate~ : Int = 48000,
  volume~ : Double = 1.0,
  pan~ : Double = 0.0,
) -> Int raise {
  let options : AudioStreamOptions = {
    capacity_ms: capacity_ms.reinterpret_as_uint(),
    startup_ms: 100,
    resume_ms: 50,
    volume: Float::from_double(volume),
    pan: Float::from_double(pan),
    group_id: 0,
    max_probe_bytes: 0,
    format: 3, // StreamFormat.pcm
    sample_rate: sample_rate.reinterpret_as_uint(),
    channels: channels.reinterpret_as_uint(),
  }
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = audioCreateStream(self.context, options, out)
  if status != 0 {
    raise Failure("audioCreateStream failed: \{status}")
  }
  out[0].reinterpret_as_int()
}

///|
/// 写入 f32 交错 PCM 样本（字节序为宿主端 little-endian f32）。
/// 返回实际接收字节数语义由原生决定（0 = 满未收）。
pub fn AudioEngine::write_pcm(
  self : AudioEngine,
  stream_id~ : Int,
  samples~ : FixedArray[Byte],
) -> Int raise {
  let status = audioWriteStream(
    self.context,
    stream_id.reinterpret_as_uint(),
    samples,
    samples.length().reinterpret_as_uint(),
  )
  if status < 0 {
    raise Failure("audioWriteStream failed: \{status}")
  }
  status
}

///|
/// 结束流（写完后调用；播放完缓冲后流自然结束）。
pub fn AudioEngine::end_stream(self : AudioEngine, stream_id~ : Int) -> Unit raise {
  let status = audioEndStream(self.context, stream_id.reinterpret_as_uint())
  if status != 0 {
    raise Failure("audioEndStream failed: \{status}")
  }
}

///|
/// 重启流（重新缓冲）。
pub fn AudioEngine::restart_stream(self : AudioEngine, stream_id~ : Int) -> Unit raise {
  let status = audioRestartStream(self.context, stream_id.reinterpret_as_uint())
  if status != 0 {
    raise Failure("audioRestartStream failed: \{status}")
  }
}

///|
/// 设置流音量（0..1+）。
pub fn AudioEngine::set_stream_volume(self : AudioEngine, stream_id~ : Int, volume~ : Double) -> Unit raise {
  let status = audioSetStreamVolume(self.context, stream_id.reinterpret_as_uint(), Float::from_double(volume))
  if status != 0 {
    raise Failure("audioSetStreamVolume failed: \{status}")
  }
}

///|
/// 设置流声像（-1 左 .. 1 右）。
pub fn AudioEngine::set_stream_pan(self : AudioEngine, stream_id~ : Int, pan~ : Double) -> Unit raise {
  let status = audioSetStreamPan(self.context, stream_id.reinterpret_as_uint(), Float::from_double(pan))
  if status != 0 {
    raise Failure("audioSetStreamPan failed: \{status}")
  }
}

///|
/// 流统计视图。
pub struct AudioStreamStatsView {
  bytes_received : Int
  frames_decoded : Int
  frames_played : Int
  state : UInt32
  sample_rate : Int
  channels : Int
  buffered_frames : Int
  underruns : Int
  error_code : Int
}

///|
pub fn AudioStreamStatsView::bytes_received(self : AudioStreamStatsView) -> Int {
  self.bytes_received
}

///|
pub fn AudioStreamStatsView::frames_decoded(self : AudioStreamStatsView) -> Int {
  self.frames_decoded
}

///|
pub fn AudioStreamStatsView::frames_played(self : AudioStreamStatsView) -> Int {
  self.frames_played
}

///|
pub fn AudioStreamStatsView::state(self : AudioStreamStatsView) -> UInt32 {
  self.state
}

///|
pub fn AudioStreamStatsView::sample_rate(self : AudioStreamStatsView) -> Int {
  self.sample_rate
}

///|
pub fn AudioStreamStatsView::buffered_frames(self : AudioStreamStatsView) -> Int {
  self.buffered_frames
}

///|
pub fn AudioStreamStatsView::underruns(self : AudioStreamStatsView) -> Int {
  self.underruns
}

///|
pub fn AudioStreamStatsView::error_code(self : AudioStreamStatsView) -> Int {
  self.error_code
}

///|
/// 读取流统计。
pub fn AudioEngine::get_stream_stats(self : AudioEngine, stream_id~ : Int) -> AudioStreamStatsView raise {
  let out : AudioStreamStats = {
    bytes_received: 0UL,
    frames_decoded: 0UL,
    frames_played: 0UL,
    state: 0,
    sample_rate: 0,
    channels: 0,
    buffered_frames: 0,
    capacity_frames: 0,
    underruns: 0,
    error_code: 0,
    ready_generation: 0,
  }
  let status = audioGetStreamStats(self.context, stream_id.reinterpret_as_uint(), out)
  if status != 0 {
    raise Failure("audioGetStreamStats failed: \{status}")
  }
  {
    bytes_received: out.bytes_received.to_int(),
    frames_decoded: out.frames_decoded.to_int(),
    frames_played: out.frames_played.to_int(),
    state: out.state,
    sample_rate: out.sample_rate.reinterpret_as_int(),
    channels: out.channels.reinterpret_as_int(),
    buffered_frames: out.buffered_frames.reinterpret_as_int(),
    underruns: out.underruns.reinterpret_as_int(),
    error_code: out.error_code,
  }
}

///|
/// 加载编码音频（mp3/flac 等；返回 sound id）。
pub fn AudioEngine::load(self : AudioEngine, data~ : FixedArray[Byte]) -> Int raise {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = audioLoad(self.context, data, data.length().reinterpret_as_uint(), out)
  if status != 0 {
    raise Failure("audioLoad failed: \{status}")
  }
  out[0].reinterpret_as_int()
}

///|
/// 卸载声音。
pub fn AudioEngine::unload(self : AudioEngine, sound_id~ : Int) -> Unit raise {
  let status = audioUnload(self.context, sound_id.reinterpret_as_uint())
  if status != 0 {
    raise Failure("audioUnload failed: \{status}")
  }
}

///|
/// 播放已加载声音（返回 voice id）。
pub fn AudioEngine::play(
  self : AudioEngine,
  sound_id~ : Int,
  volume~ : Double = 1.0,
  pan~ : Double = 0.0,
  loop_~ : Bool = false,
) -> Int raise {
  let options : AudioVoiceOptions = {
    volume: Float::from_double(volume),
    pan: Float::from_double(pan),
    loop_: if loop_ { 1 } else { 0 },
    group_id: 0,
  }
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = audioPlay(self.context, sound_id.reinterpret_as_uint(), options, out)
  if status != 0 {
    raise Failure("audioPlay failed: \{status}")
  }
  out[0].reinterpret_as_int()
}

///|
/// 停止 voice。
pub fn AudioEngine::stop_voice(self : AudioEngine, voice_id~ : Int) -> Unit raise {
  let status = audioStopVoice(self.context, voice_id.reinterpret_as_uint())
  if status != 0 {
    raise Failure("audioStopVoice failed: \{status}")
  }
}

///|
/// 设置主音量。
pub fn AudioEngine::set_master_volume(self : AudioEngine, volume~ : Double) -> Unit raise {
  let status = audioSetMasterVolume(self.context, Float::from_double(volume))
  if status != 0 {
    raise Failure("audioSetMasterVolume failed: \{status}")
  }
}

///|
/// 启动采集（f32 交错；capacity_frames 为环形缓冲帧数）。
pub fn AudioEngine::start_capture(self : AudioEngine, channels~ : Int = 1, capacity_frames~ : Int = 48000) -> Unit raise {
  let options : AudioStartOptions = {
    period_size_in_frames: 0,
    period_size_in_milliseconds: 0,
    periods: 0,
    bools0_3: 0,
    bools4_7: 0,
    bools8_11: 0,
  }
  let status = audioStartCapture(
    self.context,
    options,
    channels.reinterpret_as_uint(),
    capacity_frames.reinterpret_as_uint(),
  )
  if status != 0 {
    raise Failure("audioStartCapture failed: \{status}")
  }
}

///|
/// 停止采集。
pub fn AudioEngine::stop_capture(self : AudioEngine) -> Unit raise {
  let status = audioStopCapture(self.context)
  if status != 0 {
    raise Failure("audioStopCapture failed: \{status}")
  }
}

///|
/// 采集是否运行中。
pub fn AudioEngine::is_capture_running(self : AudioEngine) -> Bool {
  audio_is_capture_running_shim(self.context) != 0
}

///|
/// 读取采集样本（f32 交错，buffer 容量 = 样本数；返回实际读取帧数）。
pub fn AudioEngine::read_capture(self : AudioEngine, buffer~ : FixedArray[Byte], frame_count~ : Int) -> Int raise {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = audioReadCapture(
    self.context,
    buffer,
    buffer.length().reinterpret_as_uint(),
    frame_count.reinterpret_as_uint(),
    out,
  )
  if status < 0 {
    raise Failure("audioReadCapture failed: \{status}")
  }
  out[0].reinterpret_as_int()
}
