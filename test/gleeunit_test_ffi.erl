-module(gleeunit_test_ffi).
-export([rescue/1, suppress_output/1, make_temp_dir/0, read_file_text/1]).

rescue(F) ->
    try
        {ok, F()}
    catch
        _:Error:_ -> {error, Error}
    end.

suppress_output(F) ->
    OldGL = group_leader(),
    Sink = spawn_link(fun Loop() ->
        receive
            {io_request, From, ReplyAs, _Request} ->
                From ! {io_reply, ReplyAs, ok},
                Loop();
            _ ->
                Loop()
        end
    end),
    group_leader(Sink, self()),
    try F()
    after
        group_leader(OldGL, self()),
        unlink(Sink),
        exit(Sink, normal)
    end.

make_temp_dir() ->
    TmpBase = filename:basedir(user_cache, "gleeunit_test"),
    Dir = filename:join(TmpBase, integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(filename:join(Dir, "dummy")),
    list_to_binary(Dir).

read_file_text(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> {ok, Bin};
        {error, Reason} -> {error, Reason}
    end.
