import gleam/bit_array
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleeunit/internal/gleam_panic.{type GleamPanic}

pub type State {
  State(
    passed: Int,
    failed: Int,
    skipped: Int,
    todos: Int,
    todo_entries: List(String),
    failure_entries: List(String),
    todo_ids: List(String),
    report_dir: Option(String),
  )
}

pub fn new_state() -> State {
  State(
    passed: 0,
    failed: 0,
    skipped: 0,
    todos: 0,
    todo_entries: [],
    failure_entries: [],
    todo_ids: [],
    report_dir: option.None,
  )
}

pub fn new_state_with_report_dir(report_dir: Option(String)) -> State {
  State(
    passed: 0,
    failed: 0,
    skipped: 0,
    todos: 0,
    todo_entries: [],
    failure_entries: [],
    todo_ids: [],
    report_dir: report_dir,
  )
}

pub fn maybe_write_todos(state: State) -> Nil {
  case state.report_dir {
    option.Some(dir) -> write_todos_report(state, dir)
    option.None -> Nil
  }
}

pub fn finished(state: State) -> Int {
  let todo_suffix = case state.todos {
    0 -> ""
    n -> ", " <> int.to_string(n) <> " todo"
  }
  let skipped_suffix = case state.skipped {
    0 -> ""
    n -> ", " <> int.to_string(n) <> " skipped"
  }

  print_summary(state)

  case state {
    State(passed: 0, failed: 0, skipped: 0, todos: 0, ..) -> {
      io.println("\nNo tests found!")
      1
    }
    State(failed: 0, skipped: 0, todos: 0, ..) -> {
      let message =
        "\n" <> int.to_string(state.passed) <> " passed, no failures"
      io.println(green(message))
      0
    }
    State(failed: 0, ..) -> {
      let message =
        "\n"
        <> int.to_string(state.passed)
        <> " passed, 0 failures"
        <> todo_suffix
        <> skipped_suffix
      io.println(yellow(message))
      1
    }
    State(..) -> {
      let message =
        "\n"
        <> int.to_string(state.passed)
        <> " passed, "
        <> int.to_string(state.failed)
        <> " failures"
        <> todo_suffix
        <> skipped_suffix
      io.println(red(message))
      1
    }
  }
}

fn print_summary(state: State) -> Nil {
  case state.todo_entries {
    [] -> Nil
    entries -> {
      io.println("\n" <> yellow("Todo:"))
      list.reverse(entries)
      |> list.each(fn(entry) { io.println("  - " <> entry) })
    }
  }
  case state.failure_entries {
    [] -> Nil
    entries -> {
      io.println("\n" <> red("Failures:"))
      list.reverse(entries)
      |> list.each(fn(entry) { io.println("  - " <> entry) })
    }
  }
}

pub fn test_passed(state: State) -> State {
  io.print(green("."))
  State(..state, passed: state.passed + 1)
}

pub fn test_failed(
  state: State,
  module: String,
  function: String,
  error: dynamic.Dynamic,
) -> State {
  case gleam_panic.from_dynamic(error) {
    Ok(gleam_panic.GleamPanic(kind: gleam_panic.Todo, ..) as e) -> {
      let src = option.from_result(read_file(e.file))
      let message = format_gleam_error(e, module, function, src)
      io.print("\n" <> message)
      let entry =
        module
        <> "."
        <> function
        <> " ("
        <> e.file
        <> ":"
        <> int.to_string(e.line)
        <> ")"
      let todo_id = module <> ":" <> function
      State(
        ..state,
        todos: state.todos + 1,
        todo_entries: [entry, ..state.todo_entries],
        todo_ids: [todo_id, ..state.todo_ids],
      )
    }
    Ok(e) -> {
      let src = option.from_result(read_file(e.file))
      let message = format_gleam_error(e, module, function, src)
      io.print("\n" <> message)
      let entry =
        module
        <> "."
        <> function
        <> " ("
        <> e.file
        <> ":"
        <> int.to_string(e.line)
        <> ")"
      State(
        ..state,
        failed: state.failed + 1,
        failure_entries: [entry, ..state.failure_entries],
      )
    }
    Error(_) -> {
      let message = format_unknown(module, function, error)
      io.print("\n" <> message)
      let entry = module <> "." <> function
      State(
        ..state,
        failed: state.failed + 1,
        failure_entries: [entry, ..state.failure_entries],
      )
    }
  }
}

pub fn eunit_missing() -> Result(never, Nil) {
  let message = bold(red("Error")) <> ": EUnit libraries not found.

Your Erlang installation seems to be incomplete. If you installed Erlang using
a package manager ensure that you have installed the full Erlang
distribution instead of a stripped-down version.
"
  io.print_error(message)
  Error(Nil)
}

fn format_unknown(
  module: String,
  function: String,
  error: dynamic.Dynamic,
) -> String {
  string.concat([
    grey(module <> "." <> function) <> "\n",
    "An unexpected error occurred:\n",
    "\n",
    "  " <> string.inspect(error) <> "\n",
  ])
}

fn format_gleam_error(
  error: GleamPanic,
  module: String,
  function: String,
  src: Option(BitArray),
) -> String {
  let location = grey(error.file <> ":" <> int.to_string(error.line))

  case error.kind {
    gleam_panic.Panic -> {
      string.concat([
        bold(red("panic")) <> " " <> location <> "\n",
        cyan(" test") <> ": " <> module <> "." <> function <> "\n",
        cyan(" info") <> ": " <> error.message <> "\n",
      ])
    }

    gleam_panic.Todo -> {
      string.concat([
        bold(yellow("todo")) <> " " <> location <> "\n",
        cyan(" test") <> ": " <> module <> "." <> function <> "\n",
        cyan(" info") <> ": " <> error.message <> "\n",
      ])
    }

    gleam_panic.Assert(start:, end:, kind:, ..) -> {
      string.concat([
        bold(red("assert")) <> " " <> location <> "\n",
        cyan(" test") <> ": " <> module <> "." <> function <> "\n",
        code_snippet(src, start, end),
        assert_info(kind),
        cyan(" info") <> ": " <> error.message <> "\n",
      ])
    }

    gleam_panic.LetAssert(start:, end:, value:, ..) -> {
      string.concat([
        bold(red("let assert")) <> " " <> location <> "\n",
        cyan(" test") <> ": " <> module <> "." <> function <> "\n",
        code_snippet(src, start, end),
        cyan("value") <> ": " <> string.inspect(value) <> "\n",
        cyan(" info") <> ": " <> error.message <> "\n",
      ])
    }
  }
}

fn assert_info(kind: gleam_panic.AssertKind) -> String {
  case kind {
    gleam_panic.BinaryOperator(left:, right:, ..) -> {
      string.concat([assert_value(" left", left), assert_value("right", right)])
    }

    gleam_panic.FunctionCall(arguments:) -> {
      arguments
      |> list.index_map(fn(e, i) {
        let number = string.pad_start(int.to_string(i), 5, " ")
        assert_value(number, e)
      })
      |> string.concat
    }

    gleam_panic.OtherExpression(..) -> ""
  }
}

fn assert_value(name: String, value: gleam_panic.AssertedExpression) -> String {
  cyan(name) <> ": " <> inspect_value(value) <> "\n"
}

fn inspect_value(value: gleam_panic.AssertedExpression) -> String {
  case value.kind {
    gleam_panic.Unevaluated -> grey("unevaluated")
    gleam_panic.Literal(..) -> grey("literal")
    gleam_panic.Expression(value:) -> string.inspect(value)
  }
}

fn code_snippet(src: Option(BitArray), start: Int, end: Int) -> String {
  {
    use src <- result.try(option.to_result(src, Nil))
    use snippet <- result.try(bit_array.slice(src, start, end - start))
    use snippet <- result.try(bit_array.to_string(snippet))
    let snippet = cyan(" code") <> ": " <> snippet <> "\n"
    Ok(snippet)
  }
  |> result.unwrap("")
}

pub fn test_skipped(state: State, module: String, function: String) -> State {
  io.print("\n" <> module <> "." <> function <> yellow(" skipped"))
  State(..state, skipped: state.skipped + 1)
}

fn bold(text: String) -> String {
  "\u{001b}[1m" <> text <> "\u{001b}[22m"
}

fn cyan(text: String) -> String {
  "\u{001b}[36m" <> text <> "\u{001b}[39m"
}

fn yellow(text: String) -> String {
  "\u{001b}[33m" <> text <> "\u{001b}[39m"
}

fn green(text: String) -> String {
  "\u{001b}[32m" <> text <> "\u{001b}[39m"
}

fn red(text: String) -> String {
  "\u{001b}[31m" <> text <> "\u{001b}[39m"
}

fn grey(text: String) -> String {
  "\u{001b}[90m" <> text <> "\u{001b}[39m"
}

pub fn write_todos_report(state: State, dir: String) -> Nil {
  case state.todo_ids {
    [] -> Nil
    ids -> {
      let content = ids |> list.reverse |> string.join("\n")
      let filepath = join_path(dir, "todos.txt")
      let _ = write_file(filepath, content)
      Nil
    }
  }
}

@external(erlang, "filename", "join")
fn join_path(dir: String, file: String) -> String

@external(erlang, "file", "write_file")
fn write_file(path: String, content: String) -> Result(Nil, dynamic.Dynamic)

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(BitArray, dynamic.Dynamic) {
  case read_file_text(path) {
    Ok(text) -> Ok(bit_array.from_string(text))
    Error(e) -> Error(e)
  }
}

@external(javascript, "../../gleeunit_ffi.mjs", "read_file")
fn read_file_text(path: String) -> Result(String, dynamic.Dynamic)
