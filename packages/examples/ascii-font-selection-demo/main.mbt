// 移植自 packages/examples/src/ascii-font-selection-demo.ts（简化实现）：
// ASCIIFont = 字模库（半块字符画）渲染大字标题。tiny 字体 A-Z0-9 子集，
// 1/2 切换文本预设，c 循环颜色，q 退出。OT_HEADLESS=1 渲染一帧后退出。

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
/// 用字模渲染文本为行数组（未知字符跳过为空列）。
pub fn render_ascii_font(text : String, letterspace~ : Int = 1) -> Array[String] {
  let font = tiny_font()
  let rows = 2
  let out : Array[StringBuilder] = []
  for r in 0..<rows {
    out.push(StringBuilder(size_hint=text.length() * 6))
  }
  for ch in text {
    let key = ch.to_string()
    match font.get(key) {
      Some(glyph) => {
        for r in 0..<rows {
          out[r].write_string(glyph[r])
          for _ in 0..<letterspace {
            out[r].write_char(' ')
          }
        }
      }
      None => {
        for r in 0..<rows {
          out[r].write_char(' ')
          out[r].write_char(' ')
          out[r].write_char(' ')
        }
      }
    }
  }
  let result : Array[String] = []
  for r in 0..<rows {
    result.push(out[r].to_string())
  }
  result
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
      content="ASCIIFont Demo (tiny · half-block letter art)",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  let font_box = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0D1117",
    padding=1,
    align_items="center",
    justify_content="center",
    flex_direction="column",
  )
  let line0 = @core.new_text(renderer, content="", fg="#00D4AA", attributes="bold")
  let line1 = @core.new_text(renderer, content="", fg="#00D4AA", attributes="bold")
  font_box.add(line0)
  font_box.add(line1)
  root.add(font_box)

  let status = @core.new_text(
    renderer,
    content="1/2 text preset · c color · q quit",
    fg="#8b949e",
  )
  root.add(status)

  let presets = ["MOONBIT", "OPENTUI", "FFI 42"]
  let colors = ["#00D4AA", "#FF6B9D", "#FFB86C", "#82AAFF"]
  let mut preset = 0
  let mut color = 0
  let refresh = fn() raise {
    let lines = render_ascii_font(presets[preset])
    let _ = line0.set_content(lines[0])
    let _ = line1.set_content(lines[1])
    let _ = line0.set_fg(colors[color])
    let _ = line1.set_fg(colors[color])
    let _ = status.set_content(
      " text=\{presets[preset]} color=\{colors[color]} · 1/2 preset · c color · q quit",
    )
  }
  refresh()

  if headless {
    renderer.render()
    let lines = render_ascii_font(presets[preset])
    write_info(
      "font-demo-info.txt",
      [
        "text=\{presets[preset]}",
        "line0_len=\{lines[0].length()} line1_len=\{lines[1].length()}",
        "colors=\{colors.length()}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      "1" | "2" => {
        preset = if stroke.name == "1" { 0 } else { 1 }
        refresh()
        renderer.render()
      }
      "c" => {
        color = (color + 1) % colors.length()
        refresh()
        renderer.render()
      }
      _ => ()
    }
  })

  renderer.run()
}
