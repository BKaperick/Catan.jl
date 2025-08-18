function get_parsed_map_lines(map_str)
    [strip(line) for line in split(map_str,'\n') if !isempty(strip(line)) && strip(line)[1] != '#']
end

"""
    create_players(configs::Dict)::Vector{PlayerType}

Creates the vector of players that can be passed to `Game` constructor.
"""
function create_players(configs::Dict)::Vector{PlayerType}
    @debug "starting to read lines"
    players = []
    for name in configs["TEAMS"]
        config = configs["PlayerSettings"][name]
        if ~(config isa Dict)
            continue
        end
        playertype = config["TYPE"]
        name_sym = Symbol(name)
        @debug "Added player $name_sym of type $playertype"
        player = get_known_players()[playertype](name_sym, configs)
        push!(players, player)
    end
    return players
end

function read_channels_from_config(configs::Dict)::Dict{Symbol, Channel}
    channels = Dict{Symbol, Channel}()
    for name in configs["Async"]["CHANNELS"]
        c = Channel{Vector}(configs["Async"]["main"]["SIZE"])
        channels[Symbol(name)] = c
    end
    return channels
end

"""
    Board(configs::Dict)::Board

Handles three cases: LOAD_MAP from file if specified, write the map to SAVE_MAP if specified,
and if neither are set, then we just generate the map and keep in memory.
"""
function Board(configs::Dict)::Board
    load_path = configs["LOAD_MAP"]
    save_path = configs["SAVE_MAP"]
    if ~isempty(load_path)
        @info "Loading map from $load_path"
        map_str = read(load_path, String)
        if ~isempty(save_path) && abspath(save_path) != abspath(load_path)
            cp(load_path, save_path; force=true)
        end
    elseif ~isempty(save_path)
        @info "Generating random map to save in $save_path"
        generate_random_map(save_path)
        map_str = read(save_path, String)
        @info map_str
    else
        @info "Generating random map without saving it"
        map_str = generate_random_map()
    end
    return Board(map_str, configs)
end

function Map(map_str::AbstractString)::Map
    # Resource is a value W[ood],S[tone],G[rain],B[rick],P[asture]
    resourcestr_to_symbol = HUMAN_RESOURCE_TO_SYMBOL
    if length(map_str) == 0
        error("Empty map string: $map_str")
    end
    board_state = get_parsed_map_lines(map_str)
    if length(board_state) == 0
        error("Map string contains no uncommented lines: $map_str")
    end
    tile_to_dicevalue = Dict()
    tile_to_resource = Dict()
    desert_tile = :Null
    ports = Dict()
    for line in board_state
        if count(",", line) == 2
            tile_str,dice_str,resource_str = split(line,',')
            tile = Symbol(tile_str)
            resource = resourcestr_to_symbol[uppercase(resource_str)]
            dice = parse(Int8, dice_str)

            tile_to_dicevalue[tile] = dice
            tile_to_resource[tile] = resource
            if resource == :Desert
                desert_tile = tile
            end
        elseif count(",", line) == 1
            @debug line
            port,resource_str = split(line,',')
            portnum = parse(Int,port)
            ports[portnum] = resourcestr_to_symbol[uppercase(resource_str)]
        end
    end

    #dicevalue_to_tiles = Dict([v => SVector{2, Symbol}(:Empty, :Empty) for (k,v) in tile_to_dicevalue])
    dicevalue_to_tiles = Dict([v => [:Empty, :Empty] for (k,v) in tile_to_dicevalue])
    for (t,d) in tile_to_dicevalue
        if dicevalue_to_tiles[d][1] == :Empty
            dicevalue_to_tiles[d][1] = t
        elseif dicevalue_to_tiles[d][2] == :Empty
            dicevalue_to_tiles[d][2] = t
        else
            @assert false "This case shouldn't happen"
        end
    end
    
    coord_to_port = Dict()
    for (c,pnum) in COORD_TO_PORTNUM
        if haskey(ports, pnum)
            coord_to_port[c] = ports[pnum]
        else
            coord_to_port[c] = :All
        end
    end
    @debug dicevalue_to_tiles
    map = Map(tile_to_dicevalue, dicevalue_to_tiles, tile_to_resource, coord_to_port, desert_tile)

    @assert length(keys(map.tile_to_dicevalue)) == length(keys(TILE_TO_COORDS)) # 17
    t = sum(values(map.tile_to_dicevalue))
    @assert t == 133 "Sum of dice values is $(t) instead of 133"
    @assert length([r for r in values(map.tile_to_resource) if r == :Wood]) == RESOURCE_TO_COUNT[:Wood]
    @assert length([r for r in values(map.tile_to_resource) if r == :Stone]) == RESOURCE_TO_COUNT[:Stone]
    @assert length([r for r in values(map.tile_to_resource) if r == :Grain]) == RESOURCE_TO_COUNT[:Grain]
    @assert length([r for r in values(map.tile_to_resource) if r == :Brick]) == RESOURCE_TO_COUNT[:Brick]
    @assert length([r for r in values(map.tile_to_resource) if r == :Pasture]) == RESOURCE_TO_COUNT[:Pasture]
    @assert length([r for r in values(map.tile_to_resource) if r == :Desert]) == RESOURCE_TO_COUNT[:Desert]

    return map
end

"""
Generate a random board conforming to the game constraints set in constants.jl.
Save the generated map to `fname`.
"""
function generate_random_map(fname::String)::Nothing
    io = open(fname, "w")
    generate_random_map(io)
    close(io)
end

function generate_random_map(io::IO)::Nothing
    resource_bag = shuffle!(vcat([repeat([lowercase(string(r)[1])], c) for (r,c) in RESOURCE_TO_COUNT]...))
    dicevalue_bag = shuffle!(vcat([repeat([r], c) for (r,c) in DICEVALUE_TO_COUNT]...))

    # Force the Desert and the 7 to coincide
    desert_index = -1
    seven_index = -1
    for (i,r) in enumerate(resource_bag)
        if r == 'd'
            desert_index = i
        end
        if dicevalue_bag[i] == 7
            seven_index = i
        end
    end

    if desert_index != seven_index
        temp = resource_bag[seven_index]
        resource_bag[seven_index] = resource_bag[desert_index]
        resource_bag[desert_index] = temp
    end

    for (l,r,d) in zip("ABCDEFGHIJKLMNOPQRS", resource_bag, dicevalue_bag)
        write(io, "$l,$d,$r\n")
    end



    
    ports = shuffle(1:9)[1:5]
    resources = ["p","s","g","w","b"]
    for (p,r) in zip(ports,resources)
        write(io, "$(string(p)),$r\n")
    end
    return
end
function generate_random_map()::String
    io = IOBuffer()
    generate_random_map(io)
    map_str = String(take!(io))
    close(io)
    return map_str
end

stringify_arg(arg::Symbol)::AbstractString = ":$arg"
stringify_arg(arg::AbstractString)::AbstractString = "\"$arg\""
stringify_arg(arg) = replace(string(arg), " " => "")

function serialize_action(fname::String, args...)
    arg_strs = []
    for arg in args
        push!(arg_strs, stringify_arg(arg))
    end
    string("$fname ", join(arg_strs, " "))
end

"""
    log_action(configs::Dict, fname::String, args...)

Logs the action to the SAVE_FILE if `SAVE_GAME_TO_FILE` is true.
Otherwise, it is a no-op.
"""
function log_action(configs::Dict, fname::String, args...)::Nothing
    if configs["SAVE_GAME_TO_FILE"] == "" || !configs["SAVE_GAME_TO_FILE"]
        return
    end
    if configs["SERIALIZATION_STRATEGY"] == "JSON"
        log_action_json(configs["SAVE_FILE_IO"], fname, args)
    else
        log_action_text(configs["SAVE_FILE_IO"], fname, args)
    end
    return
end

function log_action(configs::Dict, api_type::Symbol, function_key::String, args...)::Nothing
    api_str = "$api_type"
    if api_type == :Board || api_type == :Game
        api_str = lowercase(string(api_type))
    end
    
    fname = "$api_str $function_key"
    log_action(configs, fname, args...)
end


function log_action_text(file_io::IO, fname::String, args)::Nothing
        serialized = serialize_action(fname, args...)
        outstring = string(serialized, "\n")
        @debug "outstring = $outstring"
        write(file_io, outstring)
        return
end

function log_action_json(file_io::IO, fname::String, args)::Nothing
    msg = Dict()
    api_name, func_name = split(fname, " ")
    msg["type"] = api_name
    msg["action"] = func_name
    msg["args"] = args
    @debug msg
    JSON.print(file_io, msg)
    println(file_io)
end

function read_action()
end

function execute_api_call_json(game::Game, board::Board, line::String)
    json = JSON.parse(line)::Dict
    func_key = json["action"]
    
    api_call = API_DICTIONARY[func_key]
    args = json["args"]

    execute_api_call(game, board, api_call, json["type"], [coerce_json_type(a) for a in args]...)
end

function coerce_json_type(arg)
    if arg isa AbstractArray
        return Tuple(arg)::Tuple{Integer, Integer}
    elseif arg isa Integer
        return Int8(arg)
    elseif arg isa String
        return Symbol(arg)
    else
        arg
    end

end

function execute_api_call_text(game::Game, board::Board, line::String)
    @debug "line = $line"
    values = split(line, " ")
    func_key = values[2]
    api_call = API_DICTIONARY[func_key]

    other_args = [eval(Meta.parse(a)) for a in values[3:end]]
    filter!(x -> x !== nothing, other_args)

    execute_api_call(game, board, api_call, values[1], other_args...)
end

function execute_api_call(game::Game, board::Board, api_call::Function, api_type::AbstractString, other_args...)
    # TODO initialize this globally somewhere?  Store in board?
    team_to_player = Dict([p.player.team => p.player for p in game.players])
    if api_type == "board"
        @debug "API: $api_call(board, $(other_args...))"
        api_call(board, other_args...)
    elseif api_type == "game"
        if length(other_args) > 0
            @info "API: $api_call(game, $(other_args...))"
            api_call(game, other_args...)
        else
            @debug "API: $api_call(game)"
            api_call(game)
        end
    else
        @debug "values[1] = $api_type"
        player = team_to_player[Symbol(api_type)]
        @debug "API: $api_call(player $(values[1]), $(other_args...))" 
        api_call(player, other_args...)
    end
end

function parse_and_execute_api_call(game, board, line)
    @info line
    if game.configs["SERIALIZATION_STRATEGY"] == "JSON"
        execute_api_call_json(game, board, line)
    else
        execute_api_call_text(game, board, line)
    end
end

function load_gamestate!(game, board)
    file = game.configs["SAVE_FILE"]
    if isfile(file) #~isdir(file)
        @info "Loading game from file $file"
        for line in readlines(file)
            parse_and_execute_api_call(game, board, line)
        end
    end
    if game.configs["PRINT_BOARD"]
        BoardApi.print_board(board)
    end
end

stop(text="Stop.") = throw(StopException(text))

struct StopException{T}
    S::T
end

function Base.showerror(io::IO, ex::StopException, bt; backtrace=true)
    Base.with_output_color(get(io, :color, false) ? :green : :nothing, io) do io
        showerror(io, ex.S)
    end
end
function print_winner(board, winner)
    team = winner.player.team
    println("winner: $(team)")
    println("------------")
    if board.longest_road == team
        println("\tlongest road (2)")
    end
    if board.largest_army == team
        println("\tlargest army (2)")
    end
    if haskey(winner.player.devcards, :VictoryPoint) && winner.player.devcards[:VictoryPoint] > 0
        println("\tvictory point devcards ($(winner.player.devcards[:VictoryPoint]))")
    end
    buildings = [b for b in board.buildings if b.team == team]
    settlements = [b for b in buildings if b.type == :Settlement]
    cities = [b for b in buildings if b.type == :City]
    println("\tsettlements ($(length(settlements)))")
    println("\tcities (2 ⋅$(length(cities)))")
end

"""
    do_post_game_action(game::Game, board::Board, players::AbstractVector{T}, player::T, 
    winner::Union{PlayerType, Nothing}) where T <: PlayerType

Perform any post-game actions while the full `Game` and `Board` states are in memory, and the 
`winner` has been defined.  Feature generation is one example.  See CatanLearning.jl for usage.
"""
function do_post_game_action(game::Game, board::Board, players::AbstractVector{T}, player::T, winner::Union{PlayerType, Nothing}) where T <: PlayerType
end

function do_post_game_produce!(channels::Dict{Symbol, Channel}, game::Game, board::Board, players::AbstractVector{PlayerType}, player::T, winner::Union{PlayerType, Nothing}) where T <: PlayerType
end

"""
    do_post_game_action(game::Game, board::Board, players::AbstractVector{T}, 
    winner::Union{PlayerType, Nothing}) where T <: PlayerType

Perform any post-game actions while the full `Game` and `Board` states are in memory, and the 
`winner` has been defined.  Feature generation is one example.  See CatanLearning.jl for usage.
"""
function do_post_game_action(game::Game, board::Board, players::AbstractVector{T}, winner::Union{PlayerType, Nothing}) where T <: PlayerType
    if winner isa PlayerType
        #print_winner(board, winner)
    end
    for player in players
        do_post_game_action(game, board, players, player, winner)
    end
end

"""
    save_parameters_after_game_end(file::IO, board::Board, players::AbstractVector{PlayerType}, player::PlayerType, winner_team::Symbol)

After the game, store or update parameters based on the end state
"""
function save_parameters_after_game_end(file::IO, board::Board, players::AbstractVector{PlayerType}, player::PlayerType, winner_team::Symbol)
end
