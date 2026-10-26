// 宿主剪贴板异步服务（对应 TS 的 HostClipboardService）。与 OSC52 的
// 区别：走系统剪贴板（macOS Pasteboard / Wayland / X11），异步操作 +
// 轮询模型：start → poll 直到终态 → 读结果 → destroy。

///|
/// 宿主剪贴板服务。
pub struct ClipboardService {
  context : Context
}

///|
/// 剪贴板操作状态（OT_CLIPBOARD_OPERATION_*）。
pub fn clipboard_state_name(state : UInt32) -> String {
  match state {
    0 => "pending"
    1 => "read"
    2 => "empty"
    3 => "written"
    4 => "cleared"
    5 => "unsupported"
    6 => "cancelled"
    7 => "timed-out"
    8 => "limit-exceeded"
    9 => "failed"
    10 => "invalid-handle"
    _ => "unknown(\{state})"
  }
}

///|
/// 创建服务（max_operations 并发上限）。
pub fn ClipboardService::create(renderer : Renderer, max_operations~ : Int = 8) -> ClipboardService raise {
  let status = ot_clipboard_service_create_shim(
    renderer.context,
    max_operations.reinterpret_as_uint(),
    4,
  )
  if status != 0 {
    raise Failure("clipboard service create failed: \{status}")
  }
  { context: renderer.context }
}

///|
/// 发起系统剪贴板写入（selection 0=clipboard）。
/// 返回操作句柄状态（OT_CLIPBOARD_START_*；0 = 已开始）。
pub fn ClipboardService::write_start(
  self : ClipboardService,
  text~ : String,
  selection~ : Int = 0,
  timeout_ms~ : Int = 3000,
) -> (UInt32, OtHandle) raise {
  let bytes = @utf8.encode(text)
  let data : FixedArray[Byte] = FixedArray::make(bytes.length(), 0)
  for i in 0..<bytes.length() {
    data[i] = bytes[i]
  }
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let status = ot_clipboard_write_operation_start_shim(
    self.context,
    data,
    data.length().reinterpret_as_uint(),
    selection.reinterpret_as_uint(),
    timeout_ms.reinterpret_as_uint(),
    out,
  )
  (status, out.to_handle())
}

///|
/// 编码读取请求：[u32 mime 数][u32 长度][mime 字节]...（小端）。
fn encode_read_request(mime_types : Array[String]) -> FixedArray[Byte] {
  let mut size = 4
  let encoded : Array[Bytes] = []
  for mime in mime_types {
    let bytes = @utf8.encode(mime)
    encoded.push(bytes)
    size += 4 + bytes.length()
  }
  let request : FixedArray[Byte] = FixedArray::make(size, 0)
  put_u32(request, 0, encoded.length().reinterpret_as_uint())
  let mut offset = 4
  for bytes in encoded {
    put_u32(request, offset, bytes.length().reinterpret_as_uint())
    offset += 4
    for j in 0..<bytes.length() {
      request[offset + j] = bytes[j]
    }
    offset += bytes.length()
  }
  request
}

///|
/// 发起系统剪贴板读取（preferredTypes 至少一个 mime）。
/// 返回 (start 状态, 操作句柄)。
pub fn ClipboardService::read_start(
  self : ClipboardService,
  preferred_types~ : Array[String] = ["text/plain;charset=utf-8"],
  selection~ : Int = 0,
  max_bytes~ : Int = 1048576,
  timeout_ms~ : Int = 3000,
) -> (UInt32, OtHandle) raise {
  let request = encode_read_request(preferred_types)
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let status = ot_clipboard_read_operation_start_shim(
    self.context,
    request,
    request.length().reinterpret_as_uint(),
    selection.reinterpret_as_uint(),
    max_bytes.reinterpret_as_uint(),
    0,
    8388608,
    timeout_ms.reinterpret_as_uint(),
    out,
  )
  (status, out.to_handle())
}

///|
/// 轮询操作状态（pending=0 未完成；其余为终态）。
pub fn ClipboardService::poll(self : ClipboardService, operation~ : OtHandle) -> UInt32 {
  ot_clipboard_operation_poll_shim(self.context, operation)
}

///|
/// 读取结果数据长度。
pub fn ClipboardService::result_length(self : ClipboardService, operation~ : OtHandle) -> Int {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let _ = ot_clipboard_operation_result_data_length(self.context, operation, out)
  out[0].reinterpret_as_int()
}

///|
/// 拷贝结果数据。
pub fn ClipboardService::result_copy(self : ClipboardService, operation~ : OtHandle, capacity~ : Int) -> String {
  let buf : FixedArray[Byte] = FixedArray::make(if capacity > 0 { capacity } else { 1 }, 0)
  let _ = ot_clipboard_operation_result_data_copy(
    self.context,
    operation,
    buf,
    buf.length().reinterpret_as_uint(),
  )
  decode_bytes(buf, capacity)
}

///|
/// 读取错误码。
pub fn ClipboardService::result_error_code(self : ClipboardService, operation~ : OtHandle) -> UInt32 {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let _ = ot_clipboard_operation_result_error_code(self.context, operation, out)
  out[0]
}

///|
/// 销毁操作记录。
pub fn ClipboardService::destroy_operation(self : ClipboardService, operation~ : OtHandle) -> Unit {
  let _ = ot_clipboard_operation_destroy_shim(self.context, operation)
}

///|
/// 排空已完成操作的回调队列。
pub fn ClipboardService::drain(self : ClipboardService) -> Unit {
  let _ = ot_clipboard_service_drain_shim(self.context)
}

///|
/// 销毁服务。
pub fn ClipboardService::destroy(self : ClipboardService) -> Unit {
  let _ = ot_clipboard_service_destroy_shim(self.context)
}
