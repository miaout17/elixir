-module(elixir_dispatch).
-export([dispatch/4]).
-include("elixir.hrl").

% TODO Implement method missing dispatching.
dispatch(Self, Object, Method, Args) ->
  Chain = elixir_object_methods:mixins(Object),
  Arity = length(Args) + 1,
  case find_module(Chain, Method, Arity) of
    [] ->
      Mixins = string:join(lists:map(fun atom_to_list/1, Chain), ", "),
      Message = "No method ~s/~w in mixins [~s]",
      elixir_errors:raise(nomethod, Message, [Method, Arity - 1, Mixins]);
    Module ->
      case visibility_matches(Self, Module, Method, Arity) of
        true  -> apply(Module, Method, [Object|Args]);
        false ->
          Message = "Cannot invoke protected method ~s/~w in mixin ~s",
          elixir_errors:raise(protectedmethod, Message, [Method, Arity - 1, atom_to_list(Module)])
      end
  end.

% If self is true, we don't check if it is protected or not
% and dispatch it right away.
visibility_matches(true, _Module, _Method, _Arity) ->
  true;

% If self is false, we need to check if the method is protected,
% if so, don't dispatch.
visibility_matches(false, Module, Method, Arity) ->
  not is_protected_method(Module, Method, Arity);

% If self is an object, we need to check if the visibility allows
% the method invocation.
visibility_matches(Self, Module, Method, Arity) ->
  case is_protected_method(Module, Method, Arity) of
    true  -> lists:member(Module, elixir_object_methods:mixins(Self));
    false -> true
  end.

is_protected_method(Module, Method, Arity) ->
  Protected = elixir_object_methods:abstract_protected_methods(Module),
  lists:member({Method, Arity}, Protected).

% Find first module that contains the method with given arity.
find_module([], _Method, _Arity) -> [];

find_module([H|T], Method, Arity) ->
  case erlang:function_exported(H, Method, Arity) of
    true -> H;
    Else -> find_module(T, Method, Arity)
  end.