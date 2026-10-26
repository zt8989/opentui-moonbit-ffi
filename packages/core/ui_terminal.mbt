// 终端与系统 FFI（core 包内）：termios raw mode、stdin 读取、单调时钟。
// termios 结构布局跨平台不同，按不透明字节缓冲处理（128 字节足够
// 容纳 macOS/Linux 的 struct termios），只做整体保存/恢复与 cfmakeraw。

///|
#borrow(termios)
extern "C" fn tcgetattr_ffi(fd : Int32, termios : FixedArray[Byte]) -> Int32 = "tcgetattr"

///|
#borrow(termios)
extern "C" fn tcsetattr_ffi(
  fd : Int32,
  actions : Int32,
  termios : FixedArray[Byte],
) -> Int32 = "tcsetattr"

///|
#borrow(termios)
extern "C" fn cfmakeraw_ffi(termios : FixedArray[Byte]) -> Unit = "cfmakeraw"

///|
#borrow(buf)
extern "C" fn read_stdin_ffi(
  fd : Int32,
  buf : FixedArray[Byte],
  count : UInt64,
) -> Int64 = "read"

///|
#borrow(timespec)
extern "C" fn clock_gettime_ffi(
  clk_id : Int32,
  timespec : FixedArray[Byte],
) -> Int32 = "clock_gettime"

///|
/// TCSANOW
const TCSANOW : Int32 = 0

///|
/// 阻塞读取 stdin；返回读取字节数（0 = EOF，-1 = 无数据/中断）。
fn read_stdin(buf : FixedArray[Byte]) -> Int32 {
  read_stdin_ffi(0, buf, buf.length().to_uint64()).to_int()
}

///|
fn u64_at(buf : FixedArray[Byte], off : Int32) -> UInt64 {
  let mut v : UInt64 = 0
  for i in 0..<8 {
    v = v | (buf[off + i].to_uint64() << (i * 8))
  }
  v
}

///|
/// 从输入事件重建 KeyStroke（键名规则见 OT_INPUT_KEY_* 常量：
/// 可打印键是 Unicode scalar，功能键用 Kitty 协议赋值）。
pub fn stroke_of_event(ev : InputEvent) -> @keymap.KeyStroke? raise {
  let code = ev.code()
  let m = ev.modifiers()
  let name : String = if code == OT_INPUT_KEY_ENTER {
    "enter"
  } else if code == OT_INPUT_KEY_ESCAPE {
    "escape"
  } else if code == OT_INPUT_KEY_TAB {
    "tab"
  } else if code == OT_INPUT_KEY_BACKSPACE {
    "backspace"
  } else if code == OT_INPUT_KEY_LEFT {
    "left"
  } else if code == OT_INPUT_KEY_RIGHT {
    "right"
  } else if code == OT_INPUT_KEY_UP {
    "up"
  } else if code == OT_INPUT_KEY_DOWN {
    "down"
  } else if code == OT_INPUT_KEY_HOME {
    "home"
  } else if code == OT_INPUT_KEY_END {
    "end"
  } else if code == OT_INPUT_KEY_PAGE_UP {
    "pageup"
  } else if code == OT_INPUT_KEY_PAGE_DOWN {
    "pagedown"
  } else if code == 32 {
    "space"
  } else if code >= 32 && code < 127 {
    code.reinterpret_as_int().to_char().unwrap_or(' ').to_string()
  } else {
    return None
  }
  Some(
    @keymap.KeyStroke::make(
      name,
      ctrl=(m & OT_INPUT_MOD_CTRL) != 0,
      shift=(m & OT_INPUT_MOD_SHIFT) != 0,
      meta=(m & OT_INPUT_MOD_ALT) != 0,
      super_=(m & OT_INPUT_MOD_SUPER) != 0,
    ),
  )
}

///|
/// 终端生命周期阶段名（OT_TERMINAL_*）。
pub fn terminal_state_name_of(state : UInt32) -> String {
  match state {
    0 => "uninitialized"
    1 => "setting-up"
    2 => "active"
    3 => "suspending"
    4 => "suspended"
    5 => "resuming"
    6 => "closing"
    7 => "restored"
    8 => "failed"
    _ => "unknown"
  }
}
