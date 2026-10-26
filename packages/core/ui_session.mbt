// TS 兼容层扩展：会话状态与分屏（对应 TS renderer 的 screenMode=
// "split-footer" / suspend / resume 底层通道）。分屏快照是 Context 离屏
// 缓冲（ot_buffer_create 创建，buffer draw 系列写入），经 render_split
// 与主帧一起提交；split_control 管理滚动偏移与过渡。

///|
/// 一条分屏快照提交（footer 缓冲 + 列数 + 标志）。
pub struct SplitCommit {
  buffer : OtHandle
  row_columns : Int
  flags : UInt32
}

///|
/// 提交分屏快照（带主帧）：帧状态写入 out（OT_RENDER_*）。
pub fn Renderer::render_split(
  self : Renderer,
  frame~ : SceneFrameRequest,
  commits~ : Array[SplitCommit],
  pinned_render_offset~ : Int = 0,
  force~ : Bool = false,
) -> Int raise {
  let buf = encode_split_commits(commits)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_session_render_split",
      ot_session_render_split_with_frame_shim(
        self.context,
        self.session,
        frame,
        buf,
        commits.length().reinterpret_as_uint(),
        pinned_render_offset.reinterpret_as_uint(),
        if force { 1 } else { 0 },
        out,
      ),
    ),
  )
  out[0].reinterpret_as_int()
}

///|
/// 提交分屏快照（无帧，纯 footer 输出）。帧状态写入 out。
pub fn Renderer::render_split_only(
  self : Renderer,
  commits~ : Array[SplitCommit],
  pinned_render_offset~ : Int = 0,
  force~ : Bool = false,
) -> Int raise {
  let buf = encode_split_commits(commits)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_session_render_split",
      ot_session_render_split_no_frame_shim(
        self.context,
        self.session,
        buf,
        commits.length().reinterpret_as_uint(),
        pinned_render_offset.reinterpret_as_uint(),
        if force { 1 } else { 0 },
        out,
      ),
    ),
  )
  out[0].reinterpret_as_int()
}

///|
/// 把快照数组打成连续 ot_split_snapshot 字节缓冲（24 字节/条）。
fn encode_split_commits(commits : Array[SplitCommit]) -> FixedArray[Byte] {
  let buf : FixedArray[Byte] = FixedArray::make(
    if commits.length() > 0 {
      commits.length() * 24
    } else {
      1
    },
    0,
  )
  for i, commit in commits {
    let base = i * 24
    // ot_handle：context_id u64 + slot u32 + generation u32
    let cid = commit.buffer.context_id
    for j in 0..<8 {
      buf[base + j] = (cid >> (j * 8) & 0xFF).to_byte()
    }
    put_u32(buf, base + 8, commit.buffer.slot)
    put_u32(buf, base + 12, commit.buffer.generation)
    put_u32(buf, base + 16, commit.row_columns.reinterpret_as_uint())
    put_u32(buf, base + 20, commit.flags)
  }
  buf
}

///|
fn put_u32(buf : FixedArray[Byte], offset : Int, value : UInt32) -> Unit {
  for j in 0..<4 {
    buf[offset + j] = (value >> (j * 8) & 0xFF).to_byte()
  }
}

///|
/// 分屏控制命令（reset/sync/output-offset/render-offset/transition）。
/// reset 用 (seed_rows, pinned_offset)，transition 用
/// (mode, source_top, source_height, target_top, target_height, scroll_rows)。
pub fn Renderer::split_control(
  self : Renderer,
  command~ : UInt32,
  arguments~ : Array[Int] = [],
) -> Int raise {
  fn arg(i : Int) -> UInt32 {
    if i < arguments.length() {
      arguments[i].reinterpret_as_uint()
    } else {
      0
    }
  }
  let control : SplitControl = {
    struct_size: 36,
    abi_version: OT_CONTEXT_ABI_VERSION,
    command,
    arg0: arg(0),
    arg1: arg(1),
    arg2: arg(2),
    arg3: arg(3),
    arg4: arg(4),
    arg5: arg(5),
  }
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_session_split_control",
      ot_session_split_control(self.context, self.session, control, out),
    ),
  )
  out[0].reinterpret_as_int()
}

///|
/// 切换主/备屏幕（alternate=true 备用屏）。trailing 为复制的尾部输出。
pub fn Renderer::set_screen(
  self : Renderer,
  alternate~ : Bool,
  width~ : Int,
  height~ : Int,
  trailing~ : FixedArray[Byte] = FixedArray::make(1, 0),
) -> Unit raise {
  rethrow_result(
    check(
      "ot_session_set_screen",
      ot_session_set_screen(
        self.context,
        self.session,
        if alternate { 1 } else { 0 },
        width.reinterpret_as_uint(),
        height.reinterpret_as_uint(),
        trailing,
        (trailing.length() - 1).reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 挂起终端（退出备用屏/raw mode；鼠标与 Kitty 意图保留）。
pub fn Renderer::suspend(self : Renderer) -> Unit raise {
  rethrow_result(check("ot_session_suspend", ot_session_suspend(self.context, self.session)))
}

///|
/// 恢复终端（复用已接受的 setup 选项，不重复探测）。
pub fn Renderer::resume(self : Renderer) -> Unit raise {
  rethrow_result(check("ot_session_resume", ot_session_resume(self.context, self.session)))
}

///|
/// 渲染器状态视图（尺寸与帧统计）。
pub struct RendererStateView {
  width : Int
  height : Int
  frame_count : Int
  frame_pending : Bool
}

///|
pub fn RendererStateView::width(self : RendererStateView) -> Int {
  self.width
}

///|
pub fn RendererStateView::height(self : RendererStateView) -> Int {
  self.height
}

///|
pub fn RendererStateView::frame_count(self : RendererStateView) -> Int {
  self.frame_count
}

///|
pub fn RendererStateView::frame_pending(self : RendererStateView) -> Bool {
  self.frame_pending
}

///|
/// 读取渲染器状态。
pub fn Renderer::get_renderer_state(self : Renderer) -> RendererStateView raise {
  let out : RendererState = {
    struct_size: 32,
    abi_version: OT_CONTEXT_ABI_VERSION,
    width: 0,
    height: 0,
    frame_count: 0UL,
    frame_pending: 0,
    reserved: 0,
  }
  rethrow_result(
    check(
      "ot_session_get_renderer_state",
      ot_session_get_renderer_state(self.context, self.session, out),
    ),
  )
  {
    width: out.width.reinterpret_as_int(),
    height: out.height.reinterpret_as_int(),
    frame_count: out.frame_count.to_int(),
    frame_pending: out.frame_pending != 0,
  }
}

///|
/// 开关调试叠加层（corner：0=左上 1=右上 2=左下 3=右下）。
pub fn Renderer::set_debug_overlay(self : Renderer, enabled~ : Bool, corner~ : Int = 0) -> Unit raise {
  rethrow_result(
    check(
      "ot_session_set_debug_overlay",
      ot_session_set_debug_overlay(
        self.context,
        self.session,
        if enabled { 1 } else { 0 },
        corner.reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 读取会话状态字（OT_SESSION_*）。
pub fn Renderer::get_session_state(self : Renderer) -> UInt32 raise {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check("ot_session_get_state", ot_session_get_state(self.context, self.session, out)),
  )
  out[0]
}

///|
/// 上报帧统计（调试叠加层显示用）。
pub fn Renderer::update_stats(self : Renderer, overall_ms~ : Double, fps~ : Int, callback_ms~ : Double) -> Unit raise {
  rethrow_result(
    check(
      "ot_session_update_stats",
      ot_session_update_stats(
        self.context,
        self.session,
        overall_ms,
        fps.reinterpret_as_uint(),
        callback_ms,
      ),
    ),
  )
}

///|
/// 构造一条分屏快照提交记录。
pub fn SplitCommit::make(
  buffer~ : OtHandle,
  row_columns~ : Int,
  flags~ : UInt32 = 0,
) -> SplitCommit {
  { buffer, row_columns, flags }
}
