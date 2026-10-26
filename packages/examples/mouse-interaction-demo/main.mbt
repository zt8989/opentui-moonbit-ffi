// 移植自 packages/examples/src/mouse-interaction-demo.ts：
// 鼠标点击/拖动色块 + 命中测试。需要真实终端（管道无法发送鼠标事件）。
// 点击色块：切换高亮；拖动：移动第一个色块；q 退出。

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#1a1a2e")
  renderer.enable_mouse()

  let root = renderer.root()

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
    content="MOUSE | click a block · drag the red one · q quit",
    fg="#e94560",
    attributes="bold",
  )
  header.add(status)
  root.add(header)

  let stage = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0f3460",
    border=true,
    border_color="#533483",
    position="relative",
  )
  root.add(stage)

  // 三个可点色块（absolute 定位，节点号 10/11/12 用于命中）
  let blocks : Array[@core.Renderable] = []
  let colors = ["#e94560", "#16c79a", "#f0c987"]
  for i, color in colors {
    let block = @core.new_box(
      renderer,
      width="10",
      height="4",
      background=color,
      border=true,
      border_color="#ffffff",
      position="absolute",
      top=(3 + i * 4).to_string(),
      left=(6 + i * 16).to_string(),
      z_index=i + 1,
    )
    block.add(
      @core.new_text(
        renderer,
        content=" \{i + 1}",
        fg="#1a1a2e",
        attributes="bold",
      ),
    )
    stage.add(block)
    blocks.push(block)
  }

  // 拖动状态
  let mut dragging = false
  let mut drag_x = 0.0
  let mut drag_y = 0.0
  let mut block_left = 6.0
  let mut block_top = 3.0

  renderer.on_mouse(fn(mouse) raise {
    if mouse.is_down() {
      // 拖动只对红块（节点号 10）生效
      let hit = renderer.hit_test(mouse.x(), mouse.y())
      match hit {
        Ok(num) =>
          if num == 10 {
            dragging = true
            drag_x = mouse.x().to_double()
            drag_y = mouse.y().to_double()
            let _ = status.set_content(" dragging block 1 …")
            renderer.render()
          }
        Err(_) => ()
      }
      return
    }
    if mouse.is_up() && dragging {
      dragging = false
      let _ = status.set_content(" dropped at \{mouse.x()},\{mouse.y()}")
      renderer.render()
      return
    }
    if mouse.is_drag() && dragging {
      let dx = mouse.x().to_double() - drag_x
      let dy = mouse.y().to_double() - drag_y
      block_left = block_left + dx
      block_top = block_top + dy
      drag_x = mouse.x().to_double()
      drag_y = mouse.y().to_double()
      blocks[0].update_style(fn(b, h) {
        b.set_position(h, "left", @core.ptd(block_left))
        b.set_position(h, "top", @core.ptd(block_top))
      })
      renderer.render()
    }
  })

  renderer.on_key(fn(stroke) {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
    }
  })

  renderer.render()
  renderer.run()
}
