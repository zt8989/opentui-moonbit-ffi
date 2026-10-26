// 交互式 keymap 示例：移植 OpenTUI keymap-demo 的核心理念。
// 绑定 → 按键 → 命令 dispatch → 场景更新，全流程运行在
// MoonBit FFI + OpenTUI 原生渲染器上（无 JavaScript 运行时）。
//
// 绑定（vim 风格）：
//   j / down    下一项        k / up     上一项
//   space       切换复选      g g        跳到第一项
//   G           跳到最后一项  q / ctrl+c 退出
//   escape      清除进行中的序列

///|
fn main {
  let saved : FixedArray[Byte] = FixedArray::make(128, 0)
  let raw : FixedArray[Byte] = FixedArray::make(128, 0)
  let have_tty = termios_save(0, saved)
  if have_tty {
    termios_make_raw(saved, raw)
    let _ = termios_apply(0, raw)
  }
  run() catch {
    Failure(msg) => {
      if have_tty {
        let _ = termios_apply(0, saved)
      }
      println("error: \{msg}")
      exit_ffi(1)
    }
    err => {
      if have_tty {
        let _ = termios_apply(0, saved)
      }
      println("error: \{err}")
      exit_ffi(1)
    }
  }
  if have_tty {
    let _ = termios_apply(0, saved)
  }
}

///|
fn[T] ok(r : Result[T, @ffi.NativeError]) -> T raise {
  match r {
    Ok(v) => v
    Err(e) => raise Failure(e.to_string())
  }
}

///|
/// 菜单条目。
struct Item {
  label : String
  mut checked : Bool
}

///|
fn run() -> Unit raise {
  let (width, height) = terminal_size()
  let km = build_keymap()

  // 终端 setup 需要预留 control 输出容量（OT_SESSION_CONTROL_PACKET_BYTES）。
  let context = ok(
    @ffi.create_context(object_capacity=64, render_cells_max=width * height),
  )
  let session = ok(
    @ffi.create_session(
      context,
      chunk_size=4096,
      span_capacity=8,
      max_bytes=65536UL,
      control_capacity=4096,
    ),
  )
  ok(@ffi.attach_renderer(context, session, width~, height~))
  ok(@ffi.setup_terminal(context, session, alternate_screen=true))

  // 泵送 setup 输出直到终端就绪。
  while ok(@ffi.terminal_state(context, session)) != @ffi.OT_TERMINAL_ACTIVE {
    let p = ok(@ffi.pump(context, session, now_ns()))
    let _ = ok(@ffi.drain_stdout(context, session))
    if p.status() == @ffi.OT_PUMP_CLOSED {
      raise Failure("terminal closed during setup")
    }
  }

  let items : Array[Item] = [
    { label: "MoonBit FFI", checked: true, },
    { label: "OpenTUI native", checked: true, },
    { label: "keymap sequences", checked: false, },
    { label: "raw terminal input", checked: false, },
    { label: "vim-style bindings", checked: false, },
  ]
  let mut selected = 0
  let mut status_text = "ready — try \"g g\" (sequence), \"G\", space, q"

  let rows = build_ui(context, session, km, items)
  render(rows, context, session, items, selected, status_text)

  // 输入循环：阻塞读 stdin，解析后交给 keymap dispatch。
  let buf : FixedArray[Byte] = FixedArray::make(256, 0)
  let mut quit = false
  while !quit {
    let p = ok(@ffi.pump(context, session, now_ns()))
    match p.status() {
      status =>
        if status == @ffi.OT_PUMP_OUTPUT_PENDING || status == @ffi.OT_PUMP_AGAIN {
          let _ = ok(@ffi.drain_stdout(context, session))
        }
    }
    let n = read_stdin(buf)
    if n < 0 {
      continue
    }
    if n == 0 {
      // stdin EOF（管道关闭）：无法继续交互，优雅退出。
      break
    }
    let fed = ok(
      @ffi.input_feed(context, session, buf, n.reinterpret_as_uint(), now_ns()),
    )
    for ev in fed.events() {
      if ev.kind() != @ffi.OT_INPUT_KEY {
        continue
      }
      let action = ev.action()
      if action != @ffi.OT_INPUT_KEY_PRESS && action != @ffi.OT_INPUT_KEY_REPEAT {
        continue
      }
      match stroke_of(ev) {
        Some(stroke) =>
          match km.handle_key(stroke) {
            @keymap.Ran(command) =>
              match command {
                "quit" => {
                  quit = true
                  status_text = "bye"
                }
                "next" => selected = (selected + 1) % items.length()
                "prev" =>
                  selected = (selected + items.length() - 1) % items.length()
                "toggle" => {
                  let it = items[selected]
                  it.checked = !it.checked
                  status_text = "toggled \{it.label}"
                }
                "top" => {
                  selected = 0
                  status_text = "top"
                }
                "bottom" => {
                  selected = items.length() - 1
                  status_text = "bottom"
                }
                _ => status_text = "unhandled \{command}"
              }
            @keymap.Pending(parts) =>
              match parts.last() {
                Some(last) =>
                  status_text = "sequence: \{last} … (esc cancels)"
                None => status_text = "sequence …"
              }
            @keymap.Cleared(_) => status_text = "sequence cleared"
            @keymap.Ignored => ()
          }
        None => ()
      }
    }
    render(rows, context, session, items, selected, status_text)
  }

  ok(@ffi.close_session(context, session))
  // 继续泵送直到终端恢复输出全部交付。
  while true {
    let p = ok(@ffi.pump(context, session, now_ns()))
    let _ = @ffi.drain_stdout(context, session)
    if p.status() == @ffi.OT_PUMP_CLOSED {
      break
    }
  }
  ok(@ffi.destroy_context(context))
}

///|
/// 构建绑定与命令处理器。
fn build_keymap() -> @keymap.Keymap raise {
  let km = @keymap.Keymap::new()
  km.register([
    @keymap.Binding::make("j", "next", description="Next item"),
    @keymap.Binding::make("down", "next"),
    @keymap.Binding::make("k", "prev", description="Previous item"),
    @keymap.Binding::make("up", "prev"),
    @keymap.Binding::make("space", "toggle", description="Toggle checked"),
    @keymap.Binding::make("g g", "top", description="Jump to first"),
    @keymap.Binding::make("G", "bottom", description="Jump to last"),
    @keymap.Binding::make("q", "quit", description="Quit"),
    @keymap.Binding::make("ctrl+c", "quit"),
  ])
  km
}

///|
/// 搭建场景：root → panel(box) → [title, rows…, status, help]，
/// 返回菜单行的 text 节点。
fn build_ui(
  context : @ffi.Context,
  session : @ffi.OtHandle,
  km : @keymap.Keymap,
  items : Array[Item],
) -> Array[@ffi.OtHandle] raise {
  let root = ok(@ffi.create_node(context, session, @ffi.OT_SCENE_ROOT, num=1))
  let panel = ok(@ffi.create_node(context, session, @ffi.OT_SCENE_BOX, num=2))
  ok(@ffi.set_paint(context, panel, @ffi.make_paint_options()))
  ok(@ffi.move_node(context, panel, root, index=0))
  let title = ok(@ffi.create_node(context, session, @ffi.OT_SCENE_TEXT, num=3))
  ok(@ffi.set_text(context, title, "OpenTUI keymap demo (MoonBit FFI)"))
  ok(
    @ffi.set_text_options(
      context,
      title,
      @ffi.make_text_options(
        foreground=(255, 255, 0, 255),
        attributes=@ffi.OT_TEXT_ATTR_BOLD,
        align=@ffi.OT_SCENE_ALIGN_CENTER,
      ),
    ),
  )
  ok(@ffi.move_node(context, title, panel, index=0))
  let rows : Array[@ffi.OtHandle] = []
  for i, _item in items {
    let row = ok(
      @ffi.create_node(
        context,
        session,
        @ffi.OT_SCENE_TEXT,
        num=(4 + i).reinterpret_as_uint(),
      ),
    )
    ok(@ffi.move_node(context, row, panel, index=(i + 1).reinterpret_as_uint()))
    rows.push(row)
  }
  let status = ok(
    @ffi.create_node(context, session, @ffi.OT_SCENE_TEXT, num=104),
  )
  ok(
    @ffi.move_node(
      context,
      status,
      panel,
      index=(items.length() + 1).reinterpret_as_uint(),
    ),
  )
  let help = ok(@ffi.create_node(context, session, @ffi.OT_SCENE_TEXT, num=105))
  let help_text = km
    .binding_help()
    .map(fn(row) {
      let (keys, _cmd, desc) = row
      "\{keys} \{desc}"
    })
    .join("   ")
  ok(@ffi.set_text(context, help, help_text))
  ok(
    @ffi.set_text_options(
      context,
      help,
      @ffi.make_text_options(foreground=(120, 120, 140, 255)),
    ),
  )
  ok(
    @ffi.move_node(
      context,
      help,
      panel,
      index=(items.length() + 2).reinterpret_as_uint(),
    ),
  )
  rows.push(status)
  rows
}

///|
/// 重绘文本行并渲染一帧。
fn render(
  rows : Array[@ffi.OtHandle],
  context : @ffi.Context,
  session : @ffi.OtHandle,
  items : Array[Item],
  selected : Int32,
  status_text : String,
) -> Unit raise {
  for i, item in items {
    let row = rows[i]
    let marker = if item.checked { "[x]" } else { "[ ]" }
    ok(@ffi.set_text(context, row, " \{marker} \{item.label}"))
    let options = if i == selected {
      @ffi.make_text_options(
        foreground=(0, 0, 0, 255),
        background=(255, 255, 0, 255),
        attributes=@ffi.OT_TEXT_ATTR_BOLD,
      )
    } else {
      @ffi.make_text_options(foreground=(220, 220, 220, 255))
    }
    ok(@ffi.set_text_options(context, row, options))
  }
  let status_row = rows[items.length()]
  ok(@ffi.set_text(context, status_row, " \{status_text}"))
  let frame = ok(@ffi.paint(context, session))
  let outcome = ok(@ffi.commit_frame(context, session, frame))
  if outcome != @ffi.OT_RENDER_PENDING && outcome != @ffi.OT_RENDER_PRESENTED {
    raise Failure("frame not accepted: outcome \{outcome}")
  }
  let _ = ok(@ffi.drain_stdout(context, session))
}

///|
/// 从输入事件重建 KeyStroke（键名规则见 ffi.OT_INPUT_KEY_*）。
fn stroke_of(ev : @ffi.InputEvent) -> @keymap.KeyStroke? raise {
  let code = ev.code()
  let m = ev.modifiers()
  let name : String = match code {
    c =>
      if c == @ffi.OT_INPUT_KEY_ENTER {
        "enter"
      } else if c == @ffi.OT_INPUT_KEY_ESCAPE {
        "escape"
      } else if c == @ffi.OT_INPUT_KEY_TAB {
        "tab"
      } else if c == @ffi.OT_INPUT_KEY_BACKSPACE {
        "backspace"
      } else if c == @ffi.OT_INPUT_KEY_LEFT {
        "left"
      } else if c == @ffi.OT_INPUT_KEY_RIGHT {
        "right"
      } else if c == @ffi.OT_INPUT_KEY_UP {
        "up"
      } else if c == @ffi.OT_INPUT_KEY_DOWN {
        "down"
      } else if c == @ffi.OT_INPUT_KEY_HOME {
        "home"
      } else if c == @ffi.OT_INPUT_KEY_END {
        "end"
      } else if c == @ffi.OT_INPUT_KEY_PAGE_UP {
        "pageup"
      } else if c == @ffi.OT_INPUT_KEY_PAGE_DOWN {
        "pagedown"
      } else if c == 32 {
        "space"
      } else if c >= 32 && c < 127 {
        utf8_scalar_to_string(c)
      } else {
        return None
      }
  }
  Some(
    @keymap.KeyStroke::make(
      name,
      ctrl=(m & @ffi.OT_INPUT_MOD_CTRL) != 0,
      shift=(m & @ffi.OT_INPUT_MOD_SHIFT) != 0,
      meta=(m & @ffi.OT_INPUT_MOD_ALT) != 0,
      super_=(m & @ffi.OT_INPUT_MOD_SUPER) != 0,
    ),
  )
}

///|
/// Unicode scalar → 单字符 String。
fn utf8_scalar_to_string(code : UInt32) -> String {
  let c = code.reinterpret_as_int().to_char().unwrap_or(' ')
  let buf = StringBuilder(size_hint=4)
  buf.write_char(c)
  buf.to_string()
}

///|
/// 单调纳秒时钟（pump/input_feed 需要）。启动时探测可用的 CLOCK id。
struct Clock {
  mut id : Int32
}

///|
let clock : Clock = { id: -1, }

///|
fn now_ns() -> UInt64 {
  if clock.id < 0 {
    // macOS 的 CLOCK_MONOTONIC 是 6，Linux 是 1。
    let candidates : Array[Int32] = [6, 1]
    for id in candidates {
      let probe : FixedArray[Byte] = FixedArray::make(16, 0)
      if clock_gettime_ffi(id, probe) == 0 {
        clock.id = id
        break
      }
    }
    if clock.id < 0 {
      clock.id = 1
    }
  }
  let tp : FixedArray[Byte] = FixedArray::make(16, 0)
  if clock_gettime_ffi(clock.id, tp) != 0 {
    return 0UL
  }
  let sec = u64_at(tp, 0)
  let nsec = u64_at(tp, 8)
  let _ = nsec
  sec * 1000000000UL + nsec
}

///|
fn u64_at(buf : FixedArray[Byte], off : Int32) -> UInt64 {
  let mut v : UInt64 = 0
  for i in 0..<8 {
    v = v | (buf[off + i].to_uint64() << (i * 8))
  }
  v
}
