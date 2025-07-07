using Revise
using Random
using Catan
using Profile
using BenchmarkTools
using ProfileView
using PProf
using Base.Threads

function benchmark_one_game(config_file::String, descr::String)
    configs = Catan.parse_configs(config_file)
    output_file = configs["BENCHMARK_OUTPUT"]
    io = open(output_file, "a")
    #t = BenchmarkTools.run(@benchmarkable Catan.run($configs) seconds=60)
    #show(stdout, MIME"text/plain"(), t)
    #println("")

    benchmark_run(configs, io, descr, 60)
end

function benchmark_run(configs::Dict, io, descr, secs=10)
    Random.seed!(123)
    b = @benchmarkable Catan.run($configs) seconds=secs
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
