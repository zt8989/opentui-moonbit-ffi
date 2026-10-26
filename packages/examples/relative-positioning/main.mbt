// 移植自 packages/examples/src/relative-positioning-demo.ts：
// relative 与 absolute 定位。方向键移动 absolute 定位的浮动块；
// r 键在 relative/absolute 之间切换。

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
      content="RELATIVE POSITIONING | arrows: move float box | r: toggle mode | q: quit",
      fg="#e94560",
      attributes="bold",
    ),
  )
  root.add(header)

  let canvas = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0f3460",
    border=true,
    border_color="#533483",
  )
  canvas.add(
    @core.new_text(
      renderer,
      content=" canvas (relative children land in flow)",
      fg="#aebbf0",
    ),
  )
  root.add(canvas)

  // 浮动块：absolute 定位，位置由 top/left 属性记录驱动
  let float_box = @core.new_box(
    renderer,
    width="12",
    height="3",
    background="#e94560",
    border=true,
    border_color="#ffffff",
    position="absolute",
    top="4",
    left="4",
    z_index=10,
  )
  float_box.add(@core.new_text(renderer, content=" float", fg="#ffffff"))
  root.add(float_box)

  let mut top = 4.0
  let mut left = 4.0
  let mut absolute = true

  fn apply_position() -> Unit raise {
    float_box.update_style(fn(b, h) {
      b.set_position(h, "top", @core.ptd(top))
      b.set_position(h, "left", @core.ptd(left))
    })
  }

  renderer.on_key(fn(stroke) raise {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
      return
    }
    if stroke.name == "r" {
      absolute = !absolute
      float_box.update_style(fn(b, h) {
        b.set_position_type(h, if absolute { "absolute" } else { "relative" })
      })
      renderer.render()
      return
    }
    let step = 2.0
    match stroke.name {
      "up" => top = if top >= step { top - step } else { 0.0 }
      "down" => top = top + step
      "left" => left = if left >= step { left - step } else { 0.0 }
      "right" => left = left + step
      _ => return
    }
    apply_position()
    renderer.render()
  })

  renderer.run()
}
