///|
test "encode_styled_chunk 字节布局与 C 一致" {
  let buf : FixedArray[Byte] = FixedArray::make(48, 0)
  encode_styled_chunk(
    buf,
    0,
    7,
    0x3,
    (255, 0, 0, 255),
    (0, 0, 255, 255),
    0,
    0,
    0,
  )
  let u32_at = fn(off : Int32) -> UInt32 {
    buf[off].to_uint() |
    (buf[off + 1].to_uint() << 8) |
    (buf[off + 2].to_uint() << 16) |
    (buf[off + 3].to_uint() << 24)
  }
  inspect(u32_at(0), content="48")
  inspect(u32_at(4), content="2")
  inspect(u32_at(8), content="7")
  // flags = FOREGROUND|BACKGROUND|bold = 1|2|1 = 3
  inspect(u32_at(12), content="3")
  // fg = (255,0,0,255)：pack(255,0)=255，pack(0,255)=16711680
  inspect(u32_at(16), content="255")
  let b20 = buf[20].to_int()
  let b21 = buf[21].to_int()
  let b22 = buf[22].to_int()
  let b23 = buf[23].to_int()
  inspect(b20, content="0")
  inspect(b21, content="0")
  inspect(b22, content="255")
  inspect(b23, content="0")
  let fg_hi = u32_at(20)
  inspect(fg_hi, content="16711680")
  // bg = (0,0,255,255)：pack(0,255)=16711680，pack(255,255)=16711935
  inspect(
    u32_at(24),
    content=(
      #|0
    ),
  )
  inspect(u32_at(28), content="16711935")
  inspect(u32_at(36), content="0")
  inspect(u32_at(44), content="0")
}

///|
test "pack_u16x2 位序" {
  inspect(pack_u16x2(255, 0), content="255")
  inspect(pack_u16x2(0, 255), content="16711680")
}
