// 移植自 packages/examples/src/embedded-terminal-demo.ts（简化实现）：
// 内嵌终端 = 原生 VT 模拟器（宿主喂字节）+ CUSTOM 节点 RENDER_SELF 合成。
// TS 版用 node-pty 拉起真实 shell；MoonBit 版演示同一管线的确定性路径：
// 喂入 ANSI 序列（颜色/光标定位/清屏），按键本地回显后 write 回模拟器，
// 并演示 key/paste/focus 编码与响应排空。
// 可打印字符写入终端（本地回显），Enter 换行，q 退出。
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
  let renderer = @core.Renderer::create(background="#0b0e14")
  let root = renderer.root()
  let frame_w = renderer.get_width().reinterpret_as_int()
  let term_cols = frame_w - 6
  let term_rows = 12

  let header = @core.new_box(
    renderer,
    height="3",
    border=true,
    border_style="double",
    border_color="#7aa2f7",
    background="#0b0e14",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="Embedded Terminal (native VT emulator)",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  let term_box = @core.new_box(
    renderer,
    height="14",
    border=true,
    border_color="#7aa2f7",
    background="#0b0e14",
    padding=1,
  )

  // 终端 + 节点缓冲（尺寸匹配单元格数）
  let terminal = @core.EmbeddedTerminal::create(
    renderer,
    cols=term_cols,
    rows=term_rows,
    max_scrollback=100,
  )
  let fb = @core.FrameBuffer::create(
    renderer,
    width=term_cols.to_uint(),
    height=term_rows.to_uint(),
  )
  // 喂入演示内容：欢迎横幅 + 颜色 + 光标定位
  terminal.write_text(
    text="\x1b[1;36m=== moonbit embedded terminal ===\x1b[0m\r\n\x1b[32mgreen\x1b[0m \x1b[33myellow\x1b[0m \x1b[31mred\x1b[0m \x1b[7mreverse\x1b[0m\r\n\r\n\x1b[1m$\x1b[0m echo \"type keys to see local echo\"\r\n\x1b[1m$\x1b[0m ",
  )
  let term_node = @core.new_embedded_terminal(
    renderer,
    terminal,
    fb,
    width=term_cols,
    height=term_rows,
    position="relative",
  )
  term_box.add(term_node)
  root.add(term_box)

  let status = @core.new_text(
    renderer,
    content="type to echo · enter newline · f focus enc · p paste enc · q quit",
    fg="#8b949e",
  )
  root.add(status)

  if headless {
    renderer.render()
    let cursor = terminal.cursor()
    let sel_test = terminal.encode_key(key_name="a", key_text="a")
    let paste_test = terminal.encode_paste(text="pasted")
    let focus_test = terminal.encode_focus(focused=true)
    write_info(
      "term-demo-info.txt",
      [
        "cursor=(\{cursor.x()},\{cursor.y()}) visible=\{cursor.visible()}",
        "encode_key(a)=\{sel_test}",
        "encode_paste=\{paste_test}",
        "encode_focus(on)=\{focus_test}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      "enter" => terminal.write_text(text="\r\n\x1b[1m$\x1b[0m ")
      "backspace" => terminal.write_text(text="\x08 \x08")
      "f" => {
        let _ = terminal.write_text(text=terminal.encode_focus(focused=true))
      }
      "p" => {
        let _ = terminal.write_text(text=terminal.encode_paste(text="paste!"))
      }
      _ => {
        // 可打印字符：先本地回显再喂模拟器
        if stroke.name.length() == 1 && !stroke.ctrl && !stroke.meta {
          let ch = stroke.name
          let _ = terminal.write_text(text=terminal.encode_key(key_name=ch, key_text=ch))
          terminal.write_text(text=ch)
        }
      }
    }
    terminal.command(command=@core.OT_EMBEDDED_TERMINAL_INVALIDATE)
    renderer.render()
  })

  renderer.run()
}
