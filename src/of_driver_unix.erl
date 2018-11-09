%%%-------------------------------------------------------------------
%%% @author alex_shavelev
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. Апр. 2018 10:17
%%%-------------------------------------------------------------------
-module(of_driver_unix).
-author("alex_shavelev").

-behaviour(gen_server).

-export([start_link/0,
  listen/0]).

-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3
]).

-export([accept/1]).

-define(SERVER, ?MODULE).
-define(STATE, of_driver_unix_state).

-record(?STATE, {
  lsock :: inets:socket()
}).

-include_lib("of_driver/include/of_driver_logger.hrl").

start_link() ->
  {ok, Pid} = gen_server:start_link({local, ?SERVER}, ?MODULE, [], []),
  {ok, Pid}.

listen() ->
  ok = gen_server:cast(?MODULE, startup).

init(_) ->
  case of_driver_utils:conf_default(listen, fun erlang:is_boolean/1, true) of
    false -> ok;
    _ -> listen()
  end,
  {ok, #?STATE{}}.

handle_call(_Msg, _From, State) ->
  {reply, ok, State}.

handle_cast(startup, State) ->
  Port = 0,
  ListenOpts = of_driver_utils:conf_default(listen_opts,
    fun erlang:is_list/1,
    [binary,
      {packet, raw},
      {active, false},
      {reuseaddr, true}]),


  SocketAddr = application:get_env(of_driver, unix_soc, "/var/run/openvswitch/test_soc"),

  file:delete(SocketAddr),

  IP = {ifaddr, {local,SocketAddr}},

  ListenOpts2 = lists:append(ListenOpts,[IP]),
  ?DEBUG("of_driver unix listening for switches on ~p~n", [Port]),
  {ok, LSocket} = gen_tcp:listen(Port,ListenOpts2),
  spawn_link(?MODULE, accept, [LSocket]),
  {noreply, State#?STATE{lsock = LSocket}};
handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Msg,State) ->
  {noreply,State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%-----------------------------------------------------------------------------

accept(ListenSocket) ->
  case gen_tcp:accept(ListenSocket) of
    {ok, Socket} ->
      case of_driver_connection_sup:start_child(Socket) of
        {ok, ConnCtrlPID} ->
%%                    gen_tcp:controlling_process(Socket, ConnCtrlPID);

%           {ok, DriverQueuePid} = of_driver_queue_sup:start_child(ConnCtrlPID),
          gen_tcp:controlling_process(Socket, ConnCtrlPID);

        {error,_Reason} ->
          ok
      end,
      accept(ListenSocket);
    _Error ->
      accept(ListenSocket)
  end.
