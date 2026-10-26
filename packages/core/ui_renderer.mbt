// Renderer：对应 @opentui/core 的 createCliRenderer + CliRenderer。
// 持有 Context/Session、场景根、节点号分配、绘制缓存与交互循环。

///|
/// 可选中节点注册项（对应 TS 的 selectable + selectionBg/selectionFg）。
pub struct SelectableNode {
  node : Renderable
  bg : RgbaColor?
  fg : RgbaColor?
}

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
  mut hook_gen : UInt64
  embedded_terminals : Map[UInt32, EmbeddedTerminal]
  mut has_hooks : Bool
  // 选区控制器（enable_selection 启用；对应 TS renderer 的跨节点选区）
  selectables : Array[SelectableNode]
  mut selection_enabled : Bool
  mut sel_active : Bool
  mut sel_dragging : Bool
  mut sel_anchor_x : Int
  mut sel_anchor_y : Int
  mut sel_touched : Array[SelectableNode]
  mut selection_handler : ((String, Int) -> Unit raise)?
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
      span_capacity=512,
      max_bytes=1048576UL,
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
    hook_gen: 0UL,
    embedded_terminals: Map::new(),
    has_hooks: false,
    selectables: [],
    selection_enabled: false,
    sel_active: false,
    sel_dragging: false,
    sel_anchor_x: 0,
    sel_anchor_y: 0,
    sel_touched: [],
    selection_handler: None,
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
    // 帧编码可能分批入队（PENDING）：pump 推进 + 反复 drain 直到无输出。
    // 非终端模式（use_terminal=false）下这一步是唯一能把整帧交付出去的路径。
    let mut idle = 0
    while idle < 16 {
      let clock : Clock = { id: self.clock_id }
      let p = unwrap(pump(self.context, self.session, clock_now(clock)))
      let written = unwrap(drain_stdout(self.context, self.session))
      if written == 0 {
        idle += 1
      } else {
        idle = 0
      }
      if p.status() == OT_PUMP_CLOSED {
        break
      }
    }
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
    let num = u32_at(24)
    if hooks.lor(OT_SCENE_HOOK_RENDER_SELF) != hooks {
      continue
    }
    // 内嵌终端：录制期内先把屏幕合成进节点缓冲（TS renderSelf 等价）
    match self.embedded_terminals.get(num) {
      Some(term) =>
        match self.framebuffers.get(num) {
          Some(fb) => term.compose(target=fb, x=0, y=0)
          None => ()
        }
      None => ()
    }
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
    EditorNode => OT_SCENE_EDITOR
    TextViewNode => OT_SCENE_TEXT_VIEW
    ImageNode => OT_SCENE_IMAGE
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
        if self.selection_enabled {
          let mouse = {
            action: ev.action(),
            button: ev.code(),
            x: ev.x(),
            y: ev.y(),
          }
          self.handle_selection_mouse(mouse)
        }
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

///|
/// 启用选区控制（对应 renderer 的跨节点鼠标选区）。启用后鼠标左键
/// 按下/拖动/释放会驱动可选中节点的选区高亮与 selection 回调。
pub fn Renderer::enable_selection(self : Renderer) -> Unit {
  self.selection_enabled = true
}

///|
/// 注册可选中节点（对应 TS 的 selectable 属性；文本节点才可选中）。
/// bg/fg 为选区高亮色（对应 selectionBg/selectionFg），空串用节点默认。
pub fn Renderer::add_selectable(
  self : Renderer,
  node : Renderable,
  bg~ : String = "",
  fg~ : String = "",
) -> Unit {
  self.selectables.push({
    node,
    bg: if bg == "" { None } else { Some(parse_color_lossy(bg)) },
    fg: if fg == "" { None } else { Some(parse_color_lossy(fg)) },
  })
}

///|
/// 注册选区回调（对应 renderer.on("selection")）。
/// 参数为当前选中文本与选中节点数；释放鼠标时触发。
pub fn Renderer::on_selection(
  self : Renderer,
  handler : (String, Int) -> Unit raise,
) -> Unit {
  self.selection_handler = Some(handler)
}

///|
/// 清除选区（对应 renderer.clearSelection()）。
pub fn Renderer::clear_selection(self : Renderer) -> Unit raise {
  for sel in self.sel_touched {
    let _ = set_text_selection(
      self.context,
      sel.node.handle,
      operation=OT_SCENE_TEXT_SELECTION_RESET,
      anchor_x=0,
      anchor_y=0,
      focus_x=0,
      focus_y=0,
    )
  }
  self.sel_touched.clear()
  self.sel_active = false
  self.sel_dragging = false
}

///|
/// 内置选区鼠标处理：左键 down 开始、drag 更新、up 结束并触发回调。
fn Renderer::handle_selection_mouse(self : Renderer, mouse : MouseEvent) -> Unit raise {
  if mouse.is_down() && mouse.button() == 0 {
    // 左键按下：命中任一 selectable 才开始选区
    for sel in self.selectables {
      let node = sel.node
      match get_layout(self.context, node.handle, observation=OT_LAYOUT_PAINT) {
        Ok(layout) => {
          let mx = mouse.x().to_double()
          let my = mouse.y().to_double()
          if mx >= layout.left && mx < layout.left + layout.width && my >= layout.top && my < layout.top + layout.height {
            self.clear_selection()
            self.sel_active = true
            self.sel_dragging = true
            self.sel_anchor_x = mouse.x().reinterpret_as_int()
            self.sel_anchor_y = mouse.y().reinterpret_as_int()
            self.apply_selection(mouse.x().reinterpret_as_int(), mouse.y().reinterpret_as_int(), is_start=true)
            return
          }
        }
        Err(_) => ()
      }
    }
    return
  }
  if mouse.is_drag() && self.sel_dragging {
    self.apply_selection(mouse.x().reinterpret_as_int(), mouse.y().reinterpret_as_int(), is_start=false)
    return
  }
  if mouse.is_up() && self.sel_dragging {
    self.sel_dragging = false
    // 汇总选中文本与命中数，触发回调
    let buf = StringBuilder(size_hint=64)
    let mut count = 0
    for sel in self.selectables {
      let node = sel.node
      match get_text_selection(self.context, node.handle) {
        Ok(Some(_)) => {
          count = count + 1
          match get_selected_text(self.context, node.handle) {
            Ok(text) => buf.write_string(text)
            Err(_) => ()
          }
        }
        _ => ()
      }
    }
    match self.selection_handler {
      Some(handler) => handler(buf.to_string(), count)
      None => ()
    }
  }
}

///|
/// 内部：把当前选区（anchor → focus）应用到全部可选中节点。
/// 相交者设局部坐标选区（SET/UPDATE），不再相交者 RESET。
fn Renderer::apply_selection(self : Renderer, focus_x : Int, focus_y : Int, is_start~ : Bool) -> Unit raise {
  let ax = self.sel_anchor_x
  let ay = self.sel_anchor_y
  let x0 = if ax < focus_x { ax } else { focus_x }
  let x1 = if ax < focus_x { focus_x } else { ax }
  let y0 = if ay < focus_y { ay } else { focus_y }
  let y1 = if ay < focus_y { focus_y } else { ay }
  let still_touched : Array[SelectableNode] = []
  for sel in self.selectables {
    let node = sel.node
    match get_layout(self.context, node.handle, observation=OT_LAYOUT_PAINT) {
      Ok(layout) => {
        let l = layout.left.to_int()
        let t = layout.top.to_int()
        let r = l + layout.width.to_int()
        let b = t + layout.height.to_int()
        if x1 >= l && x0 < r && y1 >= t && y0 < b {
          let op : UInt32 = if is_start {
            OT_SCENE_TEXT_SELECTION_SET
          } else {
            OT_SCENE_TEXT_SELECTION_UPDATE
          }
          let _ = set_text_selection(
            self.context,
            node.handle,
            operation=op,
            anchor_x=ax - l,
            anchor_y=ay - t,
            focus_x=focus_x - l,
            focus_y=focus_y - t,
            bg=sel.bg,
            fg=sel.fg,
          )
          still_touched.push(sel)
        }
      }
      Err(_) => ()
    }
  }
  // 不再相交的节点复位
  for old in self.sel_touched {
    let mut keep = false
    for cur in still_touched {
      if old.node.num == cur.node.num {
        keep = true
        break
      }
    }
    if !keep {
      let _ = set_text_selection(
        self.context,
        old.node.handle,
        operation=OT_SCENE_TEXT_SELECTION_RESET,
        anchor_x=0,
        anchor_y=0,
        focus_x=0,
        focus_y=0,
      )
    }
  }
  self.sel_touched = still_touched
}


///|
/// 复制到终端剪贴板（OSC52；返回 false 表示终端不支持）。
pub fn Renderer::copy_to_clipboard(self : Renderer, text~ : String) -> Bool raise {
  unwrap(session_copy_to_clipboard(self.context, self.session, text~)) > 0
}

///|
/// 只绘制不提交：返回帧请求供 render_split 等高级提交路径使用。
/// 场景含 FrameBuffer（RENDER_SELF 钩子）节点时不可用，改走 render()。
pub fn Renderer::paint_frame(self : Renderer) -> SceneFrameRequest raise {
  unwrap(
    paint_with_mouse(
      self.context,
      self.session,
      self.background,
      self.use_mouse,
    ),
  )
}

///|
/// 泵送会话并反复排空输出直到无字节可交（PENDING 分帧编码的完整交付）。
pub fn Renderer::flush_output(self : Renderer) -> Unit raise {
  let mut idle = 0
  while idle < 16 {
    let clock : Clock = { id: self.clock_id }
    let p = unwrap(pump(self.context, self.session, clock_now(clock)))
    let written = unwrap(drain_stdout(self.context, self.session))
    if written == 0 {
      idle += 1
    } else {
      idle = 0
    }
    if p.status() == OT_PUMP_CLOSED {
      break
    }
  }
}
