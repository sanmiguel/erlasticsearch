%%%-------------------------------------------------------------------
%%% @author Mahesh Paolini-Subramanya <mahesh@dieswaytoofast.com>
%%% @copyright (C) 2013 Mahesh Paolini-Subramanya
%%% @doc type definitions and records.
%%% @end
%%%
%%% This source file is subject to the New BSD License. You should have received
%%% a copy of the New BSD license with this software. If not, it can be
%%% retrieved from: http://www.opensource.org/licenses/bsd-license.php
%%%-------------------------------------------------------------------
-module(erlastic_search).
-author('Mahesh Paolini-Subramanya <mahesh@dieswaytoofast.com>').

-behaviour(gen_server).

-include("erlastic_search.hrl").

%% API
-export([start/0, stop/0]).
-export([start_link/0]).

%% ElasticSearch
-export([health/0]).
-export([insert_doc/4]).
-export([get_doc/3]).
-export([delete_doc/3]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(APP, ?MODULE).

-record(state, {
        connection          :: connection()
        }).


%% ------------------------------------------------------------------
%% API
%% ------------------------------------------------------------------
%% @doc Start the application and all its dependencies.
-spec start() -> ok.
start() ->
    util:start_deps(?APP).

%% @doc Stop the application and all its dependencies.
-spec stop() -> ok.
stop() ->
    util:stop_deps(?APP).

%% @doc Get the health of the ElasticSearch cluster
-spec health() -> response().
health() ->
    gen_server:call(?MODULE, {health}).

%% @doc Insert a doc into the the ElasticSearch cluster
-spec insert_doc(index(), type(), id(), doc()) -> response().
insert_doc(Index, Type, Id, Doc) ->
    gen_server:call(?MODULE, {insert_doc, Index, Type, Id, Doc}).

%% @doc Get a doc from the the ElasticSearch cluster
-spec get_doc(index(), type(), id()) -> response().
get_doc(Index, Type, Id) ->
    gen_server:call(?MODULE, {get_doc, Index, Type, Id}).

%% @doc Delete a doc from the the ElasticSearch cluster
-spec delete_doc(index(), type(), id()) -> response().
delete_doc(Index, Type, Id) ->
    gen_server:call(?MODULE, {delete_doc, Index, Type, Id}).


%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_) ->
    Connection = connection(),
    {ok, #state{connection = Connection}}.

handle_call({Request = health}, _From, State = #state{connection = Connection0}) ->
    RestRequest = rest_request(Request, undefined),
    {Connection1, RestResponse} = process_request(Connection0, RestRequest),
    {reply, RestResponse, State#state{connection = Connection1}};

handle_call({Request = insert_doc, Index, Type, Id, Doc}, _From, State = #state{connection = Connection0}) ->
    RestRequest = rest_request(Request, {Index, Type, Id, Doc}),
    {Connection1, RestResponse} = process_request(Connection0, RestRequest),
    {reply, RestResponse, State#state{connection = Connection1}};

handle_call({Request = get_doc, Index, Type, Id}, _From, State = #state{connection = Connection0}) ->
    RestRequest = rest_request(Request, {Index, Type, Id}),
    {Connection1, RestResponse} = process_request(Connection0, RestRequest),
    {reply, RestResponse, State#state{connection = Connection1}};

handle_call({Request = delete_doc, Index, Type, Id}, _From, State = #state{connection = Connection0}) ->
    RestRequest = rest_request(Request, {Index, Type, Id}),
    {Connection1, RestResponse} = process_request(Connection0, RestRequest),
    {reply, RestResponse, State#state{connection = Connection1}};

handle_call(_Request, _From, State) ->
    {stop, unhandled_call, State}.

handle_cast(_Request, State) ->
    {stop, unhandled_info, State}.

handle_info(_Info, State) ->
    {stop, unhandled_info, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.





%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------
%% @doc Build a new connection
-spec connection() -> connection().
connection() ->
    ThriftHost = get_env(thrift_host, ?DEFAULT_THRIFT_HOST),
    ThriftPort = get_env(thrift_port, ?DEFAULT_THRIFT_PORT),
    {ok, Connection} = thrift_client_util:new(ThriftHost, ThriftPort, elasticsearch_thrift, []),
    Connection.

%% @doc Process the request over thrift
-spec process_request(connection(), request()) -> {connection(), response()}.
process_request(Connection, Request) ->
    thrift_client:call(Connection, 'execute', [Request]).


%% @doc Build a new rest request
-spec rest_request(method(), any()) -> request().
rest_request(health, _) ->
    #restRequest{method = ?elasticsearch_Method_GET,
                 uri = ?HEALTH};
rest_request(insert_doc, {Index, Type, Id, Doc}) when is_binary(Index),
                                                      is_binary(Type),
                                                      is_binary(Id),
                                                      is_binary(Doc) ->
    Uri = bstr:join([Index, Type, Id], <<"/">>),
    #restRequest{method = ?elasticsearch_Method_POST,
                 uri = Uri,
                 body = Doc};
rest_request(get_doc, {Index, Type, Id}) when is_binary(Index),
                                                   is_binary(Type),
                                                   is_binary(Id) ->
    Uri = bstr:join([Index, Type, Id], <<"/">>),
    #restRequest{method = ?elasticsearch_Method_GET,
                 uri = Uri};

rest_request(delete_doc, {Index, Type, Id}) when is_binary(Index),
                                                   is_binary(Type),
                                                   is_binary(Id) ->
    Uri = bstr:join([Index, Type, Id], <<"/">>),
    #restRequest{method = ?elasticsearch_Method_DELETE,
                 uri = Uri}.


%% @doc The official way to get a value from this application's env.
%%      Will return Default if that key is unset.
-spec get_env(Key :: atom(), Default :: term()) -> term().
get_env(Key, Default) ->
    case application:get_env(?APP, Key) of
        {ok, Value} ->
            Value;
        _ ->
            Default
    end.
