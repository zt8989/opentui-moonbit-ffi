// TS 风格颜色字符串解析（对齐 @opentui/core 的颜色输入）：
// "#rgb" / "#rgba" / "#rrggbb" / "#rrggbbaa" / "transparent" / 少量命名色。
// 分量取值 0..255（uint16 通道的低 8 位是字节值，高 8 位必须为 0）。

///|
fn hex_digit(c : UInt16) -> Int32 raise {
  if c >= 48 && c <= 57 {
    c.to_int() - 48
  } else if c >= 97 && c <= 102 {
    c.to_int() - 87
  } else if c >= 65 && c <= 70 {
    c.to_int() - 55
  } else {
    raise Failure("invalid hex digit '\\{c}' in color")
  }
}

///|
fn hex_pair(s : String, index : Int32) -> Int32 raise {
  // String 索引返回 UTF-16 码元（UInt16）；十六进制字符是 ASCII，直接换算
  hex_digit(s[index]) * 16 + hex_digit(s[index + 1])
}

///|
/// 解析 TS 风格颜色。命名色仅覆盖示例用到的子集，其余用 #rrggbb。
pub fn parse_color(input : String) -> RgbaColor raise {
  let s = input.trim(chars=" ").to_owned()
  if s == "transparent" || s == "" {
    return (0, 0, 0, 0)
  }
  if s[0] == 35 {
    let hex = s[1:s.length()].to_owned()
    match hex.length() {
      3 => {
        // #rgb → 每位翻倍
        let r = (hex_digit(hex[0]) * 17).to_uint16()
        let g = (hex_digit(hex[1]) * 17).to_uint16()
        let b = (hex_digit(hex[2]) * 17).to_uint16()
        return (r, g, b, 255)
      }
      4 => {
        let r = (hex_digit(hex[0]) * 17).to_uint16()
        let g = (hex_digit(hex[1]) * 17).to_uint16()
        let b = (hex_digit(hex[2]) * 17).to_uint16()
        let a = (hex_digit(hex[3]) * 17).to_uint16()
        return (r, g, b, a)
      }
      6 =>
        return (
          hex_pair(hex, 0).to_uint16(),
          hex_pair(hex, 2).to_uint16(),
          hex_pair(hex, 4).to_uint16(),
          255,
        )
      8 =>
        return (
          hex_pair(hex, 0).to_uint16(),
          hex_pair(hex, 2).to_uint16(),
          hex_pair(hex, 4).to_uint16(),
          hex_pair(hex, 6).to_uint16(),
        )
      _ => raise Failure("unsupported color length: \{input}")
    }
  }
  match s {
    "white" => (255, 255, 255, 255)
    "black" => (0, 0, 0, 255)
    "red" => (255, 0, 0, 255)
    "green" => (0, 128, 0, 255)
    "blue" => (0, 0, 255, 255)
    "yellow" => (255, 255, 0, 255)
    "cyan" => (0, 255, 255, 255)
    "magenta" => (255, 0, 255, 255)
    "gray" | "grey" => (128, 128, 128, 255)
    _ => raise Failure("unknown color: \{input}")
  }
}

///|
/// 解析失败的变体：返回透明色（容错渲染）。
pub fn parse_color_lossy(input : String) -> RgbaColor {
  parse_color(input) catch {
    _ => (0, 0, 0, 0)
  }
}
