// 键名解析与规范显示（对应原包 services/keys.ts）。

///|
/// 修饰符按规范显示顺序；解析时顺序无关。
let modifier_names : Array[String] = ["ctrl", "shift", "meta", "super", "hyper"]

///|
pub fn KeyStroke::make(
  name : String,
  ctrl~ : Bool = false,
  shift~ : Bool = false,
  meta~ : Bool = false,
  super_~ : Bool = false,
  hyper~ : Bool = false,
) -> KeyStroke raise {
  // 单字符大写是 "shift+小写" 的语法糖（"G" 等价 "shift+g"）。
  if name.length() == 1 && !shift {
    let ch = name[0]
    if ch >= 'A' && ch <= 'Z' {
      return { name: name.to_lower(), ctrl, shift: true, meta, super_, hyper, }
    }
  }
  let normalized = normalize_key_name(name)
  { name: normalized, ctrl, shift, meta, super_, hyper, }
}

///|
fn normalize_key_name(name : String) -> String raise {
  let trimmed = name.trim(chars=" ").to_owned()
  if trimmed.length() == 0 {
    raise Failure("Invalid key name: key name cannot be empty")
  }
  // 原包 stringify 时把 return 显示为 enter；这里解析与显示统一。
  if trimmed == "return" {
    "enter"
  } else {
    trimmed.to_lower()
  }
}

///|
/// 解析单个 stroke："ctrl+shift+a"。修饰符顺序无关，末段是键名。
pub fn parse_stroke(token : String) -> KeyStroke raise {
  let trimmed = token.trim(chars=" ")
  if trimmed.length() == 0 {
    raise Failure("Invalid keymap stroke: empty token")
  }
  let segments = trimmed.split("+").collect()
  if segments.length() == 0 {
    raise Failure("Invalid keymap stroke: \"\{trimmed}\"")
  }
  let mut ctrl = false
  let mut shift = false
  let mut meta = false
  let mut super_ = false
  let mut hyper = false
  let last = segments.length() - 1
  for i, seg in segments {
    let part = seg.trim(chars=" ").to_lower().to_owned().to_string()
    if i == last {
      continue
    }
    if part == "ctrl" || part == "control" {
      ctrl = true
    } else if part == "shift" {
      shift = true
    } else if part == "meta" || part == "alt" || part == "option" {
      meta = true
    } else if part == "super" || part == "cmd" || part == "command" {
      super_ = true
    } else if part == "hyper" {
      hyper = true
    } else if part.length() == 0 {
      raise Failure("Invalid keymap stroke: empty modifier in \"\{trimmed}\"")
    } else {
      raise Failure("Unknown keymap modifier \"\{part}\" in \"\{trimmed}\"")
    }
  }
  // "<space>" 兼容写法
  let raw_name = segments.get(last).unwrap_or("").trim(chars=" ").to_owned()
  let name = if raw_name.length() >= 2 &&
    raw_name[0] == '<' &&
    raw_name[raw_name.length() - 1] == '>' {
    raw_name[1:raw_name.length() - 1].to_owned()
  } else {
    raw_name
  }
  KeyStroke::make(name, ctrl~, shift~, meta~, super_~, hyper~)
}

///|
/// 解析绑定串：空格分隔的 stroke 序列（"g g"、"ctrl+c"、"j"）。
/// 含 "+ " 的组合（如 "ctrl+a"）不受影响；字面空格键写作 "<space>"。
pub fn parse_binding_sequence(key : String) -> Array[KeyStroke] raise {
  let trimmed = key.trim(chars=" ")
  if trimmed.length() == 0 {
    raise Failure("Invalid keymap binding: empty key")
  }
  let tokens = trimmed.split(" ").collect()
  let parts : Array[KeyStroke] = []
  for token in tokens {
    let t = token.to_owned()
    if t.length() == 0 {
      continue
    }
    parts.push(parse_stroke(t))
  }
  if parts.length() == 0 {
    raise Failure("Invalid keymap binding: \"\{key}\"")
  }
  parts
}

///|
/// match id，对应 buildKeyMatchId：name:ctrl:shift:meta:super:hyper。
pub fn KeyStroke::match_id(self : KeyStroke) -> String {
  let b = (x : Bool) => if x { "1" } else { "0" }
  "\{self.name}:\{b(self.ctrl)}:\{b(self.shift)}:\{b(self.meta)}:\{b(self.super_)}:\{b(self.hyper)}"
}

///|
/// 规范显示：修饰符按 ctrl,shift,meta,super,hyper 顺序 + 键名。
pub fn KeyStroke::display(self : KeyStroke) -> String {
  let buf = StringBuilder()
  for modifier in modifier_names {
    let on = match modifier {
      "ctrl" => self.ctrl
      "shift" => self.shift
      "meta" => self.meta
      "super" => self.super_
      "hyper" => self.hyper
      _ => false
    }
    if on {
      buf.write_string(modifier)
      buf.write_char('\u{2b}')
    }
  }
  buf.write_string(self.name)
  buf.to_string()
}
