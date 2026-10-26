// 移植自 packages/examples/src/terminal-title.ts：
// 通过 OSC 控制包循环设置终端窗口标题。
// 原版用 setTimeout 定时轮换；MoonBit 侧无定时器基础设施，
// 改为按键切换（1/2/3 直接设置，空格循环，Esc 恢复默认）。

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#0d1117")
  let titles = ["OpenTUI Test", "Terminal Title Demo", "Success!"]
  let mut index = 0

  let body = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    justify_content="center",
    align_items="center",
    background="#0d1117",
  )
  let text = @core.new_text(
    renderer,
    content="Cycling terminal titles...\n\n1/2/3: set title · space: cycle · Esc: reset · q: quit",
    fg="#e6edf3",
    align="center",
  )
  body.add(text)
  renderer.root().add(body)

  let set_title = fn(i : Int32) raise {
    index = i
    let title = titles[index]
    renderer.set_terminal_title(title)
    let _ = text.set_content(
      "Current terminal title: \{title}\n\n1/2/3: set title · space: cycle · Esc: reset · q: quit",
    )
    renderer.render()
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "1" => set_title(0)
      "2" => set_title(1)
      "3" => set_title(2)
      "space" => set_title((index + 1) % titles.length())
      "escape" =>
        // 空标题恢复终端默认标题行为
        renderer.set_terminal_title("")
      "q" => renderer.stop()
      "c" => if stroke.ctrl { renderer.stop() }
      _ => ()
    }
  })

  set_title(0)
  renderer.run()
}
