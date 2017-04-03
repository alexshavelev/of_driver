%%%-------------------------------------------------------------------
%%% @author alex_shavelev
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. Apr 2017 10:21 AM
%%%-------------------------------------------------------------------
-module(of_driver_queue).
-author("alex_shavelev").

-include_lib("of_driver/include/of_driver_logger.hrl").

-behaviour(gen_server).

%% API
-export([start_link/1, process_msg/3]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
  of_driver_connection,
  queue,
  status = ready
}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------

start_link(DriverPid) ->
  gen_server:start_link(?MODULE, [DriverPid], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([DriverPid]) ->
  erlang:send_after(1, self(), process),
  {ok, #state{of_driver_connection = DriverPid, queue = queue:new()}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
  {reply, Reply :: term(), NewState :: #state{}} |
  {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_call(_Request, _From, State) ->
  {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_cast(_Request, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------

handle_info({tcp, _Socket, Data} = Msg,#state{queue = Queue} = State) ->
  ?INFO("of_driver_queue new message from socket size: ~p~n", [byte_size(Data)]),
  {noreply, State#state{queue = queue:in(Msg, Queue)}};

handle_info(done, #state{queue = _Queue, of_driver_connection = _OfDriverPid} = State) ->
%%  case queue:out(Queue) of
%%    {{value, Data}, QueueNew} ->
%%      spawn(?MODULE, process_msg, [self(), OfDriverPid, Data]),
%%      {noreply, State#state{queue = QueueNew, status = busy}};
%%    {empty, QueueNew} ->
%%      {noreply, State#state{queue = QueueNew, status = ready}}
%%  end;
  {noreply, State#state{status = ready}};

handle_info(process, #state{queue = Queue, of_driver_connection = Driver, status = ready} = State) ->
  case queue:out(Queue) of
    {{value, Data}, QueueNew} ->
      spawn(?MODULE, process_msg, [self(), Driver, Data]),
      ?INFO("of_driver_queue send message to of_driver~n", []),
      erlang:send_after(1, self(), process),
      {noreply, State#state{queue = QueueNew, status = busy}};
    {empty, QueueNew} ->
      erlang:send_after(1, self(), process),
      {noreply, State#state{queue = QueueNew, status = ready}}
  end;

handle_info(process, #state{status = busy} = State) ->
  erlang:send_after(1, self(), process),
  {noreply, State};

handle_info({tcp_closed,_Socket} = Msg, #state{of_driver_connection = Driver} = State) ->
  Driver ! Msg,
  {noreply, State};

handle_info({tcp_error, _Socket, _Reason} = Msg, #state{of_driver_connection = Driver} = State) ->
  Driver ! Msg,
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).
terminate(_Reason, _State) ->
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
  {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

process_msg(CallbackPid, OfDriverPid, Data) ->
%%  gen_server:call(OfDriverPid, Data),
  OfDriverPid ! Data,
  CallbackPid ! done.