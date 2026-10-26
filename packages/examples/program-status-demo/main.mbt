// 移植自 packages/examples/src/program-status-demo.ts：
// OSC 7501 程序状态上报。按键 1-6 发送不同状态的报告，
// 切到其他终端标签页/窗口可看到终端如何展示状态（需终端支持 OSC 7501）。

///|
fn make_report(
  state : UInt32,
  kind : UInt32,
  progress : Bool,
  progress_value : UInt32,
  message : String,
) -> @core.ProgramStatusReport raise {
  @core.ProgramStatusReport::make(
    state~,
    blocked_kind=kind,
    progress~,
    progress_value~,
    app="opentui-demo",
    message~,
  )
}

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#0d1117")

  let body = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    background="#0d1117",
    padding=1,
    gap=1,
  )
  let text = @core.new_text(renderer, content="", fg="#e6edf3")
  body.add(text)
  renderer.root().add(body)

  let mut last = "none"

  let update = fn() raise {
    let _ = text.set_content(
      "Last report: \{last}\n\n1  idle\n2  working 40%\n3  blocked on permission\n4  done\n5  error\n6  clear\n\nSwitch to another tab or window to see how the terminal shows the status.\nq: quit",
    )
    renderer.render()
  }

  let report = fn(last_label : String, r : @core.ProgramStatusReport) raise {
    renderer.report_program_status(r)
    last = last_label
    update()
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "1" =>
        report(
          "idle",
          make_report(
            @core.OT_PROGRAM_STATE_IDLE,
            0,
            false,
            0,
            "Waiting for input",
          ),
        )
      "2" =>
        report(
          "working 40%",
          make_report(@core.OT_PROGRAM_STATE_WORKING, 0, true, 40, "Building"),
        )
      "3" =>
        report(
          "blocked on permission",
          make_report(
            @core.OT_PROGRAM_STATE_BLOCKED,
            @core.OT_PROGRAM_KIND_PERMISSION,
            false,
            0,
            "Deploy to production?",
          ),
        )
      "4" =>
        report(
          "done",
          make_report(
            @core.OT_PROGRAM_STATE_DONE,
            0,
            false,
            0,
            "Build finished",
          ),
        )
      "5" =>
        report(
          "error",
          make_report(@core.OT_PROGRAM_STATE_ERROR, 0, false, 0, "Build failed"),
        )
      "6" =>
        report(
          "clear",
          make_report(@core.OT_PROGRAM_STATE_CLEAR, 0, false, 0, ""),
        )
      "q" => renderer.stop()
      "c" => if stroke.ctrl { renderer.stop() }
      _ => ()
    }
  })

  update()
  renderer.run()
}
