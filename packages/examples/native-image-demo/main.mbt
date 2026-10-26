// 移植自 packages/examples/src/native-image-demo.ts（简化实现）：
// 原生图像管线 = 像素创建 → 缩放/裁剪/旋转/合成 → OT_SCENE_IMAGE 节点。
// TS 版从 HTTP 下载 PNG；这里程序化生成 RGBA 像素（渐变 + 圆 + 网格），
// 并用 copy_png → decode 验证 PNG 编解码回路。协议用 BLOCKS（unicode
// 半块，任意终端/文件输出可见），fit=FIT。
// 1-5 切换展示阶段，q 退出。OT_HEADLESS=1 渲染一帧后退出。

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
fn headless_mode() -> Bool {
  getenv_ffi(b"OT_HEADLESS") != 0
}

///|
/// 生成 64×32 测试图：水平渐变底 + 青色圆 + 网格线 + 半透明角落块。
/// 数值计算全程用 Double，写回时 clamp 到 0..255。
fn generate_pixels(width : Int, height : Int) -> FixedArray[Byte] {
  let px : FixedArray[Byte] = FixedArray::make(width * height * 4, 0)
  let cx = width * 3 / 5
  let cy = height / 2
  let radius = (if height < width { height } else { width }) / 3
  for y in 0..<height {
    for x in 0..<width {
      let i = (y * width + x) * 4
      let t = Float::from_int(x) / Float::from_int(width)
      // 深蓝→深紫水平渐变
      let mut r : Float = 20.0 + 60.0 * t
      let mut g : Float = 16.0 + 20.0 * t
      let mut b : Float = 46.0 + 80.0 * t
      let mut a : Int = 255
      // 青色实心圆（边缘 1px 线性羽化）
      let dx = x - cx
      let dy = (y - cy) * 2
      let dist = Float::from_int(dx * dx + dy * dy).sqrt()
      let rf = Float::from_int(radius)
      if dist < rf {
        let edge = rf - dist
        let coverage : Float = if edge > 1.0 { 1.0 } else { if edge < 0.0 { 0.0 } else { edge } }
        let inv : Float = 1.0 - coverage
        r = r * inv + 78.0 * coverage
        g = g * inv + 205.0 * coverage
        b = b * inv + 196.0 * coverage
      }
      // 白色网格线（与底色 40% 混合）
      if x % 8 == 0 || y % 8 == 0 {
        r = r * 0.6 + 102.0
        g = g * 0.6 + 102.0
        b = b * 0.6 + 102.0
      }
      // 左上角半透明橙色块（验证 alpha 通道）
      if x < 10 && y < 6 {
        r = 255.0
        g = 140.0
        b = 40.0
        a = 140
      }
      px[i] = r.to_int().clamp(min=0, max=255).to_byte()
      px[i + 1] = g.to_int().clamp(min=0, max=255).to_byte()
      px[i + 2] = b.to_int().clamp(min=0, max=255).to_byte()
      px[i + 3] = a.to_byte()
    }
  }
  px
}

///|
fn main raise {
  let headless = headless_mode()
  let renderer = @core.Renderer::create(background="#0D1117")
  let root = renderer.root()

  // 终端分辨率元数据（native fit 用；块协议按单元格渲染）
  renderer.set_image_resolution(
    terminal_width=renderer.get_width().reinterpret_as_int(),
    terminal_height=renderer.get_height().reinterpret_as_int(),
    pixel_width=8,
    pixel_height=16,
  )

  let header = @core.new_box(
    renderer,
    height="3",
    border=true,
    border_style="double",
    border_color="#FF8C32",
    background="#0D1117",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="Native Image Demo (pixels → transform → IMAGE node)",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  let stage_box = @core.new_box(
    renderer,
    height="16",
    border=true,
    border_color="#FF8C32",
    background="#0D1117",
    padding=1,
    align_items="center",
    justify_content="center",
  )
  root.add(stage_box)
  let status = @core.new_text(renderer, content="", fg="#8b949e")
  root.add(status)

  // 管线：创建 → 缩放 → 旋转 → 合成角落徽标
  let base_pixels = generate_pixels(64, 32)
  let base = @core.Image::from_pixels(
    renderer,
    pixels=base_pixels,
    width=64,
    height=32,
  )
  let info0 = base.get_info()
  let badge_pixels : FixedArray[Byte] = FixedArray::make(8 * 4 * 4, 0)
  for i in 0..<32 {
    badge_pixels[i * 4] = 120
    badge_pixels[i * 4 + 1] = 220
    badge_pixels[i * 4 + 2] = 120
    badge_pixels[i * 4 + 3] = 200
  }
  let badge = @core.Image::from_pixels(
    renderer,
    pixels=badge_pixels,
    width=8,
    height=4,
  )
  let merged = @core.Image::composite(base, overlay=badge, left=2, top=2)
  let stages : Array[@core.Image] = [
    base,
    merged.resize(width=48, height=24),
    merged.extract(left=0, top=0, width=32, height=32),
    merged.transform(operation=@core.OT_IMAGE_ROTATE_90),
    merged.transform(operation=@core.OT_IMAGE_FLOP),
  ]
  let stage_names = [
    "original 64x32",
    "composite+resize 48x24",
    "extract 32x32",
    "rotate90",
    "flop",
  ]
  let mut current = 0
  let info0 = stages[0].get_info()
  let image_node = @core.new_image(
    renderer,
    stages[0],
    width="\{info0.width() / 2}",
    height="\{info0.height() / 4}",
    fit=@core.OT_IMAGE_FIT,
    protocol=@core.OT_IMAGE_PROTOCOL_BLOCKS,
  )
  stage_box.add(image_node)
  let show = fn(index : Int) raise {
    current = index
    let img = stages[index]
    let info = img.get_info()
    image_node.set_image(img, fit=@core.OT_IMAGE_FIT, protocol=@core.OT_IMAGE_PROTOCOL_BLOCKS)
    let _ = status.set_content(
      " stage \{index + 1}/5 \{stage_names[index]} · \{info.width()}x\{info.height()} alpha=\{info.has_alpha()} · 1-5 switch · q quit",
    )
  }
  show(0)

  if headless {
    renderer.render()
    // PNG 编解码回路
    let png = merged.copy_png()
    let reparsed = @core.Image::decode(renderer, bytes=png)
    let info = reparsed.get_info()
    let inspect = @core.inspect_image(renderer, bytes=png)
    let roundtrip : FixedArray[Byte] = FixedArray::make(info.width() * info.height() * 4, 0)
    reparsed.copy_pixels(destination=roundtrip)
    let mut nonzero = 0
    for i in 0..<roundtrip.length() {
      if roundtrip[i] != 0 {
        nonzero += 1
      }
    }
    write_info(
      "image-demo-info.txt",
      [
        "stages=\{stages.length()}",
        "png_bytes=\{png.length()}",
        "decoded=\{info.width()}x\{info.height()} format=\{info.format()}",
        "inspect_format=\{inspect.format()} inspect_alpha=\{inspect.has_alpha()}",
        "roundtrip_nonzero_bytes=\{nonzero}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      "1" | "2" | "3" | "4" | "5" => {
        let idx = match stroke.name {
          "1" => 0
          "2" => 1
          "3" => 2
          "4" => 3
          _ => 4
        }
        show(idx)
        renderer.render()
      }
      _ => ()
    }
  })

  renderer.run()
}
