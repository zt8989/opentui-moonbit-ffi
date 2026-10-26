// 移植自 packages/examples/src/framebuffer-demo.ts：
// 多个 FrameBuffer 节点层叠 + 透明度合成。背景缓冲平铺宽字符，
// 前景缓冲画一个弹跳的 box 与尺寸渐变的面板（z 序 + alpha 混合）。
// 方向键移动弹跳框，q 退出。OT_HEADLESS=1 渲染一帧后退出。

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
fn main raise {
  let headless = getenv_ffi(b"OT_HEADLESS") != 0
  let renderer = @core.Renderer::create(background="#0a0a1e")
  let root = renderer.root()
  let frame_w = renderer.get_width().reinterpret_as_int()
  let frame_h = renderer.get_height().reinterpret_as_int()

  // 背景缓冲：平铺宽字符，体现透明合成
  let bg_height = frame_h
  let background = @core.new_framebuffer(
    renderer,
    width=frame_w.to_uint(),
    height=bg_height.to_uint(),
    position="absolute",
    top="0",
  )
  let bg_fb = @core.framebuffer_of(renderer, background)
  bg_fb.clear(background="#0a0a1e")
  let tiles = ["回", "latin", "Ω"]
  for y in 0..<bg_height {
    let tile = tiles[y % tiles.length()]
    let line = StringBuilder(size_hint=frame_w * 2)
    let mut x = 0
    while x < frame_w {
      line.write_string(tile)
      x += tile.length() + 2
    }
    bg_fb.draw_text(
      text=line.to_string(),
      x=0,
      y=y,
      fg="#2a2a4e",
      bg=Some("#0a0a1e"),
    )
  }
  root.add(background)

  // 前景缓冲：弹跳 box（respect_alpha 保留透明区域）
  let fg = @core.new_framebuffer(
    renderer,
    width=frame_w.to_uint(),
    height=frame_h.to_uint(),
    respect_alpha=true,
    position="absolute",
    top="0",
    z_index=10,
  )
  let fg_fb = @core.framebuffer_of(renderer, fg)
  root.add(fg)

  let status = @core.new_text(
    renderer,
    content="arrows move box · q quit",
    fg="#8b949e",
    position="absolute",
    top=(frame_h - 1).to_string(),
  )
  root.add(status)

  let mut box_x = 10
  let mut box_y = 4
  let draw_box = fn() raise {
    // 清除前景（透明背景 CLEAR）后重画 box
    fg_fb.clear(background="transparent")
    let w = 14
    let h = 6
    for row in 0..<h {
      for col in 0..<w {
        let edge = row == 0 || row == h - 1 || col == 0 || col == w - 1
        if edge {
          fg_fb.draw_cell(
            x=box_x + col,
            y=box_y + row,
            character=if row == 0 || row == h - 1 {
              if col == 0 {
                0x250C
              } else if col == w - 1 {
                0x2510
              } else {
                0x2500
              }
            } else if col == 0 || col == w - 1 {
              0x2502
            } else {
              32
            },
            fg="#7aa2f7",
            bg="#10154a",
          )
        } else {
          fg_fb.fill(
            x=box_x + col,
            y=box_y + row,
            width=1,
            height=1,
            background="#10154a",
          )
        }
      }
    }
    fg_fb.draw_text(
      text=" bouncing ",
      x=box_x + 2,
      y=box_y + h / 2,
      fg="#e6edf3",
      bg=Some("#10154a"),
      attributes=@core.OT_TEXT_ATTR_BOLD,
    )
  }
  draw_box()

  if headless {
    renderer.render()
    write_info(
      "framebuffer-demo-info.txt",
      [
        "buffers=2 (bg opaque + fg respect_alpha)",
        "box=(\{box_x},\{box_y})",
      ],
    )
    renderer.stop()
    return
  }

  let step = fn(dx : Int, dy : Int) raise {
    box_x = (box_x + dx).clamp(min=0, max=frame_w - 16)
    box_y = (box_y + dy).clamp(min=0, max=frame_h - 8)
    draw_box()
    renderer.render()
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      "left" => step(-2, 0)
      "right" => step(2, 0)
      "up" => step(0, -1)
      "down" => step(0, 1)
      _ => ()
    }
  })

  renderer.run()
}
