rm benchmark_catan_release.txt
cd ../CatanEngine.jl
git checkout v0.1.0
cd ../RunScripts
julia -e "include(\"run_without_learning.jl\"); benchmark_one_game(\"configs/benchmark_run.toml\", \"v0.1.0\")"
cd ../CatanEngine.jl
git checkout v0.2.0
cd ../RunScripts
julia -e "include(\"run_without_learning.jl\"); benchmark_one_game(\"configs/benchmark_run.toml\", \"v.0.2.0\")"
cd ../CatanEngine.jl
git checkout v0.3.0
cd ../RunScripts
julia -e "include(\"run_without_learning.jl\"); benchmark_one_game(\"configs/benchmark_run.toml\", \"v.0.3.0\")"
cd ../CatanEngine.jl
git checkout master
cd ../RunScripts
julia -e "include(\"run_without_learning.jl\"); benchmark_one_game(\"configs/benchmark_run.toml\", \"v.0.4.0\")"

cp run_without_learning.jl ../CatanEngine.jl/benchmarks/
cp configs/benchmark_run.toml ../CatanEngine.jl/benchmarks/
cp release_benchmark_catan.sh ../CatanEngine.jl/benchmarks/release_benchmark.sh
cp benchmark_catan_release.txt ../CatanEngine.jl/benchmarks/
