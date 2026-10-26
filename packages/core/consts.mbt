// OpenTUI C ABI 常量。与 opentui.h 中的 #define 一一对应。

///|
pub const OT_CONTEXT_ABI_VERSION : UInt32 = 2

///|
pub const OT_OK : Int32 = 0

///|
pub const OT_INVALID_ARGUMENT : Int32 = -1

///|
pub const OT_UNSUPPORTED_VERSION : Int32 = -2

///|
pub const OT_WRONG_THREAD : Int32 = -4

///|
pub const OT_INTERNAL_ERROR : Int32 = -5

///|
pub const OT_CONTEXT_BUSY : Int32 = -6

///|
pub const OT_WRONG_CONTEXT : Int32 = -7

///|
pub const OT_WRONG_KIND : Int32 = -8

///|
pub const OT_STALE_HANDLE : Int32 = -9

///|
pub const OT_WRONG_SESSION : Int32 = -10

///|
pub const OT_OUTPUT_BACKPRESSURE : Int32 = -11

///|
pub const OT_SESSION_CLOSED : Int32 = -12

///|
pub const OT_OUTPUT_BUSY : Int32 = -13

///|
pub const OT_STALE_OUTPUT : Int32 = -14

///|
pub const OT_OUTPUT_FAILED : Int32 = -15

///|
pub const OT_OBJECT_LIMIT : Int32 = -16

///|
pub const OT_RENDERER_ATTACHED : Int32 = -17

///|
pub const OT_RENDERER_NOT_ATTACHED : Int32 = -18

///|
pub const OT_INVALID_PHASE : Int32 = -19

///|
pub const OT_UNSUPPORTED_RESOURCE : Int32 = -24

///|
pub const OT_STALE_FRAME : Int32 = -25

///|
pub const OT_FRAME_BUSY : Int32 = -27

///|
pub const OT_SCENE_ROOT : UInt32 = 0

///|
pub const OT_SCENE_BOX : UInt32 = 1

///|
pub const OT_SCENE_TEXT : UInt32 = 2

///|
pub const OT_SCENE_FRAME_DONE : UInt32 = 0

///|
pub const OT_SCENE_FRAME_RECORD : UInt32 = 4

///|
pub const OT_RENDER_PRESENTED : UInt32 = 0

///|
pub const OT_RENDER_PENDING : UInt32 = 1

///|
pub const OT_RENDER_SKIPPED : UInt32 = 2

///|
pub const OT_RENDER_FAILED : UInt32 = 3

///|
/// border_sides 位标志：left 1 | bottom 2 | right 4 | top 8
pub const OT_BORDER_ALL_SIDES : UInt32 = 15

///|
/// border_style 0：单线边框
pub const OT_BORDER_SINGLE : UInt32 = 0

///|
pub const OT_BORDER_DOUBLE : UInt32 = 1

///|
pub const OT_BORDER_ROUNDED : UInt32 = 2

///|
pub const OT_BORDER_HEAVY : UInt32 = 3

///|
/// 边框风格字符串 → 原生编号（未知值回退 single）。
pub fn parse_border_style(style : String) -> UInt32 {
  match style {
    "double" => OT_BORDER_DOUBLE
    "rounded" => OT_BORDER_ROUNDED
    "heavy" => OT_BORDER_HEAVY
    _ => OT_BORDER_SINGLE
  }
}

///|
pub const OT_INPUT_KEY : UInt32 = 1

///|
pub const OT_INPUT_KEY_PRESS : UInt32 = 1

///|
pub const OT_INPUT_KEY_REPEAT : UInt32 = 2

///|
pub const OT_INPUT_KEY_RELEASE : UInt32 = 3

///|
/// modifiers 位（ot_input_event.modifiers）
pub const OT_INPUT_MOD_SHIFT : UInt32 = 1

///|
pub const OT_INPUT_MOD_ALT : UInt32 = 2

///|
pub const OT_INPUT_MOD_CTRL : UInt32 = 4

///|
pub const OT_INPUT_MOD_SUPER : UInt32 = 8

///|
/// 功能键 code（Kitty keyboard protocol 赋值；可打印键是 Unicode scalar）
pub const OT_INPUT_KEY_ESCAPE : UInt32 = 27

///|
pub const OT_INPUT_KEY_ENTER : UInt32 = 13

///|
pub const OT_INPUT_KEY_TAB : UInt32 = 9

///|
pub const OT_INPUT_KEY_BACKSPACE : UInt32 = 127

///|
pub const OT_INPUT_KEY_INSERT : UInt32 = 57348

///|
pub const OT_INPUT_KEY_DELETE : UInt32 = 57349

///|
pub const OT_INPUT_KEY_LEFT : UInt32 = 57350

///|
pub const OT_INPUT_KEY_RIGHT : UInt32 = 57351

///|
pub const OT_INPUT_KEY_UP : UInt32 = 57352

///|
pub const OT_INPUT_KEY_DOWN : UInt32 = 57353

///|
pub const OT_INPUT_KEY_HOME : UInt32 = 57356

///|
pub const OT_INPUT_KEY_END : UInt32 = 57357

///|
pub const OT_PUMP_IDLE : UInt32 = 0

///|
pub const OT_PUMP_AGAIN : UInt32 = 1

///|
pub const OT_PUMP_OUTPUT_PENDING : UInt32 = 2

///|
pub const OT_PUMP_WAIT_UNTIL : UInt32 = 3

///|
pub const OT_PUMP_CLOSED : UInt32 = 4

///|
pub const OT_TERMINAL_ALTERNATE_SCREEN : UInt32 = 1

///|
pub const OT_TERMINAL_CLEAR_ON_CLOSE : UInt32 = 8

///|
/// ot_session_get_terminal_state 的 phase
pub const OT_TERMINAL_UNINITIALIZED : UInt32 = 0

///|
pub const OT_TERMINAL_SETTING_UP : UInt32 = 1

///|
pub const OT_TERMINAL_ACTIVE : UInt32 = 2

///|
/// 文本属性位（bits 0..7，标准 SGR：bold, dim, italic, underline, …）
pub const OT_TEXT_ATTR_BOLD : UInt32 = 1

///|
pub const OT_TEXT_ATTR_UNDERLINE : UInt32 = 8

///|
pub const OT_TEXT_ATTR_INVERSE : UInt32 = 32

///|
pub const OT_INPUT_KEY_PAGE_UP : UInt32 = 57354

///|
pub const OT_INPUT_KEY_PAGE_DOWN : UInt32 = 57355

///|
pub const OT_SCENE_ALIGN_LEFT : UInt32 = 0

///|
pub const OT_SCENE_ALIGN_CENTER : UInt32 = 1

///|
pub const OT_SCENE_ALIGN_RIGHT : UInt32 = 2

///|
/// style 记录的字段类型（ot_scene_style_property 的 group）
pub const OT_STYLE_ENUM : UInt32 = 0

///|
pub const OT_STYLE_FLOAT : UInt32 = 1

///|
pub const OT_STYLE_VALUE : UInt32 = 2

///|
pub const OT_STYLE_DIMENSION : UInt32 = 4

///|
/// VALUE 组 kind
pub const OT_STYLE_VALUE_WIDTH : UInt32 = 0

///|
pub const OT_STYLE_VALUE_HEIGHT : UInt32 = 1

///|
pub const OT_STYLE_VALUE_FLEX_BASIS : UInt32 = 6

///|
pub const OT_STYLE_VALUE_MARGIN : UInt32 = 7

///|
pub const OT_STYLE_VALUE_PADDING : UInt32 = 8

///|
pub const OT_STYLE_VALUE_POSITION : UInt32 = 9

///|
pub const OT_STYLE_VALUE_GAP : UInt32 = 10

///|
/// FLOAT 组 kind
pub const OT_STYLE_FLOAT_FLEX_GROW : UInt32 = 1

///|
pub const OT_STYLE_FLOAT_FLEX_SHRINK : UInt32 = 2

///|
/// ENUM 组 kind
pub const OT_STYLE_ENUM_FLEX_DIRECTION : UInt32 = 1

///|
pub const OT_STYLE_ENUM_JUSTIFY_CONTENT : UInt32 = 2

///|
pub const OT_STYLE_ENUM_ALIGN_ITEMS : UInt32 = 4

///|
pub const OT_STYLE_ENUM_ALIGN_SELF : UInt32 = 5

///|
pub const OT_STYLE_ENUM_POSITION_TYPE : UInt32 = 6

///|
pub const OT_STYLE_ENUM_OVERFLOW : UInt32 = 8

///|
/// flags
pub const OT_STYLE_FLAGS_NONE : UInt32 = 0

///|
pub const OT_STYLE_DISABLE_FLEX_SHRINK : UInt32 = 1

///|
/// 计量单位
pub const OT_UNIT_UNDEFINED : UInt32 = 0

///|
pub const OT_UNIT_POINT : UInt32 = 1

///|
pub const OT_UNIT_PERCENT : UInt32 = 2

///|
pub const OT_UNIT_AUTO : UInt32 = 3

///|
/// 边（VALUE MARGIN/PADDING/POSITION 的 edge）
pub const OT_EDGE_NONE : UInt32 = 0

///|
pub const OT_EDGE_LEFT : UInt32 = 0

///|
pub const OT_EDGE_TOP : UInt32 = 1

///|
pub const OT_EDGE_RIGHT : UInt32 = 2

///|
pub const OT_EDGE_BOTTOM : UInt32 = 3

///|
pub const OT_EDGE_ALL : UInt32 = 8

///|
/// ot_scene_flush 属性位：STYLE 必须是记录的唯一字段位
pub const OT_SCENE_PROPERTY_STYLE : UInt32 = 2048

///|
/// flex direction 枚举（Yoga；column=0 排最前）
pub const OT_FLEX_DIRECTION_COLUMN : UInt32 = 0

///|
pub const OT_FLEX_DIRECTION_COLUMN_REVERSE : UInt32 = 1

///|
pub const OT_FLEX_DIRECTION_ROW : UInt32 = 2

///|
pub const OT_FLEX_DIRECTION_ROW_REVERSE : UInt32 = 3

///|
/// justify-content 枚举
pub const OT_JUSTIFY_FLEX_START : UInt32 = 0

///|
pub const OT_JUSTIFY_CENTER : UInt32 = 1

///|
pub const OT_JUSTIFY_FLEX_END : UInt32 = 2

///|
pub const OT_JUSTIFY_SPACE_BETWEEN : UInt32 = 3

///|
pub const OT_JUSTIFY_SPACE_AROUND : UInt32 = 4

///|
pub const OT_JUSTIFY_SPACE_EVENLY : UInt32 = 5

///|
/// align-items / align-self 枚举
pub const OT_ALIGN_AUTO : UInt32 = 0

///|
pub const OT_ALIGN_FLEX_START : UInt32 = 1

///|
pub const OT_ALIGN_CENTER : UInt32 = 2

///|
pub const OT_ALIGN_FLEX_END : UInt32 = 3

///|
pub const OT_ALIGN_STRETCH : UInt32 = 4

///|
pub const OT_ALIGN_BASELINE : UInt32 = 5

///|
/// position-type 枚举
pub const OT_POSITION_RELATIVE : UInt32 = 1

///|
pub const OT_POSITION_ABSOLUTE : UInt32 = 2

///|
/// overflow 枚举
pub const OT_OVERFLOW_VISIBLE : UInt32 = 0

///|
pub const OT_OVERFLOW_HIDDEN : UInt32 = 1

///|
/// 文本换行（ot_scene_text_options.wrap_mode）
pub const OT_SCENE_WRAP_NONE : UInt32 = 0

///|
pub const OT_SCENE_WRAP_CHAR : UInt32 = 1

///|
pub const OT_SCENE_WRAP_WORD : UInt32 = 2

///|
/// display 枚举
pub const OT_DISPLAY_FLEX : UInt32 = 0

///|
pub const OT_DISPLAY_NONE : UInt32 = 1

///|
/// ENUM 组 kind：display
pub const OT_STYLE_ENUM_DISPLAY : UInt32 = 9

///|
/// styled text chunk 的 flags
pub const OT_SCENE_TEXT_FOREGROUND : UInt32 = 1

///|
pub const OT_SCENE_TEXT_BACKGROUND : UInt32 = 2

///|
pub const OT_SCENE_TEXT_LINK : UInt32 = 4

///|
/// slider orientation：0=horizontal，1=vertical（>1 拒绝）
pub const OT_SLIDER_ORIENTATION_HORIZONTAL : UInt32 = 0

///|
pub const OT_SLIDER_ORIENTATION_VERTICAL : UInt32 = 1

///|
/// 鼠标事件 action
pub const OT_INPUT_MOUSE_DOWN : UInt32 = 1

///|
pub const OT_INPUT_MOUSE_UP : UInt32 = 2

///|
pub const OT_INPUT_MOUSE_MOVE : UInt32 = 3

///|
pub const OT_INPUT_MOUSE_DRAG : UInt32 = 4

///|
pub const OT_INPUT_MOUSE_SCROLL : UInt32 = 5

///|
/// 鼠标按键（ot_input_event.code）
pub const OT_INPUT_MOUSE_BUTTON_NONE : UInt32 = 255

///|
/// 场景节点类型：slider
pub const OT_SCENE_SLIDER : UInt32 = 3

///|
/// 输入事件 kind：KEY=1 / MOUSE=2 / PASTE=3 / FOCUS=4 / REPLY=5
pub const OT_INPUT_MOUSE : UInt32 = 2

///|
pub const OT_INPUT_PASTE : UInt32 = 3

///|
pub const OT_INPUT_FOCUS : UInt32 = 4

///|
/// 焦点事件 action（OT_INPUT_FOCUS）
pub const OT_INPUT_FOCUS_OUT : UInt32 = 0

///|
pub const OT_INPUT_FOCUS_IN : UInt32 = 1

///|
/// 控制包 kind（ot_session_control_options.kind）
pub const OT_CONTROL_TITLE : UInt32 = 2

///|
pub const OT_CONTROL_MOUSE : UInt32 = 3

///|
pub const OT_CONTROL_PROGRAM_STATUS : UInt32 = 11

///|
/// OSC 7501 Program Status 的 state（ot_session_program_status.state）
pub const OT_PROGRAM_STATE_IDLE : UInt32 = 1

///|
pub const OT_PROGRAM_STATE_WORKING : UInt32 = 2

///|
pub const OT_PROGRAM_STATE_DONE : UInt32 = 3

///|
pub const OT_PROGRAM_STATE_BLOCKED : UInt32 = 4

///|
pub const OT_PROGRAM_STATE_ERROR : UInt32 = 5

///|
pub const OT_PROGRAM_STATE_CLEAR : UInt32 = 6

///|
/// BLOCKED 状态的 kind（ot_session_program_status.kind）
pub const OT_PROGRAM_KIND_PERMISSION : UInt32 = 1

///|
pub const OT_PROGRAM_KIND_QUESTION : UInt32 = 2

///|
pub const OT_PROGRAM_KIND_AUTH : UInt32 = 3

///|
/// fields 位：progress 有效（0..100，需 WORKING/BLOCKED）
pub const OT_PROGRAM_STATUS_PROGRESS : UInt32 = 1

///|
/// 场景节点类型：custom（宿主绘制钩子节点，FrameBuffer 等）
pub const OT_SCENE_CUSTOM : UInt32 = 6

///|
/// 场景钩子位（ot_scene_set_hooks.flags）：
pub const OT_SCENE_HOOK_RENDER_BEFORE : UInt32 = 8

///|
pub const OT_SCENE_HOOK_RENDER_AFTER : UInt32 = 16

///|
pub const OT_SCENE_HOOK_RENDER_SELF : UInt32 = 32

///|
/// 帧请求 kind 注释：DONE=0（可提交）/ UPDATE=1 / RESIZE=2 / LAYOUT_CHANGED=3 / RECORD=4（宿主录制；DONE 已在上方定义）
/// 录制流记录类型（ot_scene_record_header.operation）
pub const OT_SCENE_RECORD_SLOT : UInt32 = 0

///|
pub const OT_SCENE_RECORD_DRAW : UInt32 = 1

///|
/// 录制流 phase：BEFORE=0 / SELF=1 / AFTER=2
pub const OT_SCENE_RECORD_PHASE_BEFORE : UInt32 = 0

///|
pub const OT_SCENE_RECORD_PHASE_SELF : UInt32 = 1

///|
pub const OT_SCENE_RECORD_PHASE_AFTER : UInt32 = 2

///|
/// buffer 绘制操作（ot_buffer_draw_header.operation）
pub const OT_BUFFER_DRAW_CLEAR : UInt32 = 0

///|
pub const OT_BUFFER_DRAW_FILL : UInt32 = 1

///|
pub const OT_BUFFER_DRAW_TEXT : UInt32 = 2

///|
pub const OT_BUFFER_DRAW_CELL : UInt32 = 3

///|
pub const OT_BUFFER_DRAW_COMPOSE : UInt32 = 7

///|
/// buffer 绘制 flags：TEXT 带 background
pub const OT_BUFFER_DRAW_HAS_BACKGROUND : UInt32 = 1

///|
pub const OT_BUFFER_RESPECT_ALPHA : UInt32 = 1

///|
/// 宽度测量方法（ot_buffer_options.width_method）
pub const OT_WIDTH_METHOD_WCWIDTH : UInt32 = 0

///|

///|
/// 文本选区操作（ot_scene_text_selection_options.operation）
pub const OT_SCENE_TEXT_SELECTION_RESET : UInt32 = 0

///|
pub const OT_SCENE_TEXT_SELECTION_SET : UInt32 = 1

///|
pub const OT_SCENE_TEXT_SELECTION_UPDATE : UInt32 = 2

///|
/// 选区行为（ot_scene_text_selection_options.behavior）
pub const OT_SCENE_TEXT_SELECTION_CELL : UInt32 = 0

///|
pub const OT_SCENE_TEXT_SELECTION_WORD : UInt32 = 1

///|
pub const OT_SCENE_TEXT_SELECTION_LINE : UInt32 = 2

///|
/// 选区颜色位（ot_scene_text_selection_options.flags）
pub const OT_SCENE_TEXT_SELECTION_BACKGROUND : UInt32 = 1

///|
pub const OT_SCENE_TEXT_SELECTION_FOREGROUND : UInt32 = 2

///|
/// ot_scene_get_layout 的 observation：PUBLIC=公开 cell 几何 / PAINT=绘制几何
pub const OT_LAYOUT_PUBLIC : UInt32 = 0

///|
pub const OT_LAYOUT_PAINT : UInt32 = 2

///|
/// 场景节点类型：editor（绑定 ot_editor_view）
pub const OT_SCENE_EDITOR : UInt32 = 5

///|
pub const OT_SCENE_TEXT_VIEW : UInt32 = 7

///|
pub const OT_SCENE_IMAGE : UInt32 = 8

///|
/// 编辑缓冲命令（ot_edit_buffer_command）：完整集，见 opentui.h
pub const OT_EDIT_DELETE_FORWARD : UInt32 = 0

///|
pub const OT_EDIT_BACKSPACE : UInt32 = 1

///|
pub const OT_EDIT_NEW_LINE : UInt32 = 2

///|
pub const OT_EDIT_DELETE_LINE : UInt32 = 3

///|
pub const OT_EDIT_MOVE_LEFT : UInt32 = 4

///|
pub const OT_EDIT_MOVE_RIGHT : UInt32 = 5

///|
pub const OT_EDIT_MOVE_UP : UInt32 = 6

///|
pub const OT_EDIT_MOVE_DOWN : UInt32 = 7

///|
pub const OT_EDIT_GOTO_LINE : UInt32 = 8

///|
/// OT_EDIT_BUFFER_CURSOR_OFFSET：命令编号 9（见 opentui.h）
pub const OT_EDIT_CURSOR_OFFSET_CMD : UInt32 = 9

///|
/// 编辑器视图命令（ot_editor_view_command）
pub const OT_EDITOR_MOVE_UP : UInt32 = 0

///|
pub const OT_EDITOR_MOVE_DOWN : UInt32 = 1

///|
pub const OT_EDITOR_GOTO_LINE_END : UInt32 = 2

///|
pub const OT_EDITOR_DELETE_SELECTION : UInt32 = 3

///|
pub const OT_EDITOR_CURSOR_OFFSET : UInt32 = 4

///|
/// 选区操作（ot_editor_selection.operation）
pub const OT_EDITOR_SELECT_SET : UInt32 = 0

///|
pub const OT_EDITOR_SELECT_UPDATE : UInt32 = 1

///|
pub const OT_EDITOR_SELECT_RESET : UInt32 = 2

///|
/// ot_edit_buffer_get_position 的 query
pub const OT_EDIT_POSITION_CURSOR : UInt32 = 0

///|
pub const OT_EDIT_POSITION_OFFSET : UInt32 = 4

///|
pub const OT_EDIT_POSITION_COORDS : UInt32 = 5

///|
/// 高亮操作（ot_edit_buffer_highlight，extmark 简化实现用）
pub const OT_EDIT_HIGHLIGHT_ADD_RANGE : UInt32 = 1

///|
pub const OT_EDIT_HIGHLIGHT_REMOVE_REF : UInt32 = 2

///|
pub const OT_EDIT_HIGHLIGHT_CLEAR_ALL : UInt32 = 4

///|
/// 文本视图选项键（ot_text_buffer_view 不再有 options 调用，保留给 draw_text_view 等场景）
pub const OT_TEXT_VIEW_WRAP_WIDTH : UInt32 = 0

///|
pub const OT_TEXT_VIEW_WRAP_MODE : UInt32 = 1

///|
pub const OT_TEXT_VIEW_FIRST_LINE_OFFSET : UInt32 = 2

///|
pub const OT_TEXT_VIEW_TAB_INDICATOR : UInt32 = 3

///|
pub const OT_TEXT_VIEW_TRUNCATE : UInt32 = 4

///|
pub const OT_TEXT_VIEW_TEXT_ALIGN : UInt32 = 5

///|
/// 默认样式掩码（ot_edit_buffer_set_defaults / ot_text_buffer_set_defaults）
pub const OT_EDITOR_STYLE_FOREGROUND : UInt32 = 1

///|
pub const OT_EDITOR_STYLE_BACKGROUND : UInt32 = 2

///|
pub const OT_EDITOR_STYLE_ATTRIBUTES : UInt32 = 4

///|
/// 终端剪贴板 target（ot_session_clipboard）：0=clipboard
pub const OT_CLIPBOARD_TARGET_CLIPBOARD : UInt32 = 0

///|
/// 图像适配模式（ot_scene_set_image 的 fit）
pub const OT_IMAGE_FIT : UInt32 = 0

///|
pub const OT_IMAGE_COVER : UInt32 = 1

///|
pub const OT_IMAGE_FILL : UInt32 = 2

///|
/// 图像渲染协议（ot_scene_set_image / draw 的 protocol）
pub const OT_IMAGE_PROTOCOL_AUTO : UInt32 = 0

///|
pub const OT_IMAGE_PROTOCOL_KITTY : UInt32 = 1

///|
pub const OT_IMAGE_PROTOCOL_SIXEL : UInt32 = 2

///|
pub const OT_IMAGE_PROTOCOL_BLOCKS : UInt32 = 3

///|
/// 像素格式（ot_image_create_pixels / copy_pixels）
pub const OT_IMAGE_FORMAT_RGBA8 : UInt32 = 0

///|
pub const OT_IMAGE_FORMAT_BGRA8 : UInt32 = 1

///|
/// alpha 语义
pub const OT_IMAGE_ALPHA_STRAIGHT : UInt32 = 0

///|
pub const OT_IMAGE_ALPHA_OPAQUE : UInt32 = 1

///|
/// 缩放滤波
pub const OT_IMAGE_FILTER_DEFAULT : UInt32 = 0

///|
pub const OT_IMAGE_FILTER_NEAREST : UInt32 = 6

///|
/// 旋转/翻转操作（ot_image_transform）
pub const OT_IMAGE_ROTATE_90 : UInt32 = 0

///|
pub const OT_IMAGE_ROTATE_180 : UInt32 = 1

///|
pub const OT_IMAGE_ROTATE_270 : UInt32 = 2

///|
pub const OT_IMAGE_FLIP : UInt32 = 3

///|
pub const OT_IMAGE_FLOP : UInt32 = 4

///|
/// 混合模式（ot_image_composite）
pub const OT_IMAGE_BLEND_SOURCE_OVER : UInt32 = 0

///|
pub const OT_IMAGE_BLEND_SOURCE : UInt32 = 1

///|
pub const OT_IMAGE_BLEND_DESTINATION_OVER : UInt32 = 2

///|
/// Kitty 图像传输模式（requested）
pub const OT_KITTY_TRANSPORT_RAW : UInt32 = 0

///|
pub const OT_KITTY_TRANSPORT_ZLIB : UInt32 = 1

///|
pub const OT_KITTY_TRANSPORT_FILE : UInt32 = 2

///|
/// 分屏控制命令（ot_session_split_control）
pub const OT_SPLIT_COMMAND_RESET : UInt32 = 0

///|
pub const OT_SPLIT_COMMAND_SYNC : UInt32 = 1

///|
pub const OT_SPLIT_COMMAND_OUTPUT_OFFSET : UInt32 = 2

///|
pub const OT_SPLIT_COMMAND_RENDER_OFFSET : UInt32 = 3

///|
pub const OT_SPLIT_COMMAND_TRANSITION : UInt32 = 4

///|
pub const OT_SPLIT_COMMAND_CLEAR_TRANSITION : UInt32 = 5

///|
/// split snapshot flags：1 = 起新行，2 = 尾随换行
pub const OT_SPLIT_FLAG_NEW_LINE : UInt32 = 1

///|
pub const OT_SPLIT_FLAG_TRAILING_NEWLINE : UInt32 = 2
