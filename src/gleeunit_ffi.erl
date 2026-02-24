-module(gleeunit_ffi).

-export([find_files/2, run_eunit/3, get_cli_report_dir/0, has_cli_help_flag/0]).

find_files(Pattern, In) ->
  Results = filelib:wildcard(binary_to_list(Pattern), binary_to_list(In)),
  lists:map(fun list_to_binary/1, Results).

get_cli_report_dir() ->
    get_cli_report_dir(init:get_plain_arguments()).

get_cli_report_dir(["--report-dir", Dir | _]) ->
    {some, list_to_binary(Dir)};
get_cli_report_dir([_ | Rest]) ->
    get_cli_report_dir(Rest);
get_cli_report_dir([]) ->
    none.

has_cli_help_flag() ->
    lists:member("--help", init:get_plain_arguments())
    orelse lists:member("-h", init:get_plain_arguments()).

run_eunit(Tests, Options, ReportDir) ->
    FullOptions = case ReportDir of
        {some, Dir} ->
            Options ++ [{report, {eunit_surefire, [{dir, binary_to_list(Dir)}]}}];
        none ->
            Options
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
