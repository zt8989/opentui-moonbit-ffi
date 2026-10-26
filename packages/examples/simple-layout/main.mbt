// 移植自 packages/examples/src/simple-layout-example.ts：
// flex 布局的四种形态（水平 / 垂直 / 居中 / 三列），按 1-4 切换。
// 原版通过重设 BoxRenderable 的布局属性实现；这里用 update_style
// 提交属性记录（等价 TS 的一次属性 setter 批量赋值）。

///|
let demo_names : Array[String] = [
  "Horizontal Layout", "Vertical Layout", "Centered Layout", "Three Column",
]

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
    @core.new_text(renderer, content="", fg="#e94560", attributes="bold"),
  )
  root.add(header)

  // 内容区：sidebar + main（列数随布局变化）
  let content = @core.new_box(renderer, flex_direction="row", flex_grow=1.0)
  let sidebar = @core.new_box(
    renderer,
    background="#0f3460",
    border=true,
    border_color="#e94560",
  )
  let sidebar_text = @core.new_text(renderer, content="sidebar", fg="#ffffff")
  sidebar.add(sidebar_text)
  let main = @core.new_box(
    renderer,
    background="#533483",
    border=true,
    border_color="#0f3460",
  )
  let main_text = @core.new_text(renderer, content="main content", fg="#ffffff")
  main.add(main_text)
  content.add(sidebar)
  content.add(main)
  root.add(content)

  let footer = @core.new_box(
    renderer,
    height="3",
    background="#16213e",
    border=true,
    align_items="center",
    justify_content="center",
  )
  footer.add(
    @core.new_text(
      renderer,
      content="1-4: switch layout   q: quit",
      fg="#aebbf0",
    ),
  )
  root.add(footer)

  // 重置三列布局时需要的第三列
  let right = @core.new_box(
    renderer,
    background="#0f3460",
    border=true,
    border_color="#e94560",
  )
  right.add(@core.new_text(renderer, content="right", fg="#ffffff"))
  right.set_display("none")
  content.add(right)

  fn description_of(index : Int32) -> String {
    match index {
      0 => "sidebar on left, main content on right"
      1 => "sidebar on top, main content below"
      2 => "content centered with margins"
      _ => "left sidebar, center content, right sidebar"
    }
  }

  fn apply_layout(index : Int32) -> Unit raise {
    let name = demo_names[index]
    header.children()[0].set_content(
      "SIMPLE LAYOUT: \{name} — \{description_of(index)}",
    )
    // 第三列仅在 Three Column 显示（display:none 不占布局）
    match index {
      0 => {
        // Horizontal：sidebar 固定 20 列，main 占满剩余
        sidebar.update_style(fn(b, h) {
          b.set_width(h, @core.pt(20))
          b.set_height(h, @core.pct(100))
        })
        main.update_style(fn(b, h) {
          b.set_width(h, @core.pct(100))
          b.set_height(h, @core.pct(100))
          b.set_flex_grow(h, 1.0)
        })
        right.set_display("none")
        content.update_style(fn(b, h) { b.set_flex_direction(h, "row") })
      }
      1 => {
        // Vertical：sidebar 在上，main 在下
        sidebar.update_style(fn(b, h) {
          b.set_width(h, @core.pct(100))
          b.set_height(h, @core.pt(6))
        })
        main.update_style(fn(b, h) {
          b.set_width(h, @core.pct(100))
          b.set_height(h, @core.pct(100))
          b.set_flex_grow(h, 1.0)
        })
        right.set_display("none")
        content.update_style(fn(b, h) { b.set_flex_direction(h, "column") })
      }
      2 => {
        // Centered：居中盒子 + 边距
        sidebar.update_style(fn(b, h) {
          b.set_width(h, @core.pt(30))
          b.set_height(h, @core.pt(8))
        })
        main.update_style(fn(b, h) {
          b.set_width(h, @core.pt(30))
          b.set_height(h, @core.pt(8))
        })
        right.set_display("none")
        content.update_style(fn(b, h) {
          b.set_flex_direction(h, "row")
          b.set_justify_content(h, "center")
          b.set_align_items(h, "center")
        })
      }
      _ => {
        // Three Column：三等分
        sidebar.update_style(fn(b, h) {
          b.set_width(h, @core.pct(33))
          b.set_height(h, @core.pct(100))
        })
        main.update_style(fn(b, h) {
          b.set_width(h, @core.pct(34))
          b.set_height(h, @core.pct(100))
        })
        right.update_style(fn(b, h) {
          b.set_width(h, @core.pct(33))
          b.set_height(h, @core.pct(100))
        })
        right.set_display("flex")
        content.update_style(fn(b, h) { b.set_flex_direction(h, "row") })
      }
    }
    renderer.render()
  }

  let mut current = 0
  apply_layout(0)

  renderer.on_key(fn(stroke) raise {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
      return
    }
    let next : Int32? = match stroke.name {
      "1" => Some(0)
      "2" => Some(1)
      "3" => Some(2)
      "4" => Some(3)
      _ => None
    }
    match next {
      Some(index) => {
        current = index
        apply_layout(current)
      }
      None => ()
    }
  })

  renderer.run()
}
