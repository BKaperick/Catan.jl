module Catan

using JSON
using DocStringExtensions
using Logging
using Random
using StatsBase
using StaticArrays

include("players/structs.jl")
include("structs.jl")

include("constants.jl")
include("random_helper.jl")
include("parsing.jl")
include("io.jl")

include("apis/player_api.jl")
import .PlayerApi

include("players/human_player.jl")
include("players/robot_player.jl")

include("apis/board_api.jl")
import .BoardApi

include("apis/game_api.jl")
import .GameApi

include("trading.jl")

include("main.jl")
include("actions.jl")
include("game_runner.jl")
import .GameRunner

include("../test/helper.jl")

export HumanPlayer, DefaultRobotPlayer, ChosenAction, RobotPlayer, Player, Board, Map, Road, PlayerType, PlayerPublicView, Game,
    initialize_and_do_game!,
BoardApi, 
PlayerApi,
GameApi,
GameRunner,
PreAction,
get_known_players,
get_player_config,
set_player_config,
parse_and_execute_api_call,
get_state_score

# Customizable Player Interface
export 
choose_next_action,
choose_building_location,
choose_road_location,
choose_accept_trade,
choose_who_to_trade_with,
choose_one_resource_to_discard,
choose_monopoly_resource,
choose_place_robber,
choose_robber_victim,
choose_resource_to_draw,
initialize_player,
do_post_game_action,
do_post_game_produce!

function __init__()
    # Set the default configs
    global DEFAULT_CONFIGS = _initialize_configs()

    global known_players = KnownPlayers(Dict())
    add_player_to_register("DefaultRobotPlayer", (t,c) -> DefaultRobotPlayer(t,c))
    add_player_to_register("HumanPlayer", (t,c) -> HumanPlayer(t,c))
end

end
