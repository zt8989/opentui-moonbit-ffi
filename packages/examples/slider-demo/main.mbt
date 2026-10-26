// 移植自 packages/examples/src/slider-demo.ts：
// SliderRenderable（原生 slider 节点）。←/→ 调整值，↑/↓ 大步进。

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
      content="SLIDER | ←/→ ±1 · ↑/↓ ±10 · q quit",
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
    align_items="center",
    justify_content="center",
    gap=1,
  )
  root.add(panel)

  let slider = @core.new_slider(
    renderer,
    orientation="horizontal",
    min=0.0,
    max=100.0,
    value=50.0,
    width="40",
    height="1",
    fg="#e94560",
    bg="#16213e",
  )
  panel.add(slider)

  let readout = @core.new_text(
    renderer,
    content="value: 50",
    fg="#c0caf5",
    align="center",
  )
  panel.add(readout)

  let mut value = 50.0
  fn clamp(v : Double) -> Double {
    if v < 0.0 {
      0.0
    } else if v > 100.0 {
      100.0
    } else {
      v
    }
  }

  renderer.on_key(fn(stroke) raise {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
      return
    }
    let delta : Double? = match stroke.name {
      "right" => Some(1.0)
      "left" => Some(-1.0)
      "up" => Some(10.0)
      "down" => Some(-10.0)
      _ => None
    }
    match delta {
      Some(d) => {
        value = clamp(value + d)
        let _ = slider.set_slider_value(value~, min=0.0, max=100.0)
        let _ = readout.set_content("value: \{value}")
        renderer.render()
      }
      None => ()
    }
  })

  renderer.render()
  renderer.run()
}
