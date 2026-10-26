// 交互式 keymap 示例：移植 OpenTUI keymap-demo 的核心理念。
// 使用 core 包的 TS 兼容层（Renderer/Box/Text），与
// `new BoxRenderable(renderer, {...})` 风格一一对应。
//
// 绑定（vim 风格）：
//   j / down    下一项        k / up     上一项
//   space       切换复选      g g        跳到第一项
//   G           跳到最后一项  q / ctrl+c 退出

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#1a1b26")
  let km = @keymap.Keymap::new()

  // 面板：border + 标题 + 菜单行 + 状态/帮助栏
  let panel = @core.new_box(
    renderer,
    border=true,
    border_color="#565f89",
    background="#16161e",
    align_items="stretch",
  )
  let title = @core.new_text(
    renderer,
    content="OpenTUI keymap demo (MoonBit FFI)",
    fg="#7aa2f7",
    attributes="bold",
    align="center",
  )
  panel.add(title)
  let labels = [
    "MoonBit FFI", "OpenTUI native", "keymap sequences", "raw terminal input", "vim-style bindings",
  ]
  let checked = [true, true, false, false, false]
  let rows : Array[@core.Renderable] = []
  for _label in labels {
    let row = @core.new_text(renderer)
    panel.add(row)
    rows.push(row)
  }
  let status = @core.new_text(renderer, content="", fg="#9ece6a")
  panel.add(status)
  let help = @core.new_text(
    renderer,
    content="j/k move   space toggle   g g top   G bottom   q quit",
    fg="#565f89",
  )
  panel.add(help)
  renderer.root().add(panel)

  let mut selected = 0
  fn redraw(status_text : String) -> Unit raise {
    for i, row in rows {
      let marker = if checked[i] { "[x]" } else { "[ ]" }
      let _ = row.set_content(" \{marker} \{labels[i]}")
      if i == selected {
        row.set_fg("#1a1b26")
        row.set_bg("#e0af68")
        row.set_attributes(@core.ATTR_BOLD)
      } else {
        row.set_fg("#c0caf5")
        row.set_bg("transparent")
        row.set_attributes(0)
      }
    }
    let _ = status.set_content(" \{status_text}")
    renderer.render()
  }

  redraw("ready — try \"g g\" (sequence), \"G\", space, q")

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
    @keymap.Binding::make("escape", "clear"),
  ])

  renderer.on_key(fn(stroke) raise {
    match km.handle_key(stroke) {
      @keymap.Ran(command) =>
        match command {
          "quit" => renderer.stop()
          "next" => {
            selected = (selected + 1) % labels.length()
            redraw("next")
          }
          "prev" => {
            selected = (selected + labels.length() - 1) % labels.length()
            redraw("prev")
          }
          "toggle" => {
            checked[selected] = !checked[selected]
            redraw("toggled \{labels[selected]}")
          }
          "top" => {
            selected = 0
            redraw("top")
          }
          "bottom" => {
            selected = labels.length() - 1
            redraw("bottom")
          }
          "clear" => km.clear_pending()
          _ => redraw("unhandled \{command}")
        }
      @keymap.Pending(parts) =>
        match parts.last() {
          Some(last) => redraw("sequence: \{last} … (esc cancels)")
          None => redraw("sequence …")
        }
      @keymap.Cleared(_) => redraw("sequence cleared")
      @keymap.Ignored => ()
    }
  })

  renderer.run()
}
