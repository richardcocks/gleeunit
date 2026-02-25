import gleam/dynamic
import gleam/option
import gleam/string
import gleeunit/internal/reporting
import testhelper

@external(erlang, "gleeunit_test_ffi", "rescue")
@external(javascript, "./gleeunit_test_ffi.mjs", "rescue")
fn rescue(f: fn() -> t) -> Result(t, dynamic.Dynamic)

@external(erlang, "gleeunit_test_ffi", "suppress_output")
@external(javascript, "./gleeunit_test_ffi.mjs", "suppress_output")
fn suppress_output(f: fn() -> t) -> t

pub fn todo_counted_as_todo_not_failure_test() {
  let state = reporting.new_state()
  let assert Error(error) = rescue(fn() { testhelper.run_todo() })
  let state =
    suppress_output(fn() {
      reporting.test_failed(state, "test_module", "my_test", error)
    })
  assert state.todos == 1
  assert state.failed == 0
  assert state.passed == 0
}

pub fn panic_still_counted_as_failure_test() {
  let state = reporting.new_state()
  let assert Error(error) = rescue(fn() { panic as "something broke" })
  let state =
    suppress_output(fn() {
      reporting.test_failed(state, "test_module", "my_test", error)
    })
  assert state.failed == 1
  assert state.todos == 0
  assert state.passed == 0
}

pub fn finished_returns_1_when_todos_present_test() {
  let state =
    reporting.State(
      passed: 5,
      failed: 0,
      skipped: 0,
      todos: 2,
      todo_entries: [],
      failure_entries: [],
      todo_ids: [],
      report_dir: option.None,
    )
  let exit_code = suppress_output(fn() { reporting.finished(state) })
  assert exit_code == 1
}

pub fn finished_returns_0_when_no_todos_or_failures_test() {
  let state =
    reporting.State(
      passed: 5,
      failed: 0,
      skipped: 0,
      todos: 0,
      todo_entries: [],
      failure_entries: [],
      todo_ids: [],
      report_dir: option.None,
    )
  let exit_code = suppress_output(fn() { reporting.finished(state) })
  assert exit_code == 0
}

pub fn todo_entry_collected_test() {
  let state = reporting.new_state()
  let assert Error(error) = rescue(fn() { testhelper.run_todo() })
  let state =
    suppress_output(fn() {
      reporting.test_failed(state, "test_module", "my_test", error)
    })
  let assert [entry] = state.todo_entries
  assert string.contains(entry, "test_module.my_test")
  assert string.contains(entry, "testhelper.gleam:")
}

pub fn failure_entry_collected_test() {
  let state = reporting.new_state()
  let assert Error(error) = rescue(fn() { panic as "something broke" })
  let state =
    suppress_output(fn() {
      reporting.test_failed(state, "test_module", "my_test", error)
    })
  let assert [entry] = state.failure_entries
  assert string.contains(entry, "test_module.my_test")
  assert string.contains(entry, "reporting_test.gleam:")
}

pub fn new_state_has_no_report_dir_test() {
  let state = reporting.new_state()
  assert state.report_dir == option.None
}

pub fn new_state_with_report_dir_sets_dir_test() {
  let state = reporting.new_state_with_report_dir(option.Some("/tmp/reports"))
  assert state.report_dir == option.Some("/tmp/reports")
}

pub fn new_state_with_report_dir_none_test() {
  let state = reporting.new_state_with_report_dir(option.None)
  assert state.report_dir == option.None
}

pub fn report_dir_preserved_through_test_passed_test() {
  let state = reporting.new_state_with_report_dir(option.Some("/tmp/dir"))
  let state = suppress_output(fn() { reporting.test_passed(state) })
  assert state.report_dir == option.Some("/tmp/dir")
  assert state.passed == 1
}

pub fn report_dir_preserved_through_test_failed_test() {
  let state = reporting.new_state_with_report_dir(option.Some("/tmp/dir"))
  let assert Error(error) = rescue(fn() { testhelper.run_todo() })
  let state =
    suppress_output(fn() {
      reporting.test_failed(state, "test_module", "my_test", error)
    })
  assert state.report_dir == option.Some("/tmp/dir")
}

pub fn maybe_write_todos_with_none_does_nothing_test() {
  let state = reporting.new_state()
  // Should not crash when report_dir is None
  reporting.maybe_write_todos(state)
}

pub fn maybe_write_todos_writes_file_test() {
  let dir = make_temp_dir()
  let state =
    reporting.State(
      passed: 0,
      failed: 0,
      skipped: 0,
      todos: 1,
      todo_entries: ["entry"],
      failure_entries: [],
      todo_ids: ["my_module:my_test"],
      report_dir: option.Some(dir),
    )
  reporting.maybe_write_todos(state)
  let assert Ok(content) = read_file(dir <> "/todos.txt")
  assert content == "my_module:my_test"
}

@external(erlang, "gleeunit_test_ffi", "make_temp_dir")
fn make_temp_dir() -> String

@external(erlang, "gleeunit_test_ffi", "read_file_text")
fn read_file(path: String) -> Result(String, dynamic.Dynamic)
