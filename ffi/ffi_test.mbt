// 纯 MoonBit 侧的单元测试（不加载原生库）。

///|
test "pack_u16x2 按小端把两个 u16 通道打包进 u32" {
  // (0, 255) → 第二个通道占高 16 位，其低 8 位是字节值 255
  assert_eq(pack_u16x2(0, 255), 0x00FF_0000)
  assert_eq(pack_u16x2(255, 255), 0x00FF_00FF)
  assert_eq(pack_u16x2(0, 0), 0)
}

///|
test "status_name 覆盖常见状态码" {
  assert_eq(status_name(OT_OK), "OT_OK")
  assert_eq(status_name(-8), "OT_WRONG_KIND")
  assert_eq(status_name(-24), "OT_UNSUPPORTED_RESOURCE")
  assert_eq(status_name(-99), "OT_UNKNOWN")
}

///|
test "make_context_options 填好版本化记录头" {
  let o = make_context_options(8, 36)
  assert_eq(o.struct_size, 32)
  assert_eq(o.abi_version, OT_CONTEXT_ABI_VERSION)
  assert_eq(o.object_capacity, 8)
  assert_eq(o.render_cells_max, 36)
}

///|
test "make_paint_options 默认值符合 C 指南示例" {
  let p = make_paint_options()
  assert_eq(p.struct_size, 80)
  assert_eq(p.opacity, 1.0)
  assert_eq(p.border_sides, 15)
  // 白色不透明边框：两通道打包 (255,255)
  assert_eq(p.border_color01, 0x00FF_00FF)
  assert_eq(p.border_color23, 0x00FF_00FF)
}
