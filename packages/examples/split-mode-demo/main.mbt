// 移植自 packages/examples/src/split-mode-demo.ts（简化实现）：
// 分屏模式 = 主帧（ot_scene_paint/commit 通道）+ footer 离屏缓冲
// （ot_buffer_draw_* 写入）经 ot_session_render_split 一起提交。
// TS 版的 scrollback 捕获（capture-stdout）在此简化为 MoonBit 侧
// 维护的日志行数组，空格推入新行，↑/↓ 调整 footer 高度。
// q 退出。OT_HEADLESS=1 提交一帧后退出。

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
  let renderer = @core.Renderer::create(background="#071018")
  let root = renderer.root()
  let frame_w = renderer.get_width().reinterpret_as_int()
  let frame_h = renderer.get_height().reinterpret_as_int()
  let mut footer_h = 6

  // 主区域：标题 + 说明
  let header = @core.new_box(
    renderer,
    height="3",
    border=true,
    border_style="double",
    border_color="#2C6075",
    background="#0D1B26",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="Split Mode Demo (main frame + footer snapshots)",
      fg="#F4FBFF",
      attributes="bold",
    ),
  )
  root.add(header)

  let body = @core.new_text(
    renderer,
    content="The main frame paints above the split footer.\nspace: push a log line into the footer\nup/down: footer height (5..12)\ns: suspend/resume cycle\nr: reset split scrollback\nq: quit",
    fg="#D6E8F0",
    wrap_mode="word",
  )
  let body_box = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#071018",
    padding=1,
    overflow="hidden",
  )
  body_box.add(body)
  root.add(body_box)

  let status = @core.new_text(renderer, content="", fg="#56D6C9")
  root.add(status)

  // footer 离屏缓冲与日志行
  let log_lines : Array[String] = []
  let log_seq = [ "boot: split footer ready", "tick: main frame painted", "info: snapshot submitted", "warn: backpressure ok", "tick: footer resized" ]
  let mut log_next = 0
  let footer = @core.FrameBuffer::create(
    renderer,
    width=frame_w.to_uint(),
    height=footer_h.to_uint(),
  )
  let redraw_footer = fn() raise {
    footer.clear(background="#0D1B26")
    // 首行标题栏
    footer.draw_text(
      text=" SPLIT FOOTER (\{footer_h} rows) ── newest at bottom",
      x=0,
      y=0,
      fg="#56D6C9",
      bg=Some("#0D1B26"),
      attributes=@core.OT_TEXT_ATTR_BOLD,
    )
    // 日志行从底部往上排
    let capacity = footer_h - 1
    let start = if log_lines.length() > capacity {
      log_lines.length() - capacity
    } else {
      0
    }
    for i in start..<log_lines.length() {
      footer.draw_text(
        text=" \{log_lines[i]}",
        x=0,
        y=(i - start + 1),
        fg="#D6E8F0",
        bg=Some("#0D1B26"),
      )
    }
  }
  redraw_footer()

  // 分屏滚动回放复位（seed rows=0, pinned offset=0）
  let _ = renderer.split_control(command=@core.OT_SPLIT_COMMAND_RESET, arguments=[0, 0])

  let commit = fn() raise {
    redraw_footer()
    let frame = renderer.paint_frame()
    let snapshot = @core.SplitCommit::make(
      buffer=footer.handle,
      row_columns=frame_w,
      flags=@core.OT_SPLIT_FLAG_NEW_LINE.lor(@core.OT_SPLIT_FLAG_TRAILING_NEWLINE),
    )
    let status_code = renderer.render_split(frame=frame, commits=[snapshot])
    renderer.flush_output()
    status_code
  }
  let refresh_status = fn(code : Int) raise {
    let _ = status.set_content(
      " footer \{footer_h} rows · last submit=\{code} (0 ok 1 pending 2 skipped) · space/up/down/s/r/q",
    )
  }
  let code = commit()
  refresh_status(code)

  if headless {
    log_lines.push("headless: split snapshot verified")
    let c2 = commit()
    refresh_status(c2)
    let state = renderer.get_renderer_state()
    write_info(
      "split-demo-info.txt",
      [
        "submit=\{code}",
        "renderer=\{state.width()}x\{state.height()} frames=\{state.frame_count()} pending=\{state.frame_pending()}",
        "session_state=\{renderer.get_session_state()}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      "space" => {
        log_lines.push(log_lines[log_next % log_lines.length()])
        log_next += 1
        let c = commit()
        refresh_status(c)
      }
      "down" => {
        if footer_h < 12 {
          footer_h += 1
          let c = commit()
          refresh_status(c)
        }
      }
      "up" => {
        if footer_h > 5 {
          footer_h -= 1
          let c = commit()
          refresh_status(c)
        }
      }
      "s" => {
        // 挂起 → 恢复循环：验证终端模式往返
        renderer.suspend()
        renderer.resume()
        let c = commit()
        refresh_status(c)
      }
      "r" => {
        let _ = renderer.split_control(command=@core.OT_SPLIT_COMMAND_RESET, arguments=[0, 0])
        log_lines.clear()
        let c = commit()
        refresh_status(c)
      }
      _ => ()
    }
  })

  renderer.run()
}
