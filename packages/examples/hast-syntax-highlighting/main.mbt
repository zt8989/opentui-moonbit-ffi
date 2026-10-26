// 移植自 packages/examples/src/hast-syntax-highlighting-demo.ts（简化实现）：
// HAST（Hypertext Abstract Syntax Tree）→ 富文本 chunk 的转换演示。
// TS 版用 hastToStyledText + 完整 hljs 类名映射；这里内嵌一棵等价的
// HAST 树（className → 样式名），转换器走 TextBuffer::set_styled_text
// （富文本 + 链接通道）与 Text 节点的 set_styled_chunks 两条路径。
// r 重新转换，q 退出。OT_HEADLESS=1 渲染一帧后退出。

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
/// HAST 节点：元素（带 hljs 类名）或文本。
enum HastNode {
  HastText(String)
  HastElement(HastElement)
}

///|
struct HastElement {
  class_name : String
  children : Array[HastNode]
}

///|
/// hljs 类名 → 内部样式名。
fn style_of_class(class_name : String) -> String {
  if class_name.contains("hljs-keyword") {
    "keyword"
  } else if class_name.contains("hljs-string") {
    "string"
  } else if class_name.contains("hljs-comment") {
    "comment"
  } else if class_name.contains("hljs-number") {
    "number"
  } else if class_name.contains("hljs-function") || class_name.contains("hljs-title") {
    "function"
  } else if class_name.contains("hljs-type") || class_name.contains("hljs-built_in") {
    "type"
  } else {
    ""
  }
}

///|
/// 深度优先转换：文本节点继承最近元素的类名样式。
fn hast_to_chunks(node : HastNode, style : String, chunks : Array[@core.Chunk]) -> Unit {
  match node {
    HastText(t) => {
      if t != "" {
        chunks.push(@core.Chunk::make(text=t, fg=style_color(style)))
      }
    }
    HastElement(el) => {
      let inner = style_of_class(el.class_name)
      let inner = if inner == "" { style } else { inner }
      for child in el.children {
        hast_to_chunks(child, inner, chunks)
      }
    }
  }
}

///|
/// 样式名 → 颜色（与 SyntaxStyle 注册表一致）。
fn style_color(style : String) -> String {
  match style {
    "keyword" => "#FF6B9D"
    "string" => "#A8E6CF"
    "comment" => "#6A9955"
    "number" => "#FFB86C"
    "function" => "#82AAFF"
    "type" => "#4ECDC4"
    _ => "#e6edf3"
  }
}

///|
/// 内嵌 HAST 示例（对应 assets/hast-example.json 的精简版，一段 TS 代码）。
fn example_hast() -> HastElement {
  {
    class_name: "hljs",
    children: [
      HastElement({
        class_name: "hljs-keyword",
        children: [HastText("interface")],
      }),
      HastText(" "),
      HastElement({
        class_name: "hljs-title",
        children: [HastText("Point")],
      }),
      HastText(" {\n"),
      HastElement({
        class_name: "hljs-attr",
        children: [HastText("  x")],
      }),
      HastText(": "),
      HastElement({
        class_name: "hljs-type",
        children: [HastText("number")],
      }),
      HastText(";\n"),
      HastElement({
        class_name: "hljs-attr",
        children: [HastText("  y")],
      }),
      HastText(": "),
      HastElement({
        class_name: "hljs-type",
        children: [HastText("number")],
      }),
      HastText(";\n}\n\n"),
      HastElement({
        class_name: "hljs-comment",
        children: [HastText("// distance between two points")],
      }),
      HastText("\n"),
      HastElement({
        class_name: "hljs-keyword",
        children: [HastText("function")],
      }),
      HastText(" "),
      HastElement({
        class_name: "hljs-title",
        children: [HastText("distance")],
      }),
      HastText("(a: "),
      HastElement({
        class_name: "hljs-type",
        children: [HastText("Point")],
      }),
      HastText(", b: "),
      HastElement({
        class_name: "hljs-type",
        children: [HastText("Point")],
      }),
      HastText("): "),
      HastElement({
        class_name: "hljs-type",
        children: [HastText("number")],
      }),
      HastText(" {\n  "),
      HastElement({
        class_name: "hljs-keyword",
        children: [HastText("const")],
      }),
      HastText(" dx = a.x - b.x;\n  "),
      HastElement({
        class_name: "hljs-keyword",
        children: [HastText("const")],
      }),
      HastText(" dy = a.y - b.y;\n  "),
      HastElement({
        class_name: "hljs-keyword",
        children: [HastText("return")],
      }),
      HastText(" Math.sqrt(dx * dx + dy * dy);\n}\n"),
    ],
  }
}

///|
fn main raise {
  let headless = getenv_ffi(b"OT_HEADLESS") != 0
  let renderer = @core.Renderer::create(background="#0D1117")
  let root = renderer.root()
  let frame_w = renderer.get_width().reinterpret_as_int()
  let code_w = frame_w - 10
  let code_h = 16

  let header = @core.new_box(
    renderer,
    height="3",
    border=true,
    border_style="double",
    border_color="#4ECDC4",
    background="#0D1117",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="HAST to Styled Text Demo",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  // 路径一：TextBuffer 富文本 + TEXT_VIEW 节点（保留换行与样式，支持链接）
  let code_box = @core.new_box(
    renderer,
    height="18",
    border=true,
    border_color="#6BCF7F",
    background="#0D1117",
    padding=1,
  )
  let buffer = @core.TextBuffer::create(renderer)
  let view = buffer.view()
  let _ = view.set_viewport(x=0, y=0, width=code_w.to_uint(), height=code_h.to_uint())
  let code_node = @core.new_text_view(renderer, view, width="\{code_w}", height="\{code_h}")
  code_box.add(code_node)
  root.add(code_box)

  // 路径二：普通 Text 节点的 set_styled_chunks（同一棵树，单屏内联展示）
  let inline = @core.new_text(renderer, content="", fg="#e6edf3")
  root.add(inline)

  let status = @core.new_text(
    renderer,
    content="r: re-transform · q quit",
    fg="#8b949e",
  )
  root.add(status)

  let transform = fn() raise {
    let chunks : Array[@core.Chunk] = []
    hast_to_chunks(HastElement(example_hast()), "", chunks)
    buffer.set_styled_text(chunks)
    let info = buffer.get_info()
    let _ = status.set_content(
      "chunks=\{chunks.length()} lines=\{info.line_count()} bytes=\{info.byte_count()} · r: re-transform · q quit",
    )
    // 内联路径只取前两行做对照展示
    let mut inline_text = ""
    for chunk in chunks {
      if inline_text.contains("\n\n") {
        break
      }
      inline_text = inline_text + chunk.text
    }
    let _ = inline.set_content("inline: \{inline_text}")
  }
  transform()

  if headless {
    renderer.render()
    let info = buffer.get_info()
    write_info(
      "hast-demo-info.txt",
      [
        "lines=\{info.line_count()} bytes=\{info.byte_count()}",
        "text_len=\{buffer.get_text().length()}",
        "range_line1=\{buffer.get_range(start=0, end=17)}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      "r" => {
        transform()
        renderer.render()
      }
      _ => ()
    }
  })

  renderer.run()
}
