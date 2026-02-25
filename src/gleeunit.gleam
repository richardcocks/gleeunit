import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Options for configuring gleeunit test execution.
pub type GleeunitOption {
  /// Write Surefire XML results and todo reports to the specified directory.
  WithReportDir(String)
  /// Run only tests in the specified module.
  WithModule(String)
  /// Run only the specified test function (module, function).
  WithTest(String, String)
}

/// Find and run all test functions for the current project using Erlang's EUnit
/// test framework, or a custom JavaScript test runner.
///
/// Any Erlang or Gleam function in the `test` directory with a name ending in
/// `_test` is considered a test function and will be run.
///
/// A test that panics is considered a failure.
///
pub fn main() -> Nil {
  main_with_options([])
}

/// Like `main()`, but accepts a list of options to configure test execution.
///
/// If `WithReportDir` is provided, surefire XML results and a todos report
/// will be written to that directory. A `--report-dir` CLI argument takes
/// precedence over the API option.
///
/// Use `WithModule` or `WithTest` to filter which tests are run.
/// CLI `--module` and `--test` arguments take precedence over API options.
///
pub fn main_with_options(options: List(GleeunitOption)) -> Nil {
  let report_dir = resolve_report_dir(options)
  let filters = resolve_filters(options)
  do_main(report_dir, filters)
}

fn resolve_report_dir(options: List(GleeunitOption)) -> Option(String) {
  case get_cli_report_dir() {
    Some(dir) -> Some(dir)
    None -> find_report_dir(options)
  }
}

fn find_report_dir(options: List(GleeunitOption)) -> Option(String) {
  case options {
    [WithReportDir(dir), ..] -> Some(dir)
    [_, ..rest] -> find_report_dir(rest)
    [] -> None
  }
}

/// Resolves test filters from CLI args and API options.
/// CLI takes precedence — if any CLI filters exist, API filters are ignored.
fn resolve_filters(options: List(GleeunitOption)) -> List(EunitTestSpec) {
  let cli_modules = get_cli_modules()
  let cli_tests = get_cli_tests()
  case cli_modules, cli_tests {
    [], [] -> collect_api_filters(options, [])
    _, _ -> {
      let module_specs =
        list.map(cli_modules, fn(m) {
          ModuleSpec(dangerously_convert_string_to_atom(m, Utf8))
        })
      let test_specs =
        list.map(cli_tests, fn(pair) {
          TestSpec(
            dangerously_convert_string_to_atom(pair.0, Utf8),
            dangerously_convert_string_to_atom(pair.1, Utf8),
          )
        })
      list.append(module_specs, test_specs)
    }
  }
}

fn collect_api_filters(
  options: List(GleeunitOption),
  acc: List(EunitTestSpec),
) -> List(EunitTestSpec) {
  case options {
    [WithModule(m), ..rest] ->
      collect_api_filters(rest, [
        ModuleSpec(dangerously_convert_string_to_atom(m, Utf8)),
        ..acc
      ])
    [WithTest(m, f), ..rest] ->
      collect_api_filters(rest, [
        TestSpec(
          dangerously_convert_string_to_atom(m, Utf8),
          dangerously_convert_string_to_atom(f, Utf8),
        ),
        ..acc
      ])
    [_, ..rest] -> collect_api_filters(rest, acc)
    [] -> list.reverse(acc)
  }
}

@external(erlang, "gleeunit_ffi", "get_cli_report_dir")
fn get_cli_report_dir() -> Option(String)

@external(erlang, "gleeunit_ffi", "has_cli_help_flag")
fn has_cli_help_flag() -> Bool

@external(erlang, "gleeunit_ffi", "get_cli_modules")
fn get_cli_modules() -> List(String)

@external(erlang, "gleeunit_ffi", "get_cli_tests")
fn get_cli_tests() -> List(#(String, String))

@external(javascript, "./gleeunit_ffi.mjs", "main")
fn do_main(report_dir: Option(String), filters: List(EunitTestSpec)) -> Nil {
  case has_cli_help_flag() {
    True -> {
      io.println("gleeunit test runner")
      io.println("")
      io.println("Usage: gleam test [-- [OPTIONS]]")
      io.println("")
      io.println("Options:")
      io.println(
        "      --report-dir <DIR>       Write Surefire XML and todo reports to DIR",
      )
      io.println(
        "      --module <MODULE>        Run only tests in MODULE (repeatable)",
      )
      io.println(
        "      --test <MODULE:FUNCTION> Run only a specific test (repeatable)",
      )
      io.println(
        "  -h, --help                   Print this help message",
      )
      halt(0)
    }
    False -> Nil
  }

  case report_dir {
    Some(dir) -> io.println("Report dir: " <> dir)
    None -> Nil
  }

  let progress_options = case report_dir {
    Some(dir) -> [Colored(True), ReportDir(dir)]
    None -> [Colored(True)]
  }

  let options = [
    Verbose,
    NoTty,
    Report(#(GleeunitProgress, progress_options)),
    ScaleTimeouts(10),
  ]

  let result =
    find_files(matching: "**/*.{erl,gleam}", in: "test")
    |> list.map(gleam_to_erlang_module_name)
    |> list.map(dangerously_convert_string_to_atom(_, Utf8))
    |> run_eunit(options, report_dir, filters)

  let code = case result {
    Ok(_) -> 0
    Error(_) -> 1
  }
  halt(code)
}

@external(erlang, "erlang", "halt")
fn halt(a: Int) -> Nil

fn gleam_to_erlang_module_name(path: String) -> String {
  case string.ends_with(path, ".gleam") {
    True ->
      path
      |> string.replace(".gleam", "")
      |> string.replace("/", "@")

    False ->
      path
      |> string.split("/")
      |> list.last
      |> result.unwrap(path)
      |> string.replace(".erl", "")
  }
}

@external(erlang, "gleeunit_ffi", "find_files")
fn find_files(matching matching: String, in in: String) -> List(String)

type Atom

type Encoding {
  Utf8
}

@external(erlang, "erlang", "binary_to_atom")
fn dangerously_convert_string_to_atom(a: String, b: Encoding) -> Atom

type ReportModuleName {
  GleeunitProgress
}

type GleeunitProgressOption {
  Colored(Bool)
  ReportDir(String)
}

type EunitOption {
  Verbose
  NoTty
  Report(#(ReportModuleName, List(GleeunitProgressOption)))
  ScaleTimeouts(Int)
}

/// EUnit test specification for filtering.
/// ModuleSpec runs all tests in a module, TestSpec runs a single function.
type EunitTestSpec {
  ModuleSpec(Atom)
  TestSpec(Atom, Atom)
}

@external(erlang, "gleeunit_ffi", "run_eunit")
fn run_eunit(
  a: List(Atom),
  b: List(EunitOption),
  c: Option(String),
  d: List(EunitTestSpec),
) -> Result(Nil, a)
