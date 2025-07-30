# Human Player API

# Since we don't know which card the human took, we just give them the option to play anything
function get_admissible_devcards(player::HumanPlayer)
    return get_devcard_counts(player.player.configs)
end

function roll_dice(player::HumanPlayer)::Integer
    if get_player_config(player.player.configs, "USING_REAL_BOARD", player.player.team)
        Int8(parse_int(player.io, "Dice roll:", player.player.configs))
    else
        value = Int8(rand(1:6) + rand(1:6))
        @info "$(player) rolled a $value"
        return value
    end
end

function choose_one_resource_to_discard(board, players::AbstractVector{PlayerPublicView}, player::HumanPlayer)::Symbol
    isempty(player.player.resources) && throw(ArgumentError("Player has no resources"))
    if !get_player_config(player, "USING_REAL_BOARD")
        print_player_dashboard(player)
    end
    return parse_resources(player.io, "$(player) discards: ", player.player.configs)[1]
end


function choose_building_location(board::Board, players::AbstractVector{PlayerPublicView}, player::HumanPlayer, candidates::Vector{Tuple{TInt, TInt}}, building_type::Symbol, is_first_turn = false)::Tuple{TInt, TInt} where {TInt <: Integer}
    BoardApi.print_board(board)
    if building_type == :Settlement
        validation_check = BoardApi.is_valid_settlement_placement
    else
        validation_check = BoardApi.is_valid_city_placement
    end
    coord = nothing
    while (!validation_check(board, player.player.team, coord))
        coord = parse_ints(player.io, "$(player) places a $(building_type):", board.configs)
    end
    return coord
end

function choose_road_location(board::Board, players::AbstractVector{PlayerPublicView}, player::HumanPlayer, candidates::Vector{Tuple{Tuple{TInt, TInt}, Tuple{TInt, TInt}}}, do_pay_cost = true)::Union{Nothing,Tuple{Tuple{TInt, TInt}, Tuple{TInt, TInt}}} where {TInt <: Integer}
    road_coord1 = nothing
    road_coord2 = nothing
    road_coords = Vector{Tuple{Int,Int}}()
    while (!BoardApi.is_valid_road_placement(board, player.player.team, road_coord1, road_coord2))
        coords = parse_road_coord(player.io, "$(player) places a Road:", board.configs)
        if length(coords) == 4
            road_coords = [Tuple(coords[1:2]);Tuple(coords[3:4])]
        else
            road_coords = coords
        end
        @debug "road_coord: $road_coords"
        road_coord1 = road_coords[1]
        road_coord2 = road_coords[2]
    end
    @info road_coords
    return Tuple(road_coords)
end

function choose_place_robber(board::Board, players::AbstractVector{PlayerPublicView}, player::HumanPlayer, candidates::Vector{Symbol})::Symbol
    BoardApi.print_board(board)
    parse_tile(player.io, "$(player) places the Robber:", board.configs)
end

function choose_resource_to_draw(board, players, player::HumanPlayer)::Symbol
    parse_resources(player.io, "$(player) choose two resources for free:", board.configs)[1]
end

function choose_monopoly_resource(board, players, player::HumanPlayer)
    parse_resources(player.io, "$(player) will steal all:", board.configs)[1]
end
function choose_robber_victim(board, player::HumanPlayer, potential_victims::PlayerPublicView...)
    @info "$([p.team for p in potential_victims])"
    if length(potential_victims) == 1
        return potential_victims[1]
    end
    team = parse_teams(player.io, "$(player) chooses his victim among $(join([v.team for v in potential_victims],",")):", player.player.configs)
    return [p for p in potential_victims if p.team == team][1]
end
function choose_card_to_steal(player::HumanPlayer)::Symbol
    if get_player_config(player, "USING_REAL_BOARD")
        parse_resources(player.io, "$(player) lost his:", player.player.configs)[1]
    else
        unsafe_random_sample_one_resource(player.player.resources)
    end
end

function choose_next_action(board::Board, players::AbstractVector{PlayerPublicView}, player::HumanPlayer, actions::Set{PreAction})::ChosenAction
    BoardApi.print_board(board)
    print_player_dashboard(player)
    
    header = "What does $(player) do next?\n"
    full_options = string(header, join([ACTION_TO_DESCRIPTION[a.name] for a in actions], "\n"), "\n[quit] save and quit game")
    return parse_action(player.io, full_options, board.configs)
end

function steal_random_resource(from_player, to_player)
    stolen_good = choose_card_to_steal(from_player)
    input(stdin, "Press Enter when $((from_player isa HumanPlayer) ? from_player : to_player) is ready to see the message", from_player.player.configs)
    @info "$(to_player) stole $stolen_good from $(from_player)"
    input(stdin, "Press Enter again when you are ready to hide the message", from_player.player.configs)
    Base.run(`clear`)
    return stolen_good
end

function steal_random_resource(from_player::HumanPlayer, to_player::HumanPlayer)
    stolen_good = choose_card_to_steal(from_player)
    if ~isnothing(stolen_good)
        @info "$(to_player) stole something from $(from_player)"
    end
    return stolen_good
end

function choose_who_to_trade_with(board, player::HumanPlayer, players)
    parse_team(player.io, "$(join([p.team for p in players], ", ")) have accepted. Who do you choose?", board.configs)
end

function choose_accept_trade(board, player::HumanPlayer, from_player::PlayerPublicView, from_goods, to_goods)
    if ~get_player_config(player, "USING_REAL_BOARD")
        print_player_dashboard(player)
    end
    parse_yesno(player.io, "Does $(player) want to recieve $from_goods and give $to_goods to $(from_player) ?", board.configs)
end
