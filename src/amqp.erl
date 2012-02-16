%%%----------------------------------------------------------------------
%%% File    : amqp.erl
%%% Author  : Ery Lee <ery.lee@gmail.com>
%%% Purpose : amqp client api
%%% Created : 03 Aug 2009
%%% License : http://www.opengoss.com
%%% Descr   : implement api like ruby amqp library tmm1
%%% 
%%% Copyright (C) 2012, www.opengoss.com 
%%%----------------------------------------------------------------------
-module(amqp).

-include("amqp_client.hrl").

-import(proplists, [get_value/3]).

%%api 
%TODO: request/3, reply/4,
-export([connect/0, connect/1,
		open_channel/1,
		%access/2,
		close_channel/1,
		teardown/1,
		queue/1, queue/2, queue/3,
        exchange/2, exchange/3, exchange/4,
        direct/2, direct/3,
        topic/2, topic/3,
        fanout/2, fanout/3,
        bind/3, bind/4, 
        unbind/3,
        send/3,
        publish/3, publish/4, publish/5,
        delete/3,
        consume/2, consume/3, 
        fetch/2,
        ack/2, 
        cancel/2
        ]).

%consumer callback
-export([consumer_init/3]).

-record(consumer_state, {channel, channel_ref, 
	consumer, consumer_ref, consumer_tag}).

-define(RPC_TIMEOUT, 3000).

%% @spec connect() -> Result
%%  Result = {ok, pid()}  | {error, Error}  
%% @doc connect with default opts
connect() ->
	connect([]).

%% @spec connect(Opts) -> Result
%%  Opts = [tuple()]
%%  Result = {ok, pid()}  | {error, Error}  
%% @doc connect to amqp server
connect(Opts) when is_list(Opts) ->
    Host = get_value(host, Opts, "localhost"),
    Port = get_value(port, Opts, 5672),
    VHost = get_value(vhost, Opts, <<"/">>),
    %Realm = get_value(realm, Opts, <<"/">>),
    User = get_value(user, Opts, <<"guest">>),
    Password = get_value(password, Opts, <<"guest">>),
    Params = #amqp_params_network{host = Host, port = Port, 
		virtual_host = VHost, username = User, password = Password},
	connect(Params);

connect(Params) ->
    amqp_connection:start(Params).

open_channel(Connection) ->
    amqp_connection:open_channel(Connection).

%access(Channel, Realm) ->
%    Access = #'access.request'{realm = Realm,
%                               exclusive = false,
%                               passive = true,
%                               active = true,
%                               write = true,
%                               read = true},
%    #'access.request_ok'{ticket = Ticket} 
%		= amqp_channel:call(Channal, Access),
%    {ok, Ticket}.

close_channel(Channel) ->
    amqp_channel:close(Channel).

%% @spec stop() -> ok
%% @doc stop amqp client
teardown(Connection) ->
    amqp_connection:close(Connection).

%% @spec request(Pid, To, Request) -> Result
%%  Pid = pid() | atom()
%%  To = iolist()
%%  Request = term()
%%  Result = {ok, Reply} | {error,Error}
%%  Reply = term()
%%  Error = term() 
%% @doc rpc request
%request(Pid, To, Request) ->
%    call(Pid, {request, To, Request}).

%reply(Pid, To, Id, Reply) ->
%    call(Pid, {reply, To, Id, Reply}).

%% @spec queue(Channel) -> Result
%%  Channel = pid() | atom()
%%  Result = {ok, Q, Props} | {error,Error}
%%  Q = iolist()
%%  Props = [tuple()]
%% @doc declare temporary queue
queue(Channel) ->
	declare_queue(Channel).

declare_queue(Channel) ->
	Declare = #'queue.declare'{auto_delete = true},
	#'queue.declare_ok'{queue = Q} =
		amqp_channel:call(Channel, Declare),
	{ok, Q}.

%% @spec queue(Pid, Name) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Result = ok | {error,Error}
%% @doc declare amqp queue
queue(Channel, Name) ->
	queue(Channel, Name, []).

%% @spec queue(Pid, Name, Opts) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Opts = list()
%%  Result = ok | {error,Error}
%% @doc declare amqp queue
queue(Channel, Name, Opts) ->
    declare_queue(Channel, Name, Opts).

declare_queue(Channel, Name, Opts) ->
	Q = binary(Name),
	Durable = get_value(durable, Opts, false),
	Exclusive = get_value(exclusive, Opts, false),
	AutoDelete = get_value(auto_delete, Opts, true),
	QueueDeclare = #'queue.declare'{queue = Q,
						passive = false, 
						durable = Durable,
						exclusive = Exclusive,
						auto_delete = AutoDelete,
						nowait = false, arguments = []},
     #'queue.declare_ok'{queue = Q,
                        message_count = _MessageCount,
                        consumer_count = _ConsumerCount}
                        = amqp_channel:call(Channel, QueueDeclare),
    {ok, Q}.

%% @spec exchange(Pid, Name) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Result = ok | {error,Error}
%% @doc declare amqp exchange with default type 'direct'
exchange(Channel, Name) ->
	declare_exchange(Channel, direct, Name, []).
	
%% @spec exchange(Pid, Name, Type) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Type = iolist()
%%  Result = ok | {error,Error}
%% @doc declare amqp exchange
exchange(Channel, Type, Name) ->
    declare_exchange(Channel, Type, Name, []).

%% @spec exchange(Pid, Name, Type, Opts) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Type = iolist()
%%  Opts = list()
%%  Result = ok | {error,Error}
%% @doc declare amqp exchange
exchange(Channel, Type, Name, Opts) ->
    declare_exchange(Channel, Type, Name, Opts).

%% @spec direct(Pid, Name) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Result = ok | {error,Error}
%% @doc declare amqp direct exchange
direct(Channel, Name) ->
    declare_exchange(Channel, direct, Name, []).

%% @spec direct(Pid, Name, Opts) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Opts = list()
%%  Result = ok | {error,Error}
%% @doc declare amqp direct exchange
direct(Channel, Name, Opts) ->
    declare_exchange(Channel, direct, Name, Opts).

%% @spec topic(Pid, Name) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Result = ok | {error,Error}
%% @doc declare amqp topic exchange
topic(Channel, Name) ->
    declare_exchange(Channel, topic, Name, []).

%% @spec topic(Pid, Name, Opts) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Opts = list()
%%  Result = ok | {error,Error}
%% @doc declare amqp topic exchange
topic(Channel, Name, Opts) ->
    declare_exchange(Channel, topic, Name, Opts).

%% @spec fanout(Pid, Name) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Result = ok | {error,Error}
%% @doc declare amqp fanout
fanout(Channel, Name) ->
    declare_exchange(Channel, fanout, Name, []).

%% @spec fanout(Pid, Name, Opts) -> Result
%%  Pid = pid() | atom()
%%  Name = iolist()
%%  Opts = list()
%%  Result = ok | {error,Error}
%% @doc declare amqp fanout
fanout(Channel, Name, Opts) ->
    declare_exchange(Channel, fanout, Name, Opts).

declare_exchange(Channel, Type, Name, _Opts) ->
    Declare = #'exchange.declare'{
		exchange = binary(Name),
		type = binary(Type),
		passive = false, durable = true,
		auto_delete = false, internal = false,
		nowait = false, arguments = []},
    #'exchange.declare_ok'{} = amqp_channel:call(Channel, Declare).

%% @spec bind(Pid, Exchange, Queue) -> Result
%%  Pid = pid() | atom()
%%  Exchange = iolist()
%%  Queue = iolist()
%%  Result = ok | {error,Error}
%% @doc amqp bind
bind(Channel, Exchange, Queue) ->
	bind(Channel, Exchange, Queue, <<"">>).

%% @spec bind(Pid, Exchange, Queue, RouteKey) -> Result
%%  Pid = pid() | atom()
%%  Exchange = iolist()
%%  Queue = iolist()
%%  Opts = list()
%%  Result = ok | {error,Error}
%% @doc amqp bind
bind(Channel, Exchange, Queue, RoutingKey) ->
	bind_queue(Channel, Exchange, Queue, RoutingKey).

bind_queue(Channel, Exchange, Queue, RoutingKey) ->
    QueueBind = #'queue.bind'{queue = binary(Queue),
                              exchange = binary(Exchange),
                              routing_key = binary(RoutingKey),
                              nowait = false, arguments = []},
    #'queue.bind_ok'{} = amqp_channel:call(Channel, QueueBind),
	ok.

%% @spec unbind(Pid, Exchange, Queue) -> Result
%%  Pid = pid() | atom()
%%  Exchange = iolist()
%%  Queue = iolist()
%%  Result = ok | {error,Error}
%% @doc amqp bind
unbind(Channel, Exchange, Queue) ->
    unbind(Channel, Exchange, Queue, <<"">>).

unbind(Channel, Exchange, Queue, RoutingKey) ->
    unbind_queue(Channel, Exchange, Queue, RoutingKey).

unbind_queue(Channel, Exchange, Queue, RoutingKey) ->
    QueueUnbind = #'queue.unbind'{queue = binary(Queue),
                              exchange = binary(Exchange),
                              routing_key = RoutingKey,
                              arguments = []},
    #'queue.unbind_ok'{} = amqp_channel:call(Channel, QueueUnbind),
	ok.


%% @spec send(Pid, Queue, Payload) -> Result
%%  Pid = pid() | atom()
%%  Queue = iolist()
%%  Payload = binary()
%% @doc send directly to queue
send(Channel, Queue, Payload) ->
	basic_send(Channel, Queue, Payload).

basic_send(Channel, Queue, Payload) ->
    BasicPublish = #'basic.publish'{
					routing_key = binary(Queue),
					mandatory = false,
					immediate = false},
    Msg = #amqp_msg{props = basic_properties(),
		payload = binary(Payload)},
    amqp_channel:cast(Channel, BasicPublish, Msg).

%% @spec publish(Pid, Exchange, Payload) -> Result
%%  Pid = pid() | atom()
%%  Exchange = iolist()
%%  Payload = binary()
%% @doc amqp publish message
publish(Channel, Exchange, Payload) ->
	publish(Channel, Exchange, Payload, <<"">>).

%% @spec publish(Pid, Exchange, Payload, RoutingKey) -> Result
%%  Pid = pid() | atom()
%%  Exchange = iolist()
%%  Payload = binary()
%%  RoutingKey = iolist()
%% @doc amqp publish message
publish(Channel, Exchange, Payload, RoutingKey) ->
    publish(Channel, Exchange, none, Payload, RoutingKey).

%% @spec publish(Pid, Exchange, Properties, Payload, RoutingKey) -> Result
%%  Pid = pid() | atom()
%%  Exchange = iolist()
%%  Properties = [tuple()]
%%  Payload = binary()
%%  RoutingKey = iolist()
%% @doc amqp publish message
publish(Channel, Exchange, Properties, Payload, RoutingKey) ->
    basic_publish(Channel, Exchange, Properties, Payload, RoutingKey).

basic_publish(Channel, Exchange, _Properties, Payload, RoutingKey) ->
    BasicPublish = #'basic.publish'{exchange = binary(Exchange),
                                    routing_key = binary(RoutingKey),
                                    mandatory = false,
                                    immediate = false},
    Msg = #amqp_msg{props = basic_properties(), payload = binary(Payload)},
    amqp_channel:cast(Channel, BasicPublish, Msg).

%% @spec get(Pid, Queue) -> Result
%%  Pid = pid() | atom()
%%  Queue = iolist()
%%  Result = ok | {error,Error}
%% @doc subscribe to a queue
fetch(Channel, Queue) ->
	basic_get(Channel, Queue).

basic_get(Channel, Queue) ->
    %% Basic get
    BasicGet = #'basic.get'{queue = binary(Queue)},
    case amqp_channel:call(Channel, BasicGet) of
    {#'basic.get_ok'{exchange = _E, routing_key = RoutingKey, message_count = _C},
     #'amqp_msg'{props = Properties, payload = Payload}} ->
        #'P_basic'{content_type = ContentType} = Properties,
        {ok, {RoutingKey, [{content_type, ContentType}], Payload}};
    #'basic.get_empty'{cluster_id = _} ->
        {ok, []}
    end.

%% @spec consume(Pid, Queue) -> Result
%%  Pid = pid() | atom()
%%  Queue = iolist()
%%  Result = ok | {error,Error}
%% @doc subscribe to a queue
consume(Channel, Queue) ->
	consume(Channel, Queue, self()).

%% @spec consume(Pid, Queue, Consumer) -> Result
%%  Pid = pid() | atom()
%%  Queue = iolist()
%%  Consumer = pid() | fun()
%%  Result = ok | {error,Error}
%% @doc subscribe to a queue
consume(Channel, Queue, Consumer) when is_pid(Consumer) ->
	basic_consume(Channel, Queue, Consumer). 

basic_consume(Channel, Queue, Consumer) ->
	consumer_start(Channel, Queue, Consumer).

%% @spec delete(Pid, queue, Queue) -> Result
%%  Pid = pid() | atom()
%%  Queue = iolist()
%%  Result = ok | {error,Error}
%% @doc delete a queue
delete(Channel, queue, Queue) ->
	delete_queue(Channel, Queue);

%% @spec delete(Pid, exchange, Exchange) -> Result
%%  Pid = pid() | atom()
%%  Exchange = iolist()
%%  Result = ok | {error,Error}
%% @doc delete an exchange
delete(Channel, exchange, Exchange) ->
	delete_exchange(Channel, Exchange).

delete_queue(Channel, Queue) ->
	QueueDelete = #'queue.delete'{queue = binary(Queue)},
	#'queue.delete_ok'{message_count = _MessageCount} =
		amqp_channel:call(Channel, QueueDelete),
	ok.

delete_exchange(Channel, Exchange) ->
    ExchangeDelete = #'exchange.delete'{exchange= binary(Exchange)},
    #'exchange.delete_ok'{} = amqp_channel:call(Channel, ExchangeDelete),
	ok.

%% @spec ack(Pid, DeliveryTag) -> Result
%%  Pid = pid() | atom()
%%  DeliveryTag = iolist()
%%  Result = ok | {error,Error}
%% @doc ack a message
ack(Channel, DeliveryTag) ->
	basic_ack(Channel, DeliveryTag).

basic_ack(Channel, DeliveryTag) ->
    BasicAck = #'basic.ack'{delivery_tag = DeliveryTag},
    amqp_channel:cast(Channel, BasicAck).

%% @spec cancel(Pid, ConsumerTag) -> Result
%%  Pid = pid() | atom()
%%  ConsumerTag = iolist()
%%  Result = ok | {error,Error}
%% @doc cancel a consumer
cancel(Channel, ConsumerTag) ->
	basic_cancel(Channel, ConsumerTag).	

basic_cancel(Channel, ConsumerTag) ->
    BasicCancel = #'basic.cancel'{nowait = false,
		consumer_tag = ConsumerTag},
    #'basic.cancel_ok'{consumer_tag = ConsumerTag} =
		amqp_channel:call(Channel,BasicCancel),
	ok.

consumer_start(Channel, Queue, Consumer)
	when is_pid(Channel) and is_pid(Consumer) ->
	%TODO: no need link? 
	proc_lib:start(?MODULE, consumer_init, 
		[Channel, Queue, Consumer], 13000).

consumer_init(Channel, Queue, Consumer) ->
    %% Register a consumer to listen to a queue
    BasicConsume = #'basic.consume'{queue = binary(Queue),
                                    consumer_tag = <<"">>,
                                    no_local = false,
                                    no_ack = true,
                                    exclusive = false,
                                    nowait = false},
	Res = amqp_channel:subscribe(Channel, BasicConsume, self()),
	%io:format("subscribe: ~p~n", [Res]),
    %% If the registration was sucessful, then consumer will be notified
    receive
    #'basic.consume_ok'{consumer_tag = ConsumerTag} ->
		proc_lib:init_ack({ok, self(), ConsumerTag}),
		ChannelRef = erlang:monitor(process, Channel),
		ConsumerRef = erlang:monitor(process, Consumer),
		ConsumerState = #consumer_state{channel = Channel,
			channel_ref = ChannelRef, 
			consumer = Consumer,
			consumer_ref = ConsumerRef,
			consumer_tag = ConsumerTag},
		consumer_loop(ConsumerState);
	Msg ->
		error_logger:error_msg("error consume result: ~p~n", [Msg]),
		proc_lib:init_ack({error, consumer_error})
    after 10000 ->
        proc_lib:init_ack({error, consume_timeout})
    end.

consumer_loop(#consumer_state{channel = Channel,
			channel_ref = ChannelRef, 
			consumer = Consumer,
			consumer_ref = ConsumerRef,
			consumer_tag = ConsumerTag} = ConsumerState) ->
	receive
	{#'basic.deliver'{consumer_tag = ConsumerTag,
		delivery_tag = _DeliveryTag,
		redelivered = _Redelivered,
		exchange = _Exchange,
		routing_key = RoutingKey},
		#amqp_msg{props = Properties, payload = Payload}} ->

		#'P_basic'{content_type = ContentType,
				  correlation_id = CorrelationId,
				  reply_to = ReplyTo} = Properties,
		Header = [{content_type, ContentType},
				 {correlation_id, CorrelationId},
				 {reply_to, ReplyTo}],
		Consumer ! {deliver, RoutingKey, Header, Payload},
		consumer_loop(ConsumerState);
	{#'basic.deliver'{consumer_tag = OtherTag}, _Msg} ->
		error_logger:error_msg("unexpected deliver to ~p,"
			" error tag: ~p~n", [ConsumerTag, OtherTag]),
		consumer_loop(ConsumerState);
	{'DOWN', ChannelRef, _Type, _Object, _Info} ->
		{stop, channel_shutdown};
	{'DOWN', ConsumerRef, _Type, _Object, _Info} ->
		io:format("Consumer Shutdown, begin to cancel~n"),
		basic_cancel(Channel, ConsumerTag),
		{stop, consumer_shutdown};
	stop ->
		{stop, normal};
	Msg ->
		error_logger:error_msg("amqp consumer received "
			"unexpected msg:~n~p~n", [Msg]),
		consumer_loop(ConsumerState)
	end.

binary(A) when is_atom(A) ->
	list_to_binary(atom_to_list(A));

binary(L) when is_list(L) ->
    list_to_binary(L);

binary(B) when is_binary(B) ->
    B.

basic_properties() ->
  #'P_basic'{content_type = <<"application/octet-stream">>,
             delivery_mode = 1,
             priority = 1}.

cancel_timer(undefined) -> ok;

cancel_timer(Timer) -> erlang:cancel_timer(Timer).
