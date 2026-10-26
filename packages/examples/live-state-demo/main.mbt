// 移植自 packages/examples/src/live-state-demo.ts（简化实现）：
// 渲染器实时状态 = ot_session_get_renderer_state / get_state /
// get_terminal_state / update_stats 的周期读取展示。
// 空格强制重绘（帧计数变化），s 模拟统计上报，q 退出。
// OT_HEADLESS=1 渲染一帧后退出。

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
  let renderer = @core.Renderer::create(background="#0D1117")
  let root = renderer.root()

  let header = @core.new_box(
    renderer,
    height="3",
    border=true,
    border_style="double",
    border_color="#00D4AA",
    background="#0D1117",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="Live State Demo (renderer/session/terminal state)",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  let state_text = @core.new_text(renderer, content="", fg="#c9d1d9", wrap_mode="word")
  let state_box = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0D1117",
    padding=1,
    overflow="hidden",
  )
  state_box.add(state_text)
  root.add(state_box)

  let status = @core.new_text(
    renderer,
    content="space: redraw (frame++) · s: report stats · q quit",
    fg="#8b949e",
  )
  root.add(status)

  let mut frames : Int = 0
  let refresh = fn() raise {
    let rs = renderer.get_renderer_state()
    let session_state = renderer.get_session_state()
    let terminal = @core.terminal_state_name_of(session_state)
    let _ = state_text.set_content(
      "renderer: \{rs.width()}x\{rs.height()}  frames=\{rs.frame_count()}  pending=\{rs.frame_pending()}\nsession state: \{session_state} (\{terminal})\ndemo frames drawn: \{frames}",
    )
  }
  refresh()

  if headless {
    renderer.render()
    frames = frames + 1
    let rs = renderer.get_renderer_state()
    write_info(
      "live-state-demo-info.txt",
      [
        "renderer=\{rs.width()}x\{rs.height()}",
        "frames=\{rs.frame_count()} pending=\{rs.frame_pending()}",
        "session_state=\{renderer.get_session_state()}",
        "demo_frames=\{frames}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      " " => {
        frames = frames + 1
        renderer.render()
        refresh()
        renderer.render()
      }
      "s" => {
        renderer.update_stats(overall_ms=1.5, fps=60, callback_ms=0.2)
        refresh()
        renderer.render()
      }
      _ => ()
    }
  })

  renderer.run()
}
