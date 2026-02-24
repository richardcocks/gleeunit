import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Options for configuring gleeunit test execution.
pub type GleeunitOption {
  /// Write Surefire XML results and todo reports to the specified directory.
  WithReportDir(String)
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
pub fn main_with_options(options: List(GleeunitOption)) -> Nil {
  let report_dir = resolve_report_dir(options)
  do_main(report_dir)
}

fn resolve_report_dir(options: List(GleeunitOption)) -> Option(String) {
  case get_cli_report_dir() {
    Some(dir) -> Some(dir)
    None ->
      case options {
        [WithReportDir(dir), ..] -> Some(dir)
        [] -> None
      }
  }
}

@external(erlang, "gleeunit_ffi", "get_cli_report_dir")
fn get_cli_report_dir() -> Option(String)

@external(javascript, "./gleeunit_ffi.mjs", "main")
fn do_main(report_dir: Option(String)) -> Nil {
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
    |> run_eunit(options, report_dir)

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

@external(erlang, "gleeunit_ffi", "run_eunit")
fn run_eunit(
  a: List(Atom),
  b: List(EunitOption),
  c: Option(String),
) -> Result(Nil, a)
