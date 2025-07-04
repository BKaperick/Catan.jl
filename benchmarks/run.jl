using Revise
using Catan
using CatanLearning
using Profile
using BenchmarkTools
using ProfileView
using PProf
using Base.Threads

function retrain_models(config_file)
    configs = Catan.parse_configs(config_file)
    player_configs = configs["PlayerSettings"]
    iter = 1
    CatanLearning.train_and_serialize_model(player_configs["FEATURES"], player_configs["MODEL"], num_tuning_iterations = 30)
    CatanLearning.train_and_serialize_model(player_configs["PUBLIC_FEATURES"], player_configs["PUBLIC_MODEL"], num_tuning_iterations = 30)
    cp(player_configs["PUBLIC_MODEL"], "../CatanLearning.jl/test/data/public_model.jls", force=true)
    cp(player_configs["MODEL"], "../CatanLearning.jl/test/data/model.jls", force=true)
end

function run(args::Tuple)
    if length(args) == 1
        run(args[1])
    else
        run(args[1], args[2])
    end
end

"""
    `run(config_file::String, file_suffix)`

A bit of a hack.  For parallel runs of fature generation, to stop locking issues, we pass a 
random number to CLI via bash script so each worker is writing to a different file.
"""
function run(config_file::String, file_suffix)
    configs = Catan.parse_configs(config_file)
    configs["PlayerSettings"]["FEATURES"] = replace(configs["PlayerSettings"]["FEATURES"], ".csv" => "_$file_suffix.csv")
    configs["PlayerSettings"]["PUBLIC_FEATURES"] = replace(configs["PlayerSettings"]["PUBLIC_FEATURES"], ".csv" => "_$file_suffix.csv")
    CatanLearning.run_tournament(configs)
end

function run_tournament(config_file::String)
    configs = Catan.parse_configs(config_file)
    CatanLearning.run_tournament(configs)
end

function run_state_space_tournament(config_file::String)
    configs = Catan.parse_configs(config_file)
    CatanLearning.run_state_space_tournament(configs)
end

function run_tournament_async(config_file::String)
    configs = Catan.parse_configs(config_file)
    CatanLearning.run_tournament_async(configs)
end

function run_benchmark_async(config_file::String)
    configs = Catan.parse_configs(config_file)
    touch(configs["BENCHMARK_OUTPUT"])
    io = open(configs["BENCHMARK_OUTPUT"], "a")
    b = @benchmarkable CatanLearning.run_tournament_async($configs) seconds=60
    t = BenchmarkTools.run(b)
    println("\nnum threads $(Threads.nthreads()) - channel size 64")
    show(stdout, MIME"text/plain"(), t)
    print(io, "\n\nnum threads $(Threads.nthreads()) - channel size 64\n")
    show(io, MIME"text/plain"(), t)
end



function run_async_benchmark(config_file::String)
    configs = Catan.parse_configs(config_file)
    
    b = @benchmarkable CatanLearning.run_tournament_async($configs) seconds=30
    t = BenchmarkTools.run(b)

    # Print to REPL
    show(stdout, MIME"text/plain"(), t)
    println("")

    # Save to IO
    #println(io, descr)
    #show(io, MIME"text/plain"(), t)
    #print(io, "\n\n")

    #return t

end

function profile_simple_run(config_file)

    # Setup and run first turn before profiling starts
    configs = Catan.parse_configs(config_file)
    players = Catan.create_players(configs)
    game = Game(players, configs)
    board = GameRunner.initialize_game!(game)
    GameRunner.do_first_turn(game, board, game.players)

    @profile GameRunner.do_rest_of_game!(game, board)
    open("./tmp/prof.txt", "w") do s
        Profile.print(IOContext(s, :displaysize => (24, 500)), sortedby=:count, mincount=40)
    end
end

function memory_loop_run(config_file)
    configs = Catan.parse_configs(config_file)
    Catan.run(configs)
    allocs = Vector{Int64}(undef, 5)
    for i=1:5
        t = @ballocated Catan.run($configs) seconds=10
        #b = @benchmarkable Catan.run($configs) seconds=10
        #t = BenchmarkTools.run(b)
        allocs[i] = t

        # Print to REPL
        show(stdout, MIME"text/plain"(), t)
        println("")
    end
    
    output_file = configs["BENCHMARK_OUTPUT"]
    io = open(output_file, "w")
    print(io, mean(allocs))
    close(io)
end

function memory_profile_run(config_file)
    configs = Catan.parse_configs(config_file)
    #@profview Catan.run(configs)
    Catan.run(configs)
    Profile.Allocs.clear()
    Profile.Allocs.@profile sample_rate=.1 Catan.run(configs)
    #Profile.Allocs.@profile sample_rate=1 Catan.run(configs)
    PProf.Allocs.pprof(from_c=false)
end

function time_profile_run(config_file)
    configs = Catan.parse_configs(config_file)
    #@profview Catan.run(configs)
    Catan.run(configs)
    Profile.clear()
    @profile Catan.run(configs)
    pprof(from_c=true)
end

function memory_profile_run_async(config_file)
    configs = Catan.parse_configs(config_file)
    #@profview Catan.run(configs)
    Profile.Allocs.clear()
    CatanLearning.run_tournament_async(configs)
    #Catan.run(configs)
    Profile.Allocs.@profile sample_rate=1 CatanLearning.run_tournament_async(configs)
    PProf.Allocs.pprof(from_c=false)
end

function time_profile_run_async(config_file)
    configs = Catan.parse_configs(config_file)
    
    CatanLearning.run_tournament_async(configs)
    Profile.clear()
    
    @profile CatanLearning.run_tournament_async(configs)
    pprof(from_c=true)
end

function run_one(config_file)
    configs = Catan.parse_configs(config_file)
    Catan.run(configs)
end

function run_one_async(config_file)
    configs = Catan.parse_configs(config_file)
    Catan.run_async(configs)
end

function profile_run(config_file)
    configs = Catan.parse_configs(config_file)
    #@profview Catan.run(configs)
    @profile Catan.run(configs)
    open("./tmp/prof.txt", "w") do s
        Profile.print(IOContext(s, :displaysize => (24, 500)), sortedby=:count, mincount=100)
    end
    #=
    =#
end

function benchmark_dry_run(config_file::String)
    configs = Catan.parse_configs(config_file)
    configs["PlayerSettings"]["blue"]["TYPE"] = "EmpathRobotPlayer"
    configs["PlayerSettings"]["blue"]["SEARCH_DEPTH"] = 1
    configs["LOG_OUTPUT"] = "stderr"
    configs["LOG_LEVEL"] = "Info"
    Catan.parse_logging_configs!(configs)
    Catan.run(configs)
end

function benchmark_one_tournament(config_file::String, descr::String)
    configs = Catan.parse_configs(config_file)
    output_file = configs["BENCHMARK_OUTPUT"]
    io = open(output_file, "a")
    benchmark_run(configs, io, descr, 60)
    close(io)
end

function benchmark_run(config_file::String)
    trials = []
    configs = Catan.parse_configs(config_file)
    output_file = configs["BENCHMARK_OUTPUT"]
    io = open(output_file, "w")
    
    push!(trials, benchmark_run(configs, io, "4 DefaultRobotPlayers - $(configs["MAX_TURNS"]) turns - no saving or logging"))

    configs["MAX_TURNS"] = 20
    push!(trials, benchmark_run(configs, io, "4 DefaultRobotPlayers - $(configs["MAX_TURNS"]) turns - no saving or logging"))

    configs["MAX_TURNS"] = 30
    push!(trials, benchmark_run(configs, io, "4 DefaultRobotPlayers - $(configs["MAX_TURNS"]) turns - no saving or logging"))

    configs["MAX_TURNS"] = 40
    push!(trials, benchmark_run(configs, io, "4 DefaultRobotPlayers - $(configs["MAX_TURNS"]) turns - no saving or logging"))
    #=    
    configs["MAX_TURNS"] = 10
    configs["PlayerSettings"]["blue"]["TYPE"] = "EmpathRobotPlayer"
    configs["PlayerSettings"]["blue"]["SEARCH_DEPTH"] = 1
    push!(trials, benchmark_run(configs, io, "1 EmpathRobotPlayer(SEARCH_DEPTH=1) - $(configs["MAX_TURNS"]) turns - no saving or logging"))
    
    configs["MAX_TURNS"] = 20
    push!(trials, benchmark_run(configs, io, "1 EmpathRobotPlayer(SEARCH_DEPTH=1) - $(configs["MAX_TURNS"]) turns - no saving or logging"))
    
    configs["MAX_TURNS"] = 30
    push!(trials, benchmark_run(configs, io, "1 EmpathRobotPlayer(SEARCH_DEPTH=1) - $(configs["MAX_TURNS"]) turns - no saving or logging"))
    =#

    close(io)
    return trials
end

function benchmark_run(configs::Dict, io, descr, secs=10)
    b = @benchmarkable CatanLearning.run_tournament($configs) seconds=secs
    t = BenchmarkTools.run(b)

    # Print to REPL
    show(stdout, MIME"text/plain"(), t)
    println("")

    # Save to IO
    println(io, descr)
    show(io, MIME"text/plain"(), t)
    print(io, "\n\n")

    return t
end

if ~isinteractive() && length(ARGS) > 0
    run(ARGS...)
end
