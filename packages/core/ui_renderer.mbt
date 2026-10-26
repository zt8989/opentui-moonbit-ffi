// Renderer：对应 @opentui/core 的 createCliRenderer + CliRenderer。
// 持有 Context/Session、场景根、节点号分配、绘制缓存与交互循环。

///|
pub struct Renderer {
  context : Context
  session : OtHandle
  root_node : Renderable
  width : UInt32
  height : UInt32
  background : RgbaColor
  mut next_num : UInt32
  use_terminal : Bool
  mut raw_saved : FixedArray[Byte]
  mut has_raw : Bool
  mut clock_id : Int32
  mut stop_flag : Bool
  mut key_handler : ((@keymap.KeyStroke) -> Unit raise)?
  mut use_mouse : Bool
  mut mouse_handler : ((MouseEvent) -> Unit raise)?
}

///|
/// 单调时钟缓存（探测可用的 CLOCK id：macOS=6，Linux=1）。
priv struct Clock {
  mut id : Int32
}

///|
fn clock_now(clock : Clock) -> UInt64 {
  if clock.id < 0 {
    let candidates : Array[Int32] = [6, 1]
    for id in candidates {
      let probe : FixedArray[Byte] = FixedArray::make(16, 0)
      if clock_gettime_ffi(id, probe) == 0 {
        clock.id = id
        break
      }
    }
    if clock.id < 0 {
      clock.id = 1
    }
  }
  let tp : FixedArray[Byte] = FixedArray::make(16, 0)
  if clock_gettime_ffi(clock.id, tp) != 0 {
    return 0UL
  }
  u64_at(tp, 0) * 1000000000UL + u64_at(tp, 8)
}

///|
/// 创建渲染器（对应 await createCliRenderer({...})）。
/// use_terminal=true 进入备用屏 + raw mode（交互 TUI）；
/// false 时渲染输出直接写 stdout（可重定向到文件）。
pub fn Renderer::create(
  width~ : UInt32 = 80,
  height~ : UInt32 = 24,
  background~ : String = "#000000",
  use_terminal~ : Bool = true,
) -> Renderer raise {
  let context = unwrap(
    create_context(object_capacity=256, render_cells_max=width * height),
  )
  // 终端 setup 需要预留 control 输出容量
  let session = unwrap(
    create_session(
      context,
      chunk_size=4096,
      span_capacity=8,
      max_bytes=65536UL,
      control_capacity=4096,
    ),
  )
  let _ = unwrap(attach_renderer(context, session, width~, height~))
  if use_terminal {
    let _ = unwrap(setup_terminal(context, session, alternate_screen=true))
    let clock : Clock = { id: -1, }
    while unwrap(terminal_state(context, session)) != OT_TERMINAL_ACTIVE {
      let p = unwrap(pump(context, session, clock_now(clock)))
      let _ = drain_stdout(context, session)
      if p.status() == OT_PUMP_CLOSED {
        let _ = destroy_context(context)
        raise Failure("terminal closed during setup")
      }
    }
  }
  let root_handle = unwrap(create_node(context, session, OT_SCENE_ROOT, num=1))
  let root : Renderable = {
    context,
    session,
    handle: root_handle,
    kind: RootNode,
    children: [],
    background: (0, 0, 0, 0),
    border_sides: 0,
    border_style: 0,
    border_color: (255, 255, 255, 255),
    should_fill: 0,
    opacity: 1.0,
    z_index: 0,
    translate_x: 0.0,
    translate_y: 0.0,
    content: "",
    fg: (255, 255, 255, 255),
    text_bg: (0, 0, 0, 0),
    text_attributes: 0,
    wrap_mode: 0,
    truncate: false,
    text_align: 0,
  }
  let renderer : Renderer = {
    context,
    session,
    root_node: root,
    width,
    height,
    background: parse_color_lossy(background),
    next_num: 2,
    use_terminal,
    raw_saved: FixedArray::make(128, 0),
    has_raw: false,
    clock_id: -1,
    stop_flag: false,
    key_handler: None,
    use_mouse: false,
    mouse_handler: None,
  }
  if use_terminal {
    renderer.enable_raw_mode()
  }
  renderer
}

///|
/// 场景根节点（对应 renderer.root）。
pub fn Renderer::root(self : Renderer) -> Renderable {
  self.root_node
}

///|
pub fn Renderer::get_width(self : Renderer) -> UInt32 {
  self.width
}

///|
pub fn Renderer::get_height(self : Renderer) -> UInt32 {
  self.height
}

///|
/// 注册按键处理（对应 renderer.keyInput.on("keypress", fn)）。
/// 按键是 keymap 包的 KeyStroke；事件由内部输入循环解析。
pub fn Renderer::on_key(
  self : Renderer,
  handler : (@keymap.KeyStroke) -> Unit raise,
) -> Unit {
  self.key_handler = Some(handler)
}

///|
/// 请求退出 run() 循环（对应 renderer.destroy() 的退出路径）。
pub fn Renderer::stop(self : Renderer) -> Unit {
  self.stop_flag = true
}

///|
/// paint 的鼠标开关包装。
fn paint_with_mouse(
  context : Context,
  session : OtHandle,
  background : RgbaColor,
  use_mouse : Bool,
) -> Result[SceneFrameRequest, NativeError] {
  paint(context, session, background~, use_mouse~)
}

///|
/// 渲染一帧并把输出交付到 stdout（对应 renderer 的帧调度）。
pub fn Renderer::render(self : Renderer) -> Unit raise {
  let frame = unwrap(
    paint_with_mouse(
      self.context,
      self.session,
      self.background,
      self.use_mouse,
    ),
  )
  let outcome = unwrap(commit_frame(self.context, self.session, frame))
  if outcome == OT_RENDER_PENDING || outcome == OT_RENDER_PRESENTED {
    let _ = drain_stdout(self.context, self.session)
    return
  }
  raise Failure("frame not accepted: outcome \{outcome}")
}

///|
fn[T] unwrap(r : Result[T, NativeError]) -> T raise {
  match r {
    Ok(v) => v
    Err(e) => raise Failure(e.to_string())
  }
}

///|
/// 交付队列中的输出（pump 之后调用）。
pub fn Renderer::drain(self : Renderer) -> Unit {
  let _ = drain_stdout(self.context, self.session)
}

///|
/// 内部：按节点类型创建场景节点。
fn next_node(
  context : Context,
  session : OtHandle,
  kind : NodeKind,
  num~ : UInt32,
) -> OtHandle raise {
  let ot_kind : UInt32 = match kind {
    RootNode => OT_SCENE_ROOT
    BoxNode => OT_SCENE_BOX
    TextNode => OT_SCENE_TEXT
    SliderNode => OT_SCENE_SLIDER
  }
  unwrap(create_node(context, session, ot_kind, num~))
}

///|
fn Renderer::take_node_number(self : Renderer) -> UInt32 {
  let n = self.next_num
  self.next_num = self.next_num + 1
  n
}

///|
/// 内部：把 paint 缓存整体提交（自由函数：Renderable 自带 context/session）。
fn apply_paint(
  context : Context,
  node : Renderable,
  paint : ScenePaintOptions,
) -> Result[Unit, NativeError] {
  set_paint(context, node.handle, paint)
}

///|
/// 内部：把文本内容与选项整体提交。
fn apply_text(
  context : Context,
  node : Renderable,
) -> Result[Unit, NativeError] {
  let r1 = set_text(context, node.handle, node.content)
  match r1 {
    Err(e) => Err(e)
    Ok(_) => set_text_options(context, node.handle, node.build_text_options())
  }
}

///|
/// 内部：挂载子节点。
fn move_child(
  context : Context,
  child : Renderable,
  parent : Renderable,
  index~ : UInt32,
) -> Result[Unit, NativeError] {
  move_node(context, child.handle, parent.handle, index~)
}

///|
/// 内部：flush 样式记录。
fn flush_styles_of(
  context : Context,
  builder : StyleBuilder,
) -> Result[UInt32, NativeError] {
  flush_styles(context, builder)
}

///|
/// 启用鼠标上报（paint 时带 use_mouse；对应 renderer.enableMouse()）。
pub fn Renderer::enable_mouse(self : Renderer) -> Unit {
  self.use_mouse = true
}

///|
/// 注册鼠标回调（对应 renderer.on(MouseEvent)）。
pub fn Renderer::on_mouse(
  self : Renderer,
  handler : (MouseEvent) -> Unit raise,
) -> Unit {
  self.mouse_handler = Some(handler)
}

///|
/// 阻塞交互循环（对应 renderer 的事件循环）：泵送终端工作、阻塞读
/// stdin、解析按键并回调 on_key，直到 stop() 或 stdin EOF。
/// use_terminal=false 时读到 EOF 即返回。
pub fn Renderer::run(self : Renderer) -> Unit raise {
  let buf : FixedArray[Byte] = FixedArray::make(256, 0)
  while !self.stop_flag {
    let p = unwrap(pump(self.context, self.session, self.now_ns()))
    let status = p.status()
    if status == OT_PUMP_OUTPUT_PENDING || status == OT_PUMP_AGAIN {
      self.drain()
    }
    if status == OT_PUMP_CLOSED {
      break
    }
    let n = read_stdin(buf)
    if n < 0 {
      continue
    }
    if n == 0 {
      break
    }
    let fed = unwrap(
      input_feed(
        self.context,
        self.session,
        buf,
        n.reinterpret_as_uint(),
        self.now_ns(),
      ),
    )
    for ev in fed.events() {
      if ev.kind() == OT_INPUT_MOUSE {
        match self.mouse_handler {
          Some(handler) =>
            handler({
              action: ev.action(),
              button: ev.code(),
              x: ev.x(),
              y: ev.y(),
            })
          None => ()
        }
        continue
      }
      if ev.kind() != OT_INPUT_KEY {
        continue
      }
      let action = ev.action()
      if action != OT_INPUT_KEY_PRESS && action != OT_INPUT_KEY_REPEAT {
        continue
      }
      match stroke_of_event(ev) {
        Some(stroke) =>
          match self.key_handler {
            Some(handler) => handler(stroke)
            None => ()
          }
        None => ()
      }
    }
  }
  self.destroy()
}

///|
/// 关闭会话并恢复终端（对应 renderer.destroy()）。
/// 幂等：重复调用安全。
pub fn Renderer::destroy(self : Renderer) -> Unit {
  if self.use_terminal && self.has_raw {
    let _ = close_session(self.context, self.session)
    // 泵送终端恢复输出直到交付完成
    while true {
      let p = pump(self.context, self.session, self.now_ns())
      match p {
        Ok(p) => {
          let _ = drain_stdout(self.context, self.session)
          if p.status() == OT_PUMP_CLOSED {
            break
          }
        }
        Err(_) => break
      }
    }
    self.disable_raw_mode()
    self.has_raw = false
  } else {
    let _ = close_session(self.context, self.session)
  }
  let _ = destroy_context(self.context)
}

///|
/// 注册到 Renderer 的 now_ns（clock id 缓存在 Renderer 上）。
fn Renderer::now_ns(self : Renderer) -> UInt64 {
  if self.clock_id < 0 {
    // macOS 的 CLOCK_MONOTONIC 是 6，Linux 是 1。
    let candidates : Array[Int32] = [6, 1]
    for id in candidates {
      let probe : FixedArray[Byte] = FixedArray::make(16, 0)
      if clock_gettime_ffi(id, probe) == 0 {
        self.clock_id = id
        break
      }
    }
    if self.clock_id < 0 {
      self.clock_id = 1
    }
  }
  let tp : FixedArray[Byte] = FixedArray::make(16, 0)
  if clock_gettime_ffi(self.clock_id, tp) != 0 {
    return 0UL
  }
  u64_at(tp, 0) * 1000000000UL + u64_at(tp, 8)
}

///|
/// 内部：启用终端 raw mode（termios 整体保存 + cfmakeraw）。
fn Renderer::enable_raw_mode(self : Renderer) -> Unit {
  let saved : FixedArray[Byte] = FixedArray::make(128, 0)
  if tcgetattr_ffi(0, saved) == 0 {
    let raw : FixedArray[Byte] = FixedArray::make(128, 0)
    for i in 0..<128 {
      raw[i] = saved[i]
    }
    cfmakeraw_ffi(raw)
    if tcsetattr_ffi(0, TCSANOW, raw) == 0 {
      self.raw_saved = saved
      self.has_raw = true
    }
  }
}

///|
/// 内部：恢复保存的 termios。
fn Renderer::disable_raw_mode(self : Renderer) -> Unit {
  if self.has_raw {
    let _ = tcsetattr_ffi(0, TCSANOW, self.raw_saved)
  }
}
