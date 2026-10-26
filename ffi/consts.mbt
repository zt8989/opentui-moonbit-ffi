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
