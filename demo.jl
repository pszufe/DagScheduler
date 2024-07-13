
using Random, Revise, DagScheduler, HiGHS

# using Gurobi

push!(LOAD_PATH, joinpath(dirname(pathof(DagScheduler)), "..", "lib", "DagSchedulerViz"))
using DagSchedulerViz


Random.seed!(123);
g, c, γ = generate_test_problem(K=8,p=0.4,W=3);


@time times, assignW, penalties, dfloads, execution_time = solve(g, c, γ;optimizer=HiGHS.Optimizer);

plot_solution_report(g, c, γ, times, assignW, penalties, dfloads)
