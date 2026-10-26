// 移植自 packages/examples/src/notification-demo.ts：
// ot_session_notification 触发系统/终端通知。
// 原版用 ScrollBox 列出动作；这里动作为固定 6 条，改为面板内文本行。
// 返回 false / 状态 0 表示当前终端不支持通知协议。

///|
struct Action {
  key : String
  title : String
  subtitle : String
  message : String
  notify_title : String
}

///|
let actions : Array[Action] = [
  {
    key: "1",
    title: "Quick ping",
    subtitle: "Body-only notification",
    message: "OpenTUI notification ping delivered.",
    notify_title: "",
  },
  {
    key: "2",
    title: "Build complete",
    subtitle: "Title and body",
    message: "The example build finished successfully.",
    notify_title: "OpenTUI build",
  },
  {
    key: "3",
    title: "Needs review",
    subtitle: "Longer body text",
    message: "The generated diff is ready for your review.",
    notify_title: "Review requested",
  },
  {
    key: "4",
    title: "Deployment",
    subtitle: "Operational message",
    message: "Deployment to staging completed in 42s.",
    notify_title: "",
  },
  {
    key: "5",
    title: "Failure",
    subtitle: "Error path",
    message: "Tests failed on shard 3 of 4.",
    notify_title: "CI alert",
  },
  {
    key: "6",
    title: "Plain",
    subtitle: "No title, plain text",
    message: "Plain body without a notification title.",
    notify_title: "",
  },
]

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#08111f")

  let root = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    background="#08111f",
    padding=1,
    gap=1,
  )

  let header = @core.new_box(
    renderer,
    width="100%",
    height="3",
    background="#0f1b2d",
    border=true,
    border_color="#223553",
    padding=1,
  )
  header.add(
    @core.new_text(
      renderer,
      content="Notifications — press 1-6 to send · s: last result · q: quit",
      fg="#22d3ee",
      attributes="bold",
    ),
  )
  root.add(header)

  // 动作列表（原版为 ScrollBox，这里动作固定，直接排文本行）
  let list = @core.new_box(
    renderer,
    width="100%",
    flex_grow=1.0,
    background="#0f1b2d",
    border=true,
    border_color="#223553",
    padding=1,
    gap=0,
  )
  for action in actions {
    list.add(
      @core.new_text(
        renderer,
        content="\{action.key}  \{action.title} — \{action.subtitle}",
        fg="#d7e3f7",
      ),
    )
  }
  root.add(list)

  let status = @core.new_text(
    renderer,
    content="ready — notifications require terminal support",
    fg="#7d8da8",
  )
  root.add(status)
  renderer.root().add(root)

  let send = fn(action : Action) raise {
    let sent = renderer.notify(
      message=action.message,
      title=action.notify_title,
    )
    let _ = status.set_content(
      "[\{action.key}] \{action.title} → \{if sent { "sent" } else { "unsupported by this terminal" }}",
    )
    renderer.render()
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "1" => send(actions[0])
      "2" => send(actions[1])
      "3" => send(actions[2])
      "4" => send(actions[3])
      "5" => send(actions[4])
      "6" => send(actions[5])
      "q" => renderer.stop()
      "c" => if stroke.ctrl { renderer.stop() }
      _ => ()
    }
  })

  renderer.render()
  renderer.run()
}
