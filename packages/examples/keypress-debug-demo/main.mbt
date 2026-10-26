// 移植自 packages/examples/src/keypress-debug-demo.ts（简化版）：
// 实时显示按键与粘贴事件。原版用 ScrollBox 展示 120 条历史 + JSON 快照；
// 这里保留核心价值——最近 14 条事件日志 + 末次事件详情面板（键名、修饰符）。
// 显示修饰键组合与大写键（shift+A 会显示为 shift+A）。

///|
fn stroke_label(stroke : @keymap.KeyStroke) -> String {
  let parts : Array[String] = []
  if stroke.ctrl {
    parts.push("ctrl")
  }
  if stroke.meta {
    parts.push("alt")
  }
  if stroke.super_ {
    parts.push("super")
  }
  if stroke.hyper {
    parts.push("hyper")
  }
  if stroke.shift {
    parts.push("shift")
  }
  parts.push(stroke.name)
  let buf = StringBuilder(size_hint=16)
  for i, p in parts {
    if i > 0 {
      buf.write_string("+")
    }
    buf.write_string(p)
  }
  buf.to_string()
}

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#0d1117")
  renderer.enable_mouse()

  let root = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    background="#0d1117",
    padding=1,
    gap=1,
  )

  let header = @core.new_box(
    renderer,
    width="100%",
    height="3",
    background="#161b22",
    border=true,
    border_color="#50565d",
    padding=1,
  )
  header.add(
    @core.new_text(
      renderer,
      content="Keypress Debug — type anything · paste text · q: quit",
      fg="#58a6ff",
      attributes="bold",
    ),
  )
  root.add(header)

  let detail = @core.new_text(
    renderer,
    content="last event: (none)",
    fg="#7ee787",
  )
  root.add(detail)

  let log = @core.new_text(renderer, content="", fg="#c9d1d9")
  let log_box = @core.new_box(
    renderer,
    width="100%",
    flex_grow=1.0,
    background="#0d1117",
    border=true,
    border_color="#50565d",
    padding=1,
  )
  log_box.add(log)
  root.add(log_box)
  renderer.root().add(root)

  // 事件日志环（原版 120 条 + 滚动；这里保留最近 14 条）
  let max_lines = 14
  let lines : Array[String] = []
  let mut count = 0

  let push_line = fn(line : String) raise {
    if lines.length() >= max_lines {
      let _ = lines.remove(0)
    }
    lines.push(line)
    count = count + 1
    let buf = StringBuilder(size_hint=256)
    for i, l in lines {
      buf.write_string("\{count - lines.length() + i + 1}. ")
      buf.write_string(l)
      buf.write_string("\n")
    }
    let _ = log.set_content(buf.to_string())
    renderer.render()
  }

  renderer.on_key(fn(stroke) raise {
    let label = stroke_label(stroke)
    let _ = detail.set_content(
      "last event: key \"\{label}\" (name=\{stroke.name} ctrl=\{stroke.ctrl} shift=\{stroke.shift} meta=\{stroke.meta})",
    )
    push_line("key  \{label}")
    if stroke.name == "q" {
      renderer.stop()
    }
    if stroke.ctrl && stroke.name == "c" {
      renderer.stop()
    }
  })

  renderer.on_paste(fn(text) raise {
    let bytes = @utf8.encode(text).length()
    let preview = if text.length() > 40 {
      text.substring(start=0, end=40) + "…"
    } else {
      text
    }
    let _ = detail.set_content("last event: paste \{bytes} bytes")
    let one_line = preview
      .replace(old="\n", new="\\n")
      .replace(old="\r", new="\\r")
    push_line("paste \{bytes}B  \"\{one_line}\"")
  })

  renderer.render()
  renderer.run()
}
