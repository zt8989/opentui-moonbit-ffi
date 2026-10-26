// 终端与系统 FFI：termios raw mode、stdin 读取、窗口尺寸、单调时钟。
// termios 结构布局跨平台不同，这里按不透明字节缓冲处理（128 字节足够
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
extern "C" fn read_ffi(
  fd : Int32,
  buf : FixedArray[Byte],
  count : UInt64,
) -> Int64 = "read"

///|
#borrow(winsize)
extern "C" fn ioctl_ffi(
  fd : Int32,
  request : UInt64,
  winsize : FixedArray[Byte],
) -> Int32 = "ioctl"

///|
#borrow(timespec)
extern "C" fn clock_gettime_ffi(
  clk_id : Int32,
  timespec : FixedArray[Byte],
) -> Int32 = "clock_gettime"

///|
extern "C" fn exit_ffi(code : Int32) -> Unit = "exit"

///|
/// TCSANOW
const TCSANOW : Int32 = 0

///|
/// 保存当前 termios。返回是否为 TTY。
fn termios_save(fd : Int32, out : FixedArray[Byte]) -> Bool {
  tcgetattr_ffi(fd, out) == 0
}

///|
/// 从已保存的配置生成 raw mode 副本。
fn termios_make_raw(saved : FixedArray[Byte], out : FixedArray[Byte]) -> Unit {
  for i in 0..<out.length() {
    out[i] = saved[i]
  }
  cfmakeraw_ffi(out)
}

///|
fn termios_apply(fd : Int32, termios : FixedArray[Byte]) -> Int32 {
  tcsetattr_ffi(fd, TCSANOW, termios)
}

///|
/// 阻塞读取 stdin；返回读取字节数（0 = EOF，-1 = 无数据/中断）。
fn read_stdin(buf : FixedArray[Byte]) -> Int32 {
  read_ffi(0, buf, buf.length().to_uint64()).to_int()
}

///|
/// 终端尺寸（行列）。探测失败时回退 80×24。
fn terminal_size() -> (UInt32, UInt32) {
  let ws : FixedArray[Byte] = FixedArray::make(8, 0)
  // TIOCGWINSZ：Linux 0x5413，macOS/BSD 0x40087468。两个都试，取先成功者。
  if ioctl_ffi(1, 0x5413UL, ws) == 0 || ioctl_ffi(1, 0x40087468UL, ws) == 0 {
    let rows = u16_at(ws, 0)
    let cols = u16_at(ws, 2)
    if rows > 0 && cols > 0 {
      return (cols, rows)
    }
  }
  (80, 24)
}

///|
fn u16_at(buf : FixedArray[Byte], off : Int32) -> UInt32 {
  buf[off].to_uint() | (buf[off + 1].to_uint() << 8)
}
