using Dates
using Logging
using TOML

function _initialize_configs()
    config_path = joinpath(@__DIR__, "..", "DefaultConfiguration.toml")
    configs = TOML.parsefile(config_path)::Dict{String, Any}
    out = _parse_configs(configs)
    @debug "Default configs loaded from $config_path"
    return out
end

function _upsert_configs!(new::Dict, old::Dict)
    for (k,v) in old
        if ~haskey(new, k)
            new[k] = v
        elseif v isa Dict
            _upsert_configs!(new[k], v)
        elseif v != new[k]
            @debug "updating config $k from $v -> $(new[k])"
        end
    end
end

function update_default_configs(new_path)
    global DEFAULT_CONFIGS = parse_configs(new_path, DEFAULT_CONFIGS)
end

parse_configs(config_path::String) = parse_configs(config_path, DEFAULT_CONFIGS)

function parse_configs(config_path::String, old::Dict)
    @info "Adding new configs: $config_path"
    configs = TOML.parsefile(config_path)::Dict{String, Any}
    _upsert_configs!(configs, old)
    out = _parse_configs(configs)
    @debug "More configs loaded from $config_path"
    return out
end

function _parse_configs(configs::Dict)
    parse_logging_configs!(configs["LogSettings"])
    reset_savefile!(configs)
    return configs
end

get_player_config(player::PlayerType, key) = get_player_config(player.player.configs, key, player.player.team)

"""
    get_player_config(configs, key, team_sym = nothing)

Retrieves the `key`, potentially overridden for this team.  This accessor method handles the fallback to a default
value set at the `configs["PlayerSettings"]` level, and custom player-level values set in `configs["PlayerSettings"][team]`.
"""
function get_player_config(configs, key, team_sym = nothing)
    player_config = configs["PlayerSettings"]
    team = team_sym === nothing ? nothing : String(team_sym)
    if team !== nothing && haskey(player_config, team) && haskey(player_config[team], key)
        return player_config[team][key]
    elseif haskey(player_config, key)
        return player_config[key]
    else
        @warn "PlayerSettings.$key has not been set "
        return nothing
    end
end

"""
    set_player_config(configs, team_sym, key, value)

Retrieves the `key`, potentially overridden for this team.  This accessor method handles the fallback to a default
value set at the `configs["PlayerSettings"]` level, and custom player-level values set in `configs["PlayerSettings"][team]`.
"""
function set_player_config(configs, team_sym, key, value)
    team = String(team_sym)
    player_config = configs["PlayerSettings"][team]
    player_config[key] = value
end

function make_logger(log_level::String, logger_output::String)
    make_logger(parse_log_level(log_level), logger_output)
end

function parse_log_level(log_level_str::String)
    if log_level_str == "Logging.Info" || log_level_str == "Info"
        log_level = Logging.Info
    elseif log_level_str == "Logging.Warn" || log_level_str == "Warn"
        log_level = Logging.Warn
    elseif log_level_str == "Logging.Debug" || log_level_str == "Debug"
        log_level = Logging.Debug
    else
        log_level = Logging.Info
    end
    return log_level
end

function make_logger(log_level::LogLevel, logger_output::String)
    logger_io = stderr
    if logger_output == "stderr"
        logger_io = stderr
        logger = ConsoleLogger(logger_io, log_level)

    elseif logger_output == "Null" || logger_output == ""
        logger_io = stderr
        logger = NullLogger()
        @warn "No more logging will take place, since NullLogger is set"
    else
        logger_io = open(logger_output, "w+")
        write(logger_io, "")
        close(logger_io)
        logger_io = open(logger_output, "w+")
        logger = SimpleLogger(logger_io, log_level)
    end
    return (logger,log_level,logger_io)
end

function parse_logging_configs!(log_configs::Dict)
    log_level_str = log_configs["LOG_LEVEL"]
    logger_output = log_configs["LOG_OUTPUT"]
    (logger,log_level,logger_io) = make_logger(log_level_str, logger_output)

    log_configs["LOG_LEVEL"] = log_level
    log_configs["LOGGER_IO"] = logger_io
    log_configs["LOGGER"] = logger
    global_logger(logger)
end

function reset_savefile!(configs::Dict, path, io)
    configs["SAVE_FILE"] = path
    configs["SAVE_FILE_IO"] = io
end

reset_savefile!(configs::Dict) = reset_savefile!(configs, joinpath(@__DIR__, "..", configs["SAVE_FILE"]))

function reset_savefile!(configs::Dict, path)
    configs["SAVE_FILE"] = path

    if configs["SAVE_GAME_TO_FILE"]
        io = open(path, "w"); write(io,""); close(io)
    end
    configs["SAVE_FILE_IO"] = open(path, "a")
    @debug "Savefile set to $path"
end

const VP_AWARDS = Dict([
                  :Settlement => 1,
                  :City => 2,
                  :Road => 0,
                  :LargestArmy => 2,
                  :LongestRoad => 2
                 ])

const HUMAN_ACTIONS = Dict(
    "bs" => :ConstructSettlement,
    "bc" => :ConstructCity,
    "br" => :ConstructRoad,
    "pt" => :ProposeTrade,
    "bd" => :BuyDevCard,
    "pd" => :PlayDevCard
   )
const ACTION_TO_DESCRIPTION = Dict(
    :ProposeTrade => "[pt] Propose trade (e.g. \"pt 2 w w g g\")",
    :ConstructCity => "[bc] Build city",
    :ConstructSettlement => "[bs] Build settlement",
    :ConstructRoad => "[br] Build road",
    :BuyDevCard => "[bd] Buy development card",
    :PlayDevCard => "[pd] Play development card"
   )


const COSTS = Dict([
              :Settlement => Dict([
                                   :Wood => 1,
                                   :Brick => 1,
                                   :Pasture => 1,
                                   :Grain => 1
                                  ]),
              :City => Dict([
                             :Grain => 2,
                             :Stone => 3
                            ]),
              :DevelopmentCard => Dict([
                                        :Pasture => 1,
                                        :Stone => 1,
                                        :Grain => 1
                                       ]),
              :Road => Dict([
                             :Brick => 1,
                             :Wood => 1
                            ])
             ])

const HUMAN_DEVCARD_TO_SYMBOL = Dict([
"K" => :Knight,
"M" => :Monopoly,
"Y" => :YearOfPlenty,
"R" => :RoadBuilding,
"V" => :VictoryPoint
])

function get_devcard_counts(configs)
    dc_configs = configs["GameSettings"]["DevCards"]
    return Dict([
                                :Knight => dc_configs["KNIGHT"],
                                :RoadBuilding => dc_configs["ROAD_BUILDING"],
                                :YearOfPlenty => dc_configs["YEAR_OF_PLENTY"],
                                :Monopoly => dc_configs["MONOPOLY"],
                                :VictoryPoint => dc_configs["VICTORY_POINT"]
                                ])
end

const HUMAN_RESOURCE_TO_SYMBOL = Dict([
"W" => :Wood,
"S" => :Stone,
"G" => :Grain,
"B" => :Brick,
"P" => :Pasture,
"D" => :Desert
])

const RESOURCES = Set([
                 :Wood,
                 :Stone,
                 :Grain,
                 :Brick,
                 :Pasture
                ])

const RESOURCE_TO_COUNT = Dict([
    :Wood => 4
    :Stone => 3
    :Grain => 4
    :Brick => 3
    :Pasture => 4
    :Desert => 1
   ]) 
const DICEVALUE_TO_COUNT = Dict([
    2 => 1
    3 => 2
    4 => 2
    5 => 2
    6 => 2
    7 => 1
    8 => 2
    9 => 2
    10 => 2
    11 => 2
    12 => 1
   ]) 

const COORD_TO_PORTNUM = Dict([
                         (1,1) => 1,
                         (1,2) => 1,
                         (1,4) => 2,
                         (1,5) => 2,
                         (2,8) => 3,
                         (2,9) => 3,
                         (3,11) => 4,
                         (3,12) => 4,
                         (5,8) => 5,
                         (5,9) => 5,
                         (6,4) => 6,
                         (6,5) => 6,
                         (6,1) => 7,
                         (6,2) => 7,
                         (4,1) => 8,
                         (4,2) => 8,
                         (3,2) => 9,
                         (2,1) => 9
                        ])
const TILE_TO_ISOLATED_EDGE_COORDS = Dict([
                      :A => Set([(1,1),(1,2)]),
                      :B => Set([(1,4)]),
                      :C => Set([(1,6),(1,7)]),
                      
                      :D => Set([(2,1)]),
                      :E => Set(),
                      :F => Set(),
                      :G => Set([(2,9)]),
                      
                      :H => Set([(3,1),(4,1)]),
                      :I => Set(),
                      :J => Set(),
                      :K => Set(),
                      :L => Set([(3,11),(4,11)]),
                      
                      :M => Set([(5,1)]),
                      :N => Set(),
                      :O => Set(),
                      :P => Set([(5,9)]),
                      
                      :Q => Set([(6,1),(6,2)]),
                      :R => Set([(6,4)]),
                      :S => Set([(6,6),(6,7)]),
                           ])
const TILE_TO_EDGE_COORDS = Dict(
                      :A => Set([(1,1),(1,2),(1,3),(2,2)]),
                      :B => Set([(1,3),(1,4),(1,5)]),
                      :C => Set([(1,5),(1,6),(1,7),(2,8)]),
                      
                      :D => Set([(2,1),(2,2),(3,2)]),
                      :E => Set(),
                      :F => Set(),
                      :G => Set([(2,8),(2,9),(3,10)]),
                      
                      :H => Set([(3,1),(3,2),(4,1),(4,2)]),
                      :I => Set(),
                      :J => Set(),
                      :K => Set(),
                      :L => Set([(3,10),(3,11),(4,10),(4,11)]),
                      
                      :M => Set([(5,1),(5,2),(4,2)]),
                      :N => Set(),
                      :O => Set(),
                      :P => Set([(5,8),(5,9),(4,10)]),
                      
                      :Q => Set([(6,1),(6,2),(6,3),(5,2)]),
                      :R => Set([(6,3),(6,4),(6,5)]),
                      :S => Set([(6,5),(6,6),(6,7),(5,8)]),
                     )
const TILE_TO_COORDS = Dict(
                      :A => Set([(1,1),(1,2),(1,3),(2,2),(2,3),(2,4)]),
                      :B => Set([(1,3),(1,4),(1,5),(2,4),(2,5),(2,6)]),
                      :C => Set([(1,5),(1,6),(1,7),(2,6),(2,7),(2,8)]),
                      
                      :D => Set([(2,1),(2,2),(2,3),(3,2),(3,3),(3,4)]),
                      :E => Set([(2,3),(2,4),(2,5),(3,4),(3,5),(3,6)]),
                      :F => Set([(2,5),(2,6),(2,7),(3,6),(3,7),(3,8)]),
                      :G => Set([(2,7),(2,8),(2,9),(3,8),(3,9),(3,10)]),
                      
                      :H => Set([(3,1),(3,2),(3,3),(4,1),(4,2),(4,3)]),
                      :I => Set([(3,3),(3,4),(3,5),(4,3),(4,4),(4,5)]),
                      :J => Set([(3,5),(3,6),(3,7),(4,5),(4,6),(4,7)]),
                      :K => Set([(3,7),(3,8),(3,9),(4,7),(4,8),(4,9)]),
                      :L => Set([(3,9),(3,10),(3,11),(4,9),(4,10),(4,11)]),
                      
                      :M => Set([(5,1),(5,2),(5,3),(4,2),(4,3),(4,4)]),
                      :N => Set([(5,3),(5,4),(5,5),(4,4),(4,5),(4,6)]),
                      :O => Set([(5,5),(5,6),(5,7),(4,6),(4,7),(4,8)]),
                      :P => Set([(5,7),(5,8),(5,9),(4,8),(4,9),(4,10)]),
                      
                      :Q => Set([(6,1),(6,2),(6,3),(5,2),(5,3),(5,4)]),
                      :R => Set([(6,3),(6,4),(6,5),(5,4),(5,5),(5,6)]),
                      :S => Set([(6,5),(6,6),(6,7),(5,6),(5,7),(5,8)]),
                     )
TILES = [t for t in keys(TILE_TO_COORDS)]
COORD_TO_TILES = Dict()
for elem in TILE_TO_COORDS
    # print("elem: ", elem, "\n")
    tile = elem[1]
    coords = elem[2]
    for c in coords
        if haskey(COORD_TO_TILES,c)
            push!(COORD_TO_TILES[c], tile)
        else
            COORD_TO_TILES[c] = Set([tile])
        end
    end
end


const DIMS = SVector{6, Int8}(7,9,11,11,9,7)
const DIMS_ROWS = length(DIMS)
const DIMS_COLS = maximum(DIMS)

const DICEVALUE_TO_PROBA_WEIGHT = Dict(
                                 2 => 1,
                                 12 => 1,
                                 3 => 2,
                                 11 => 2,
                                 4 => 3,
                                 10 => 3,
                                 5 => 4,
                                 9 => 4,
                                 6 => 5,
                                 8 => 5,
                                 7 => 0
                                )
