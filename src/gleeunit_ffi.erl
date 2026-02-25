-module(gleeunit_ffi).

-export([find_files/2, run_eunit/4, get_cli_report_dir/0, has_cli_help_flag/0,
         get_cli_modules/0, get_cli_tests/0,
         parse_report_dir/1, parse_modules/1, parse_tests/1]).

find_files(Pattern, In) ->
  Results = filelib:wildcard(binary_to_list(Pattern), binary_to_list(In)),
  lists:map(fun list_to_binary/1, Results).

%% CLI argument access — delegates to parse functions with actual CLI args.

get_cli_report_dir() ->
    parse_report_dir(init:get_plain_arguments()).

has_cli_help_flag() ->
    Args = init:get_plain_arguments(),
    lists:member("--help", Args) orelse lists:member("-h", Args).

get_cli_modules() ->
    parse_modules(init:get_plain_arguments()).

get_cli_tests() ->
    parse_tests(init:get_plain_arguments()).

%% Parse functions — accept explicit args for testability.

parse_report_dir(["--report-dir", Dir | _]) ->
    {some, list_to_binary(Dir)};
parse_report_dir([_ | Rest]) ->
    parse_report_dir(Rest);
parse_report_dir([]) ->
    none.

parse_modules(Args) ->
    parse_modules(Args, []).

parse_modules(["--module", Mod | Rest], Acc) ->
    parse_modules(Rest, [list_to_binary(Mod) | Acc]);
parse_modules([_ | Rest], Acc) ->
    parse_modules(Rest, Acc);
parse_modules([], Acc) ->
    lists:reverse(Acc).

parse_tests(Args) ->
    parse_tests(Args, []).

parse_tests(["--test", ModFn | Rest], Acc) ->
    case string:split(ModFn, ":") of
        [Mod, Fn] ->
            parse_tests(Rest, [{list_to_binary(Mod), list_to_binary(Fn)} | Acc]);
        _ ->
            parse_tests(Rest, Acc)
    end;
parse_tests([_ | Rest], Acc) ->
    parse_tests(Rest, Acc);
parse_tests([], Acc) ->
    lists:reverse(Acc).

%% EUnit integration

to_eunit_spec({module_spec, Mod}) -> Mod;
to_eunit_spec({test_spec, Mod, Fn}) -> {Mod, Fn}.

run_eunit(AllTests, Options, ReportDir, Filters) ->
    FullOptions = case ReportDir of
        {some, Dir} ->
            Options ++ [{report, {eunit_surefire, [{dir, binary_to_list(Dir)}]}}];
        none ->
            Options
    end,
    Tests = case Filters of
        [] -> AllTests;
        _ -> lists:map(fun to_eunit_spec/1, Filters)
    end,
    case code:which(eunit) of
        non_existing ->
            gleeunit@internal@reporting:eunit_missing();

        _ ->
            case eunit:test(Tests, FullOptions) of
                ok -> {ok, nil};
                error -> {error, nil};
                {error, Term} -> {error, Term}
            end
    end.
