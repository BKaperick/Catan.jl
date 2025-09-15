ALL_ACTIONS = Set([
:ConstructSettlement,
:ConstructCity,
:ConstructRoad,
:ProposeTrade,
:BuyDevCard,
:PlayDevCard,
:PlaceRobber #FromKnight,
#:PlaceRobberFromSeven
])

"""
PLAYER_ACTIONS = Dict([
    :ConstructSettlement    => act_construct_settlement,
    :ConstructCity          => act_construct_city,
    :ConstructRoad          => act_construct_road,
    :ProposeTrade           => act_propose_trade_goods,
    :PlayDevCard            => act_play_devcard,

    # Probabilistic actions
    :BuyDevCard             => act_buy_devcard,
    :PlaceRobber            => do_robber_move_theft ,
    :TradeWithBank          => trade_resource_with_bank
   ])


ACTIONS_DICTIONARY = Dict(
    :ConstructCity => construct_city,
    :ConstructRoad => construct_road,
    :ConstructSettlement => construct_settlement
   )
"""


function do_trade_with_bank(board, player, from::Symbol, to::Symbol)
    if BoardApi.can_draw_resource(board, to)
        PlayerApi.trade_resource_with_bank(player.player, from, to)
    else
        @debug "Not enough resources to trade with bank (missing sufficient $to)"
    end
end

#
# CONSTRUCTION ACTIONS
#

function construct_road(board, player::Player, coord1::Tuple{TInt, TInt}, coord2::Tuple{TInt, TInt}, do_pay_cost) where {TInt <: Integer}
    if do_pay_cost
        PlayerApi.pay_construction(player, :Road)
        BoardApi.pay_construction!(board, :Road)
    end
    BoardApi.build_road!(board, player.team, coord1, coord2)
end

function construct_city(board, player::Player, coord::Tuple{Integer, Integer}, first_turn = false)
    if ~first_turn
        PlayerApi.pay_construction(player, :City)
        BoardApi.pay_construction!(board, :City)
    end
    BoardApi.build_city!(board, player.team, coord)
end
function construct_settlement(board, player::Player, coord::Tuple{Integer, Integer}, first_turn = false)
    if ~first_turn
        PlayerApi.pay_construction(player, :Settlement)
        BoardApi.pay_construction!(board, :Settlement)
    end
    check_add_port(board, player, coord)
    BoardApi.build_settlement!(board, player.team, coord)
end

function check_add_port(board::Board, player::Player, coord)
    if haskey(board.map.coord_to_port, coord)
        PlayerApi.add_port!(player, board.map.coord_to_port[coord])
    end
end

#
# DEVCARD ACTIONS
#

function draw_devcard(game::Game, board::Board, player::Player)
    card = GameApi.draw_devcard(game)
    PlayerApi.buy_devcard(player, card)
    BoardApi.pay_construction!(board, :DevelopmentCard)
end

function do_play_devcard(board::Board, players, player, card::Union{Nothing,Symbol})
    if card !== nothing
        PlayerApi.play_devcard!(player.player, card)
        do_devcard_action(board, players, player, card)
        decide_and_assign_largest_army!(board, players)
        # Note: longest road is assigned within the build road call
    end
end

function do_devcard_action(board, players::AbstractVector{PlayerType}, player::PlayerType, card::Symbol)
    @info "$(player) does devcard $card action"
    players_public = PlayerPublicView.(players)
    if card == :Knight
        do_knight_action(board, players, player)
    elseif card == :Monopoly
        do_monopoly_action(board, players, player)
    elseif card == :YearOfPlenty
        do_year_of_plenty_action(board, players_public, player)
    elseif card == :RoadBuilding
        do_road_building_action(board, players_public, player)
    else
        @assert false
    end
    return
end

function do_road_building_action(board, players::AbstractVector{PlayerPublicView}, player::PlayerType)
    choose_validate_build_road!(board, players, player, false, true)
    choose_validate_build_road!(board, players, player, false, true)
end

function do_year_of_plenty_action(board, players::AbstractVector{PlayerPublicView}, player::PlayerType)
    r1 = choose_resource_to_draw(board, players, player)::Symbol
    PlayerApi.give_resource!(player.player, r1)
    BoardApi.draw_resource!(board, r1)
    r2 = choose_resource_to_draw(board, players, player)::Symbol
    PlayerApi.give_resource!(player.player, r2)
    BoardApi.draw_resource!(board, r2)
end

function do_monopoly_action(board, players::AbstractVector{PlayerType}, player::PlayerType)
    players_public = PlayerPublicView.(players)
    res = choose_monopoly_resource(board, players_public, player)
    for victim in players
        @info "$(victim) gives $(PlayerApi.count_resource(victim.player, res)) $res to $(player)"
        for i in 1:PlayerApi.count_resource(victim.player, res)
            PlayerApi.take_resource!(victim.player, res)
            PlayerApi.give_resource!(player.player, res)
        end
    end
end

function do_knight_action(board, players::AbstractVector{PlayerType}, player)
    do_robber_move_theft(board, players, player)
end

function do_robber_move(board, players::AbstractVector{PlayerType}, player)
    for p in players
        do_robber_move_discard(board, players, p)
    end
    do_robber_move_theft(board, players, player)
end

function do_robber_move_discard(board, players::AbstractVector{PlayerType}, player::PlayerType)
    r_count = PlayerApi.count_cards(player.player)
    if r_count > 7
        discard_amount = Int(floor(r_count / 2))
        @info "$player has $r_count resources, so he must discard $discard_amount of them"
        for i = 1:discard_amount
            resource = choose_one_resource_to_discard(board, PlayerPublicView.(players), player)
            PlayerApi.discard_cards!(player.player, resource)
            BoardApi.give_resource!(board, resource)
        end
    end
end

function do_robber_move_theft(board, players::AbstractVector{PlayerType}, player::PlayerType)
    players_public = PlayerPublicView.(players)
    candidate_tiles = BoardApi.get_admissible_robber_tiles(board) 
    new_robber_tile = choose_place_robber(board, players_public, player, candidate_tiles)::Symbol
    @info "$(player) moves robber to $new_robber_tile"
    players_public = PlayerPublicView.(players)
    admissible_victims_public = [p.team for p in get_admissible_theft_victims(board, players_public, player.player, new_robber_tile)]
    admissible_victims = Vector{PlayerType}([p for p in players if p.player.team in admissible_victims_public])
    
    do_robber_move_choose_victim_theft(board, admissible_victims, player, new_robber_tile)
end

function do_robber_move_choose_victim_theft(board, admissible_victims::AbstractVector{PlayerType}, 
        player::T, new_robber_tile::Symbol) where T <: PlayerType
    stolen_good = nothing
    victim_team = nothing
    if length(admissible_victims) > 0
        admissible_victims_public = PlayerPublicView.(admissible_victims)
        from_player_view = choose_robber_victim(board, player, admissible_victims_public...)
        victim_team = from_player_view.team
        victim = admissible_victims[1]
        for p in admissible_victims
            if p.player.team == victim_team
                victim = p
                break
            end
        end
        #victim = [p for p in admissible_victims if p.player.team == victim_team][1]
        stolen_good = steal_random_resource(victim, player)
    end
    inner_do_robber_move_theft(board, admissible_victims::AbstractVector{PlayerType}, player, victim_team, new_robber_tile, stolen_good)
end

function inner_do_robber_move_theft(board, players::AbstractVector{PlayerType}, player::PlayerType, victim_team::Union{Symbol, Nothing}, new_robber_tile::Symbol, stolen_good::Union{Symbol,Nothing})
    BoardApi.move_robber!(board, new_robber_tile)
    for p in players
        if p.player.team == victim_team && stolen_good !== nothing
            PlayerApi.take_resource!(p.player, stolen_good)
            PlayerApi.give_resource!(player.player, stolen_good)
        end
    end
end

function get_admissible_theft_victims(board::Board, players::AbstractVector{PlayerPublicView}, thief::Player, new_tile)::Vector{PlayerPublicView}
    admissible_victims = []
    for c in [cc for cc in TILE_TO_COORDS[new_tile] if haskey(board.coord_to_building, cc)]
        team = board.coord_to_building[c].team
        victim = [p for p in players if p.team == team][1]

        if PlayerApi.has_any_resources(victim) && (team != thief.team)
            push!(admissible_victims, victim)
        end
    end
    return admissible_victims
end

function options_construct_city(board::Board, player::Player, candidates::Vector{Tuple{Int,Int}})
    for candidate in candidates
    end
end
function with_options(action::Function, candidates::Vector)
    actions = []
    for c in candidates
        return [action(c) for c in candidates]
    end
    return actions
end

function get_legal_actions(game, board, player::Player)::Set{PreAction}
    is_first_turn = game.turn_num == 1
    actions = Set{PreAction}([PreAction(:DoNothing)])

    admissible_cities = BoardApi.get_admissible_city_locations(board, player.team)
    if PlayerApi.has_enough_resources(player, COSTS[:City]) && length(admissible_cities) > 0
        push!(actions, PreAction(:ConstructCity, Vector{Tuple{Tuple{Int8,Int8}}}([(c,) for c in admissible_cities])))
    end

    admissible_settlements = BoardApi.get_admissible_settlement_locations(board, player.team, is_first_turn)
    resource_check = is_first_turn || PlayerApi.has_enough_resources(player, COSTS[:Settlement])
    if resource_check && length(admissible_settlements) > 0
        push!(actions, PreAction(:ConstructSettlement, Vector{Tuple}([(c,is_first_turn) for c in admissible_settlements])))
    end

    admissible_roads = BoardApi.get_admissible_road_locations(board, player.team, is_first_turn)
    resource_check = is_first_turn || PlayerApi.has_enough_resources(player, COSTS[:Road])
    if resource_check && length(admissible_roads) > 0
        push!(actions, PreAction(:ConstructRoad, Vector{Tuple}([(r...,!is_first_turn) for r in admissible_roads])))
    end

    if PlayerApi.has_enough_resources(player, COSTS[:DevelopmentCard]) && GameApi.can_draw_devcard(game)
        push!(actions, PreAction(:BuyDevCard))
    end
    if PlayerApi.can_play_devcard(player)
        push!(actions, PreAction(:PlayDevCard, PlayerApi.get_admissible_devcards(player)))
    end
    if PlayerApi.has_any_resources(player)
        push!(actions, PreAction(:ProposeTrade))
    end
    trade_args = Vector{Tuple}([])
    for from_resource = PlayerApi.resources_to_trade_with_bank(player)
        for to_resource in RESOURCES
            if from_resource == to_resource || !BoardApi.can_draw_resource(board, to_resource)
                continue
            end
            push!(trade_args, (from_resource, to_resource))
        end
    end
    if length(trade_args) > 0
        push!(actions, PreAction(:TradeWithBank, trade_args))
    end
    return actions
end

action_construct_city(g::Game, b::Board, p::PlayerType, coord, first_turn = false) = construct_city(b, p.player, coord)
action_construct_settlement(g::Game, b::Board, p::PlayerType, coord, first_turn) = construct_settlement(b, p.player, coord, first_turn)
action_construct_road(g::Game, b::Board, p::PlayerType, coord1, coord2, do_pay_cost) = construct_road(b, p.player, coord1, coord2, do_pay_cost)
action_buy_devcard(g::Game, b::Board, p::PlayerType) = draw_devcard(g, b, p.player)
action_play_devcard(g::Game, b::Board, p::PlayerType, card::Symbol) = do_play_devcard(b, g.players, p, card)
action_trade_with_bank(g::Game, b::Board, p::PlayerType, from_resource::Symbol, to_resource::Symbol) = do_trade_with_bank(b, p, from_resource, to_resource)
action_propose_trade_goods(g::Game, b::Board, p::PlayerType, rand_resource_from::Vector{Symbol}, rand_resource_to::Vector{Symbol}) = propose_trade_goods(b, g.players, p, rand_resource_from, rand_resource_to)
action_do_nothing(g::Game, b::Board, p::PlayerType) = Returns(nothing)

const ACTIONS_DICTIONARY = Dict(
    :ConstructCity => action_construct_city,
    :ConstructRoad => action_construct_road,
    :ConstructSettlement => action_construct_settlement,
    :BuyDevCard => action_buy_devcard,
    :PlayDevCard => action_play_devcard,
    :ProposeTrade => action_propose_trade_goods,
    :DoNothing => action_do_nothing,
    :TradeWithBank => action_trade_with_bank
   )
