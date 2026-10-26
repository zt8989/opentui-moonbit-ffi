// 移植自 packages/examples/src/input-demo.ts（简化实现）：
// 单行输入组件 = MoonBit 侧 Input 结构（封装 EditBuffer/EditorView 单行
// 视口 + placeholder + maxLength），Tab 切换字段，输入回显到状态栏。
// q 退出。OT_HEADLESS=1 渲染一帧后退出。

///|
#borrow(name)
extern "C" fn getenv_ffi(name : Bytes) -> Int64 = "getenv"

///|
#borrow(path, mode)
extern "C" fn fopen_ffi(path : Bytes, mode : Bytes) -> Int64 = "fopen"

///|
#borrow(buf)
extern "C" fn fwrite_ffi(
  buf : FixedArray[Byte],
  size : UInt64,
  count : UInt64,
  file : Int64,
) -> UInt64 = "fwrite"

///|
extern "C" fn fclose_ffi(file : Int64) -> Int32 = "fclose"

///|
fn write_info(path : String, lines : Array[String]) -> Unit {
  let file = fopen_ffi(@utf8.encode(path), b"w")
  if file == 0L {
    return
  }
  for line in lines {
    let bytes = @utf8.encode(line + "\n")
    let fa : FixedArray[Byte] = FixedArray::make(bytes.length(), 0)
    for i in 0..<bytes.length() {
      fa[i] = bytes[i]
    }
    let _ = fwrite_ffi(fa, 1UL, bytes.length().to_uint64(), file)
  }
  let _ = fclose_ffi(file)
}

///|
/// 单行输入（MoonBit 侧组件：数据在 EditBuffer，视口固定 1 行）。
pub struct Input {
  buffer : @core.EditBuffer
  view : @core.EditorView
  node : @core.Renderable
  placeholder : String
  max_length : Int
  mut focused : Bool
}

///|
/// 创建单行输入。
pub fn Input::create(
  renderer : @core.Renderer,
  width~ : Int,
  placeholder~ : String = "",
  max_length~ : Int = 200,
) -> Input raise {
  let buffer = @core.EditBuffer::create(renderer)
  let view = @core.EditorView::create(renderer, buffer, width=width.reinterpret_as_uint(), height=1)
  view.set_placeholder(text=placeholder)
  let node = @core.new_editor(
    renderer,
    view,
    width="\{width}",
    height="1",
    position="relative",
    show_cursor=true,
  )
  { buffer, view, node, placeholder, max_length, focused: false }
}

///|
pub fn Input::node(self : Input) -> @core.Renderable {
  self.node
}

///|
pub fn Input::set_focused(self : Input, focused~ : Bool) -> Unit raise {
  self.focused = focused
  // 聚焦高亮：底色变化
  self.node.set_background(if focused { "#1a2332" } else { "transparent" })
}

///|
/// 插入可打印字符（maxLength 限制）。
pub fn Input::insert(self : Input, ch : String) -> Unit raise {
  let len = self.buffer.get_info().cursor_offset()
  if len < self.max_length {
    let _ = self.view.replace_selection(text=ch)
  }
}

///|
/// 退格。
pub fn Input::backspace(self : Input) -> Unit raise {
  if self.view.get_selection().selection_present() {
    self.view.command(command=@core.OT_EDITOR_DELETE_SELECTION)
  } else {
    self.buffer.command(command=@core.OT_EDIT_BACKSPACE)
  }
}

///|
/// 当前文本。
pub fn Input::text(self : Input) -> String raise {
  self.buffer.get_text()
}

///|
fn main raise {
  let headless = getenv_ffi(b"OT_HEADLESS") != 0
  let renderer = @core.Renderer::create(background="#0D1117")
  let root = renderer.root()

  let header = @core.new_box(
    renderer,
    height="3",
    border=true,
    border_style="double",
    border_color="#FFCC00",
    background="#0D1117",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="Input Demo (Tab switch · type · Enter submit)",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  let form = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    background="#0D1117",
    padding=1,
    gap=1,
  )

  let fields : Array[Input] = []
  let labels = ["name", "email", "comment"]
  for i, label in labels {
    form.add(
      @core.new_text(
        renderer,
        content="\{label}:",
        fg="#8b949e",
      ),
    )
    let input = Input::create(
      renderer,
      width=40,
      placeholder="your \{label} here…",
      max_length=60,
    )
    form.add(input.node())
    fields.push(input)
  }
  root.add(form)

  let status = @core.new_text(
    renderer,
    content="tab/shift+tab: switch · enter: submit · q quit",
    fg="#8b949e",
  )
  root.add(status)

  let mut active = 0
  let refresh_focus = fn() raise {
    for i, input in fields {
      input.set_focused(focused=i == active)
    }
    let _ = status.set_content(
      " [\{labels[active]}] \"\{fields[active].text()}\" · tab: next · enter: submit · q quit",
    )
  }
  refresh_focus()

  if headless {
    // 预填字段验证组件逻辑
    for i, ch in ["ada", "ada@example.com", "hi"] {
      for c in ch {
        fields[i].insert(c.to_string())
      }
    }
    refresh_focus()
    renderer.render()
    write_info(
      "input-demo-info.txt",
      [
        "name=\{fields[0].text()}",
        "email=\{fields[1].text()}",
        "comment=\{fields[2].text()}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      "tab" => {
        active = if stroke.shift {
          (active + fields.length() - 1) % fields.length()
        } else {
          (active + 1) % fields.length()
        }
        refresh_focus()
        renderer.render()
      }
      "enter" => {
        let values : Array[String] = []
        for input in fields {
          values.push(input.text())
        }
        let _ = status.set_content(
          " submitted: \{values[0]} <\{values[1]}> \{values[2]}",
        )
        renderer.render()
      }
      "backspace" => {
        fields[active].backspace()
        refresh_focus()
        renderer.render()
      }
      _ => {
        if stroke.name.length() == 1 && !stroke.ctrl && !stroke.meta {
          fields[active].insert(stroke.name)
          refresh_focus()
          renderer.render()
        }
      }
    }
  })

  renderer.run()
}
