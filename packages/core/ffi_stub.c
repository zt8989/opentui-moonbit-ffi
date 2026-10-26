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
