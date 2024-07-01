
using Random
using Revise
using DagScheduler

Random.seed!(123);
g, c, γ = generate_test_problem(K=6,p=0.2,W=3);


@time times, assignW, penalties, dfloads, execution_time = solve(g, c, γ);
@show execution_time

# Requires a Gurobi license to run this code - is approximately 10x-20x faster than the default solver
#using Gurobi
#@time times, assignW, penalties, dfloads, execution_time = solve(g, c, γ;optimizer=Gurobi.Optimizer);
#@show execution_time

push!(LOAD_PATH, joinpath(dirname(pathof(DagScheduler)), "..", "lib", "DagSchedulerViz"))
using DagSchedulerViz

plot_solution_report(g, c, γ, times, assignW, penalties, dfloads)


using OperationsResearchModels
using Graphs
function solve_heuristic(g, c, γ)
    g2 = deepcopy(g)
    inns = filter(n -> indegree(g, n) == 0, vertices(g))
    outns = filter(n -> outdegree(g, n) == 0, vertices(g))
    add_vertex!(g2)
    for inn in inns
        add_edge!(g2, nv(g2), inn)
    end
    add_vertex!(g2)
    for outn in outns
        add_edge!(g2, outn, nv(g2))
    end

    ts = zeros(eltype(c), size(c,1))
    ws = zeros(Int, size(c,1))
    for inn in inns
        ts[inn] = argmin(c[inn,:])
    end


end

c