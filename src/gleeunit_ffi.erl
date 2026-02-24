-module(gleeunit_ffi).

-export([find_files/2, run_eunit/2]).

find_files(Pattern, In) ->
  Results = filelib:wildcard(binary_to_list(Pattern), binary_to_list(In)),
  lists:map(fun list_to_binary/1, Results).

run_eunit(Tests, Options) ->
    FullOptions = case os:getenv("GLEEUNIT_REPORT_DIR") of
        false -> Options;
        Dir -> Options ++ [{report, {eunit_surefire, [{dir, Dir}]}}]
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
    
