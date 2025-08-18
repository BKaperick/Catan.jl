mutable struct Game
    devcards::Dict{Symbol,Int8}
    players::AbstractVector{PlayerType}
    # This field is needed in order to reload a game that was saved and quit in the middle of a turn
    already_played_this_turn::Set{Symbol}
    turn_num::Int
    turn_order_set::Bool
    first_turn_forward_finished::Bool
    rolled_dice_already::Bool
    unique_id::Int
    configs::Dict{String, Any}
end

Game(players::AbstractVector{PlayerType}) = Game(SVector{length(players)}(players), Dict{String, Any}())
function Game(players::AbstractVector{PlayerType}, configs::Dict)
    # TODO, fails with ERROR: Tuple field type cannot be Union{} in broadcast, so we have to do it as list comp.
    # Seems weird, maybe was working before 1.10
    # TODO test now that deepcopy changed to copy
    static_copied_players = SVector{length(players)}([copy(p) for p in players])
    #bad_static_copied_players = SVector{length(players)}(copy.(players))
    Game(get_devcard_counts(configs), static_copied_players, Set(), 1, false, false, false, rand(range(1,10000)), configs)
end

struct Road
    coord1::Tuple{Int8,Int8}
    coord2::Tuple{Int8,Int8}
    team::Symbol
end

struct Building
    coord::Tuple{Int8,Int8}
    type::Symbol
    team::Symbol
end

struct Map
    tile_to_dicevalue::Dict{Symbol,Int8}
    dicevalue_to_tiles::Dict{Int8,AbstractVector{Symbol}}
    tile_to_resource::Dict{Symbol,Symbol}
    coord_to_port::Dict{Tuple{Int8,Int8},Symbol}
    desert_tile::Symbol
end

# TODO: Either 
# (1) Create a non-mutable `struct Map` that contains all the non-changing data structures
# (2) Create a function to reset a board to the initial game state.
# (3) Both - separate out Map, copy()ing just re-uses Map, and a function to reset
mutable struct Board
    map::Map
    coord_to_building::Dict{Tuple{Int8,Int8},Building}
    coord_to_roads::Dict{Tuple{Int8, Int8}, Set{Road}}
    coord_to_road_teams::Dict{Tuple{Int8, Int8}, Set{Symbol}}
    buildings::Array{Building,1}
    roads::Array{Road,1}
    team_to_road_length::Dict{Symbol, Int8}
    robber_tile::Symbol
    spaces::Vector{Vector{Bool}}
    resources::Dict{Symbol,Int8}
    # Team of player with the longest road card (is nothing if no player has a road at least 5 length)
    longest_road::Union{Nothing, Symbol}
    largest_army::Union{Nothing, Symbol}
    configs::Dict
end

Board(map_str::AbstractString, configs::Dict) = Board(Map(map_str), configs)
Board(map::Map, configs::Dict) = Board(map, Dict(), Dict(), Dict(), 
      [], [], Dict(), map.desert_tile, 
      BoardApi.initialize_empty_board(), 
      Dict([(r, configs["GameSettings"]["MaxComponents"]["RESOURCE"]) for r in RESOURCES]), 
      nothing, nothing, configs)
#Board(csvfile) = BoardApi.Board(csvfile)

function Base.copy(board::Board)
    return Board(
                 board.map,
                 copy(board.coord_to_building),
                 Dict([k=>copy(v) for (k,v) in board.coord_to_roads]),
                 copy(board.coord_to_road_teams),
                 copy(board.buildings),
                 copy(board.roads),
                 copy(board.team_to_road_length),
                 board.robber_tile,
                 [copy(s) for s in board.spaces],
                 copy(board.resources),
                 board.longest_road,
                 board.largest_army,
                 board.configs
                    )
end

struct PreAction
    name::Symbol
    admissible_args::Vector{Tuple}
    function PreAction(name::Symbol, admissible_args::Vector{Tuple})
        new(name, unique(admissible_args))
    end
    function PreAction(name::Symbol, admissible_args::Vector{Tuple{T}}) where {T <: Any}
        new(name, unique(admissible_args))
    end

    function PreAction(name::Symbol, admissible_args::Vector{Tuple{T, T}}) where {T <: Any}
        new(name, unique(admissible_args))
    end

    function PreAction(name::Symbol, admissible_args::Vector{Tuple{T1, T2, T3}}) where {T1,T2,T3 <: Any}
        new(name, unique(admissible_args))
    end
end

Base.:(==)(x::PreAction, y::PreAction) = x.name == y.name && x.admissible_args == y.admissible_args

struct ChosenAction
    name::Symbol
    args::Tuple
    ChosenAction(name::Symbol, args...) = new(name, args)
end

function Base.show(io::IO, a::ChosenAction)
    compact = get(io, :compact, false)
    if length(a.args) == 0
        print(io, "$(a.name)()")
        return
    end
    if compact
        print(io, "$(a.name)(...)")
    else
        print(io, "$(a.name)($(a.args))")
    end
end

Base.length(a::PreAction) = length(a.admissible_args)

function Base.show(io::IO, a::PreAction)
    compact = get(io, :compact, false)
    if length(a.admissible_args) == 0
        print(io, "$(a.name)()")
        return
    end
    if compact
        print(io, "$(a.name)(...)")
    else
        print(io, "$(a.name)($(a.admissible_args))")
    end
end

PreAction(name::Symbol) = PreAction(name, Vector{Tuple{Any}}())
PreAction(name::Symbol, arg::Vector{Symbol}) = PreAction(name, [(s,) for s in arg])