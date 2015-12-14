%%%-------------------------------------------------------------------
%%% @author AlanHiggins
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. Nov 2015 10:04 PM
%%%-------------------------------------------------------------------
-module(sugarscape).
-author("AlanHiggins").

%% API
-compile(export_all).


start()->start(5,0.2,5,0.3,8,8).
start(TotMales,MaleRatio,TotFemale,FemaleRatio,XRange,YRange)->
  Scape_PId=spawn(?MODULE,init,[TotMales,MaleRatio,TotFemale,FemaleRatio,XRange,YRange]),
  register(sugarscape,Scape_PId).



init(TotMales,MaleRatio,TotFemale,FemaleRatio,X,Y)->
  random:seed(erlang:unique_integer()),
  Male_PIds=spawn_agents(male,TotMales,X,Y,MaleRatio,[]),
  Female_PIds=spawn_agents(female,TotFemale,X,Y,FemaleRatio,[]),
  Agents_PIDs= Male_PIds++Female_PIds,
  grid(Agents_PIDs,Agents_PIDs,X,Y,1).

spawn_agents(_Type,0,_XRange,_YRange,_Ratio,Acc)->
  Acc;
spawn_agents(Type,Index,XRange,YRange,Ratio,Acc)->
 {X,Y}=find_empty_loc(XRange,YRange),
 Agent_PId = spawn(?MODULE,Type,[self(),{X,Y},Ratio]),
 put({X,Y},{Agent_PId,Type}),
 spawn_agents(Type,Index-1,XRange,YRange,Ratio,[Agent_PId|Acc]).

find_empty_loc(XRange,YRange)->
  Random_X = random:uniform(XRange),
  Random_Y = random:uniform(YRange),
  case get({Random_X,Random_Y}) of
      undefined -> {Random_X,Random_Y};
      _ -> find_empty_loc(XRange,YRange)
  end.

grid(_,MPIds,_,_,50)->
  [APId ! terminate || APId <-MPIds],
 io:format("Terminating scape:~p~n",[self()]);
grid([Agent_PId|PIds],MPIds,XRange,YRange,RoundIndex)->
 receive
     {Agent_PId,{Target_X,Target_Y},get_LocalState} ->
        Local_State = [get({X,Y})|| X <- [Target_X-1,Target_X,Target_X+1],Y<-
[Target_Y-1,Target_Y,Target_Y+1]],
    Agent_PId ! {self(),Local_State},
       grid([Agent_PId|PIds],MPIds,XRange,YRange,RoundIndex);
    {Agent_PId,Type,Loc,Choice}->
        U_Loc = ?MODULE:Choice(Agent_PId,Type,Loc,XRange,YRange),
      Agent_PId ! {self(),updated_loc,U_Loc},
      grid(PIds,MPIds,XRange,YRange,RoundIndex);
    pause ->
      receive
        continue ->
          grid([Agent_PId|PIds],MPIds,XRange,YRange,RoundIndex);
        terminate ->
          [APId ! terminate || APId <-MPIds],
          io:format("Terminating scape:~p~n",[self()])
      end;
   terminate ->
      [APId ! terminate || APId <-MPIds],
     io:format("Terminating Scape: ~p~n",[self()])
 end;
 grid([],MPIds,XRange,YRange,RoundIndex)->
    {A,B}=gather_stats(1,1,XRange+1,YRange,0,0),
    io:format("Round Index: ~p A:~p B:~p~n",[RoundIndex,A,B]),
    grid(MPIds,MPIds,XRange,YRange,RoundIndex+1).

stay(_Agent_PId,_Type,Loc,_XRange,_YRange)->
      Loc.

move(Agent_PId,Type,{Target_X,Target_Y},XRange,YRange)->
    {X,Y}=find_empty_loc(XRange,YRange),
    erase({Target_X,Target_Y}),
    put({X,Y},{Agent_PId,Type}),
    {X,Y}.

  gather_stats(XRange,YRange,XRange,YRange,AccA,AccB)->
     {AccA,AccB};
   gather_stats(XRange,Y,XRange,YRange,AccA,AccB)->
      gather_stats(1,Y+1,XRange,YRange,AccA,AccB);
   gather_stats(X,Y,XRange,YRange,AccA,AccB)->
      case get({X,Y}) of
           undefined ->
               Local_State = [get({TX,TY})|| TX <- [X-1,X,X+1],TY<-[Y-1,Y,Y+1]],
               TotMales = lists:sum([1 || {_APId,male} <- Local_State--[{self(),male}
              ]]),
               TotFemale = lists:sum([1 || {_APId,female} <- Local_State--[{self(),female}]]),
               if
               (TotFemale > TotMales) -> gather_stats(X+1,Y,XRange,YRange,AccA
              +1,AccB);
               (TotFemale < TotMales) -> gather_stats(X+1,Y,XRange,YRange,AccA,AccB
              +1);
               true -> gather_stats(X+1,Y,XRange,YRange,AccA,AccB)
               end;
               _ ->
               gather_stats(X+1,Y,XRange,YRange,AccA,AccB)
       end.

male(Scape_PId,Loc,Ratio)->
    Scape_PId ! {self(),Loc,get_LocalState},
   receive
      {Scape_PId,Local_State}->
         TotMale = lists:sum([1 || {_APId,male} <- Local_State--[{self(),male}]]),
         Choice = case TotMale >= (5*Ratio) of
               true -> stay;
               false -> move
                  end,
         Scape_PId ! {self(),swimmer,Loc,Choice},
         receive {Scape_PId,updated_loc,U_Loc} -> ok end,
         male(Scape_PId,U_Loc,Ratio);
       terminate -> ok
    end.

female(Scape_PId,Loc,Ratio)->
   Scape_PId ! {self(),Loc,get_LocalState},
 receive
   {Scape_PId,Local_State}->
         TotFemale = lists:sum([1 || {_APId,female} <- Local_State--[{self(),female}]]),
         Choice = case TotFemale >= (5*Ratio) of
               true -> stay;
               false -> move
                  end,
         Scape_PId ! {self(),surfer,Loc,Choice},
         receive {Scape_PId,updated_loc,U_Loc} -> ok end,
         female(Scape_PId,U_Loc,Ratio);
   terminate -> ok
 end.
