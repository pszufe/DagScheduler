
using Random
using Revise
using DagScheduler

Random.seed!(123)
g, c, γ = generate_test_problem(K=7,p=0.35);

@time times, assignW, penalties, dfloads, execution_time = solve(g, c, γ);

push!(LOAD_PATH, joinpath(dirname(pathof(DagScheduler)), "..", "lib", "DagSchedulerViz"))
using DagSchedulerViz

plot_solution_report(g, c, γ, times, assignW, penalties, dfloads)
