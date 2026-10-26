// 移植自 packages/examples/src/tab-select-demo.ts：
// 顶部标签条（左右键切 tab），下方内容区显示当前标签内容。

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#1a1a2e")
  let km = @keymap.Keymap::new()

  let tabs = ["Home", "Files", "Settings", "About"]
  let contents = [
    "Welcome to the tab-select demo.\nTabs are just text nodes driven by keymap.",
    "Files tab: use h/l or left/right to switch tabs.", "Settings tab: everything renders through the native scene.",
    "About tab: MoonBit FFI + OpenTUI native renderer.",
  ]

  let header = @core.new_box(
    renderer,
    height="3",
    background="#16213e",
    border=true,
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="TAB SELECT | h/l or ←/→ switch · q quit",
      fg="#e94560",
      attributes="bold",
    ),
  )
  renderer.root().add(header)

  // 标签条
  let tabbar = @core.new_box(
    renderer,
    flex_direction="row",
    background="#16161e",
    align_items="center",
  )
  renderer.root().add(tabbar)
  let tab_texts : Array[@core.Renderable] = []
  for _t in tabs {
    let tab = @core.new_text(renderer, width="12", align="center")
    tabbar.add(tab)
    tab_texts.push(tab)
  }

  // 内容区
  let content = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0f3460",
    border=true,
    border_color="#533483",
    padding=1,
  )
  let body = @core.new_text(renderer, content="", fg="#c0caf5")
  content.add(body)
  renderer.root().add(content)

  let mut active = 0
  fn redraw() -> Unit raise {
    for i, tab in tab_texts {
      let _ = tab.set_content(
        if i == active {
          "[ \{tabs[i]} ]"
        } else {
          "  \{tabs[i]}  "
        },
      )
      if i == active {
        tab.set_fg("#1a1b26")
        tab.set_bg("#7aa2f7")
        tab.set_attributes(@core.ATTR_BOLD)
      } else {
        tab.set_fg("#565f89")
        tab.set_bg("transparent")
        tab.set_attributes(0)
      }
    }
    let _ = body.set_content(contents[active])
    renderer.render()
  }
  redraw()

  km.register([
    @keymap.Binding::make("l", "next-tab"),
    @keymap.Binding::make("right", "next-tab"),
    @keymap.Binding::make("h", "prev-tab"),
    @keymap.Binding::make("left", "prev-tab"),
    @keymap.Binding::make("q", "quit"),
    @keymap.Binding::make("ctrl+c", "quit"),
  ])

  renderer.on_key(fn(stroke) raise {
    match km.handle_key(stroke) {
      @keymap.Ran(command) =>
        match command {
          "quit" => renderer.stop()
          "next-tab" => {
            active = (active + 1) % tabs.length()
            redraw()
          }
          "prev-tab" => {
            active = (active + tabs.length() - 1) % tabs.length()
            redraw()
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
