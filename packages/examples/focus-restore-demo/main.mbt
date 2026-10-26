// 移植自 packages/examples/src/focus-restore-demo.ts：
// 鼠标全移动上报 + 焦点（focus/blur）事件计数。
// 验证方法：移动鼠标看坐标实时更新；Alt-Tab 切走再切回，
// focus/blur 计数应变化且鼠标跟踪立即恢复；q 退出。

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#101418")
  renderer.enable_mouse_motion()

  let root = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    background="#101418",
    padding=1,
    gap=1,
  )

  let header = @core.new_box(
    renderer,
    width="100%",
    height="3",
    background="#1b2129",
    border=true,
    border_color="#3ddc97",
    padding=1,
  )
  header.add(
    @core.new_text(
      renderer,
      content="Focus Restore Demo — move the mouse, alt-tab away and back",
      fg="#3ddc97",
      attributes="bold",
    ),
  )
  root.add(header)

  let mouse_text = @core.new_text(renderer, content="mouse: -", fg="#e6edf3")
  let focus_text = @core.new_text(
    renderer,
    content="focus: in=0 blur=0 · now focused",
    fg="#e6edf3",
  )
  let hint = @core.new_text(
    renderer,
    content="If mouse tracking stops after refocusing the window, the restore fix regressed.\nm=toggle motion mode · q: quit",
    fg="#8b949e",
  )
  for t in [mouse_text, focus_text, hint] {
    root.add(t)
  }
  renderer.root().add(root)

  let mut mouse_events = 0
  let mut focus_count = 0
  let mut blur_count = 0

  let render_mouse = fn(x : UInt32, y : UInt32) raise {
    let _ = mouse_text.set_content(
      "mouse: x=\{x} y=\{y} · events=\{mouse_events}",
    )
    renderer.render()
  }

  renderer.on_mouse(fn(mouse) raise {
    mouse_events = mouse_events + 1
    // 只在移动/拖动时刷新坐标展示，按下/滚轮另行标注
    if mouse.is_move() || mouse.is_drag() {
      render_mouse(mouse.x(), mouse.y())
    } else if mouse.is_down() {
      let _ = mouse_text.set_content(
        "mouse: down b\{mouse.button()} at \{mouse.x()},\{mouse.y()} · events=\{mouse_events}",
      )
      renderer.render()
    } else if mouse.is_scroll() {
      let _ = mouse_text.set_content(
        "mouse: scroll at \{mouse.x()},\{mouse.y()} · events=\{mouse_events}",
      )
      renderer.render()
    }
  })

  renderer.on_focus(fn(focused) raise {
    if focused {
      focus_count = focus_count + 1
    } else {
      blur_count = blur_count + 1
    }
    let _ = focus_text.set_content(
      "focus: in=\{focus_count} blur=\{blur_count} · now \{if focused { "focused" } else { "blurred" }}",
    )
    renderer.render()
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
