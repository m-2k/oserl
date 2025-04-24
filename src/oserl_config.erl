-module(oserl_config).

-export([get_env/1, get_env/2]).

get_env(Key) ->
    get_env(Key, undefined).

get_env(Key, Default) ->
    case application:get_env(oserl, Key) of
        undefined -> Default;
        {ok, Val} -> Val
    end.