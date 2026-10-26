// 移植自 packages/examples/src/styled-text-demo.ts：
// StyledText 混排（每段独立颜色/属性），q 退出。

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#1a1a2e")
  let root = renderer.root()

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
      content="STYLED TEXT | q: quit",
      fg="#e94560",
      attributes="bold",
    ),
  )
  root.add(header)

  let panel = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0f3460",
    border=true,
    border_color="#533483",
    padding=1,
    flex_direction="column",
    gap=1,
  )
  root.add(panel)

  // 混排段落 1：彩虹单词
  let line1 = @core.new_text(renderer, content="")
  line1.set_styled_chunks([
    @core.Chunk::make(text="Moon", fg="#e94560", attributes=@core.ATTR_BOLD),
    @core.Chunk::make(text="Bit ", fg="#16c79a", attributes=@core.ATTR_BOLD),
    @core.Chunk::make(text="makes ", fg="#f0c987"),
    @core.Chunk::make(text="TUI ", fg="#7aa2f7"),
    @core.Chunk::make(
      text="native",
      fg="#c792ea",
      attributes=@core.ATTR_UNDERLINE,
    ),
    @core.Chunk::make(text=" again.", fg="#c0caf5"),
  ])
  panel.add(line1)

  // 混排段落 2：带背景高亮
  let line2 = @core.new_text(renderer, content="")
  line2.set_styled_chunks([
    @core.Chunk::make(
      text="styled",
      fg="#1a1b26",
      bg="#9ece6a",
      attributes=@core.ATTR_BOLD,
    ),
    @core.Chunk::make(text=" chunks ", fg="inherit"),
    @core.Chunk::make(text="share", fg="inherit"),
    @core.Chunk::make(text=" one ", fg="#1a1b26", bg="#e0af68"),
    @core.Chunk::make(text="text node.", fg="inherit"),
  ])
  panel.add(line2)

  // 纯色对照
  panel.add(
    @core.new_text(
      renderer,
      content="(plain text node for comparison)",
      fg="#565f89",
    ),
  )

  renderer.on_key(fn(stroke) {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
    }
  })

  renderer.render()
  renderer.run()
}
