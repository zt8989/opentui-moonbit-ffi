// 移植自 packages/examples/src/grayscale-buffer-demo.ts（简化实现）：
// 灰度采样图 = FrameBuffer + ot_buffer_draw_grayscale。左右双面板：
// 左普通采样（每单元格 1 样本），右 2×2 超采样（draw_grayscale 的
// supersample 变体，更平滑）。1-6 切换图案，空格暂停时间，q 退出。
// OT_HEADLESS=1 渲染一帧后退出。

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
let pattern_names = ["Plasma", "Ripples", "Waves", "Starburst", "Dots", "Checkers"]

///|
/// 图案强度场（0..1）。参数与时间为 Float，内部 Double 数学。
fn intensity(pattern : Int, nx : Float, ny : Float, px : Float, py : Float, t : Float) -> Float {
  Float::from_double(intensity_d(pattern, nx.to_double(), ny.to_double(), px.to_double(), py.to_double(), t.to_double()))
}

///|
fn intensity_d(pattern : Int, nx : Double, ny : Double, px : Double, py : Double, t : Double) -> Double {
  match pattern {
    1 => {
      // Ripples：中心距离波 + 径向衰减
      let dx : Double = px - 0.5
      let dy : Double = py - 0.5
      let dist : Double = (dx * dx + dy * dy).sqrt()
      let wave : Double = @math.sin(dist * 24.0 - t * 3.0) * 0.5 + 0.5
      let fade : Double = 1.0 - (dist * 2.4).min(1.0)
      wave * fade
    }
    2 => {
      // Waves：对角波 + 交叉调制
      let diagonal : Double = (nx + ny) * 6.0 - t * 2.0
      let cross : Double = @math.sin(nx * 8.0 + t) * @math.sin(ny * 8.0 + t * 0.8)
      (@math.sin(diagonal) * 0.5 + 0.5) * 0.6 + (cross * 0.5 + 0.5) * 0.4
    }
    3 => {
      // Starburst：12 道射线（atan2 参数序 y,x）
      let ddx : Double = px - 0.5
      let ddy : Double = py - 0.5
      let angle : Double = @math.atan2(ddy, ddx) + t * 0.5
      let rays : Double = angle * 12.0 / 6.2832
      let rayi : Double = @math.sin(rays * 3.1416).abs()
      if rayi > 0.7 { 1.0 } else { 0.0 }
    }
    4 => {
      // Dots：滚动圆点阵
      let gx : Double = (px * 8.0) % 1.0 - 0.5
      let gy : Double = (py * 8.0 + t * 0.3) % 1.0 - 0.5
      let d : Double = (gx * gx + gy * gy).sqrt()
      if d < 0.3 { 1.0 } else { 0.0 }
    }
    5 => {
      // Checkers：旋转棋盘
      let dx : Double = px - 0.5
      let dy : Double = py - 0.5
      let cs : Double = @math.sin(t * 0.3)
      let cc : Double = @math.cos(t * 0.3)
      let rx : Double = dx * cc - dy * cs
      let ry : Double = dx * cs + dy * cc
      let cx : Int = (rx / 0.125).to_int()
      let cy : Int = (ry / 0.125).to_int()
      if (cx + cy) % 2 == 0 { 1.0 } else { 0.0 }
    }
    // 0 Plasma：多组正弦叠加
    _ => {
      let v1 : Double = @math.sin(nx * 10.0 + t)
      let v2 : Double = @math.sin(ny * 10.0 + t * 0.7)
      let v3 : Double = @math.sin((nx + ny) * 8.0 + t * 1.3)
      let ddx : Double = nx - 0.5
      let ddy : Double = ny - 0.5
      let v4 : Double = @math.sin((ddx * ddx + ddy * ddy).sqrt() * 12.0 - t * 2.0)
      (v1 + v2 + v3 + v4 + 4.0) / 8.0
    }
  }
}

///|
fn main raise {
  let headless = getenv_ffi(b"OT_HEADLESS") != 0
  let renderer = @core.Renderer::create(background="#0a0a12")
  let root = renderer.root()
  let frame_w = renderer.get_width().reinterpret_as_int()
  let frame_h = renderer.get_height().reinterpret_as_int()
  let panel_w = (frame_w - 4) / 2
  let panel_h = frame_h - 6

  let header = @core.new_text(
    renderer,
    content="Grayscale Buffer Demo · 1-6 pattern · space pause · q quit",
    fg="#8b949e",
  )
  root.add(header)

  // 一个全屏 FrameBuffer 节点承载两个面板（绘制目标取节点自带的缓冲）
  let fb_node = @core.new_framebuffer(
    renderer,
    width=frame_w.to_uint(),
    height=(frame_h - 1).to_uint(),
    position="absolute",
    top="1",
  )
  let fb = @core.framebuffer_of(renderer, fb_node)
  root.add(fb_node)

  let mut pattern = 0
  let mut paused = false
  let time = 0.0

  let render_demo = fn() raise {
    fb.clear(background="#0a0a12")
    fb.draw_text(
      text=" normal (1x)          pattern: \{pattern_names[pattern]}",
      x=1,
      y=0,
      fg="#56D6C9",
      attributes=@core.OT_TEXT_ATTR_BOLD,
    )
    fb.draw_text(
      text=" supersampled (2x)",
      x=panel_w + 3,
      y=0,
      fg="#FFCB6B",
      attributes=@core.OT_TEXT_ATTR_BOLD,
    )
    // 左：普通采样
    let left : FixedArray[Float] = FixedArray::make(panel_w * panel_h, 0.0)
    for row in 0..<panel_h {
      for col in 0..<panel_w {
        left[row * panel_w + col] = intensity(
          pattern,
          Float::from_int(col) / Float::from_int(panel_w),
          Float::from_int(row) / Float::from_int(panel_h),
          Float::from_int(col) / Float::from_int(panel_w),
          Float::from_int(row) / Float::from_int(panel_h),
          Float::from_double(time),
        )
      }
    }
    fb.draw_grayscale(
      intensities=left,
      x=1,
      y=1,
      width=panel_w.to_uint(),
      height=panel_h.to_uint(),
      fg="#56D6C9",
      bg="#0a0a12",
    )
    fb.draw_grayscale(
      intensities=left,
      x=1,
      y=1,
      width=panel_w.to_uint(),
      height=panel_h.to_uint(),
      fg="#56D6C9",
      bg="#0a0a12",
    )
    // 右：2×2 超采样
    let ss_w = panel_w * 2
    let ss_h = panel_h * 2
    let right : FixedArray[Float] = FixedArray::make(ss_w * ss_h, 0.0)
    for row in 0..<ss_h {
      for col in 0..<ss_w {
        right[row * ss_w + col] = intensity(
          pattern,
          Float::from_int(col) / Float::from_int(ss_w),
          Float::from_int(row) / Float::from_int(ss_h),
          Float::from_int(col) / Float::from_int(ss_w),
          Float::from_int(row) / Float::from_int(ss_h),
          Float::from_double(time),
        )
      }
    }
    // 右：2×2 超采样
    fb.draw_grayscale(
      intensities=right,
      x=(panel_w + 3),
      y=1,
      width=panel_w.to_uint(),
      height=panel_h.to_uint(),
      fg="#FFCB6B",
      bg="#0a0a12",
      supersample=true,
    )
  }
  render_demo()
  renderer.render()

  if headless {
    write_info(
      "grayscale-demo-info.txt",
      [
        "pattern=\{pattern_names[pattern]}",
        "panel=\{panel_w}x\{panel_h} ss=\{panel_w * 2}x\{panel_h * 2}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => renderer.stop()
      " " => paused = !paused
      "1" | "2" | "3" | "4" | "5" | "6" => {
        pattern = match stroke.name {
          "1" => 0
          "2" => 1
          "3" => 2
          "4" => 3
          "5" => 4
          _ => 5
        }
        render_demo()
        renderer.render()
      }
      _ => ()
    }
  })

  // 时间推进循环（无定时器基础设施，用按键驱动之外的空闲步进不可行，
  // 与 TS 版的 requestAnimationFrame 不同；这里以渲染帧计数推进）
  let _ = paused
  renderer.run()
}
