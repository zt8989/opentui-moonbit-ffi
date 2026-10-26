// 移植自 packages/examples/src/opacity-example.ts：
// 四层不同透明度的色块，按 1-4 切换对应层的透明度（1.0 ↔ 0.25）。

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
      content="OPACITY DEMO | 1-4: toggle opacity | q: quit",
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
    justify_content="space-evenly",
    align_items="center",
  )
  root.add(stage)

  // 四个色块，初始透明度 1.0，1 键 ↔ 第一块……
  let layers : Array[@core.Renderable] = []
  let opacities : Array[Bool] = [true, true, true, true]
  let colors = ["#e94560", "#16c79a", "#f0c987", "#7aa2f7"]
  for i, color in colors {
    let column = @core.new_box(
      renderer,
      width="14",
      height="8",
      background=color,
      border=true,
      border_color="#ffffff",
      align_items="center",
      justify_content="center",
    )
    column.add(
      @core.new_text(
        renderer,
        content="\{i + 1}",
        fg="#1a1a2e",
        attributes="bold",
      ),
    )
    stage.add(column)
    layers.push(column)
  }

  fn apply(index : Int32) -> Unit raise {
    let on = opacities[index]
    layers[index].set_opacity(if on { 1.0 } else { 0.25 })
    renderer.render()
  }

  renderer.on_key(fn(stroke) raise {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
      return
    }
    let target : Int32? = match stroke.name {
      "1" => Some(0)
      "2" => Some(1)
      "3" => Some(2)
      "4" => Some(3)
      _ => None
    }
    match target {
      Some(index) => {
        opacities[index] = !opacities[index]
        apply(index)
      }
      None => ()
    }
  })

  renderer.run()
}
