// 移植自 packages/examples/src/code-demo.ts（简化实现）：
// 语法高亮代码查看器 = TextBuffer + SyntaxStyle + OT_SCENE_TEXT_VIEW 节点
// + MoonBit 侧单遍分词器。TS 版 CodeRenderable 用 lezer 做完整语法分析；
// 这里按关键字/字符串/注释/数字/类型级高亮四种语言，机制链路完整：
// 样式注册 → ADD_RANGE 高亮 → 原生经视口换行绘制。
// 1-4 切换语言，↑/↓（j/k）滚动，PgUp/PgDn 翻页，q 退出。
// OT_HEADLESS=1 时渲染一帧到 stdout 后退出（供非交互验证）。

///|
#borrow(name)
extern "C" fn getenv_ffi(name : Bytes) -> Int64 = "getenv"

///|
#borrow(path, mode)
extern "C" fn fopen_ffi(path : Bytes, mode : Bytes) -> Int64 = "fopen"

///|
#borrow(buf)
extern "C" fn fwrite_ffi(
  buf : FixedArray[Byte],
  size : UInt64,
  count : UInt64,
  file : Int64,
) -> UInt64 = "fwrite"

///|
extern "C" fn fclose_ffi(file : Int64) -> Int32 = "fclose"

///|
fn write_info(path : String, lines : Array[String]) -> Unit {
  let file = fopen_ffi(@utf8.encode(path), b"w")
  if file == 0L {
    return
  }
  for line in lines {
    let bytes = @utf8.encode(line + "\n")
    let _ = fwrite_ffi(bytes_as_fa(bytes), 1UL, bytes.length().to_uint64(), file)
  }
  let _ = fclose_ffi(file)
}

///|
fn bytes_as_fa(bytes : Bytes) -> FixedArray[Byte] {
  let fa : FixedArray[Byte] = FixedArray::make(bytes.length(), 0)
  for i in 0..<bytes.length() {
    fa[i] = bytes[i]
  }
  fa
}

///|
/// 语言种类。
enum Lang {
  Ts
  Js
  Py
  Json
}

///|
fn Lang::name(self : Lang) -> String {
  match self {
    Ts => "TypeScript"
    Js => "JavaScript"
    Py => "Python"
    Json => "JSON"
  }
}

///|
fn Lang::file_ext(self : Lang) -> String {
  match self {
    Ts => "typescript"
    Js => "javascript"
    Py => "python"
    Json => "json"
  }
}

///|
/// 一个高亮 token：display-width 区间（跳过换行）+ 样式名。
struct Token {
  start : Int
  end : Int
  style : String
}

///|
/// 关键字集合（TS/JS 共用主干，Python/JSON 各自一套）。
fn is_keyword(lang : Lang, word : String) -> Bool {
  match lang {
    Ts =>
      match word {
        "interface" | "class" | "private" | "public" | "protected" | "readonly" | "constructor" | "return" | "if" | "else" | "throw" | "new" | "const" | "let" | "var" | "function" | "for" | "while" | "import" | "from" | "export" | "async" | "await" | "this" | "super" | "extends" | "implements" | "try" | "catch" | "finally" | "typeof" | "switch" | "case" | "break" | "continue" | "default" | "static" | "get" | "set" | "enum" | "type" | "namespace" | "in" | "of" | "void" | "null" | "undefined" | "true" | "false" => true
        _ => false
      }
    Js =>
      match word {
        "class" | "constructor" | "return" | "if" | "else" | "throw" | "new" | "const" | "let" | "var" | "function" | "for" | "while" | "import" | "from" | "export" | "async" | "await" | "this" | "super" | "extends" | "try" | "catch" | "finally" | "typeof" | "switch" | "case" | "break" | "continue" | "default" | "in" | "of" | "null" | "undefined" | "true" | "false" => true
        _ => false
      }
    Py =>
      match word {
        "def" | "class" | "return" | "if" | "elif" | "else" | "for" | "while" | "import" | "from" | "as" | "with" | "try" | "except" | "finally" | "raise" | "lambda" | "None" | "True" | "False" | "self" | "pass" | "break" | "continue" | "in" | "not" | "and" | "or" | "is" | "global" | "yield" | "async" | "await" | "del" => true
        _ => false
      }
    Json =>
      match word {
        "true" | "false" | "null" => true
        _ => false
      }
  }
}

///|
/// 判断 ch 是否属于标识符（字母/数字/下划线）。
fn is_word_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '_'
}

///|
/// 单遍扫描器：注释 / 字符串 / 数字 / 关键字 / 函数调用 / 类型名 / 运算符。
/// offset 空间为 display-width 且跳过换行（ADD_RANGE 语义，见 opentui.h）。
fn tokenize(lang : Lang, code : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let chars = code.to_array()
  let n = chars.length()
  // 起点显示列：offset(i) = i - 之前换行数（ASCII 文本）
  let mut newlines = 0
  let offsets : Array[Int] = []
  for i in 0..<n {
    offsets.push(i - newlines)
    if chars[i] == '\n' {
      newlines += 1
    }
  }
  offsets.push(n - newlines)
  let mut i = 0
  while i < n {
    let ch = chars[i]
    if ch == '\n' || ch == ' ' || ch == '\t' || ch == '\r' {
      i += 1
      continue
    }
    // 注释
    if ch == '/' && i + 1 < n && chars[i + 1] == '/' {
      let start = i
      while i < n && chars[i] != '\n' {
        i += 1
      }
      tokens.push({ start: offsets[start], end: offsets[i], style: "comment" })
      continue
    }
    if ch == '#' && (lang is Py) {
      let start = i
      while i < n && chars[i] != '\n' {
        i += 1
      }
      tokens.push({ start: offsets[start], end: offsets[i], style: "comment" })
      continue
    }
    if ch == '/' && i + 1 < n && chars[i + 1] == '*' {
      let start = i
      i += 2
      while i + 1 < n && !(chars[i] == '*' && chars[i + 1] == '/') {
        i += 1
      }
      if i + 1 < n {
        i += 2
      }
      tokens.push({ start: offsets[start], end: offsets[i], style: "comment" })
      continue
    }
    // 字符串（含转义）
    if ch == '"' || ch == '\'' || ch == '`' {
      let quote = ch
      let start = i
      i += 1
      while i < n {
        if chars[i] == '\\' {
          i += 2
          continue
        }
        if chars[i] == quote || chars[i] == '\n' {
          i += 1
          break
        }
        i += 1
      }
      tokens.push({ start: offsets[start], end: offsets[i], style: "string" })
      continue
    }
    // 数字
    if ch >= '0' && ch <= '9' {
      let start = i
      while i < n && (is_word_char(chars[i]) || chars[i] == '.') {
        i += 1
      }
      tokens.push({ start: offsets[start], end: offsets[i], style: "number" })
      continue
    }
    // 标识符 / 关键字 / 类型 / 函数
    if is_word_char(ch) && !(ch >= '0' && ch <= '9') {
      let start = i
      while i < n && is_word_char(chars[i]) {
        i += 1
      }
      let word = code.substring(start=start, end=i)
      let style : String = if is_keyword(lang, word) {
        "keyword"
      } else if i < n && chars[i] == '(' {
        "function"
      } else if ch >= 'A' && ch <= 'Z' {
        "type"
      } else {
        ""
      }
      if style != "" {
        tokens.push({ start: offsets[start], end: offsets[i], style })
      }
      continue
    }
    // 运算符与标点
    let start = i
    i += 1
    tokens.push({ start: offsets[start], end: offsets[i], style: "operator" })
  }
  tokens
}

///|
/// 四段示例代码（ASCII，保证显示列偏移简化成立）。
fn snippet(lang : Lang) -> String {
  match lang {
    Ts =>
      #|interface User {
      #|  name: string;
      #|  age: number;
      #|  email?: string;
      #|}
      #|
      #|class UserManager {
      #|  private users: User[] = [];
      #|
      #|  addUser(user: User): void {
      #|    if (!user.name || user.age < 0) {
      #|      throw new Error("Invalid user data");
      #|    }
      #|    this.users.push(user);
      #|  }
      #|
      #|  getAdults(minAge: number = 18): User[] {
      #|    // filter users over a certain age
      #|    return this.users.filter(user => user.age >= minAge);
      #|  }
      #|}
      #|
      #|const manager = new UserManager();
      #|manager.addUser({ name: "Alice", age: 25 });
      #|console.log(`Total: ${manager.getAdults().length}`);
      #|
    Js =>
      #|import React, { useState, useEffect } from 'react';
      #|
      #|function TodoApp() {
      #|  const [todos, setTodos] = useState([]);
      #|
      #|  useEffect(() => {
      #|    const saved = localStorage.getItem('todos');
      #|    if (saved) {
      #|      setTodos(JSON.parse(saved));
      #|    }
      #|  }, []);
      #|
      #|  const addTodo = () => {
      #|    if (input.trim()) {
      #|      setTodos([...todos, { id: Date.now(), text: input }]);
      #|    }
      #|  };
      #|
      #|  return (
      #|    /* render the list */
      #|    <ul>
      #|      {todos.map(todo => (
      #|        <li key={todo.id}>{todo.text}</li>
      #|      ))}
      #|    </ul>
      #|  );
      #|}
      #|
    Py =>
      #|from dataclasses import dataclass
      #|
      #|
      #|@dataclass
      #|class Task:
      #|    title: str
      #|    done: bool = False
      #|
      #|
      #|def complete_all(tasks):
      #|    # mark every task as done
      #|    for task in tasks:
      #|        if not task.done:
      #|            task.done = True
      #|    return tasks
      #|
      #|
      #|if __name__ == "__main__":
      #|    board = [Task("write spec"), Task("ship it")]
      #|    complete_all(board)
      #|    print(f"done: {len(board)}")
      #|
    Json =>
      #|{
      #|  "name": "opentui",
      #|  "version": "1.0.0",
      #|  "private": true,
      #|  "flags": [true, false, null],
      #|  "config": {
      #|    "borderStyle": "single",
      #|    "fontSize": 14,
      #|    "ratio": 0.75,
      #|    "tags": ["ui", "tui"]
      #|  },
      #|  "nested": {
      #|    "list": [1, 2, 3],
      #|    "enabled": false
      #|  }
      #|}
      #|
  }
}

///|
fn syntax_register(renderer : @core.Renderer) -> @core.SyntaxStyle raise {
  let style = @core.SyntaxStyle::create(renderer)
  let _ = style.register(name="keyword", fg="#FF6B9D", attributes=@core.OT_TEXT_ATTR_BOLD)
  let _ = style.register(name="string", fg="#A8E6CF")
  let _ = style.register(name="comment", fg="#6A9955")
  let _ = style.register(name="number", fg="#FFB86C")
  let _ = style.register(name="function", fg="#82AAFF")
  let _ = style.register(name="type", fg="#4ECDC4", attributes=@core.OT_TEXT_ATTR_BOLD)
  let _ = style.register(name="operator", fg="#89DDFF")
  style
}

///|
fn main raise {
  let headless = getenv_ffi(b"OT_HEADLESS") != 0
  let renderer = @core.Renderer::create(background="#0D1117")
  let root = renderer.root()
  let frame_w = renderer.get_width().reinterpret_as_int()
  let code_w = frame_w - 12
  let code_h = 12

  // 头部
  let header = @core.new_box(
    renderer,
    height="3",
    border=true,
    border_style="double",
    border_color="#4ECDC4",
    background="#0D1117",
    align_items="center",
    justify_content="center",
  )
  header.add(
    @core.new_text(
      renderer,
      content="Code Demo (TextBuffer + SyntaxStyle)",
      fg="#e6edf3",
      attributes="bold",
    ),
  )
  root.add(header)

  // 代码区：行号列 + TEXT_VIEW 节点
  let code_box = @core.new_box(
    renderer,
    height="16",
    border=true,
    border_color="#6BCF7F",
    background="#0D1117",
    padding=1,
    flex_direction="row",
    gap=1,
  )
  let line_numbers = @core.new_text(renderer, content="", fg="#3d4753", width="3")
  code_box.add(line_numbers)

  // 语法样式与文本缓冲
  let syntax = syntax_register(renderer)
  let buffer = @core.TextBuffer::create(renderer)
  let _ = buffer.set_syntax_style(syntax)
  let _ = buffer.set_tab_width(width=2)
  let view = buffer.view()
  let _ = view.set_viewport(x=0, y=0, width=code_w.to_uint(), height=code_h.to_uint())
  let code_node = @core.new_text_view(renderer, view, width="\{code_w}", height="\{code_h}")
  code_box.add(code_node)
  root.add(code_box)

  // 底部：语言状态 + 按键提示
  let status = @core.new_text(renderer, content="", fg="#8b949e")
  root.add(status)
  let footer = @core.new_text(
    renderer,
    content="1-4: language · ↑/↓ scroll · PgUp/PgDn page · q quit",
    fg="#8b949e",
  )
  root.add(footer)

  // 装载一段代码：文本 + 分词高亮
  let languages : Array[Lang] = [Ts, Js, Py, Json]
  let mut current = 0
  let mut scroll_y = 0
  let load = fn(lang : Lang) raise {
    let code = snippet(lang)
    buffer.set_text(text=code)
    // 重置旧高亮（富文本/高亮都以 ref 记录，CLEAR_ALL 一并清除）
    buffer.highlight_clear()
    for token in tokenize(lang, code) {
      let style_id = syntax.resolve(name=token.style)
      if style_id != 0 {
        buffer.highlight_range(
          start=token.start,
          end=token.end,
          style_id=style_id,
          ref_=0,
        )
      }
    }
    let info = buffer.get_info()
    let _ = status.set_content(
      "\{lang.name()}  lines=\{info.line_count()} bytes=\{info.byte_count()} highlights=\{info.highlight_count()}",
    )
  }
  let refresh = fn() raise {
    let _ = view.set_viewport(
      x=0,
      y=scroll_y.reinterpret_as_uint(),
      width=code_w.to_uint(),
      height=code_h.to_uint(),
    )
    // 行号按视口可见行的 source_line 重建
    let visible = view.get_lines(logical=false, capacity=code_h)
    let nums = StringBuilder(size_hint=code_h * 4)
    for line in visible.lines() {
      let n = line.source_line() + 1
      // 右对齐 2 位 + 换行（节点宽度 3，间隔列由 flex gap 提供）
      if n < 10 {
        nums.write_string(" \{n}\n")
      } else {
        nums.write_string("\{n}\n")
      }
    }
    let _ = line_numbers.set_content(nums.to_string())
  }
  load(languages[current])
  refresh()

  if headless {
    renderer.render()
    let info = buffer.get_info()
    let all = view.get_lines(logical=true, capacity=64)
    write_info(
      "code-demo-info.txt",
      [
        "lang=\{languages[current].file_ext()}",
        "lines=\{info.line_count()} bytes=\{info.byte_count()} highlights=\{info.highlight_count()}",
        "syntax_styles=\{syntax.get_count()}",
        "wrapped_lines=\{all.line_count()} width_max=\{all.width_cols_max()}",
        "text_len=\{buffer.get_text().length()}",
        "range_0_10=\{buffer.get_range(start=0, end=10)}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "q" | "escape" => {
        renderer.stop()
      }
      "1" | "2" | "3" | "4" => {
        current = match stroke.name { "1" => 0; "2" => 1; "3" => 2; _ => 3 }
        scroll_y = 0
        load(languages[current])
        refresh()
        renderer.render()
      }
      "down" | "j" => {
        if scroll_y < 200 {
          scroll_y += 1
          refresh()
          renderer.render()
        }
      }
      "up" | "k" => {
        if scroll_y > 0 {
          scroll_y -= 1
          refresh()
          renderer.render()
        }
      }
      "pagedown" => {
        scroll_y += code_h
        refresh()
        renderer.render()
      }
      "pageup" => {
        scroll_y -= code_h
        if scroll_y < 0 {
          scroll_y = 0
        }
        refresh()
        renderer.render()
      }
      _ => ()
    }
  })

  renderer.run()
}
