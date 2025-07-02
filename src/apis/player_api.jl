"""
Players API


Meta-game Player API: for initializing and storing results for purposes of algorithm training

# Functions that modify player state, only called via API_DICTIONARY:

_add_devcard!(player::Player, devcard::Symbol)
_add_port!(player::Player, resource::Symbol)
_discard_cards!(player, resources...)
_give_resource!(player::Player, resource::Symbol)
_play_devcard!(player::Player, devcard::Symbol)
_take_resource!(player::Player, resource::Symbol)

# Read-only helper functions, can be used from anywhere:

add_devcard!(player::Player, devcard::Symbol)
add_port!(player::Player, resource::Symbol)
can_play_devcard(player::Player)::Bool
count_cards(player::Player)
count_resource(player::Player, resource::Symbol)::Int
count_resources(player::Player)
discard_cards!(player, resources...)
get_admissible_devcards(player::Player)
get_vp_count_from_devcards(player::Player)
give_resource!(player::Player, resource::Symbol)
has_any_resources(player::Player)::Bool
has_enough_resources(player::Player, resources::Dict{Symbol,Int})::Bool
pay_construction(player::Player, construction::Symbol)
pay_price!(player::Player, cost::Dict)
play_devcard!(player::Player, devcard::Symbol)
take_resource!(player::Player, resource::Symbol)
trade_resource_with_bank(player::Player, from_resource, to_resource)
"""
module PlayerApi
using ..Catan: Player, PlayerPublicView, RESOURCES, COSTS, RESOURCE_TO_COUNT, log_action, get_devcard_counts

# Player API

function get_admissible_devcards(player::Player)::Vector{Tuple{Symbol}}
    return [(k,) for k in keys(get_admissible_devcards_with_counts(player))]
end
function get_admissible_devcards_with_counts(player::Player)::Dict{Symbol, Int8}
    if player.played_devcard_this_turn
        return Dict()
    end
    
    # Non-playable card :VictoryPoint
    out = copy(player.devcards)
    out[:VictoryPoint] = 0

    if player.bought_devcard_this_turn !== nothing
        out[player.bought_devcard_this_turn::Symbol] -= 1
    end
    return Dict((c,cc) for (c,cc) in out if cc > 0)
end
function trade_resource_with_bank(player::Player, from_resource, to_resource)
    rate = player.ports[from_resource]
    for r in 1:rate
        take_resource!(player, from_resource)
    end
    give_resource!(player, to_resource)
end

function can_play_devcard(player::Player)::Bool
    return ~isempty(get_admissible_devcards(player))
    #=
    total_num_devcards = sum(values(player.devcards))
    if haskey(player.devcards, :VictoryPoint) && total_num_devcards == player.devcards[:VictoryPoint]
        return false
    end
    return total_num_devcards > 0 && ~player.played_devcard_this_turn
    =#
end

function get_vp_count_from_devcards(player::Player)
    if haskey(player.devcards, :VictoryPoint)
        return player.devcards[:VictoryPoint]
    end
    return 0
end

function buy_devcard(player::Player, card::Symbol)
    pay_construction(player, :DevelopmentCard)
    add_devcard!(player, card)
end

function add_devcard!(player::Player, devcard::Symbol)
    log_action(player.configs, ":$(player.team) ad", devcard)
    _add_devcard!(player, devcard)
end
function _add_devcard!(player::Player, devcard::Symbol)
    if haskey(player.devcards, devcard)
        player.devcards[devcard] += 1
    else
        player.devcards[devcard] = 1
    end
    player.bought_devcard_this_turn = devcard
end
    
function play_devcard!(player::Player, devcard::Symbol)
    log_action(player.configs, ":$(player.team) pd", devcard)
    _play_devcard!(player, devcard)
end

function _play_devcard!(player::Player, devcard::Symbol)
    if ~haskey(player.devcards_used, devcard)
        player.devcards_used[devcard] = 0
    end
    player.devcards[devcard] -= 1
    player.devcards_used[devcard] += 1
    player.played_devcard_this_turn = true
end

function count_resources(player::Player)
    total = 0
    for r in keys(RESOURCE_TO_COUNT)
        total += count_resource(player, r)
    end
    return total
end
function count_resource(player::Player, resource::Symbol)::Int
    if haskey(player.resources, resource)
        return player.resources[resource]
    end
    return 0
end

function has_any_resources(player::Player)::Bool
    for (r,amt) in player.resources
        if amt > 0
            return true
        end
    end
    return false
end

function has_any_resources(player::PlayerPublicView)::Bool
    return player.resource_count > 0
end

function has_enough_resources(player::Player, resources::Dict{Symbol,Int})::Bool
    for (r,amt) in resources
        if !haskey(player.resources, r)
            return false
        end
        if player.resources[r] < amt
            return false
        end
    end
    return true
end

function discard_cards!(player, resources...)
    log_action(player.configs, ":$(player.team) dc", resources...)
    _discard_cards!(player, resources...)
end
function _discard_cards!(player, resources...)
    for r in resources
        _take_resource!(player, r)
    end
end

function count_cards(player::Player)
    sum(values(player.resources))
end

function add_port!(player::Player, resource::Symbol)
    log_action(player.configs, ":$(player.team) ap", resource)
    _add_port!(player, resource)
end
function _add_port!(player::Player, resource::Symbol)
    if haskey(player.ports, resource)
        player.ports[resource] = 2

    # Alternative is that this port is a 3:1 universal, so we change any exchange rates of 4 to 3
    else
        for (k,v) in player.ports
            if v == 4
                player.ports[k] = 3
            end
        end
    end
end

function give_resource!(player::Player, resource::Symbol)
    if resource in RESOURCES
        log_action(player.configs, ":$(player.team) gr", resource)
        _give_resource!(player, resource)
    else
        #@warn "giving $(player.team) $resource"
    end
end
function _give_resource!(player::Player, resource::Symbol)
    if haskey(player.resources, resource)
        player.resources[resource] += 1
    else
        player.resources[resource] = 1
    end
end
function take_resource!(player::Player, resource::Symbol)
    log_action(player.configs, ":$(player.team) tr", resource)
    _take_resource!(player, resource)
end
function _take_resource!(player::Player, resource::Symbol)
    if haskey(player.resources, resource) && player.resources[resource] > 0
        player.resources[resource] -= 1
    else
        @debug "$(player.team) has insufficient $(resource) cards"
    end
end

function pay_price!(player::Player, cost::Dict)
    resources = keys(cost)
    for (r,amount) in cost
        discard_cards!(player, repeat([r], amount)...)
    end
end

function pay_construction(player::Player, construction::Symbol)
    cost = COSTS[construction]
    pay_price!(player, cost)
end
end
