// keymap 包：OpenTUI @opentui/keymap 核心的 MoonBit 移植。
//
// 覆盖原包的核心语义（packages/keymap/src）：
// - services/keys.ts：键名归一化、stroke 解析与规范显示（ctrl+shift+a），
//   match id（name:ctrl:shift:meta:super:hyper）
// - services/pending-sequence.ts + dispatch-decisions.ts：序列匹配的
//   sync 决策（run-exact / continue-sequence / clear）
// - 命令注册与 dispatch（command-executor.ts 的同步路径）
// 未移植：layer 条件系统、sequence pattern（<any> 捕获）、pending 超时
// （deferred disambiguation）、binding parser/token 扩展机制。

///|
/// 一次按键。name 为归一化小写键名："a"、"space"、"enter"、"up" 等。
pub struct KeyStroke {
  name : String
  ctrl : Bool
  shift : Bool
  meta : Bool
  super_ : Bool
  hyper : Bool
}

///|
/// 键绑定声明：key 是绑定串（"j"、"ctrl+c"、空格分隔的序列 "g g"），
/// command 是命令名，交给 on() 注册的处理器执行。
pub struct Binding {
  key : String
  command : String
  layer : String
  description : String
}

///|
pub fn Binding::make(
  key : String,
  command : String,
  layer~ : String = "default",
  description~ : String = "",
) -> Binding {
  { key, command, layer, description, }
}

///|
/// handle_key 的结果，对应原包 dispatch 的决策：
/// - Ran：命令已匹配并执行
/// - Pending：序列进行中，参数是已按下部分的规范显示
/// - Cleared：序列被不匹配的按键清除（参数是显示串）
/// - Ignored：无绑定匹配
pub enum DispatchResult {
  Ran(String)
  Pending(Array[String])
  Cleared(String)
  Ignored
}

///|
/// 编译后的绑定：解析好的按键序列 + 命令。
struct CompiledBinding {
  command : String
  description : String
  parts : Array[KeyStroke]
}

///|
struct PendingCandidate {
  binding : CompiledBinding
  next : Int32
}

///|
pub struct Keymap {
  bindings : Array[CompiledBinding]
  handlers : Map[String, () -> Unit]
  mut pending : Array[PendingCandidate]
  mut pending_display : Array[String]
}
