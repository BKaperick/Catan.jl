abstract type PlayerType end
mutable struct Player
    team::Symbol
    resources::Dict{Symbol,Int}
    vp_count::Int
    dev_cards::Dict{Symbol,Int}
    dev_cards_used::Dict{Symbol,Int}
    ports::Dict{Symbol, Int}
    played_dev_card_this_turn::Bool
    bought_dev_card_this_turn::Union{Nothing,Symbol}
    has_largest_army::Bool
    has_longest_road::Bool
end
mutable struct HumanPlayer <: PlayerType
    player::Player
    io::IO
end
abstract type RobotPlayer <: PlayerType
end

mutable struct DefaultRobotPlayer <: RobotPlayer
    player::Player
end

function Player(team::Symbol)
    default_ports = Dict([
    :Wood => 4
    :Stone => 4
    :Grain => 4
    :Brick => 4
    :Pasture => 4
    ])
    return Player(team, Dict(), 0, Dict(), Dict(), default_ports, false, nothing, false, false)
end
HumanPlayer(team::Symbol, io::IO) = HumanPlayer(Player(team), io)
HumanPlayer(team::Symbol) = HumanPlayer(team, stdin)
DefaultRobotPlayer(team::Symbol) = DefaultRobotPlayer(Player(team))


mutable struct Public_Info
    resource_count::Int
    dev_cards_count::Int
    dev_cards_used::Dict{Symbol,Int}
    vp_count::Int
end
Public_Info(player::Player) = Public_Info(
    sum(values(player.resources)), 
    sum(values(player.dev_cards)),
    Dict(),
    player.vp_count)

mutable struct Private_Info
    resources::Dict{Symbol,Int}
    dev_cards::Dict{Symbol,Int}
    private_vp_count::Int
end
Private_Info(player::Player) = Private_Info(player.resources, player.dev_cards, player.vp_count)

mutable struct Game
    devcards::Dict{Symbol,Int}
    players::Vector{PlayerType}
    # This field is needed in order to reload a game that was saved and quit in the middle of a turn
    already_played_this_turn::Set{Symbol}
    turn_num::Int
    turn_order_set::Bool
    first_turn_forward_finished::Bool
    rolled_dice_already::Bool
end
Game(players) = Game(copy(DEVCARD_COUNTS), players, Set(), 0, false, false, false)

mutable struct Construction
end

mutable struct Road
    coord1::Tuple{Int,Int}
    coord2::Tuple{Int,Int}
    team::Symbol
end

mutable struct Building
    coord::Tuple{Int,Int}
    type::Symbol
    team::Symbol
end

mutable struct Board
    tile_to_dicevalue::Dict{Symbol,Int}
    #dicevalue_to_coords::Dict{Symbol,Int}
    dicevalue_to_tiles::Dict{Int,Vector{Symbol}}
    tile_to_resource::Dict{Symbol,Symbol}
    coord_to_building::Dict{Tuple,Building}
    coord_to_roads::Dict{Tuple,Set{Road}}
    coord_to_port::Dict{Tuple,Symbol}
    empty_spaces::Vector
    buildings::Array{Building,1}
    roads::Array{Road,1}
    robber_tile::Symbol
    spaces::Vector
end

Board(tile_to_value::Dict, dicevalue_to_tiles::Dict, tile_to_resource::Dict, robber_tile::Symbol, coord_to_port::Dict) = Board(tile_to_value, dicevalue_to_tiles, tile_to_resource, Dict(), Dict(), coord_to_port, initialize_empty_board(DIMS), [], [], robber_tile, initialize_empty_board(DIMS))

