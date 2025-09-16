using Random
import Base: copy

abstract type PlayerType end
mutable struct Player
    # Private fields (can't be directly accessed by other players)
    const resources::Dict{Symbol,Int8}
    const devcards::Dict{Symbol,Int8}
    
    # Public fields (can be used by other players to inform their moves)
    const team::Symbol
    const devcards_used::Dict{Symbol,Int8}
    const ports::Dict{Symbol, Int8}
    played_devcard_this_turn::Bool
    bought_devcard_this_turn::Union{Nothing,Symbol}
    const configs::Dict
end

function Player(team::Symbol, configs::Dict)
    return Player(team, configs, Dict{Symbol,Int8}())
end
function Player(team::Symbol, configs::Dict, resources::Dict{Symbol, Int8})
    default_ports = Dict([
    :Wood => 4
    :Stone => 4
    :Grain => 4
    :Brick => 4
    :Pasture => 4
    ])
    return Player(resources, Dict(), team, Dict(), Dict{Symbol,Int8}(), false, nothing, configs)
end


"""
    PlayerPublicView

Combines the public fields of `Player`, with some additional fields representing the info available
publicly about the private fields.  E.g. everyone knows how many dev cards each player has, but not which ones.
"""
struct PlayerPublicView
    # This is the same as the public fields in `Player`
    team::Symbol
    devcards_used::Dict{Symbol,Int8}
    ports::Dict{Symbol, Int8}
    played_devcard_this_turn::Bool
    
    # Aggregated fields pertaining to the publicly-known info about the private fields
    resource_count::Int8
    devcards_count::Int8
end

function Base.show(io::IO, a::PlayerPublicView)
    compact = get(io, :compact, false)
    if compact
        print(io, "Public($(a.team))")
    else
        print(io, "Public($(a.team), $(a.resource_count), $(a.devcards_count))")
    end
end

PlayerPublicView(player::PlayerPublicView) = player;
PlayerPublicView(player::PlayerType) = PlayerPublicView(player.player)
PlayerPublicView(player::Player) = PlayerPublicView(
    player.team,
    player.devcards_used,
    player.ports,
    player.played_devcard_this_turn,

    # Resource count
    sum(values(player.resources)), 
    # Dev cards count
    sum(values(player.devcards))
   )


struct HumanPlayer <: PlayerType
    player::Player
    io::IO
end
abstract type RobotPlayer <: PlayerType
end

struct DefaultRobotPlayer <: RobotPlayer
    player::Player
end

function Base.show(io::IO, p::Player)
    compact = get(io, :compact, false)
    if compact
        print(io, "$(p.team)")
    else
        print(io, "$(p.team)")
    end
end

function Base.show(io::IO, p::PlayerType)
    compact = get(io, :compact, false)
    if compact
        print(io, "$(p.player)")
    else
        print(io, "$(p.player)")
    end
end

function print_player_dashboard(p::PlayerType)
    @info "Player $p:"
    for (r,c) in p.player.resources
        if c > 0
            @info "\t$r => $c"
        end
    end
    for (r,c) in p.player.devcards
        if c > 0
            @info "\t$r => $c"
        end
    end
end


HumanPlayer(team::Symbol, io::IO, configs::Dict) = HumanPlayer(Player(team, configs), io)
HumanPlayer(team::Symbol, configs::Dict) = HumanPlayer(team, stdin, configs)

DefaultRobotPlayer(team::Symbol, configs::Dict) = DefaultRobotPlayer(Player(team, configs))
DefaultRobotPlayer(team::Symbol, configs::Dict, resources::Dict{Symbol, Int8}) = DefaultRobotPlayer(Player(team, configs, resources))


function Base.copy(player::DefaultRobotPlayer)
    return DefaultRobotPlayer(copy(player.player))
end

function Base.copy(player::HumanPlayer)
    return HumanPlayer(copy(player.player), player.io)
end

function Base.copy(player::Player)
    return Player(
        copy(player.resources),
        copy(player.devcards),
        player.team,
        copy(player.devcards_used),
        copy(player.ports),
        player.played_devcard_this_turn,
        player.bought_devcard_this_turn,
        player.configs
    )
end

struct KnownPlayers
    registered_constructors::Dict
end

function get_known_players()
    return known_players.registered_constructors
end
function add_player_to_register(name, constructor)
    @debug "Registering $name"
    known_players.registered_constructors[name] = constructor
end

