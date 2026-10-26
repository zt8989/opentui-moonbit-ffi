// 移植自 packages/examples/src/wide-grapheme-overlay-demo.ts：
// 宽字符（CJK/emoji）背景 + 可拖动半透明色块 + 遮罩切换。
// 与 TS 版的差异：resize 不重排（终端尺寸固定为启动值）；alpha 标签为静态文本。

///|
let grapheme_lines : Array[String] = [
  "東京都  北京市  서울시  大阪府  名古屋  横浜市  上海市",
  "👨‍👩‍👧‍👦  👩🏽‍💻  🏳️‍🌈  🇺🇸  🇩🇪  🇯🇵  🇮🇳  家族  絵文字  🎉🎊🎈",
  "こんにちは世界  你好世界  안녕하세요  สวัสดี  مرحبا",
  "漢字テスト  中文测试  한국어  日本語  繁體中文  简体中文",
  "🚀 Full-width: ＡＢＣＤＥＦ  Half: abcdef  ½ ⅞ ⅓",
  "混合テキスト mixed text with 漢字 and emoji 🎯",
]

///|
const HEADER_HEIGHT : Int = 2

///|
struct DragBox {
  node : @core.Renderable
  num : UInt32
  mut left : Double
  mut top : Double
  width : Double
  height : Double
}

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#0A0E14")
  renderer.enable_mouse()
  let frame_w = renderer.get_width().to_int()
  let frame_h = renderer.get_height().to_int()

  let root = @core.new_box(renderer, flex_grow=1.0)

  // 顶栏（styled chunks，z=200）
  let header = @core.new_text(
    renderer,
    width="100%",
    height="2",
    position="absolute",
    left="2",
    top="0",
    z_index=200,
  )
  header.set_styled_chunks([
    @core.Chunk::make(text="Wide Grapheme Overlay", fg="#00D4AA", attributes=@core.ATTR_BOLD),
    @core.Chunk::make(text=" | D: show scrim | drag boxes over CJK/emoji | q: quit", fg="#A8A8B2"),
  ])
  root.add(header)

  // 宽字符背景（FrameBuffer，header 以下）
  let bg_height = frame_h - HEADER_HEIGHT
  let background = @core.new_framebuffer(
    renderer,
    width=frame_w.to_uint(),
    height=bg_height.to_uint(),
    position="absolute",
    top=HEADER_HEIGHT.to_string(),
    left="0",
  )
  let bg_fb = @core.framebuffer_of(renderer, background)
  bg_fb.clear(background="#0A0E14")
  for y in 0..<bg_height {
    bg_fb.draw_text(
      text=grapheme_lines[y % grapheme_lines.length()],
      x=2,
      y=y,
      fg="#DCDCDC",
      bg=Some("#0A0E14"),
    )
  }
  root.add(background)

  // 遮罩（半透明黑，初始隐藏；d 键切换）
  let mut scrim_visible = false
  let scrim = @core.new_box(
    renderer,
    position="absolute",
    left="0",
    top=HEADER_HEIGHT.to_string(),
    width="100%",
    height=bg_height.to_string(),
    background="#00000096",
    z_index=50,
  )
  scrim.set_display("none")
  root.add(scrim)

  // 四个可拖动半透明色块（Box + 静态 alpha 标签，z=100）
  let specs : Array[(String, String, Int, Int, String)] = [
    ("50%", "#40b0ff80", 4, HEADER_HEIGHT + 1, "#0A0E14"),
    ("75%", "#ff6b81c0", 20, HEADER_HEIGHT + 5, "#0A0E14"),
    ("25%", "#8b45c140", 40, HEADER_HEIGHT + 3, "#0A0E14"),
    ("100%", "#1e1e2a", 60, HEADER_HEIGHT + 7, "#1e1e2a"),
  ]
  let boxes : Array[DragBox] = []
  for spec in specs {
    let (label, bg, bx, by, fg) = spec
    let box = @core.new_box(
      renderer,
      width="25",
      height="8",
      background=bg,
      position="absolute",
      left=bx.to_string(),
      top=by.to_string(),
      z_index=100,
      border=true,
      border_color="#ffffff",
    )
    box.add(
      @core.new_text(
        renderer,
        content=" \{label}",
        fg=fg,
        attributes="bold",
      ),
    )
    root.add(box)
    boxes.push({
      node: box,
      num: box.num,
      left: bx.to_double(),
      top: by.to_double(),
      width: 25.0,
      height: 8.0,
    })
  }

  // 拖动状态
  let mut dragging : DragBox? = None
  let mut drag_x = 0.0
  let mut drag_y = 0.0

  renderer.on_mouse(fn(mouse) raise {
    if mouse.is_down() {
      match renderer.hit_test(mouse.x(), mouse.y()) {
        Ok(num) =>
          for b in boxes {
            if b.num == num {
              dragging = Some(b)
              drag_x = mouse.x().to_double()
              drag_y = mouse.y().to_double()
              break
            }
          }
        Err(_) => ()
      }
      return
    }
    if mouse.is_up() {
      dragging = None
      return
    }
    if mouse.is_drag() {
      match dragging {
        Some(b) => {
          let nx = (mouse.x().to_double() - drag_x + b.left).clamp(min=0.0, max=frame_w.to_double() - b.width)
          let ny = (mouse.y().to_double() - drag_y + b.top).clamp(min=0.0, max=frame_h.to_double() - b.height)
          drag_x = mouse.x().to_double()
          drag_y = mouse.y().to_double()
          b.left = nx
          b.top = ny
          b.node.update_style(fn(builder, handle) {
            builder.set_position(handle, "left", @core.ptd(nx))
            builder.set_position(handle, "top", @core.ptd(ny))
          })
          renderer.render()
        }
        None => ()
      }
    }
  })

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "d" => {
        // 切换遮罩：display none ↔ flex
        scrim_visible = !scrim_visible
        let _ = scrim.set_display(if scrim_visible { "flex" } else { "none" })
        let _ = header.set_styled_chunks([
          @core.Chunk::make(text="Wide Grapheme Overlay", fg="#00D4AA", attributes=@core.ATTR_BOLD),
          @core.Chunk::make(
            text=" | \{if scrim_visible { "hide" } else { "show" } } scrim | drag boxes over CJK/emoji | q: quit",
            fg="#A8A8B2",
          ),
        ])
        renderer.render()
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
