// 移植自 packages/examples/src/transparency-demo.ts（简化实现）：
// 透明合成 = 带_ALPHA 通道的背景色（#RRGGBBAA）叠加层 + z 序。
// 三个半透明色块叠在宽字符背景上；方向键移动顶层色块，
// 数字 1-3 切换不透明度档位，q 退出。OT_HEADLESS=1 渲染一帧后退出。

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
  let renderer = @core.Renderer::create(background="#0A0E14")
  let root = renderer.root()

  let header = @core.new_box(
    renderer,
    height="3",
    border=true,
    border_style="double",
    border_color="#00D4AA",
    background="#0A0E14",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="Transparency Demo (alpha backgrounds + z order)",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  // 宽字符底纹（观察透明叠层）
  let backdrop = @core.new_text(
    renderer,
    content="回最之上在层透明回最之上在层透明回最之上在层透明回最之上在层透明回最之上在层透明\n透明层下的文字应当透出 alpha 混合效果透明层下的文字应当透出\n回最之上在层透明回最之上在层透明回最之上在层透明回最之上在层透明回最之上在层透明",
    fg="#3a3a5e",
    position="absolute",
    top="4",
  )
  root.add(backdrop)

  // 三个半透明色块（#RRGGBBAA：alpha 0..255 由末字节表达）
  // (背景色, 标签, 初始 left, 初始 top)
  let block_specs : Array[(String, String, Int, Int)] = [
    ("#7B68EE60", "violet 38%", 2, 6),
    ("#00D4AA50", "teal 31%", 14, 10),
    ("#FFB84D40", "amber 25%", 26, 14),
  ]
  let blocks : Array[@core.Renderable] = []
  for spec in block_specs {
    let block = @core.new_box(
      renderer,
      width="6",
      height="6",
      background=spec.0,
      border=true,
      border_color=spec.0,
      position="absolute",
      left=spec.2.to_string(),
      top=spec.3.to_string(),
    )
    block.add(
      @core.new_text(renderer, content=spec.1, fg="#FFFFFFE6"),
    )
    blocks.push(block)
    root.add(block)
  }

  let status = @core.new_text(
    renderer,
    content="arrows move top · 1/2/3 pick top · shift+1/2/3 alpha · q quit",
    fg="#8b949e",
    position="absolute",
    top=(renderer.get_height().reinterpret_as_int() - 1).to_string(),
  )
  root.add(status)

  let mut top_index = 2
  let mut alpha_step = 0
  let alpha_values = ["40", "80", "C0"]
  let refresh = fn() raise {
    // 顶层块提升 z 序并按档位调整 alpha
    for i, block in blocks {
      block.set_z_index(if i == top_index { 30 } else { 20 + i })
    }
    let spec = block_specs[top_index]
    let base = spec.0.substring(start=0, end=7)
    let _ = blocks[top_index].set_background(base + alpha_values[alpha_step])
    let _ = status.set_content(
      " top=\{spec.1} alpha=0x\{alpha_values[alpha_step]} · arrows move · 1/2/3 alpha · q quit",
    )
  }
  refresh()

  if headless {
    renderer.render()
    write_info(
      "transparency-demo-info.txt",
      [
        "blocks=3",
        "top=\{top_index} alpha=0x\{alpha_values[alpha_step]}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      "left" | "right" | "up" | "down" => {
        // 移动顶层块（update_style 的属性记录流路径）
        let block = blocks[top_index]
        let spec = block_specs[top_index]
        let dx = if stroke.name == "left" {
          -2
        } else if stroke.name == "right" {
          2
        } else {
          0
        }
        let dy = if stroke.name == "up" {
          -1
        } else if stroke.name == "down" {
          1
        } else {
          0
        }
        let _ = block.update_style(fn(builder, handle) {
          builder.set_position(handle, "left", @core.Size::parse_lossy((spec.2 + dx).to_string()))
          builder.set_position(handle, "top", @core.Size::parse_lossy((spec.3 + dy).to_string()))
        })
        renderer.render()
      }
      "1" | "2" | "3" => {
        // 无 shift：切顶层；有 shift：调 alpha 档
        if stroke.shift {
          alpha_step = match stroke.name {
            "1" => 0
            "2" => 1
            _ => 2
          }
        } else {
          top_index = match stroke.name {
            "1" => 0
            "2" => 1
            _ => 2
          }
        }
        refresh()
        renderer.render()
      }
      _ => ()
    }
  })

  renderer.run()
}
