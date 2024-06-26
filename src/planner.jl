

"""
     generate_test_problem(;K::Integer=10, p::Real = 3/K, W::Integer=3)

Generate a test problem for the planner

     * `K` - number of tasks
     * `p` - probability of a task being assigned to a worker
     * `W` - number of workers

Returns a `NamedTuple` with the following fields:

     * `g` - a DAG graph for task execution
     * `c` - a matrix with the times required to complete each task on each worker
     * `γ` - a dictionary describing for each edge (`Tuple` of vertices) penalties for moving between workers (a matrix of penalties).
"""
function generate_test_problem(;K::Integer=10, p::Real = 3/K, W::Integer=3)
     a = collect(UpperTriangular(rand(Binomial(1,p), K, K)))
     setindex!.(Ref(a), 0, 1:K, 1:K);
     g = SimpleDiGraph(a)
     c= zeros(Int, K, W) #times required to complete each task
     c[:,1] .= rand(1:7, K)
     if W > 1
          c[:,2:end] .= c[:,1] .+1
     end
     c[:, end] .+= 1
     γ0 = collect(Symmetric(rand(0.0:0.1:0.5, W, W)))
     setindex!.(Ref(γ0), 0, 1:W, 1:W);
     γ= Dict{Tuple{Int,Int}, typeof(γ0)}()
     for (i,j) in Tuple.(edges(g))
          γ[(i, j)] = deepcopy(γ0)
     end
     (;g, c, γ)
end


function solve(g::AbstractGraph, c::AbstractMatrix{<:Real}, γ::AbstractMatrix{<:Real};
     M::Real = ceil(Int,1.5*sum(maximum.(eachrow(c)))), Z::Real=10, rounding_digits::Integer=4)
     γ2= Dict{Tuple{Int,Int}, typeof(γ)}()
     for (i,j) in Tuple.(edges(g))
          γ2[(i, j)] = γ
     end
     solve(g, c, γ2; kwargs...)
end
"""
     solve(g::AbstractGraph, c::AbstractMatrix{<:Real}, γ::Union{AbstractMatrix{<:Real}, Dict{Tuple{Int,Int}, <:AbstractMatrix{<:Real}}}; M::Real = ceil(Int,1.5*sum(maximum.(eachrow(c)))), Z::Real=10, rounding_digits::Integer=4)

Finds the optimal assignment of tasks to workers in a directed acyclic graph.

Parameters:

     * `g` - a DAG graph for task execution
     * `c` - a matrix with the times required to complete each task on each worker
     * `γ` - a dictionary describing for each edge (`Tuple` of vertices) penalties for moving between workers (a matrix of penalties) or a dictionary of such matrices where keys are tuples of vertices
     * `M` - a large M number in the optimization model. Should be larger than the maximum possible execution time of the entire DAG
     * `Z` - a factor for the importance of the total execution time in the optimization model
     * `rounding_digits` - number of digits to round the results to (JuMP solver may return floating point numbers insteadq of integers so this is for display convenience)

Returns a `NamedTuple` with the following fields:
          * `times` - vector of start times of each task
          * `assignW` - worker assigned to each task
          * `penalties` - penalties for moving between workers
          * `dfloads` - a named tuple with the load of each worker
          * `execution_time` - total execution time of the DAG
"""
function solve(g::AbstractGraph, c::AbstractMatrix{<:Real}, γ::Dict{Tuple{Int,Int}, <:AbstractMatrix{<:Real}};
     M::Real = ceil(Int,1.5*sum(maximum.(eachrow(c)))), Z::Real=10, rounding_digits::Integer=4)

     K = nv(g)
     W = size(c,2)
     a = adjacency_matrix(g)
     @assert size(c,1) == K "Number of tasks must match the number of rows in c"
     @assert all(size.(values(γ),1) .== size.(values(γ),2) .== W) "γ needs to be defined for each pair of workers and for each pair of tasks"
     @assert all(all(γ0 .>= 0) for γ0 in values(γ)) "Penalties for moving between workers must be non-negative"
     @assert sum(sum.(diag.(values(γ)))) == 0 "Penalties not allowed within the same worker"
     @assert LinearAlgebra.istriu(a) && sum(diag(a))==0 "Adjacency matrix must be upper triangular with zeros on the diagonal"
     @assert is_directed(g) "The DAG graph must be directed"
     @assert !is_cyclic(g) "The DAG graph must be acyclic"

     a_kls =  Tuple.(edges(g))
     m = Model(HiGHS.Optimizer)
     JuMP.set_silent(m)

     @variable(m, t[1:K] >=0) #start time of each task
     @variable(m, t_last_end >=0) #end time of the last task


     @variable(m, s[1:K,1:W], Bin) # 1 if task k is assigned to worker w
     @variable(m, p[a_kls] >=0 ) #penalties for moving between workers


     @constraint(m, [k in 1:K], sum(s[k,:]) == 1) #each task is assigned to exactly one worker


     for (k,l) in a_kls
          for w1 in 1:W
               for w2 in 1:W
                    w1 == w2 && continue
                    #the task l occurs after k if the workers are different there is the penalty
                    @constraint(m, p[(k,l)] >= (s[k,w1] + s[l,w2]-1)*γ[(k,l)][w1,w2])
               end
          end

          @constraint(m, t[k] + c[k,:]'*s[k,:] + p[(k,l)]  <= t[l])
          # or an alternative way to write the constraint:
          # sum(p[(k,k2)] for k2 in outneighbors(g,k))
          # another option is tu use maximum instead of sum
     end
     for l in filter(n->outdegree(g,n)==0, vertices(g))
          @constraint(m, t[l] + c[l,:]'*s[l,:] <= t_last_end)
     end

     for l in 2:K
          for k in 1:(l-1)
               for w in 1:W
                    # if k and l share the same worker, the task l occurs after k
                    if !((k,l) ∈ a_kls)
                         @constraint(m, t[k] + c[k,:]'*s[k,:] <= t[l] + M*(2-s[k,w]-s[l,w]) )
                    end
               end
          end
     end
     @objective(m, Min, Z*t_last_end + sum(t) .+ sum(p))
     optimize!(m)

     times = round.(value.(t), digits=rounding_digits)
     assign = round.(Int,value.(s))
     penalties_vals = value.(p)
     # unpacking the penalties from a DenseAxisArray to a Dict
     p_keys = [keys(penalties_vals)[i][1] for i in 1:length(penalties_vals)]
     penalties = Dict(key => abs(round(penalties_vals[key],digits=5)) for key in p_keys)
     assignW = findfirst.(==(1), eachrow(assign))
     cs = [c[i, assignW[i]] for i in 1:length(assignW)]
     dfloads = (;i=1:nv(g), worker=assignW, t_start=times, t_end=times .+ cs )
     execution_time = round(value(t_last_end), digits=rounding_digits)
     (;times, assignW, penalties,dfloads,execution_time)
end
