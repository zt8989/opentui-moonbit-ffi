// 移植自 packages/examples/src/select-demo.ts：
// SelectRenderable 的行为用列表 + keymap 重建（选中高亮 + Enter 确认）。

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#1a1a2e")
  let km = @keymap.Keymap::new()

  let header = @core.new_box(
    renderer,
    height="3",
    background="#16213e",
    border=true,
    align_items="center",
    justify_content="center",
  )
  let status = @core.new_text(
    renderer,
    content="SELECT | j/k move · enter select · q quit",
    fg="#e94560",
    attributes="bold",
  )
  header.add(status)
  renderer.root().add(header)

  let panel = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0f3460",
    border=true,
    border_color="#533483",
    padding=1,
    gap=0,
  )
  renderer.root().add(panel)

  let options = ["MoonBit", "Rust", "TypeScript", "Zig", "Go"]
  let rows : Array[@core.Renderable] = []
  for _opt in options {
    let row = @core.new_text(renderer)
    panel.add(row)
    rows.push(row)
  }

  let footer = @core.new_box(
    renderer,
    height="3",
    background="#16213e",
    border=true,
    align_items="center",
  )
  let confirmed = @core.new_text(
    renderer,
    content=" selected: (none)",
    fg="#9ece6a",
  )
  footer.add(confirmed)
  renderer.root().add(footer)

  let mut selected = 0
  fn redraw() -> Unit raise {
    for i, row in rows {
      let _ = row.set_content(
        " \{if i == selected { "▶ " } else { "  " }}\{options[i]}",
      )
      if i == selected {
        row.set_fg("#1a1b26")
        row.set_bg("#7aa2f7")
        row.set_attributes(@core.ATTR_BOLD)
      } else {
        row.set_fg("#c0caf5")
        row.set_bg("transparent")
        row.set_attributes(0)
      }
    }
    renderer.render()
  }
  redraw()

  km.register([
    @keymap.Binding::make("j", "next"),
    @keymap.Binding::make("down", "next"),
    @keymap.Binding::make("k", "prev"),
    @keymap.Binding::make("up", "prev"),
    @keymap.Binding::make("enter", "confirm"),
    @keymap.Binding::make("q", "quit"),
    @keymap.Binding::make("ctrl+c", "quit"),
  ])

  renderer.on_key(fn(stroke) raise {
    match km.handle_key(stroke) {
      @keymap.Ran(command) =>
        match command {
          "quit" => renderer.stop()
          "next" => {
            selected = (selected + 1) % options.length()
            redraw()
          }
          "prev" => {
            selected = (selected + options.length() - 1) % options.length()
            redraw()
          }
          "confirm" => {
            let _ = confirmed.set_content(" selected: \{options[selected]}")
            renderer.render()
          }
          _ => ()
        }
      @keymap.Pending(_) => ()
      @keymap.Cleared(_) => ()
      @keymap.Ignored => ()
    }
  })

  renderer.run()
}
