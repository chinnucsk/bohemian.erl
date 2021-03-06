%% bohemian.erl
%% 
%% © 2013 David J Goehrig <dave@dloh.org>
%% All Rights Reserved
%%
%%	Bohemian for Erlang function objects with private state.
%%

-module(bohemian).
-export([ object/1,state/0 ]).

state() ->
	receive
		{ Self, Key, Value } when is_pid(Self) -> put(Key,Value);
		{ Self, Key } when is_pid(Self) -> Self ! get(Key);
		_ -> true
	end,
	state().

object(Parents) ->
	State = spawn_link(?MODULE,state,[]),
	May = fun(Self, Method) ->
		io:format("Looking up ~p with parents ~p~n", [ Method, Parents ]),
		case lists:filter(fun(X) -> is_function(X) end, 
			lists:map(fun(P) -> P([lookup, Method]) end, Parents)) of
			[F|X] when is_function(F) -> F;
			_ -> false
		end
	end,
	Lookup = fun(_Self,Method) ->
		State ! { self(), Method },
		receive
			Fun when is_function(Fun) -> Fun;
			_ -> false
		end
	end,
	Does = fun(_Self,Method,Fun) ->
		State ! { self(), Method, Fun }
	end,
	Has = fun(_Self, Property, Value) ->	
		State ! { self(), Property, fun(_Self) -> Value end }
	end,
	Unknown = fun(Self,Method,Args) ->
		io:format("~p doesn't ~p with ~p~n", [ Self, Method, Args]) 
	end,
	Y = fun([M|A]) -> 
		G = fun(Self,Method,Args) ->
			case Lookup(Self,Method) of
				F when is_function(F) -> apply(F, [ fun([MM|AA]) -> Self(Self,MM,AA) end | Args ]);
				_  -> case May(Self,Method) of
					FF when is_function(FF) -> apply(FF, [ fun([MM|AA]) -> Self(Self,MM,AA) end | Args ]);
					_ -> apply(Lookup(Self,'*'), [ 	
						fun([MMM|AAA]) -> 
							Self(Self,MMM,AAA) end, 
						Method , Args ])
				end
			end
		end,
		G(G,M,A)
	end,
	State ! { self(), does, Does },
	State ! { self(), has, Has },
	State ! { self(), lookup, Lookup },
	State ! { self(), '*', Unknown },
	Y.
