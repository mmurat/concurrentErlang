%% Based on code from
%%   Erlang Programming
%%   Francecso Cesarini and Simon Thompson
%%   O'Reilly, 2008
%%   http://oreilly.com/catalog/9780596518189/
%%   http://www.erlangprogramming.org/
%%   (c) Francesco Cesarini and Simon Thompson

-module(frequency).
-export([start/0,allocate/0,deallocate/1,stop/0]).
-export([init/0]).
-export([
	 supervisor_start/0,
	 supervisor_stop/0,
	 supervisor_init/0
	]).

%% These are the start functions used to create and
%% initialize the server.

start() ->
    register(frequency,
	     spawn(frequency, init, [])).

init() ->
  process_flag(trap_exit, true),
  Frequencies = {get_frequencies(), []},
  loop(Frequencies).

% Hard Coded
get_frequencies() -> [10,11,12,13,14,15].

%% The Main Loop

loop(Frequencies) ->
  receive
    {request, Pid, allocate} ->
      {NewFrequencies, Reply} = allocate(Frequencies, Pid),
      Pid ! {reply, Reply},
      loop(NewFrequencies);
    {request, Pid , {deallocate, Freq}} ->
      NewFrequencies = deallocate(Frequencies, Freq),
      Pid ! {reply, ok},
      loop(NewFrequencies);
    {request, Pid, stop} ->
      Pid ! {reply, stopped};
    {'EXIT', Pid, _Reason} ->                   %%% CLAUSE ADDED
      NewFrequencies = exited(Frequencies, Pid),
      loop(NewFrequencies)
  end.

%% Functional interface

allocate() ->
    frequency ! {request, self(), allocate},
    receive
	    {reply, Reply} -> Reply
    end.

deallocate(Freq) ->
    frequency ! {request, self(), {deallocate, Freq}},
    receive
	    {reply, Reply} -> Reply
    end.

stop() ->
    frequency ! {request, self(), stop},
    receive
	    {reply, Reply} -> Reply
    end.


%% The Internal Help Functions used to allocate and
%% deallocate frequencies.

allocate({[], Allocated}, _Pid) ->
  {{[], Allocated}, {error, no_frequency}};
allocate({[Freq|Free], Allocated}, Pid) ->
  link(Pid),
  {{Free, [{Freq, Pid}|Allocated]}, {ok, Freq}}.

deallocate({Free, Allocated}, Freq) ->
  {value,{Freq,Pid}} = lists:keysearch(Freq,1,Allocated),
  unlink(Pid),
  NewAllocated=lists:keydelete(Freq, 1, Allocated),
  {[Freq|Free],  NewAllocated}.

exited({Free, Allocated}, Pid) ->
    case lists:keysearch(Pid,2,Allocated) of
      {value,{Freq,Pid}} ->
        NewAllocated = lists:keydelete(Freq,1,Allocated),
        {[Freq|Free],NewAllocated};
      false ->
        {Free,Allocated}
    end.

supervisor_init() ->
    process_flag(trap_exit, true),
    Pid = spawn_link(frequency, init, []),
    register(frequency, Pid),
    supervisor_loop(Pid).

supervisor_loop(Pid) ->
  receive
    {'EXIT', Pid, _Reason} ->
      NewPid = spawn_link(frequency, init, []),
      register(frequency, NewPid),
      supervisor_loop(NewPid);
    {stop, Pid} ->
      exit(whereis(frequency),kill),
      Pid ! {reply,ok}
  end.


supervisor_start() ->
    register(supervisor,
	     spawn(frequency,supervisor_init,[])).


supervisor_stop() ->
    supervisor ! {stop,self()},
    receive
	{reply,Reply} ->
	    Reply
    end.
