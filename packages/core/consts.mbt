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
