module GameRunner
using ..Catan: Game, Board, PlayerType, Player, PlayerPublicView, PreAction, ChosenAction,
               read_map, load_gamestate!, initialize_player,
               do_first_turn_building!,
               decide_and_roll_dice!,choose_next_action, do_post_game_produce!,
               do_post_action_step, do_post_game_action, get_legal_actions,
               COORD_TO_TILES, COSTS, RESOURCES, generate_random_map, ACTIONS_DICTIONARY,
               action_construct_city, action_construct_settlement,
               action_construct_road, action_buy_devcard, action_play_devcard,
               action_propose_trade_goods, action_do_nothing

using ..Catan.BoardApi
using ..Catan.PlayerApi
using ..Catan.GameApi

function initialize_and_do_game!(game::Game)::Tuple{Board, Union{PlayerType, Nothing}}
    board = initialize_game!(game)
    winner = do_game(game, board)
    return board, winner
end

function initialize_and_do_game_async!(channels::Dict, game::Game)::Tuple{Board, Union{PlayerType, Nothing}}
    board = initialize_game!(game)
    winner = do_game_async(channels, game, board)
    return board, winner
end

function initialize_and_do_game_async!(channels::Dict, game::Game, board)::Tuple{Board, Union{PlayerType, Nothing}}
    board = initialize_game!(game, board)
    winner = do_game_async(channels, game, board)
    return board, winner
end

function initialize_game!(game::Game)
    board = read_map(game.configs)
    initialize_game!(game, board)
end

function initialize_game!(game::Game, board::Board)
    load_gamestate!(game, board)

    for p in game.players
        initialize_player(board, p)
    end
    return board
end

function do_game(game::Game, board::Board)::Union{PlayerType, Nothing}
    if game.turn_num == 1
        @info "Starting game $(game.unique_id) turn 0"
        do_first_turn(game, board, game.players)
    end

    do_rest_of_game!(game, board)

    winner = get_winner(game, board, game.players)

    # Post game steps (writing features, updating models, etc)
    do_post_game_action(game, board, game.players, winner);
    
    return winner
end


function do_game_async(channels::Dict, game::Game, board::Board)::Union{PlayerType, Nothing}
    if game.turn_num == 1
        @info "Starting game $(game.unique_id) turn 0"
        do_first_turn(game, board, game.players)
    end

    do_rest_of_game!(game, board)

    winner = get_winner(game, board, game.players)

    for player in game.players
        do_post_game_produce!(channels, game, board, game.players, player, winner)
    end

    # Post game steps (writing features, updating models, etc)
    #do_post_game_action(game, board, game.players, winner)
    #=
    if game.configs["ASYNC"]
        t = @task begin;
            do_post_game_action(game, board, game.players, winner);
        end
        schedule(t)
    else
        do_post_game_produce!(channels, game, board, game.players, winner);

        #do_post_game_action(game, board, game.players, winner);
    end
    =#
    return winner
end

function do_rest_of_game!(game, board)
    while ~someone_has_won(game, board, game.players)
        GameApi.start_turn(game)
        @info "Starting game $(game.unique_id) turn $(game.turn_num)"

        # We can't just use game.players since we need to handle re-loading from a game paused mid-turn
        for player in GameApi.get_players_to_play(game)
            do_turn(game, board, player)
        end
        GameApi.finish_turn(game)
        if game.configs["PRINT_BOARD"]
            BoardApi.print_board(board)
        end

        @info "turn num $(game.turn_num)"

        if game.turn_num >= game.configs["MAX_TURNS"]
            break
        end
    end
end

function do_first_turn(game::Game, board::Board, players)
    # Here we need to pass the whole game so we can modify the players list order in-place
    GameApi.do_set_turn_order(game) 
    if !game.first_turn_forward_finished
        do_first_turn_forward(game, board, players)
    end
    do_first_turn_reverse(game, board, players)
end
function do_first_turn_forward(game, board, players)
    @info "Doing first turn forward"
    for player in GameApi.get_players_to_play(game)
        do_first_turn_building!(game, board, players, player)
        GameApi.finish_player_turn(game, player.player.team)
    end
    GameApi.finish_turn(game)
end
function do_first_turn_reverse(game, board, players)
    @info "Doing first turn reverse"
    for player in reverse(GameApi.get_players_to_play(game))
        settlement = do_first_turn_building!(game, board, players, player)
        for tile in COORD_TO_TILES[settlement.coord]
            resource = board.tile_to_resource[tile]
            if resource != :Desert
                PlayerApi.give_resource!(player.player, resource)
                BoardApi.draw_resource!(board, resource)
            end
        end
        GameApi.finish_player_turn(game, player.player.team)
    end
    GameApi.finish_turn(game)
end

function do_action_from_legal_actions(game, board, player, legal_actions::Set{PreAction})::Bool
    @debug "actions for $player: $legal_actions"
    if length(legal_actions) == 0
        @info "no legal actions"
        return false
    end
    next_action = choose_next_action(board, PlayerPublicView.(game.players), player, legal_actions)::ChosenAction
    if next_action.name == :DoNothing
        do_post_action_step(board, player)
        return false
    end
    next_action_func! = ACTIONS_DICTIONARY[next_action.name]::Function
    #TODO Wrapped in one too many tuples
    @debug next_action
    next_action_func!(game, board, player, next_action.args...)
    do_post_action_step(board, player)
    return true
end

"""
    `do_turn(game::Game, board::Board, player::PlayerType)`

Called each turn except the first turn.  See `do_first_turn` for first turn behavior.
"""
function do_turn(game::Game, board::Board, player::PlayerType)

    # Player is only allowed to play a dev card before rolling the dice
    if PlayerApi.can_play_devcard(player.player)
        do_action_from_legal_actions(game, board, player, Set([PreAction(:PlayDevCard, PlayerApi.get_admissible_devcards(player.player))]))
    end

    decide_and_roll_dice!(game, board, player)
    
    actions = get_legal_actions(game, board, player.player)
    while do_action_from_legal_actions(game, board, player, actions)
        actions = get_legal_actions(game, board, player.player)
    end

    @debug "setting dice false"
    GameApi.set_dice_false(game)
    @debug "finishing player turn"
    GameApi.finish_player_turn(game, player.player.team)
end

function someone_has_won(game, board, players::AbstractVector{PlayerType})::Bool
    return get_winner(game, board, players) !== nothing
end

function get_winner(game, board, players::AbstractVector{PlayerType})::Union{Nothing,PlayerType}
    winner = nothing
    for player in players
        player_points = get_total_vp_count(board, player.player)
        if player_points >= game.configs["GameSettings"]["VICTORY_POINT_GOAL"]
            @debug "Winner: $player_points ($player)"
            if game.configs["PRINT_BOARD"]
                BoardApi.print_board(board)
            end
            print_player_stats(game, board, player.player)
            winner = player
        end
    end
    return winner
end

function print_player_stats(game, board, player::Player)
    public_points = BoardApi.get_public_vp_count(board, player.team)
    total_points = get_total_vp_count(board, player)
    @info "$(player) has $total_points points on turn $(game.turn_num) ($public_points points were public)"
    BoardApi.print_board_stats(board, player.team)
    if board.largest_army == player.team
        @info "Largest Army ($(player.devcards_used[:Knight]) knights)"
    end
    if board.longest_road == player.team
        @info "Longest road"
    end
    if PlayerApi.get_vp_count_from_devcards(player) > 0
        @info "$(PlayerApi.get_vp_count_from_devcards(player)) points from dev cards"
    end
    @debug player
end

function get_total_vp_count(board, player)
    return BoardApi.get_public_vp_count(board, player.team) + PlayerApi.get_vp_count_from_devcards(player)
end
end
