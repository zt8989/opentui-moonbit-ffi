// 移植自 packages/examples/src/nested-zindex-demo.ts：
// 嵌套盒子的 z-index 叠放。z 键循环交换三层盒子的 z-index。

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
      content="NESTED Z-INDEX | z: rotate z-index | q: quit",
      fg="#e94560",
      attributes="bold",
    ),
  )
  root.add(header)

  let stage = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0f3460",
    border=true,
    border_color="#533483",
    align_items="center",
    justify_content="center",
  )
  root.add(stage)

  // 三层叠加的盒子（尺寸递减，视觉上可辨叠放顺序）
  let layers : Array[@core.Renderable] = []
  let colors : Array[(String, String)] = [
    ("#e94560", "layer A"),
    ("#16c79a", "layer B"),
    ("#f0c987", "layer C"),
  ]
  for i, color in colors {
    let (bg, label) = color
    let box = @core.new_box(
      renderer,
      width=(20 - i * 4).to_string(),
      height="6",
      background=bg,
      border=true,
      border_color="#ffffff",
      align_items="center",
      justify_content="center",
      z_index=i,
    )
    box.add(
      @core.new_text(renderer, content=label, fg="#1a1a2e", attributes="bold"),
    )
    stage.add(box)
    layers.push(box)
  }
  // 用负 margin 让三层重叠（flex 列布局下彼此压住）
  layers[1].update_style(fn(b, h) { b.set_margin(h, "top", @core.ptd(-3.0)) })
  layers[2].update_style(fn(b, h) { b.set_margin(h, "top", @core.ptd(-3.0)) })

  let mut rotation = 0
  fn apply_z() -> Unit raise {
    // 三层 z-index 轮转：0,1,2 → 2,0,1 → 1,2,0
    for i, layer in layers {
      layer.set_z_index((i + rotation) % 3)
    }
    renderer.render()
  }

  renderer.on_key(fn(stroke) raise {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
      return
    }
    if stroke.name == "z" {
      rotation += 1
      apply_z()
    }
  })

  renderer.run()
}
