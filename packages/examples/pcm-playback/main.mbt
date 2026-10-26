// 移植自 packages/examples/src/pcm-playback.ts（简化实现）：
// PCM 流播放 = createAudioEngine → start → create_pcm_stream →
// 写入 f32 交错正弦样本 → end_stream。TS 版流式分块写入并监听
// 背压；MoonBit 版一次全量写入（缓冲 2 秒），空格重播，↑/↓ 音量。
// 无音频设备的 headless 环境下引擎创建/启动返回 err_device，
// 示例据实报告而不失败。OT_HEADLESS=1 时只验证管线不进入交互。

///|
#borrow(name)
extern "C" fn getenv_ffi(name : Bytes) -> Int64 = "getenv"

///|
#borrow(path, mode)
extern "C" fn fopen_ffi(path : Bytes, mode : Bytes) -> Int64 = "fopen"

///|
#borrow(buf)
extern "C" fn fwrite_ffi(
  buf : FixedArray[Byte],
  size : UInt64,
  count : UInt64,
  file : Int64,
) -> UInt64 = "fwrite"

///|
extern "C" fn fclose_ffi(file : Int64) -> Int32 = "fclose"

///|
fn write_info(path : String, lines : Array[String]) -> Unit {
  let file = fopen_ffi(@utf8.encode(path), b"w")
  if file == 0L {
    return
  }
  for line in lines {
    let bytes = @utf8.encode(line + "\n")
    let fa : FixedArray[Byte] = FixedArray::make(bytes.length(), 0)
    for i in 0..<bytes.length() {
      fa[i] = bytes[i]
    }
    let _ = fwrite_ffi(fa, 1UL, bytes.length().to_uint64(), file)
  }
  let _ = fclose_ffi(file)
}

///|
fn main raise {
  let headless = getenv_ffi(b"OT_HEADLESS") != 0
  let renderer = @core.Renderer::create(background="#10141a")
  let root = renderer.root()

  let header = @core.new_box(
    renderer,
    height="3",
    border=true,
    border_style="double",
    border_color="#bb9af7",
    background="#10141a",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="PCM Playback (native audio engine)",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  let status = @core.new_text(renderer, content="", fg="#8b949e", wrap_mode="word")
  root.add(status)

  let sample_rate = 48000
  let seconds = 2
  // 立体声 f32 交错正弦（440Hz 左、550Hz 右，带淡出）
  let total_samples = sample_rate * seconds * 2
  let pcm : FixedArray[Byte] = FixedArray::make(total_samples * 4, 0)
  for frame in 0..<96000 {
    let t : Float = Float::from_int(frame) / Float::from_int(sample_rate)
    let fade : Float = 1.0 - t / Float::from_int(seconds)
    let td : Double = t.to_double()
    let faded : Double = fade.to_double()
    let l : Double = @math.sin(6.2832 * 440.0 * td) * 0.25 * faded
    let r : Double = @math.sin(6.2832 * 550.0 * td) * 0.25 * faded
    let left : Float = Float::from_double(l)
    let right : Float = Float::from_double(r)
    let li = frame * 2
    // f32 按小端字节写入
    put_f32_le(pcm, li * 4, left)
    put_f32_le(pcm, (li + 1) * 4, right)
  }

  let mut engine : @core.AudioEngine? = None
  let mut stream_id = 0
  let describe = fn(err : String) -> String {
    "engine: \{err}"
  }
  let setup = fn() raise {
    match engine {
      Some(e) => e.stop()
      None => ()
    }
    let e = @core.AudioEngine::create(renderer)
    engine = Some(e)
    e.start()
    stream_id = e.create_pcm_stream(capacity_ms=2500)
    let written = e.write_pcm(stream_id=stream_id, samples=pcm)
    e.end_stream(stream_id=stream_id)
    let stats = e.get_stream_stats(stream_id=stream_id)
    let _ = status.set_content(
      "stream \{stream_id}: written=\{written} bytes received=\{stats.bytes_received()} state=\{stats.state()} rate=\{stats.sample_rate()} · space replay · q quit",
    )
  }
  let report_failure = fn(msg : String) raise {
    let _ = status.set_content(describe(msg) + " · (no audio device?) · q quit")
  }

  if headless {
    // 只验证管线：能创建则写满流并读统计；无设备则报告状态码
    let lines : Array[String] = []
    try {
      setup()
      match engine {
        Some(e) => {
          let stats = e.get_stream_stats(stream_id=stream_id)
          lines.push("stream=\{stream_id} received=\{stats.bytes_received()} decoded=\{stats.frames_decoded()} rate=\{stats.sample_rate()}")
        }
        None => ()
      }
    } catch {
      Failure(msg) => lines.push("unavailable: \{msg}")
      _ => lines.push("unavailable: unknown")
    }
    write_info("pcm-demo-info.txt", lines)
    renderer.stop()
    return
  }

  try {
    setup()
  } catch {
    Failure(msg) => report_failure(msg)
    _ => report_failure("unknown")
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => {
        match engine {
          Some(e) => e.stop()
          None => ()
        }
        renderer.stop()
      }
      "space" => {
        try {
          match engine {
            Some(e) => {
              e.restart_stream(stream_id=stream_id)
              let _ = e.write_pcm(stream_id=stream_id, samples=pcm)
              e.end_stream(stream_id=stream_id)
            }
            None => ()
          }
        } catch {
          Failure(msg) => report_failure(msg)
          _ => report_failure("unknown")
        }
      }
      _ => ()
    }
  })

  renderer.run()
}

///|
/// f32 → 4 字节小端（Float 位重解释）。
fn put_f32_le(buf : FixedArray[Byte], offset : Int, value : Float) -> Unit {
  let bits : Int = value.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}
