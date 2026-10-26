// FFI shim：解决 MoonBit 同一 C 符号只能绑定一个 extern 的限制。
//
// ot_scene_frame_step_with_geometry 的 previous 参数需要两种形态：
// NULL（开始新尝试）与非 NULL（确认上一次的请求）。C 侧无 NULL 包装，
// 这里补一个固定传 NULL 的入口，MoonBit 侧分别绑定两个符号。

#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct ot_context ot_context;

typedef struct ot_handle {
  uint64_t context_id;
  uint32_t slot;
  uint32_t generation;
} ot_handle;

typedef struct ot_scene_frame_request {
  uint32_t struct_size;
  uint32_t abi_version;
  ot_handle session;
  ot_handle root;
  ot_handle node;
  uint64_t frame_id;
  uint64_t request_id;
  uint64_t layout_epoch;
  uint64_t hook_generation;
  uint32_t kind;
  uint32_t num;
  uint32_t width;
  uint32_t height;
  uint32_t reserved[2];
} ot_scene_frame_request;
typedef struct ot_scene_frame_options ot_scene_frame_options;
typedef struct ot_scene_frame_geometry ot_scene_frame_geometry;

extern int32_t ot_scene_frame_step_with_geometry(
    ot_context *context, const ot_handle *session,
    const ot_scene_frame_request *previous,
    const ot_scene_frame_options *options, const uint8_t *recording,
    uint32_t recording_length, ot_scene_frame_request *out_request,
    ot_scene_frame_geometry *out_geometry);

int32_t ot_scene_frame_step_begin(
    ot_context *context, const ot_handle *session,
    const ot_scene_frame_options *options, const uint8_t *recording,
    uint32_t recording_length, ot_scene_frame_request *out_request,
    ot_scene_frame_geometry *out_geometry) {
  // MoonBit 空 Bytes 是非 NULL 指针；协议要求无录制时 recording 为 NULL。
  if (recording_length == 0)
    recording = 0;
  if (recording_length == 0)
    recording = 0;
  return ot_scene_frame_step_with_geometry(context, session, 0, options,
                                           recording, recording_length,
                                           out_request, out_geometry);
}

int32_t ot_scene_frame_step_confirm(
    ot_context *context, const ot_handle *session,
    const ot_scene_frame_request *previous,
    const ot_scene_frame_options *options, const uint8_t *recording,
    uint32_t recording_length, ot_scene_frame_request *out_request,
    ot_scene_frame_geometry *out_geometry) {
  if (recording_length == 0)
    recording = 0;
  if (recording_length == 0)
    recording = 0;
  return ot_scene_frame_step_with_geometry(context, session, previous, options,
                                           recording, recording_length,
                                           out_request, out_geometry);
}

// ot_buffer_draw 的记录类型多变体也受同一符号限制，且 MoonBit Bytes 传参
// 经验证与原生期待不符，这里为每种操作提供 shim：MoonBit struct 直接
// 传参（与 C 布局一致），shim 固定 frame=NULL（owned buffer）、source=NULL。

typedef struct ot_buffer_draw_header {
  uint32_t struct_size;
  uint32_t abi_version;
  uint32_t operation;
  uint32_t flags;
} ot_buffer_draw_header;

typedef struct ot_buffer_draw_clear {
  ot_buffer_draw_header header;
  uint16_t background[4];
} ot_buffer_draw_clear;

typedef struct ot_buffer_draw_fill {
  ot_buffer_draw_header header;
  int32_t x;
  int32_t y;
  uint32_t width;
  uint32_t height;
  uint16_t background[4];
} ot_buffer_draw_fill;

typedef struct ot_buffer_draw_text_record {
  ot_buffer_draw_header header;
  int32_t x;
  int32_t y;
  uint32_t attributes;
  uint16_t foreground[4];
  uint16_t background[4];
} ot_buffer_draw_text_record;

typedef struct ot_buffer_draw_cell {
  ot_buffer_draw_header header;
  int32_t x;
  int32_t y;
  uint32_t character;
  uint32_t attributes;
  uint16_t foreground[4];
  uint16_t background[4];
} ot_buffer_draw_cell;

extern int32_t ot_buffer_draw(ot_context *context, const ot_handle *target,
                              const ot_scene_frame_request *frame,
                              const ot_buffer_draw_header *options,
                              const ot_handle *source, const uint8_t *text,
                              uint32_t text_len,
                              const uint8_t *bottom_title,
                              uint32_t bottom_title_len);

int32_t ot_buffer_draw_clear_shim(ot_context *context, const ot_handle *target,
                                  const ot_buffer_draw_clear *record) {
  return ot_buffer_draw(context, target, 0,
                        (const ot_buffer_draw_header *)record, 0, 0, 0, 0, 0);
}

int32_t ot_buffer_draw_fill_shim(ot_context *context, const ot_handle *target,
                                 const ot_buffer_draw_fill *record) {
  return ot_buffer_draw(context, target, 0,
                        (const ot_buffer_draw_header *)record, 0, 0, 0, 0, 0);
}

int32_t ot_buffer_draw_text_shim(ot_context *context, const ot_handle *target,
                                 const ot_buffer_draw_text_record *record,
                                 const uint8_t *text, uint32_t text_len) {
  return ot_buffer_draw(context, target, 0,
                        (const ot_buffer_draw_header *)record, 0, text,
                        text_len, 0, 0);
}

int32_t ot_buffer_draw_cell_shim(ot_context *context, const ot_handle *target,
                                 const ot_buffer_draw_cell *record) {
  return ot_buffer_draw(context, target, 0,
                        (const ot_buffer_draw_header *)record, 0, 0, 0, 0, 0);
}


// ot_edit_buffer_highlight 的 ADD_RANGE 路径：MoonBit 侧混合传参
// （标量×4 + struct 指针）实测被原生拒绝，shim 固定 operation/argument。
typedef struct ot_edit_highlight {
  uint32_t start;
  uint32_t end;
  uint32_t style_id;
  uint32_t priority;
  uint32_t ref;
} ot_edit_highlight;

extern int32_t ot_edit_buffer_highlight(ot_context *context,
                                        const ot_handle *buffer,
                                        uint32_t operation, uint32_t argument,
                                        const ot_edit_highlight *highlight);

int32_t ot_edit_buffer_highlight_add_range(ot_context *context,
                                           const ot_handle *buffer,
                                           const ot_edit_highlight *highlight) {
  return ot_edit_buffer_highlight(context, buffer, 1 /* ADD_RANGE */, 0,
                                  highlight);
}

int32_t ot_edit_buffer_highlight_remove_ref(ot_context *context,
                                            const ot_handle *buffer,
                                            uint32_t ref) {
  // REMOVE_REF 只读 argument；highlight 记录必须为 NULL
  return ot_edit_buffer_highlight(context, buffer, 2 /* REMOVE_REF */, ref, 0);
}

int32_t ot_edit_buffer_highlight_clear(ot_context *context,
                                       const ot_handle *buffer) {
  // CLEAR_ALL 同样要求 highlight 为 NULL
  return ot_edit_buffer_highlight(context, buffer, 4 /* CLEAR_ALL */, 0, 0);
}

// ot_text_buffer_highlight 与 ot_edit_buffer_highlight 同形（标量×4+struct 尾），
// 按同一套 shim 处理三个常用路径。
extern int32_t ot_text_buffer_highlight(ot_context *context,
                                        const ot_handle *buffer,
                                        uint32_t operation, uint32_t argument,
                                        const ot_edit_highlight *highlight);

int32_t ot_text_buffer_highlight_add_range(ot_context *context,
                                           const ot_handle *buffer,
                                           const ot_edit_highlight *highlight) {
  return ot_text_buffer_highlight(context, buffer, 1 /* ADD_RANGE */, 0,
                                  highlight);
}

int32_t ot_text_buffer_highlight_remove_ref(ot_context *context,
                                            const ot_handle *buffer,
                                            uint32_t ref) {
  return ot_text_buffer_highlight(context, buffer, 2 /* REMOVE_REF */, ref, 0);
}

int32_t ot_text_buffer_highlight_clear(ot_context *context,
                                       const ot_handle *buffer) {
  return ot_text_buffer_highlight(context, buffer, 4 /* CLEAR_ALL */, 0, 0);
}

// ot_editor_style 内联展开为标量传参，避免（标量×2 + struct + out）混合形态。
typedef struct ot_editor_style {
  uint32_t struct_size;
  uint32_t abi_version;
  uint32_t flags;
  uint32_t attributes;
  uint16_t foreground[4];
  uint16_t background[4];
} ot_editor_style;

static void fill_editor_style(ot_editor_style *style, uint32_t flags,
                              uint32_t attributes, uint32_t fg01, uint32_t fg23,
                              uint32_t bg01, uint32_t bg23) {
  style->struct_size = (uint32_t)sizeof(ot_editor_style);
  style->abi_version = 2;
  style->flags = flags;
  style->attributes = attributes;
  style->foreground[0] = (uint16_t)(fg01 & 0xFFFF);
  style->foreground[1] = (uint16_t)(fg01 >> 16);
  style->foreground[2] = (uint16_t)(fg23 & 0xFFFF);
  style->foreground[3] = (uint16_t)(fg23 >> 16);
  style->background[0] = (uint16_t)(bg01 & 0xFFFF);
  style->background[1] = (uint16_t)(bg01 >> 16);
  style->background[2] = (uint16_t)(bg23 & 0xFFFF);
  style->background[3] = (uint16_t)(bg23 >> 16);
}

extern int32_t ot_syntax_style_register(ot_context *context,
                                        const ot_handle *style,
                                        const uint8_t *name, uint32_t name_len,
                                        const ot_editor_style *definition,
                                        uint32_t *out_id);

int32_t ot_syntax_style_register_packed(
    ot_context *context, const ot_handle *style, const uint8_t *name,
    uint32_t name_len, uint32_t flags, uint32_t attributes, uint32_t fg01,
    uint32_t fg23, uint32_t bg01, uint32_t bg23, uint32_t *out_id) {
  ot_editor_style definition;
  fill_editor_style(&definition, flags, attributes, fg01, fg23, bg01, bg23);
  return ot_syntax_style_register(context, style, name, name_len, &definition,
                                  out_id);
}

extern int32_t ot_edit_buffer_set_defaults(ot_context *context,
                                           const ot_handle *buffer,
                                           uint32_t mask,
                                           const ot_editor_style *defaults);

int32_t ot_edit_buffer_set_defaults_packed(ot_context *context,
                                           const ot_handle *buffer,
                                           uint32_t mask, uint32_t flags,
                                           uint32_t attributes, uint32_t fg01,
                                           uint32_t fg23, uint32_t bg01,
                                           uint32_t bg23) {
  if (flags == 0)
    return ot_edit_buffer_set_defaults(context, buffer, mask, 0);
  ot_editor_style defaults;
  fill_editor_style(&defaults, flags, attributes, fg01, fg23, bg01, bg23);
  return ot_edit_buffer_set_defaults(context, buffer, mask, &defaults);
}

extern int32_t ot_text_buffer_set_defaults(ot_context *context,
                                           const ot_handle *buffer,
                                           uint32_t mask,
                                           const ot_editor_style *defaults);

int32_t ot_text_buffer_set_defaults_packed(ot_context *context,
                                           const ot_handle *buffer,
                                           uint32_t mask, uint32_t flags,
                                           uint32_t attributes, uint32_t fg01,
                                           uint32_t fg23, uint32_t bg01,
                                           uint32_t bg23) {
  if (flags == 0)
    return ot_text_buffer_set_defaults(context, buffer, mask, 0);
  ot_editor_style defaults;
  fill_editor_style(&defaults, flags, attributes, fg01, fg23, bg01, bg23);
  return ot_text_buffer_set_defaults(context, buffer, mask, &defaults);
}

// 占位符：原生要求 chunk 覆盖全部字节（零 chunk = 清除占位符），
// 简化为纯文本 shim，自动补一个无样式 chunk 覆盖全部字节。
extern int32_t ot_editor_view_set_placeholder(ot_context *context,
                                              const ot_handle *view,
                                              const uint8_t *bytes,
                                              uint32_t byte_count,
                                              const void *chunks,
                                              uint32_t chunk_count);

typedef struct ot_styled_text_chunk {
  uint32_t struct_size;
  uint32_t abi_version;
  uint32_t byte_count;
  uint32_t flags;
  uint16_t foreground[4];
  uint16_t background[4];
  uint32_t attributes;
  uint32_t reserved;
  uint32_t link_offset;
  uint32_t link_byte_count;
} ot_styled_text_chunk;

int32_t ot_editor_view_set_placeholder_text(ot_context *context,
                                            const ot_handle *view,
                                            const uint8_t *bytes,
                                            uint32_t byte_count) {
  if (byte_count == 0)
    return ot_editor_view_set_placeholder(context, view, 0, 0, 0, 0);
  ot_styled_text_chunk chunk;
  memset(&chunk, 0, sizeof(chunk));
  chunk.struct_size = (uint32_t)sizeof(ot_styled_text_chunk);
  chunk.abi_version = 2;
  chunk.byte_count = byte_count;
  return ot_editor_view_set_placeholder(context, view, bytes, byte_count,
                                        &chunk, 1);
}

// get_lines / measure 的 out ot_editor_measure 用字节缓冲回传，
// 避免（标量×4 + struct 尾）形态；shim 只是把两种 out 合并到一次调用。
extern int32_t ot_editor_view_measure(ot_context *context, const ot_handle *view,
                                      uint32_t width, uint32_t height,
                                      void *out_measure);

int32_t ot_editor_view_measure_shim(ot_context *context, const ot_handle *view,
                                    uint32_t width, uint32_t height,
                                    uint32_t *out_pairs) {
  // out_pairs[0] = line_count, out_pairs[1] = width_cols_max
  uint32_t measure[4] = {16, 2, 0, 0};
  int32_t status =
      ot_editor_view_measure(context, view, width, height, measure);
  out_pairs[0] = measure[2];
  out_pairs[1] = measure[3];
  return status;
}

typedef struct ot_scene_text_line {
  uint32_t start_cols;
  uint32_t width_cols;
  uint32_t source_line;
  uint32_t wrap_index;
} ot_scene_text_line;

typedef struct ot_editor_measure {
  uint32_t struct_size;
  uint32_t abi_version;
  uint32_t line_count;
  uint32_t width_cols_max;
} ot_editor_measure;

extern int32_t ot_text_buffer_view_measure(ot_context *context,
                                           const ot_handle *view,
                                           uint32_t width, uint32_t height,
                                           void *out_measure);

int32_t ot_text_buffer_view_measure_shim(ot_context *context,
                                         const ot_handle *view,
                                         uint32_t width, uint32_t height,
                                         uint32_t *out_pairs) {
  uint32_t measure[4] = {16, 2, 0, 0};
  int32_t status =
      ot_text_buffer_view_measure(context, view, width, height, measure);
  out_pairs[0] = measure[2];
  out_pairs[1] = measure[3];
  return status;
}

typedef struct ot_editor_viewport {
  uint32_t struct_size;
  uint32_t abi_version;
  uint32_t x;
  uint32_t y;
  uint32_t width;
  uint32_t height;
} ot_editor_viewport;

extern int32_t ot_text_buffer_view_get_lines(ot_context *context,
                                             const ot_handle *view,
                                             uint32_t logical,
                                             uint32_t first_line,
                                             ot_scene_text_line *lines,
                                             uint32_t capacity,
                                             ot_editor_measure *out_info);

int32_t ot_text_buffer_view_get_lines_shim(ot_context *context,
                                           const ot_handle *view,
                                           uint32_t logical,
                                           uint32_t first_line,
                                           ot_scene_text_line *lines,
                                           uint32_t capacity,
                                           uint32_t *out_pairs) {
  ot_editor_measure measure = {16, 2, 0, 0};
  int32_t status = ot_text_buffer_view_get_lines(
      context, view, logical, first_line, lines, capacity, &measure);
  out_pairs[0] = measure.line_count;
  out_pairs[1] = measure.width_cols_max;
  return status;
}

extern int32_t ot_editor_view_get_lines(ot_context *context,
                                        const ot_handle *view, uint32_t logical,
                                        ot_scene_text_line *lines,
                                        uint32_t capacity,
                                        ot_editor_measure *out_info);

int32_t ot_editor_view_get_lines_shim(ot_context *context,
                                      const ot_handle *view, uint32_t logical,
                                      ot_scene_text_line *lines,
                                      uint32_t capacity, uint32_t *out_pairs) {
  ot_editor_measure measure = {16, 2, 0, 0};
  int32_t status =
      ot_editor_view_get_lines(context, view, logical, lines, capacity, &measure);
  out_pairs[0] = measure.line_count;
  out_pairs[1] = measure.width_cols_max;
  return status;
}

// ot_scene_set_image 的 buffer 参数固定 NULL（非缓冲绘制路径）。
extern int32_t ot_scene_set_image(ot_context *context, const ot_handle *node,
                                 const ot_handle *image, uint32_t fit,
                                 uint32_t protocol, const ot_handle *buffer);

int32_t ot_scene_set_image_null_buffer(ot_context *context,
                                       const ot_handle *node,
                                       const ot_handle *image, uint32_t fit,
                                       uint32_t protocol) {
  return ot_scene_set_image(context, node, image, fit, protocol, 0);
}

// ot_session_render_split 的 frame 双形态：NULL（纯 snapshot 提交）与
// 非 NULL（带主帧）。snapshots 缓冲是 24 字节/条的连续 ot_split_snapshot。
typedef struct ot_split_snapshot {
  ot_handle buffer;
  uint32_t row_columns;
  uint32_t flags;
} ot_split_snapshot;

extern int32_t ot_session_render_split(ot_context *context,
                                       const ot_handle *session,
                                       const ot_scene_frame_request *frame,
                                       const ot_split_snapshot *snapshots,
                                       uint32_t count,
                                       uint32_t pinned_render_offset,
                                       uint32_t force, uint32_t *out_status);

int32_t ot_session_render_split_no_frame(ot_context *context,
                                         const ot_handle *session,
                                         const ot_split_snapshot *snapshots,
                                         uint32_t count,
                                         uint32_t pinned_render_offset,
                                         uint32_t force,
                                         uint32_t *out_status) {
  return ot_session_render_split(context, session, 0, snapshots, count,
                                 pinned_render_offset, force, out_status);
}

int32_t ot_session_render_split_with_frame(
    ot_context *context, const ot_handle *session,
    const ot_scene_frame_request *frame, const ot_split_snapshot *snapshots,
    uint32_t count, uint32_t pinned_render_offset, uint32_t force,
    uint32_t *out_status) {
  return ot_session_render_split(context, session, frame, snapshots, count,
                                 pinned_render_offset, force, out_status);
}

// 内嵌终端：compose 离屏路径（frame 固定 NULL）；key 编码打包 shim。
extern int32_t ot_embedded_terminal_compose(ot_context *context,
                                           const ot_handle *terminal,
                                           const ot_handle *target,
                                           const ot_scene_frame_request *frame,
                                           int32_t x, int32_t y);

int32_t ot_embedded_terminal_compose_offscreen(ot_context *context,
                                               const ot_handle *terminal,
                                               const ot_handle *target, int32_t x,
                                               int32_t y) {
  return ot_embedded_terminal_compose(context, terminal, target, 0, x, y);
}

typedef struct ot_embedded_terminal_key {
  uint32_t struct_size;
  uint32_t abi_version;
  uint32_t action;
  uint32_t composing;
  uint32_t mods;
  uint32_t consumed_mods;
  uint32_t unshifted_codepoint;
  uint32_t reserved;
} ot_embedded_terminal_key;

extern int32_t ot_embedded_terminal_encode_key(
    ot_context *context, const ot_handle *terminal,
    const ot_embedded_terminal_key *key, const uint8_t *key_name,
    uint32_t key_count, const uint8_t *key_text, uint32_t text_count,
    uint8_t *bytes, uint32_t capacity, uint32_t *out_count);

int32_t ot_embedded_terminal_encode_key_packed(
    ot_context *context, const ot_handle *terminal, uint32_t action,
    uint32_t mods, uint32_t unshifted_codepoint, const uint8_t *key_name,
    uint32_t key_count, const uint8_t *key_text, uint32_t text_count,
    uint8_t *bytes, uint32_t capacity, uint32_t *out_count) {
  ot_embedded_terminal_key key;
  memset(&key, 0, sizeof(key));
  key.struct_size = (uint32_t)sizeof(key);
  key.abi_version = 2;
  key.action = action;
  key.mods = mods;
  key.unshifted_codepoint = unshifted_codepoint;
  return ot_embedded_terminal_encode_key(context, terminal, &key, key_name,
                                         key_count, key_text, text_count, bytes,
                                         capacity, out_count);
}


// Zig export bool（C _Bool，1 字节）与 MoonBit UInt32 返回不匹配，
// shim 转成 u32。
extern _Bool audioIsCaptureRunning(ot_context *context);

uint32_t audio_is_capture_running_shim(ot_context *context) {
  return audioIsCaptureRunning(context) ? 1u : 0u;
}


// 缓冲绘制扩展的离屏 shim（frame 固定 NULL），fg/bg 打包为 u32 对。
extern int32_t ot_buffer_draw_grayscale(ot_context *context,
                                        const ot_handle *target,
                                        const ot_scene_frame_request *frame,
                                        const float *data,
                                        uint32_t sample_count, int32_t x,
                                        int32_t y, uint32_t width,
                                        uint32_t height,
                                        const uint16_t *foreground,
                                        const uint16_t *background,
                                        uint32_t supersampled);

int32_t ot_buffer_draw_grayscale_offscreen(
    ot_context *context, const ot_handle *buffer, const uint8_t *data,
    uint32_t sample_count, int32_t x, int32_t y, uint32_t width,
    uint32_t height, uint32_t fg01, uint32_t fg23, uint32_t bg01,
    uint32_t bg23, uint32_t supersampled) {
  uint16_t fg[4] = {(uint16_t)(fg01 & 0xFFFF), (uint16_t)(fg01 >> 16),
                    (uint16_t)(fg23 & 0xFFFF), (uint16_t)(fg23 >> 16)};
  uint16_t bg[4] = {(uint16_t)(bg01 & 0xFFFF), (uint16_t)(bg01 >> 16),
                    (uint16_t)(bg23 & 0xFFFF), (uint16_t)(bg23 >> 16)};
  return ot_buffer_draw_grayscale(context, buffer, 0, (const float *)data,
                                  sample_count, x, y, width, height, fg, bg,
                                  supersampled);
}

extern int32_t ot_buffer_draw_supersample(ot_context *context,
                                          const ot_handle *target,
                                          const ot_scene_frame_request *frame,
                                          const uint8_t *data,
                                          uint32_t byte_count, int32_t x,
                                          int32_t y, uint32_t format,
                                          uint32_t stride);

int32_t ot_buffer_draw_supersample_offscreen(
    ot_context *context, const ot_handle *buffer, const uint8_t *data,
    uint32_t byte_count, int32_t x, int32_t y, uint32_t format,
    uint32_t stride) {
  return ot_buffer_draw_supersample(context, buffer, 0, data, byte_count, x, y,
                                    format, stride);
}

extern int32_t ot_buffer_draw_packed(ot_context *context,
                                     const ot_handle *target,
                                     const ot_scene_frame_request *frame,
                                     const uint8_t *data, uint32_t byte_count,
                                     int32_t x, int32_t y, uint32_t width,
                                     uint32_t height);

int32_t ot_buffer_draw_packed_offscreen(ot_context *context,
                                        const ot_handle *buffer,
                                        const uint8_t *data,
                                        uint32_t byte_count, int32_t x,
                                        int32_t y, uint32_t width,
                                        uint32_t height) {
  return ot_buffer_draw_packed(context, buffer, 0, data, byte_count, x, y,
                               width, height);
}

extern int32_t ot_buffer_draw_unicode(
    ot_context *context, const ot_handle *target,
    const ot_scene_frame_request *frame, const ot_handle *unicode,
    uint32_t index, int32_t x, int32_t y, const uint16_t *foreground,
    const uint16_t *background, uint32_t attributes);

int32_t ot_buffer_draw_unicode_offscreen(
    ot_context *context, const ot_handle *buffer, const ot_handle *unicode,
    uint32_t index, int32_t x, int32_t y, uint32_t fg01, uint32_t fg23,
    uint32_t bg01, uint32_t bg23, uint32_t attributes) {
  uint16_t fg[4] = {(uint16_t)(fg01 & 0xFFFF), (uint16_t)(fg01 >> 16),
                    (uint16_t)(fg23 & 0xFFFF), (uint16_t)(fg23 >> 16)};
  uint16_t bg[4] = {(uint16_t)(bg01 & 0xFFFF), (uint16_t)(bg01 >> 16),
                    (uint16_t)(bg23 & 0xFFFF), (uint16_t)(bg23 >> 16)};
  return ot_buffer_draw_unicode(context, buffer, 0, unicode, index, x, y, fg,
                                bg, attributes);
}


// 剪贴板异步服务：u8 返回转 u32 的 shim。
extern uint8_t ot_clipboard_service_create(ot_context *context,
                                           uint32_t max_operations,
                                           uint32_t max_provider_transfers,
                                           const uint8_t *wayland_seat,
                                           uint32_t wayland_seat_length);
extern uint8_t ot_clipboard_service_drain(ot_context *context);
extern uint8_t ot_clipboard_service_destroy(ot_context *context);
extern uint8_t ot_clipboard_read_operation_start(
    ot_context *context, const uint8_t *request, uint32_t request_length,
    uint8_t selection, uint32_t max_bytes, uint32_t max_image_pixels,
    uint32_t max_conversion_bytes, uint32_t timeout_ms, ot_handle *out_operation);
extern uint8_t ot_clipboard_write_operation_start(
    ot_context *context, const uint8_t *text, uint32_t text_length,
    uint8_t selection, uint32_t timeout_ms, ot_handle *out_operation);
extern uint8_t ot_clipboard_operation_poll(ot_context *context,
                                           const ot_handle *operation);
extern uint8_t ot_clipboard_operation_result_data_length(
    ot_context *context, const ot_handle *operation, uint32_t *out_length);
extern uint8_t ot_clipboard_operation_result_data_copy(ot_context *context,
                                                       const ot_handle *operation,
                                                       uint8_t *out_bytes,
                                                       uint32_t capacity);
extern uint8_t ot_clipboard_operation_result_error_code(ot_context *context,
                                                        const ot_handle *operation,
                                                        uint32_t *out_error_code);
extern uint8_t ot_clipboard_operation_destroy(ot_context *context,
                                              const ot_handle *operation);

uint32_t ot_clipboard_service_create_shim(ot_context *context,
                                          uint32_t max_operations,
                                          uint32_t max_provider_transfers) {
  return ot_clipboard_service_create(context, max_operations,
                                     max_provider_transfers, 0, 0);
}

uint32_t ot_clipboard_service_drain_shim(ot_context *context) {
  return ot_clipboard_service_drain(context);
}

uint32_t ot_clipboard_service_destroy_shim(ot_context *context) {
  return ot_clipboard_service_destroy(context);
}

uint32_t ot_clipboard_read_operation_start_shim(
    ot_context *context, const uint8_t *request, uint32_t request_length,
    uint32_t selection, uint32_t max_bytes, uint32_t max_image_pixels,
    uint32_t max_conversion_bytes, uint32_t timeout_ms,
    ot_handle *out_operation) {
  return ot_clipboard_read_operation_start(context, request, request_length,
                                           (uint8_t)selection, max_bytes,
                                           max_image_pixels,
                                           max_conversion_bytes, timeout_ms,
                                           out_operation);
}

uint32_t ot_clipboard_write_operation_start_shim(
    ot_context *context, const uint8_t *text, uint32_t text_length,
    uint32_t selection, uint32_t timeout_ms, ot_handle *out_operation) {
  return ot_clipboard_write_operation_start(context, text, text_length,
                                            (uint8_t)selection, timeout_ms,
                                            out_operation);
}

uint32_t ot_clipboard_operation_poll_shim(ot_context *context,
                                          const ot_handle *operation) {
  return ot_clipboard_operation_poll(context, operation);
}

uint32_t ot_clipboard_operation_result_data_length_shim(
    ot_context *context, const ot_handle *operation, uint32_t *out_length) {
  return ot_clipboard_operation_result_data_length(context, operation,
                                                   out_length);
}

uint32_t ot_clipboard_operation_result_data_copy_shim(
    ot_context *context, const ot_handle *operation, uint8_t *out_bytes,
    uint32_t capacity) {
  return ot_clipboard_operation_result_data_copy(context, operation, out_bytes,
                                                 capacity);
}

uint32_t ot_clipboard_operation_result_error_code_shim(
    ot_context *context, const ot_handle *operation, uint32_t *out_code) {
  return ot_clipboard_operation_result_error_code(context, operation, out_code);
}

uint32_t ot_clipboard_operation_destroy_shim(ot_context *context,
                                             const ot_handle *operation) {
  return ot_clipboard_operation_destroy(context, operation);
}
