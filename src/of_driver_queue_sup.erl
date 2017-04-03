%%%-------------------------------------------------------------------
%%% @author alex_shavelev
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. Apr 2017 10:21 AM
%%%-------------------------------------------------------------------
-module(of_driver_queue_sup).
-author("alex_shavelev").


-behaviour(supervisor).

-export([start_link/0, init/1]).
-export([start_child/1
]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  C = of_driver_queue,
  RestartStrategy = simple_one_for_one,
  MaxRestarts = 1000,
  MaxSecondsBetweenRestarts = 3600,
  SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
  {ok, {SupFlags,
    [{queue_id,{C, start_link, []},temporary, 1000, worker, [C]}
    ]}
  }.

start_child(DriverPid) ->
  supervisor:start_child(?MODULE, [DriverPid]).

