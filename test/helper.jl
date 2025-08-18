global counter = 1
global base_dir = @__DIR__
using Test


Game(typed_players::Vector{T}, configs::Dict) where T <: RobotPlayer = Game(Vector{PlayerType}(typed_players), configs)

function reset_savefile_with_timestamp(name, configs)
    configs["SAVE_GAME_TO_FILE"] = true
    ~ispath("data") && mkdir("data")
    savefile = "data/_$(name)_$(Dates.format(now(), "yyyymmdd_HHMMSS"))_$counter.txt"
    configs["SAVE_FILE"] = savefile
    global counter += 1
    reset_savefile!(configs, savefile)
    return savefile, configs["SAVE_FILE_IO"]
end

function setup_players(player_configs)
    # Configure players and table configuration
    team_and_playertype = [
                          (:blue, DefaultRobotPlayer),
                          (:cyan, DefaultRobotPlayer),
                          (:green, DefaultRobotPlayer),
                          #(:red, DefaultRobotPlayer)
                          (:red, DefaultRobotPlayer)
    ]
    setup_players(team_and_playertype, player_configs)
end

function setup_players(team_and_playertype::Vector, player_configs::Dict)
    players = Vector{PlayerType}([player(team, player_configs) for (team,player) in team_and_playertype])
    return players
end

function setup_and_do_robot_game(configs::Dict{String, Any})
    players = setup_players(configs)
    setup_and_do_robot_game(players, configs)
end

function setup_and_do_robot_game(team_and_playertype::Vector, configs::Dict{String, Any})
    players = setup_players(team_and_playertype, configs)
    return setup_and_do_robot_game(players, configs)
end

"""
    setup_and_do_robot_game(players::Vector{PlayerType}, savefile::Union{Nothing, String} = nothing)

If no savefile is passed, we use the standard format "test_robot_game_savefile_yyyyMMdd_HHmmss.txt".
If a savefile is passed, we use it to save the game state.  If the file is nonempty, the game will replay
up until the end of the save file and then continue to write ongoing game states to the file.
"""
function setup_and_do_robot_game(players::Vector{PlayerType}, configs::Dict{String, Any})
    game = Game(players, configs)
    if (haskey(configs, "SAVE_FILE"))
        savefile, io = reset_savefile_with_timestamp("test_robot_game_savefile", configs)
    else
        reset_savefile!(configs)
    end
    board, winner = GameRunner.initialize_and_do_game!(game)
    return board, game
end

function test_automated_game(neverend, players, configs::Dict)
    if neverend
        while true
            # Play the game once
            try
                setup_and_do_robot_game(players)
            catch e
                Base.Filesystem.cp(configs["SAVE_FILE"], "$(@__DIR__)/data/last_save.txt", force=true)
            end

            # Then immediately try to replay the game from its save file
            println("replaying game from $(configs["SAVE_FILE"])")
            try
                setup_and_do_robot_game(players, configs["SAVE_FILE"])
            catch e
                Base.Filesystem.cp(configs["SAVE_FILE"], "$(@__DIR__)/data/last_save.txt", force=true)
            end

            # Now move the latest save file to a special `last_save` file for easy retrieval
        end
    else
        setup_and_do_robot_game(configs)
    end
end

function test_player_implementation(T::Type, configs) #where {T <: PlayerType}
    private_players = [
                       T(:Blue, configs)::PlayerType,
               DefaultRobotPlayer(:Cyan, configs),
               DefaultRobotPlayer(:Yellow, configs),
               DefaultRobotPlayer(:Red, configs)
              ]

    player = private_players[1]
    players = PlayerPublicView.(private_players)
    game = Game(private_players, configs)
    board = Board(configs)::Board
    from_player = players[2]
    #actions = Catan.ALL_ACTIONS
    actions = Set([PreAction(:BuyDevCard)])

    from_goods = [:Wood]
    to_goods = [:Grain]

    PlayerApi.give_resource!(player.player, :Grain)
    PlayerApi.give_resource!(player.player, :Grain)
    settlement_candidates = BoardApi.get_admissible_settlement_locations(board, player.player.team, true)
    devcards = Dict([:Knight => 2])
    PlayerApi.add_devcard!(player.player, :Knight)
    PlayerApi.add_devcard!(player.player, :Knight)
    #player.player.devcards = devcards

    choose_accept_trade(board, player, from_player, from_goods, to_goods)
    coord = choose_building_location(board, players, player, settlement_candidates, :Settlement, true)
    BoardApi.build_settlement!(board, player.player.team, coord)
    road_candidates = BoardApi.get_admissible_road_locations(board, player.player.team, true)

    PlayerApi.give_resource!(player.player, :Grain)
    PlayerApi.give_resource!(player.player, :Grain)
    PlayerApi.give_resource!(player.player, :Stone)
    PlayerApi.give_resource!(player.player, :Stone)
    PlayerApi.give_resource!(player.player, :Stone)
    choose_building_location(board, players, player, [coord], :City)

    PlayerApi.give_resource!(player.player, :Pasture)
    choose_one_resource_to_discard(board, players, player)
    choose_monopoly_resource(board, players, player)
    choose_next_action(board, players, player, actions)
    choose_place_robber(board, players, player, BoardApi.get_admissible_robber_tiles(board))
    
    PlayerApi.give_resource!(player.player, :Brick)
    PlayerApi.give_resource!(player.player, :Wood)
    choose_road_location(board, players, player, road_candidates, true)

    BoardApi.build_road!(board, player.player.team, road_candidates[1][1], road_candidates[1][1])
    road_candidates = BoardApi.get_admissible_road_locations(board, player.player.team, false)
    @test ~isempty(road_candidates)

    choose_robber_victim(board, player, players[2], players[3])
    choose_who_to_trade_with(board, player, players)
    choose_resource_to_draw(board, players, player)
    #get_legal_action_functions(board, players, player, actions)
end

function doset(ti)
    desc = ti.name
    if :broken in ti.tags || :skipactions in ti.tags
        return false
    end
    if length(ARGS) == 0
        return true
    end
    for a in ARGS
        if occursin(lowercase(a), lowercase(desc))
            return true
        end
    end
    return false
end
