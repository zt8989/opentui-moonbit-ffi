// 移植自 packages/examples/src/full-unicode-demo.ts：
// 全 Unicode/grapheme 渲染。FrameBuffer 背景 + 可移动 grapheme 窗口 +
// 富文本混排。与 TS 版的差异：TS 用鼠标拖 FrameBuffer 盒子（CUSTOM 节点
// 不参与命中测试），这里改为数字键选中 + 方向键移动；Vignette 后处理未移植。

///|
let grapheme_lines : Array[String] = [
  "✅ 👩🏽‍💻  👨‍👩‍👧‍👦  🏳️‍🌈  🇺🇸  🇩🇪  🇯🇵  🇮🇳",
  "a̐éö̲  Z͑͗͛̒͘a̴͈͚̐̓l̷͓̱͉g̶̙̗̓͘o̵͍͈  क्‍ष",
  "مرحبا  こんにちは  สวัสดี  Здравствуйте",
  "𝔘𝔫𝔦𝔠𝔬𝔡𝔢  𝒻𝓊𝓁𝓁 𝓌𝒾𝒹𝓉𝒽：ＡＢＣ  ½ ⅞ ⅓",
]

///|
struct GraphemeBox {
  node : @core.Renderable
  num : UInt32
  mut left : Int
  mut top : Int
  width : Int
  height : Int
  label : String
}

///|
fn fill_graphemes(fb : @core.FrameBuffer, width~ : Int, height~ : Int, offset~ : Int) -> Unit raise {
  fb.clear(background="#001122")
  for y in 0..<height {
    fb.draw_text(
      text=grapheme_lines[(y + offset) % grapheme_lines.length()],
      x=1,
      y=y,
      fg="#DCDCDC",
      bg=Some("#001122"),
    )
  }
}

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#001122")
  renderer.enable_mouse()
  let frame_w = renderer.get_width().reinterpret_as_int()
  let frame_h = renderer.get_height().reinterpret_as_int()

  let root = @core.new_box(renderer, flex_grow=1.0)

  // 全屏 grapheme 背景
  let background = @core.new_framebuffer(
    renderer,
    width=frame_w.to_uint(),
    height=frame_h.to_uint(),
    position="absolute",
    top="0",
    left="0",
  )
  let bg_fb = @core.framebuffer_of(renderer, background)
  fill_graphemes(bg_fb, width=frame_w, height=frame_h, offset=0)
  root.add(background)

  // 三个可移动 grapheme 窗口（FrameBuffer；数字键选中、方向键移动）
  let specs : Array[(Int, Int, Int, Int, String, String)] = [
    (6, 4, 30, 6, "#2060c0", "1"),
    (24, 10, 28, 6, "#c06080", "2"),
    (42, 7, 26, 6, "#40b060", "3"),
  ]
  let boxes : Array[GraphemeBox] = []
  for spec in specs {
    let (bx, by, bw, bh, bg, label) = spec
    let node = @core.new_framebuffer(
      renderer,
      width=bw.to_uint(),
      height=bh.to_uint(),
      position="absolute",
      top=by.to_string(),
      left=bx.to_string(),
      z_index=10,
    )
    let fb = @core.framebuffer_of(renderer, node)
    fill_graphemes(fb, width=bw, height=bh, offset=1)
    // 标签行
    fb.draw_text(text="box \{label} (move with arrows)", x=1, y=0, fg="#0A0E14", bg=Some(bg))
    root.add(node)
    boxes.push({
      node,
      num: node.num,
      left: bx,
      top: by,
      width: bw,
      height: bh,
      label,
    })
  }
  let mut selected = 0

  // 富文本 grapheme 混排（styled chunks）
  let styled = @core.new_text(
    renderer,
    position="absolute",
    left="8",
    top="12",
    z_index=20,
  )
  styled.set_styled_chunks([
    @core.Chunk::make(text="Graphemes:", fg="#4da6ff", attributes=@core.ATTR_BOLD),
    @core.Chunk::make(text=" ✅ 👩🏽‍💻  👨‍👩‍👧‍👦  🏳️‍🌈", fg="inherit"),
    @core.Chunk::make(text="\nComplex:", fg="#4da6ff", attributes=@core.ATTR_UNDERLINE),
    @core.Chunk::make(text=" a̐éö̲  Z͑͗͛̒͘a̴͈͚̐̓l̷͓̱͉g̶̙̗̓͘o̵͍͈  क्‍ष", fg="inherit"),
  ])
  root.add(styled)

  let styled2 = @core.new_text(
    renderer,
    position="absolute",
    left="18",
    top="16",
    z_index=20,
  )
  styled2.set_styled_chunks([
    @core.Chunk::make(text="Emoji Check:", fg="#55ff55", attributes=@core.ATTR_BOLD),
    @core.Chunk::make(text=" ✅ 🇺🇸 🇩🇪 🇯🇵 🇮🇳", fg="inherit"),
    @core.Chunk::make(text="\nDrag me too:", fg="#55ff55", attributes=@core.ATTR_UNDERLINE),
    @core.Chunk::make(text=" ½ ⅞ ⅓ ＡＢＣ", fg="inherit"),
  ])
  root.add(styled2)

  // 提示与标尺
  let hint = @core.new_text(
    renderer,
    content="1/2/3: select box · arrows: move · q: quit",
    fg="#AAFFAA",
    position="absolute",
    left="2",
    top="0",
    z_index=30,
  )
  root.add(hint)

  let ruler = @core.new_text(
    renderer,
    content="1234567890123456789012345678901234567890| 40-cell ruler\nOpenCode search configuration പരിശോധിക്കൽ| Malayalam",
    fg="#ffffff",
    bg="#001122",
    position="absolute",
    left="2",
    top="1",
    z_index=30,
  )
  root.add(ruler)

  let redraw_box = fn(b : GraphemeBox) raise {
    b.node.update_style(fn(builder, handle) {
      builder.set_position(handle, "left", @core.pt(b.left))
      builder.set_position(handle, "top", @core.pt(b.top))
    })
    renderer.render()
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "1" => {
        selected = 0
        let _ = hint.set_content("box 1 selected · arrows: move · q: quit")
        renderer.render()
      }
      "2" => {
        selected = 1
        let _ = hint.set_content("box 2 selected · arrows: move · q: quit")
        renderer.render()
      }
      "3" => {
        selected = 2
        let _ = hint.set_content("box 3 selected · arrows: move · q: quit")
        renderer.render()
      }
      "left" | "right" | "up" | "down" => {
        let b = boxes[selected]
        let dx = match stroke.name {
          "left" => -2
          "right" => 2
          _ => 0
        }
        let dy = match stroke.name {
          "up" => -1
          "down" => 1
          _ => 0
        }
        b.left = (b.left + dx).clamp(min=0, max=frame_w - b.width)
        b.top = (b.top + dy).clamp(min=0, max=frame_h - b.height)
        redraw_box(b)
      }
      "q" => renderer.stop()
      "c" =>
        if stroke.ctrl {
          renderer.stop()
        }
      _ => ()
    }
  })

  renderer.render()
  renderer.run()
}
