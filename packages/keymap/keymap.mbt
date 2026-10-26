// Keymap：绑定注册 + 按键 dispatch（序列匹配采用原包 sync 决策：
// run-exact 优先于 continue-sequence；不匹配时清除 pending 并把当前键
// 作为新序列的第一键重试，等价于 escape-clears-pending-sequence 之外
// 的默认行为）。

///|
pub fn Keymap::new() -> Keymap {
  { bindings: [], handlers: {}, pending: [], pending_display: [], }
}

///|
/// 注册命令处理器。重复注册覆盖旧的。
pub fn Keymap::on(
  self : Keymap,
  command : String,
  handler : () -> Unit,
) -> Unit {
  self.handlers.set(command, handler)
}

///|
/// 注册一批绑定。
pub fn Keymap::register(self : Keymap, bindings : Array[Binding]) -> Unit raise {
  for entry in bindings {
    let parts = parse_binding_sequence(entry.key)
    self.bindings.push({
      command: entry.command,
      description: entry.description,
      parts,
    })
  }
}

///|
/// 快捷注册到 default 层。
pub fn Keymap::bind(self : Keymap, binding : Binding) -> Unit raise {
  self.register([binding])
}

///|
fn CompiledBinding::matches_at(
  self : CompiledBinding,
  index : Int32,
  stroke : KeyStroke,
) -> Bool {
  self.parts[index].match_id() == stroke.match_id()
}

///|
/// 处理一次按键。
pub fn Keymap::handle_key(self : Keymap, stroke : KeyStroke) -> DispatchResult {
  if self.pending.length() > 0 {
    return self.handle_key_in_pending(stroke)
  }
  self.match_fresh(stroke)
}

///|
/// pending 为空：以 stroke 作为序列第一键扫描全部绑定。
fn Keymap::match_fresh(self : Keymap, stroke : KeyStroke) -> DispatchResult {
  let mut exact : CompiledBinding? = None
  let continuing : Array[PendingCandidate] = []
  for b in self.bindings {
    if b.matches_at(0, stroke) {
      if b.parts.length() == 1 {
        // 后注册的同层绑定覆盖先注册的：保持最后一个 exact。
        exact = Some(b)
      } else {
        continuing.push({ binding: b, next: 1, })
      }
    }
  }
  match exact {
    // run-exact 优先于 continue-sequence
    Some(b) => self.run(b)
    None =>
      if continuing.length() > 0 {
        self.pending = continuing
        self.pending_display = [stroke.display()]
        Pending(self.pending_display.copy())
      } else {
        Ignored
      }
  }
}

///|
/// pending 非空：尝试把 stroke 接到每个候选的下一位置。
fn Keymap::handle_key_in_pending(
  self : Keymap,
  stroke : KeyStroke,
) -> DispatchResult {
  let mut exact : CompiledBinding? = None
  let continuing : Array[PendingCandidate] = []
  for candidate in self.pending {
    let b = candidate.binding
    if b.matches_at(candidate.next, stroke) {
      if candidate.next + 1 == b.parts.length() {
        exact = Some(b)
      } else {
        continuing.push({ binding: b, next: candidate.next + 1, })
      }
    }
  }
  match exact {
    Some(b) => {
      self.clear_pending()
      self.run(b)
    }
    None =>
      if continuing.length() > 0 {
        self.pending = continuing
        self.pending_display.push(stroke.display())
        Pending(self.pending_display.copy())
      } else {
        // 清除 pending，当前键按全新序列首键重试。
        let dropped = self.pending_display.copy()
        self.clear_pending()
        match self.match_fresh(stroke) {
          Ignored => Cleared(join_display(dropped))
          other => other
        }
      }
  }
}

///|
/// Escape 清除进行中的序列（原包 escape-clears-pending-sequence addon）。
pub fn Keymap::clear_pending(self : Keymap) -> Unit {
  self.pending = []
  self.pending_display = []
}

///|
fn join_display(parts : Array[String]) -> String {
  let buf = StringBuilder()
  for i, part in parts {
    if i > 0 {
      buf.write_string(" ")
    }
    buf.write_string(part)
  }
  buf.to_string()
}

///|
fn Keymap::run(self : Keymap, binding : CompiledBinding) -> DispatchResult {
  match self.handlers.get(binding.command) {
    Some(handler) => handler()
    None => ()
  }
  Ran(binding.command)
}

///|
/// 当前已注册命令的绑定说明（帮助栏用）：[(display, command, description)]。
pub fn Keymap::binding_help(self : Keymap) -> Array[(String, String, String)] {
  let rows : Array[(String, String, String)] = []
  let seen : Map[String, Bool] = Map([])
  for b in self.bindings {
    if seen.contains(b.command) {
      continue
    }
    seen.set(b.command, true)
    let display = join_display(b.parts.map(fn(p) { p.display() }))
    rows.push((display, b.command, b.description))
  }
  rows
}
