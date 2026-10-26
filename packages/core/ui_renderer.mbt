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
  mut focus_handler : ((Bool) -> Unit raise)?
  mut paste_handler : ((String) -> Unit raise)?
  // FrameBuffer 节点：公开节点号 → 离屏缓冲（RECORD 时供录制流查表）
  framebuffers : Map[UInt32, FrameBuffer]
  mut has_hooks : Bool
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
    num: 1,
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
    focus_handler: None,
    paste_handler: None,
    framebuffers: Map::new(),
    has_hooks: false,
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
/// 有 FrameBuffer 节点时走 step 循环：原生返回 RECORD 请求，宿主回放
/// SLOT+DRAW 录制流（RENDER_SELF 用离屏 buffer 替代节点本体绘制），
/// 直到 DONE 后提交。
pub fn Renderer::render(self : Renderer) -> Unit raise {
  let frame = if self.has_hooks {
    self.step_frame()
  } else {
    unwrap(
      paint_with_mouse(
        self.context,
        self.session,
        self.background,
        self.use_mouse,
      ),
    )
  }
  let outcome = unwrap(commit_frame(self.context, self.session, frame))
  if outcome == OT_RENDER_PENDING || outcome == OT_RENDER_PRESENTED {
    let _ = drain_stdout(self.context, self.session)
    return
  }
  raise Failure("frame not accepted: outcome \{outcome}")
}

///|
/// step 循环：驱动带钩子的帧尝试直到 DONE。
fn Renderer::step_frame(self : Renderer) -> SceneFrameRequest raise {
  let mut req = unwrap(
    frame_step(
      self.context,
      self.session,
      background=self.background,
      use_mouse=self.use_mouse,
    ),
  )
  // 每次尝试最多遇到 slots 上限的 RECORD；max_host_requests 也是 64，这里防死循环
  let mut rounds = 0
  while req.kind == OT_SCENE_FRAME_RECORD {
    rounds = rounds + 1
    if rounds > 64 {
      raise Failure("too many RECORD requests in one frame")
    }
    let recording = self.build_recording(req.to_request())
    req = unwrap(
      frame_step_ack(
        self.context,
        self.session,
        req.to_request(),
        background=self.background,
        use_mouse=self.use_mouse,
        recording~,
      ),
    )
  }
  req.to_request()
}

///|
/// 为 RECORD 请求构建录制流：每个带 RENDER_SELF 钩子且注册了
/// FrameBuffer 的 slot，回放 SLOT(phase=SELF) + DRAW(buffer)。
fn Renderer::build_recording(
  self : Renderer,
  request : SceneFrameRequest,
) -> Bytes raise {
  let slots = unwrap(frame_paint_slots(self.context, self.session, request))
  let buf : Array[Byte] = []
  let put32 = fn(v : UInt32) -> Unit {
    for i in 0..<4 {
      buf.push(((v >> (i * 8)) & 0xff).reinterpret_as_int().to_byte())
    }
  }
  let put64 = fn(v : UInt64) -> Unit {
    for i in 0..<8 {
      let byte = (v >> (i * 8)).to_uint() & 0xff
      buf.push(byte.reinterpret_as_int().to_byte())
    }
  }
  for i, slot in slots {
    // ot_scene_paint_slot（152 字节）布局：0-16 句柄，16-24 generation，
    // 24 num，28 hooks，56 起是 ot_scene_layout paint（left@64 f32，top@68 f32）
    let u32_at = fn(off : Int32) -> UInt32 {
      slot[off].to_uint() |
      (slot[off + 1].to_uint() << 8) |
      (slot[off + 2].to_uint() << 16) |
      (slot[off + 3].to_uint() << 24)
    }
    let hooks = u32_at(28)
    if hooks.lor(OT_SCENE_HOOK_RENDER_SELF) != hooks {
      continue
    }
    let num = u32_at(24)
    match self.framebuffers.get(num) {
      Some(fb) => {
        // SLOT 记录：header{size, operation}(8) + slot(4) + phase(4)
        put32(16)
        put32(OT_SCENE_RECORD_SLOT)
        put32(i.reinterpret_as_uint())
        put32(OT_SCENE_RECORD_PHASE_SELF)
        // DRAW 记录 = ot_scene_record_draw(32) + ot_buffer_draw_compose(40)：
        // compose 的 x/y 相对 slot clip 原点，0,0 即绘制在节点自身位置
        // （对应 TS renderSelf 的 drawFrameBuffer）。
        put32(72)
        put32(OT_SCENE_RECORD_DRAW)
        put64(fb.handle.context_id)
        put32(fb.handle.slot)
        put32(fb.handle.generation)
        put32(0)
        put32(0)
        // ot_buffer_draw_compose：header(16) + x/y(8) + src_x/src_y/src_w/src_h(16)
        put32(40)
        put32(OT_CONTEXT_ABI_VERSION)
        put32(OT_BUFFER_DRAW_COMPOSE)
        put32(0)
        put32(0)
        put32(0)
        put32(0)
        put32(0)
        put32(fb.width)
        put32(fb.height)
      }
      None => ()
    }
  }
  Bytes::from_array(FixedArray::from_iter(buf.iter()))
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
    CustomNode => OT_SCENE_CUSTOM
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
/// 注册焦点回调（终端焦点报告，对应 renderer 的 focus/blur 事件）。
pub fn Renderer::on_focus(
  self : Renderer,
  handler : (Bool) -> Unit raise,
) -> Unit {
  self.focus_handler = Some(handler)
}

///|
/// 注册粘贴回调（对应 renderer 的 paste 事件）。
pub fn Renderer::on_paste(
  self : Renderer,
  handler : (String) -> Unit raise,
) -> Unit {
  self.paste_handler = Some(handler)
}

///|
/// 设置终端窗口标题（对应 renderer.setTerminalTitle，OSC 控制包）。
pub fn Renderer::set_terminal_title(
  self : Renderer,
  title : String,
) -> Unit raise {
  let _ = unwrap(
    send_control(
      self.context,
      self.session,
      kind=OT_CONTROL_TITLE,
      payload=title,
    ),
  )
}

///|
/// 上报程序状态（对应 renderer.setProgramStatus，OSC 7501）。
pub fn Renderer::report_program_status(
  self : Renderer,
  report : ProgramStatusReport,
) -> Unit raise {
  let _ = unwrap(report_program_status(self.context, self.session, report))
}

///|
/// 发送终端通知（对应 renderer.triggerNotification）。
/// 返回 false 表示终端不支持或输出被拒。
pub fn Renderer::notify(
  self : Renderer,
  message~ : String,
  title~ : String = "",
) -> Bool raise {
  unwrap(trigger_notification(self.context, self.session, message~, title~)) > 0
}

///|
/// 启用鼠标全移动上报（对应 enableMouseMovement，控制包 OT_CONTROL_MOUSE
/// argument=2）。paint 的 use_mouse 只发布命中列表；运动事件靠这个开关。
pub fn Renderer::enable_mouse_motion(self : Renderer) -> Unit raise {
  self.use_mouse = true
  let _ = unwrap(
    send_control(self.context, self.session, kind=OT_CONTROL_MOUSE, argument=2),
  )
}

///|
/// (x, y) 处的链接 URL（无链接返回 None）。需要先渲染过带链接的帧。
pub fn Renderer::link_url_at(
  self : Renderer,
  x : UInt32,
  y : UInt32,
) -> String? raise {
  let id = unwrap(link_id_at(self.context, self.session, x, y))
  if id == 0 {
    return None
  }
  Some(unwrap(link_url(self.context, id)))
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
      if ev.kind() == OT_INPUT_FOCUS {
        match self.focus_handler {
          Some(handler) => handler(ev.action() == OT_INPUT_FOCUS_IN)
          None => ()
        }
        continue
      }
      if ev.kind() == OT_INPUT_PASTE {
        match self.paste_handler {
          Some(handler) => handler(ev.text())
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
