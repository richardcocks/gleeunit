-module(cli_parsing_test).
-include_lib("eunit/include/eunit.hrl").

%% Tests for gleeunit_ffi CLI argument parsing functions.

%% parse_report_dir/1

parse_report_dir_empty_test() ->
    ?assertEqual(none, gleeunit_ffi:parse_report_dir([])).

parse_report_dir_present_test() ->
    ?assertEqual({some, <<"/tmp/reports">>},
                 gleeunit_ffi:parse_report_dir(["--report-dir", "/tmp/reports"])).

parse_report_dir_with_other_args_test() ->
    ?assertEqual({some, <<"/tmp/dir">>},
                 gleeunit_ffi:parse_report_dir(["--module", "foo", "--report-dir", "/tmp/dir"])).

parse_report_dir_missing_value_test() ->
    ?assertEqual(none, gleeunit_ffi:parse_report_dir(["--report-dir"])).

%% parse_modules/1

parse_modules_empty_test() ->
    ?assertEqual([], gleeunit_ffi:parse_modules([])).

parse_modules_single_test() ->
    ?assertEqual([<<"my_test">>],
                 gleeunit_ffi:parse_modules(["--module", "my_test"])).

parse_modules_multiple_test() ->
    ?assertEqual([<<"foo_test">>, <<"bar_test">>],
                 gleeunit_ffi:parse_modules(["--module", "foo_test", "--module", "bar_test"])).

parse_modules_mixed_args_test() ->
    ?assertEqual([<<"my_test">>],
                 gleeunit_ffi:parse_modules(["--report-dir", "/tmp", "--module", "my_test", "--test", "x:y"])).

parse_modules_no_module_flag_test() ->
    ?assertEqual([], gleeunit_ffi:parse_modules(["--report-dir", "/tmp"])).

%% parse_tests/1

parse_tests_empty_test() ->
    ?assertEqual([], gleeunit_ffi:parse_tests([])).

parse_tests_single_test() ->
    ?assertEqual([{<<"my_module">>, <<"my_fn">>}],
                 gleeunit_ffi:parse_tests(["--test", "my_module:my_fn"])).

parse_tests_multiple_test() ->
    ?assertEqual([{<<"mod_a">>, <<"fn_a">>}, {<<"mod_b">>, <<"fn_b">>}],
                 gleeunit_ffi:parse_tests(["--test", "mod_a:fn_a", "--test", "mod_b:fn_b"])).

parse_tests_invalid_format_skipped_test() ->
    ?assertEqual([], gleeunit_ffi:parse_tests(["--test", "no_colon"])).

parse_tests_mixed_args_test() ->
    ?assertEqual([{<<"mod">>, <<"fn">>}],
                 gleeunit_ffi:parse_tests(["--module", "foo", "--test", "mod:fn"])).
