// 可执行示例：OpenTUI 原生渲染的 box + label。
// 渲染 "Hello" 写入 hello.ansi，把同一棵场景树的文本改为 "Ready" 再渲染
// ready.ansi（保留场景模型：改属性，不重建树）。
// 输出文件内容是终端指令序列，预览方式见 README。

// 标准库的 fopen/fwrite/fclose：示例把输出交付到文件，
// 与 C 指南一致；换成终端或网络写入时只需替换这一层。

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
extern "C" fn exit_ffi(code : Int32) -> Unit = "exit"

///|
fn main {
  run() catch {
    Failure(msg) => {
      println("error: \{msg}")
      exit_ffi(1)
    }
  }
}

///|
fn[T] ok(r : Result[T, @ffi.NativeError]) -> T raise Failure {
  match r {
    Ok(v) => v
    Err(e) => raise Failure(e.to_string())
  }
}

///|
fn run() -> Unit raise Failure {
  // 12 列 × 3 行的绘制区域：
  //   ┌──────────┐
  //   │Hello     │
  //   └──────────┘
  let area_width : UInt32 = 12
  let area_height : UInt32 = 3

  // 对象槽位与帧单元格上限按这个小示例设定，不是总内存预算。
  let context = ok(@ffi.create_context(object_capacity=8, render_cells_max=36))
  // 两个 4KiB 块、共 8KiB 的输出队列容量足够两帧小画面。
  let session = ok(
    @ffi.create_session(
      context,
      chunk_size=4096,
      span_capacity=2,
      max_bytes=8192UL,
    ),
  )
  // remote = 1：不继承本地终端环境设置。
  ok(
    @ffi.attach_renderer(context, session, width=area_width, height=area_height),
  )

  // 先建 root（第一个节点必须是 root），再建 box 与 label。
  // 1/2/3 是应用自选的公开节点号，不能为 0。
  let root = ok(@ffi.create_node(context, session, @ffi.OT_SCENE_ROOT, num=1))
  let panel = ok(@ffi.create_node(context, session, @ffi.OT_SCENE_BOX, num=2))
  let label = ok(@ffi.create_node(context, session, @ffi.OT_SCENE_TEXT, num=3))

  // paint 记录整体替换节点绘制属性；默认白边框、不透明。
  ok(@ffi.set_paint(context, panel, @ffi.make_paint_options()))
  ok(@ffi.set_text(context, label, "Hello"))
  ok(@ffi.move_node(context, panel, root, index=0))
  ok(@ffi.move_node(context, label, panel, index=0))

  write_frame(context, session, "hello.ansi")

  // 同一棵场景树：只改 label 的内容，再渲染一帧。
  ok(@ffi.set_text(context, label, "Ready"))
  write_frame(context, session, "ready.ansi")

  ok(@ffi.close_session(context, session))
  ok(@ffi.destroy_context(context))
  println("written: hello.ansi, ready.ansi")
}

///|
/// 渲染一帧并把它排队输出全部交付到文件后返回，
/// 因此下一次调用可以立刻渲染下一帧。
fn write_frame(
  context : @ffi.Context,
  session : @ffi.OtHandle,
  path : String,
) -> Unit raise Failure {
  let file = fopen_ffi(@utf8.encode(path), b"wb")
  if file == 0L {
    raise Failure("fopen \{path} failed")
  }
  let frame = ok(@ffi.paint(context, session))
  let outcome = ok(@ffi.commit_frame(context, session, frame))
  // SKIPPED（输出背压）与 FAILED（编码/容量失败）都会丢帧，这里显式报错。
  if outcome != @ffi.OT_RENDER_PENDING && outcome != @ffi.OT_RENDER_PRESENTED {
    let _ = fclose_ffi(file)
    raise Failure("frame not accepted: outcome \{outcome}")
  }
  let buf : FixedArray[Byte] = FixedArray::make(512, 0)
  while true {
    let ticket = ok(@ffi.read_output(context, session, buf))
    let count = ticket.byte_count
    if count == 0 {
      break
    }
    let delivered = fwrite_ffi(buf, 1UL, count.to_uint64(), file) ==
      count.to_uint64()
    ok(@ffi.complete_output(context, session, ticket, success=delivered))
    if !delivered {
      let _ = fclose_ffi(file)
      raise Failure("write to \{path} failed")
    }
  }
  if fclose_ffi(file) != 0 {
    raise Failure("fclose \{path} failed")
  }
}
