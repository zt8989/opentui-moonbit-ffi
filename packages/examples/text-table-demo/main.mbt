// 移植自 packages/examples/src/text-table-demo.ts（简化实现）：
// 表格组件 = MoonBit 侧 TextTable（列宽测量 + 对齐 + 边框线渲染成
// 单个 Text 节点）。左右两列数据源，tab 切换边框风格，q 退出。
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
/// 对齐文本（width 为显示宽度；ASCII 假设）。
fn pad(text : String, width : Int, align~ : String = "left") -> String {
  let len = text.length()
  if len >= width {
    return text
  }
  let gap = width - len
  if align == "right" {
    let sb = StringBuilder(size_hint=width)
    for _ in 0..<gap {
      sb.write_char(' ')
    }
    sb.write_string(text)
    sb.to_string()
  } else if align == "center" {
    let left = gap / 2
    let sb = StringBuilder(size_hint=width)
    for _ in 0..<left {
      sb.write_char(' ')
    }
    sb.write_string(text)
    for _ in 0..<(gap - left) {
      sb.write_char(' ')
    }
    sb.to_string()
  } else {
    let sb = StringBuilder(size_hint=width)
    sb.write_string(text)
    for _ in 0..<gap {
      sb.write_char(' ')
    }
    sb.to_string()
  }
}

///|
/// 表格组件：列定义 + 行数据 → 带边框的文本表格。
pub struct TextTable {
  headers : Array[String]
  aligns : Array[String]
  rows : Array[Array[String]]
  mut border_style : String
}

///|
/// 创建表格（aligns：left/right/center）。
pub fn TextTable::create(
  headers~ : Array[String],
  aligns~ : Array[String],
  rows~ : Array[Array[String]],
  border_style~ : String = "single",
) -> TextTable {
  { headers, aligns, rows, border_style }
}

///|
/// 渲染为多行文本。
pub fn TextTable::render(self : TextTable) -> Array[String] {
  let col_count = self.headers.length()
  // 列宽 = max(表头, 各行)
  let widths : Array[Int] = []
  for c in 0..<col_count {
    let mut w = self.headers[c].length()
    for row in self.rows {
      if c < row.length() && row[c].length() > w {
        w = row[c].length()
      }
    }
    widths.push(w + 2)
  }
  let (tl, tr, bl, br, hz, vt) = if self.border_style == "double" {
    ("╔", "╗", "╚", "╝", "═", "║")
  } else if self.border_style == "rounded" {
    ("╭", "╮", "╰", "╯", "─", "│")
  } else {
    ("┌", "┐", "└", "┘", "─", "│")
  }
  let lines : Array[String] = []
  // 顶边
  let top = StringBuilder(size_hint=128)
  top.write_string(tl)
  for c, w in widths {
    if c > 0 {
      top.write_string(if self.border_style == "double" { "╤" } else { "┬" })
    }
    for _ in 0..<w {
      top.write_string(hz)
    }
  }
  top.write_string(tr)
  lines.push(top.to_string())
  // 表头
  let header_row = StringBuilder(size_hint=128)
  header_row.write_string(vt)
  for c, w in widths {
    header_row.write_string(pad(self.headers[c], w, align="center"))
    header_row.write_string(vt)
  }
  lines.push(header_row.to_string())
  // 分隔
  let sep = StringBuilder(size_hint=128)
  sep.write_string(if self.border_style == "double" { "╠" } else { "├" })
  for c, w in widths {
    if c > 0 {
      sep.write_string(if self.border_style == "double" { "╪" } else { "┼" })
    }
    for _ in 0..<w {
      sep.write_string(hz)
    }
  }
  sep.write_string(if self.border_style == "double" { "╣" } else { "┤" })
  lines.push(sep.to_string())
  // 数据行
  for row in self.rows {
    let line = StringBuilder(size_hint=128)
    line.write_string(vt)
    for c, w in widths {
      let cell = if c < row.length() { row[c] } else { "" }
      line.write_string(pad(cell, w, align=self.aligns[c]))
      line.write_string(vt)
    }
    lines.push(line.to_string())
  }
  // 底边
  let bottom = StringBuilder(size_hint=128)
  bottom.write_string(bl)
  for c, w in widths {
    if c > 0 {
      bottom.write_string(if self.border_style == "double" { "╧" } else { "┴" })
    }
    for _ in 0..<w {
      bottom.write_string(hz)
    }
  }
  bottom.write_string(br)
  lines.push(bottom.to_string())
  lines
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
    border_color="#d2a8ff",
    background="#0D1117",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="TextTable Demo (column measure · alignment · borders)",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  let table_box = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0D1117",
    padding=1,
    align_items="center",
    justify_content="center",
  )
  let table_text = @core.new_text(renderer, content="", fg="#c9d1d9")
  table_box.add(table_text)
  root.add(table_box)

  let status = @core.new_text(
    renderer,
    content="t: border style · q quit",
    fg="#8b949e",
  )
  root.add(status)

  let table = TextTable::create(
    headers=["Task", "Owner", "Status", "Done"],
    aligns=["left", "left", "center", "right"],
    rows=[
      ["port core", "moon", "done", "34"],
      ["port examples", "moon", "active", "12"],
      ["verify headless", "ci", "done", "40"],
      ["three.js", "—", "skipped", "0"],
    ],
  )
  let mut border_style = "single"
  let refresh = fn() raise {
    table.border_style = border_style
    let lines = table.render()
    let _ = table_text.set_content(lines.join("\n"))
    let _ = status.set_content(
      " border=\{border_style} rows=\{table.rows.length()} cols=\{table.headers.length()} · t: style · q quit",
    )
  }
  refresh()

  if headless {
    renderer.render()
    write_info(
      "table-demo-info.txt",
      [
        "rows=\{table.rows.length()} cols=\{table.headers.length()}",
        "border=\{border_style}",
        "rendered_lines=\{table.render().length()}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      "t" => {
        border_style = match border_style {
          "single" => "double"
          "double" => "rounded"
          _ => "single"
        }
        refresh()
        renderer.render()
      }
      _ => ()
    }
  })

  renderer.run()
}
