// 移植自 packages/examples/src/link-demo.ts：
// 富文本超链接（OT_SCENE_TEXT_LINK + URL 表）+ 点击解析。
// 原版点击后用 node:child_process 打开浏览器；MoonBit 侧无子进程 API，
// 点击后在状态栏显示解析出的 URL（验证 get_link_id / get_link_url 链路）。

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#0f111a")
  renderer.enable_mouse()

  let root = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    background="#0f111a",
    padding=1,
    gap=1,
  )

  let header = @core.new_box(
    renderer,
    width="100%",
    height="3",
    background="#151b2e",
    border=true,
    border_color="#7aa2f7",
    padding=1,
  )
  header.add(
    @core.new_text(
      renderer,
      content="Link Demo — ctrl+click / click a link below",
      fg="#7aa2f7",
      attributes="bold",
    ),
  )
  root.add(header)

  // 富文本链接：url 非空的 chunk 生成原生链接（带 LINK 标志 + URL 表）
  let links = @core.new_text(renderer, content="", fg="#c0caf5")
  links.set_styled_chunks([
    @core.Chunk::make(text="Docs: ", fg="#565f89"),
    @core.Chunk::make(
      text="opentui.com",
      fg="#7aa2f7",
      attributes=@core.ATTR_UNDERLINE,
      url="https://opentui.com/docs/",
    ),
    @core.Chunk::make(text="  ·  ", fg="#565f89"),
    @core.Chunk::make(
      text="MoonBit",
      fg="#9ece6a",
      attributes=@core.ATTR_UNDERLINE,
      url="https://www.moonbitlang.com/",
    ),
    @core.Chunk::make(text="\nRepo: ", fg="#565f89"),
    @core.Chunk::make(
      text="anomalyco/opentui",
      fg="#bb9af7",
      attributes=@core.ATTR_UNDERLINE,
      url="https://github.com/anomalyco/opentui",
    ),
    @core.Chunk::make(text="  ·  ", fg="#565f89"),
    @core.Chunk::make(text="plain text (no link)", fg="#c0caf5"),
  ])
  root.add(links)

  let status = @core.new_text(
    renderer,
    content="no link clicked yet",
    fg="#9aa5ce",
  )
  root.add(status)

  let help = @core.new_text(
    renderer,
    content="点击链接段落在状态栏显示 URL · 拖动下方色块 · q: quit",
    fg="#565f89",
  )
  root.add(help)

  // 可拖动色块（节点号 10，对应原版的 DraggableBox）
  let stage = @core.new_box(
    renderer,
    width="100%",
    height="6",
    background="#111624",
    border=true,
    border_color="#292e42",
    position="relative",
  )
  let block = @core.new_box(
    renderer,
    width="8",
    height="3",
    background="#e94560",
    border=true,
    border_color="#ffffff",
    position="absolute",
    top="1",
    left="2",
    z_index=100,
  )
  block.add(
    @core.new_text(renderer, content="drag", fg="#1a1a2e", attributes="bold"),
  )
  stage.add(block)
  root.add(stage)
  renderer.root().add(root)

  let mut dragging = false
  let mut drag_x = 0.0
  let mut drag_y = 0.0
  let mut block_left = 2.0
  let mut block_top = 1.0

  renderer.on_mouse(fn(mouse) raise {
    if mouse.is_down() {
      // 先查链接：命中链接时显示 URL，否则进入色块拖动
      match renderer.link_url_at(mouse.x(), mouse.y()) {
        Some(url) => {
          let _ = status.set_content("clicked link → \{url}")
          renderer.render()
          return
        }
        None => ()
      }
      match renderer.hit_test(mouse.x(), mouse.y()) {
        Ok(num) =>
          if num == 10 {
            dragging = true
            drag_x = mouse.x().to_double()
            drag_y = mouse.y().to_double()
          }
        Err(_) => ()
      }
      return
    }
    if mouse.is_up() {
      dragging = false
      return
    }
    if mouse.is_drag() && dragging {
      block_left = block_left + mouse.x().to_double() - drag_x
      block_top = block_top + mouse.y().to_double() - drag_y
      drag_x = mouse.x().to_double()
      drag_y = mouse.y().to_double()
      block.update_style(fn(b, h) {
        b.set_position(h, "left", @core.ptd(block_left))
        b.set_position(h, "top", @core.ptd(block_top))
      })
      renderer.render()
    }
  })

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" => renderer.stop()
      "c" => if stroke.ctrl { renderer.stop() }
      _ => ()
    }
  })

  renderer.render()
  renderer.run()
}
