// keymap 包：解析与 dispatch 的单元测试（对齐原包测试语义的子集）。

///|
fn describe_stroke(token : String) -> String raise {
  @keymap.parse_stroke(token).display()
}

///|
test "parse_stroke：修饰符顺序无关且归一化" {
  let a = @keymap.parse_stroke("ctrl+shift+a")
  assert_eq(a.name, "a")
  assert_true(a.ctrl && a.shift && !a.meta)
  let b = @keymap.parse_stroke("Shift+CTRL+a")
  assert_eq(b.match_id(), a.match_id())
  let enter = @keymap.parse_stroke("return")
  assert_eq(enter.name, "enter")
  // 规范显示
  assert_eq(describe_stroke("shift+ctrl+a"), "ctrl+shift+a")
  assert_eq(describe_stroke("j"), "j")
}

///|
test "parse_binding_sequence：空格分隔序列" {
  let parts : Array[@keymap.KeyStroke] = @keymap.parse_binding_sequence("g g")
  assert_eq(parts.length(), 2)
  assert_eq(parts[0].name, "g")
  assert_eq(parts[1].name, "g")
}

///|
fn describe_dispatch(km : @keymap.Keymap, token : String) -> String raise {
  match km.handle_key(@keymap.KeyStroke::make(token)) {
    @keymap.Ran(cmd) => "ran:\{cmd}"
    @keymap.Pending(parts) => "pending:\{parts.length()}"
    @keymap.Cleared(_) => "cleared"
    @keymap.Ignored => "ignored"
  }
}

///|
test "单键 dispatch：匹配执行命令" {
  let km = @keymap.Keymap::new()
  let mut ran = ""
  km.on("quit", fn() { ran = "quit!" })
  km.bind(@keymap.Binding::make("q", "quit", description="Quit"))
  assert_eq(describe_dispatch(km, "q"), "ran:quit")
  assert_eq(ran, "quit!")
}

///|
test "序列 dispatch：g g 跳顶，中间态 Pending，不匹配清除后重试" {
  let km = @keymap.Keymap::new()
  km.bind(@keymap.Binding::make("g g", "top", description="Top"))
  km.bind(@keymap.Binding::make("q", "quit", description="Quit"))
  // 第一键进入 pending
  assert_eq(describe_dispatch(km, "g"), "pending:1")
  // 完成序列
  assert_eq(describe_dispatch(km, "g"), "ran:top")
  // 再次进入 pending 后按不匹配的 q：清除并执行 q 的绑定
  let _ = describe_dispatch(km, "g")
  assert_eq(describe_dispatch(km, "q"), "ran:quit")
}

///|
test "无匹配 Ignored" {
  let km = @keymap.Keymap::new()
  km.bind(@keymap.Binding::make("q", "quit"))
  assert_eq(describe_dispatch(km, "x"), "ignored")
}

///|
test "shift+g 与 g 不冲突" {
  let km = @keymap.Keymap::new()
  km.bind(@keymap.Binding::make("G", "bottom"))
  let mut bottom_ran = false
  km.on("bottom", fn() { bottom_ran = true })
  match km.handle_key(@keymap.parse_stroke("shift+g")) {
    @keymap.Ran(cmd) => assert_eq(cmd, "bottom")
    _ => fail("expected Ran(bottom)")
  }
  assert_true(bottom_ran)
  // 小写 g 无绑定
  assert_eq(describe_dispatch(km, "g"), "ignored")
}
