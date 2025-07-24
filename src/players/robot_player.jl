get_admissible_devcards(player::RobotPlayer) = PlayerApi.get_admissible_devcards(player.player)

"""
    choose_accept_trade(board::Board, player::RobotPlayer, from_player::PlayerPublicView, 
    from_goods::Vector{Symbol}, to_goods::Vector{Symbol})::Bool

Decides whether `player` will accept the trade from `from_player`.  The trade is not performed within this function.
"""
function choose_accept_trade(board::Board, player::RobotPlayer, from_player::PlayerPublicView, from_goods, to_goods)::Bool
    return rand() > .5
end

function roll_dice(player::RobotPlayer)::Integer
    value = Int8(rand(1:6) + rand(1:6))
    @info "$(player) rolled a $value"
    return value
end

"""
    choose_road_location(board::Board, players::AbstractVector{PlayerPublicView}, 
    player::RobotPlayer, candidates::Vector{Vector{Tuple{Int, Int}}})
    ::Vector{Tuple{Int, Int}}

`candidates` is guaranteed to be non-empty.  Given all legal road placements, 
return a `Tuple` containing two coordinates signifying the road placement choice.
"""
function choose_road_location(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer, candidates::Vector{Tuple{Tuple{TInt, TInt}, Tuple{TInt, TInt}}}, do_pay_cost = true)::Union{Nothing,Tuple{Tuple{TInt, TInt}, Tuple{TInt, TInt}}} where {TInt <: Integer}
    return sample(candidates)
end

"""
    choose_building_location(board::Board, players::AbstractVector{PlayerPublicView}, 
    player::RobotPlayer, candidates::Vector{Tuple{Int, Int}}, building_type::Symbol
    )::Tuple{Int,Int}

`candidates` is guaranteed to be non-empty.  This method is only called if there is a legal placement available.
"""
function choose_building_location(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer, candidates::Vector{Tuple{TInt, TInt}}, building_type::Symbol, is_first_turn = false)::Tuple{TInt, TInt} where {TInt <: Integer}
    @debug "$(player) chooses $building_type location randomly"
    return sample(candidates, 1)[1]
end

"""
    choose_one_resource_to_discard(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer)::Symbol

Returned symbol must be present in both `Catan.RESOURCES` and `keys(player.resources)`. 
"""
function choose_one_resource_to_discard(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer)::Symbol
    isempty(player.player.resources) && throw(ArgumentError("Player has no resources"))
    return unsafe_random_sample_one_resource(player.player.resources)
    #return random_sample_resources(player.player.resources, 1)[1]
end

"""
    choose_place_robber(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer, 
    candidates::Vector{Symbol})::Union{Nothing, Symbol}
"""
function choose_place_robber(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer, candidates::Vector{Symbol})::Symbol
    if length(candidates) > 0
        return sample(candidates, 1)[1]
    end
    throw(ArgumentError("candidates can't be empty for placing robber"))
end

function steal_random_resource(from_player::RobotPlayer, to_player::RobotPlayer)
    stolen_good = choose_card_to_steal(from_player)
end

function choose_card_to_steal(player::RobotPlayer)::Symbol
    unsafe_random_sample_one_resource(player.player.resources)
    #random_sample_resources(player.player.resources, 1)[1]
end

"""
    choose_monopoly_resource(board::Board, players::AbstractVector{PlayerPublicView}, 
    player::RobotPlayer)::Symbol

Called during the Monopoly development card action.  Choose the resource to steal from each player based on public information.
"""
function choose_monopoly_resource(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer)::Symbol
    return get_random_resource()
end

"""
    choose_resource_to_draw(board, players::AbstractVector{PlayerPublicView}, 
    player::RobotPlayer)::Symbol

Called two times during the Year of Plenty development card action.  TODO inconsistent naming.
"""
function choose_resource_to_draw(board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer)::Symbol
    return get_random_resource()
end

"""
    choose_robber_victim(board::Board, player::RobotPlayer, 
    potential_victims::PlayerPublicView...)::PlayerPublicView

The robber has already been placed, so here `player` decided which adjacent player to steal from.
"""
function choose_robber_victim(board::Board, player::RobotPlayer, potential_victims::PlayerPublicView...)::PlayerPublicView
    random_player = sample(collect(potential_victims), 1)[1]
    @info "$(player) decided it is wisest to steal from the $(random_player) player"
    return random_player
end

function _choose_play_devcard(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer, devcards::Dict)::Union{Symbol,Nothing}
    if sum(values(devcards)) > 0 && (rand() > .5)
        return unsafe_random_sample_one_resource(devcards)
        #return random_sample_resources(devcards, 1)[1]
    end
    return nothing
end

"""
    choose_next_action(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer, 
    actions::Set{PreAction})::Function

Given a `Set` of `PreAction` legal move categories, decide what will be taken as the next action.
The return `Function` needs to accept a `Game, Board, PlayerType` triple.

TODO integrate with `CatanLearning` `Action` type.  This should not be returning a function.
"""
function choose_next_action(board::Board, players::AbstractVector{PlayerPublicView}, player::RobotPlayer, actions::Set{PreAction})::ChosenAction
    rand_action = sample(collect(actions), 1)[1]
    name = rand_action.name
    # candidates is a Vector of argument Tuples.
    # For example, ConstructSettlement takes a 1-tuple of Tuple{Int8,Int8}, so it is a Vector{Tuple{Tuple{Int8,Int8}}}
    candidates = rand_action.admissible_args
    if name == :ConstructCity
        candidates_unwrapped = [x[1] for x in candidates]
        coord = choose_building_location(board, players::AbstractVector{PlayerPublicView}, player, candidates_unwrapped, :City)
        return ChosenAction(name, coord)
    end
    if name == :ConstructSettlement
        candidates_unwrapped = [x[1] for x in candidates]
        coord = choose_building_location(board, players::AbstractVector{PlayerPublicView}, player, candidates_unwrapped, :Settlement)
        return ChosenAction(name, coord, candidates[1][end])
    end
    if name == :ConstructRoad
        is_first_turn = candidates[1][end]::Bool
        typed_candidates = [x[1:2]::Tuple{Tuple{Int8,Int8}, Tuple{Int8,Int8}} for x in candidates]
        coord = choose_road_location(board, players::AbstractVector{PlayerPublicView}, player, typed_candidates, is_first_turn)
        coord1 = coord[1]
        coord2 = coord[2]
        return ChosenAction(name, coord1, coord2, is_first_turn)
    end
    if name == :BuyDevCard
        return ChosenAction(name)
    end
    if name == :PlayDevCard
        devcards = PlayerApi.get_admissible_devcards_with_counts(player.player)
        card = _choose_play_devcard(board, players, player, devcards)
        if card !== nothing
            return ChosenAction(name, card)
        end            
    end
    if name == :ProposeTrade
        # We add an additional random filter here to avoid extremely long, uninteresting trade negotiations between DefaultRobotPlayers.
        if rand() > .8 && sum(values(player.player.resources)) > 0
            rand_resource_from = [unsafe_random_sample_one_resource(player.player.resources)]
            #sampled = random_sample_resources(player.player.resources, 1)
            #rand_resource_from = [sampled...]
            
            rand_resource_to = [get_random_resource()]
            while rand_resource_to[1] == rand_resource_from[1]
                rand_resource_to = [get_random_resource()]
            end
            return ChosenAction(name, rand_resource_from, rand_resource_to)
            #return (g, b, p) -> propose_trade_goods(b, g.players, p, rand_resource_from, rand_resource_to)
        end
    end
    return ChosenAction(:DoNothing) #Returns(nothing)
end

"""
    choose_who_to_trade_with(board::Board, player::RobotPlayer, 
    players::AbstractVector{PlayerPublicView})::Symbol

Called when multiple other players have accepted a trade offer via `choose_accept_trade`, and now the trade initiator, `player`, selects which player will be selected.
"""
function choose_who_to_trade_with(board::Board, player::RobotPlayer, players::AbstractVector{PlayerPublicView})::Symbol
    max_ind = player.player
    while max_ind.team == player.player.team
        max_ind = sample(collect(players), 1)[1]
    end
    @info "$(player) decided it is wisest to do business with $(max_ind.team) player"
    return max_ind.team
end
