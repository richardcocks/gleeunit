-module(gleeunit_test_ffi).
-export([rescue/1, suppress_output/1]).

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
