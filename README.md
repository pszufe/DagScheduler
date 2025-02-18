### DagScheduler

Involved people:
- Przemyslaw Szufel
- Julian Samaroo
- Guillaume Dalle


[Discussion - planning Przemyslaw Szufel & Guillaume Dalle](notes.md)


A WIP library for optimal planning of tasks in a directed acyclic graph (DAG) with dependencies.
The library takes into consideration heterogenous distributed environment, where tasks are executed on multiple workers. The library takes into consideration heterogenous data transfer times between workers and tasks.

Sample usage (see demo.jl for more details):
```julia
using DagScheduler, Random
Random.seed!(123)

g, c, γ = generate_test_problem(K=7,p=0.35);

times, assignW, penalties, dfloads, execution_time = solve(g, c, γ);

push!(LOAD_PATH, joinpath(dirname(pathof(DagScheduler)), "..", "lib", "DagSchedulerViz"))
using DagSchedulerViz

plot_solution_report(g, c, γ, times, assignW, penalties, dfloads)
```
![Sample DAG](demoim.png)


# Mathematical Formulation of the MILP Model for the DAG Scheduler

## Parameters:

- $` \gamma_{kl} \geq 0 `$: Penalties for moving between workers, applicable for task pairs $`(k, l)`$ (edges in the DAG).
- $` c_{kw} \geq 0 `$:  a matrix with the times required to complete task $` k `$ on worker $` w `$
- $` Z `$: a factor for the importance of the total execution time in the optimization model
- $` M `$: so called "big-M" - a large M number in the optimization model. Should be larger than the maximum possible execution time of the entire DAG
 
## Decision Variables:

- $` t_k \geq 0 `$: Start time of each task $k$, for $` k = 1, \ldots, K `$.
- $` t^{*} \geq 0 `$: End time of the last task.
- $` s_{kw} \in \{0,1\} `$: Binary variable that is 1 if task $` k `$ is assigned to worker $` w `$, for $` w = 1, \ldots, W `$.
- $` p_{kl} \geq 0 `$: Applied penalties for moving between workers, applicable for task pairs $`(k, l)`$ (edges in the DAG).
  
## Objective:

Minimize the following expression:
```math
\min Z \cdot t^{*} + \sum_{k=1}^K t_k + \sum_{(k,l) edges(g)} p_{kl}
```


## Constraints:

1. **Assignment Constraint:** Each task is assigned to exactly one worker:

```math
    \sum_{w=1}^W s_{kw} = 1, \quad \forall k = 1, \ldots, K
```

2. **Task Timing and Penalties:**

```math
    t_k + \sum_{w=1}^W c_{kw} s_{kw} + p_{kl} \leq t_l, \quad \forall (k, l) \in edges(g)
```
```math
    p_{kl} \geq (s_{kw_1} + s_{lw_2} - 1) \cdot \gamma^{(k,l)}_{w_1,w_2}, \quad \forall (k, l) \in edges(g), \forall w_1 \neq w_2
```


3. **Last Task Timing:**

```math
    t_l + \sum_{w=1}^W c_{lw} s_{lw} \leq t^{*}, \quad \forall l : \text{outdegree}(l) = 0
```

4. **Sequential Task Execution:** If tasks $` k `$ and $` l `$ share the same worker, the task $` l`$ occurs after task $` k `$:

```math
    t_k + \sum_{w=1}^W c_{kw} s_{kw} \leq t_l + M \cdot (2 - s_{kw} - s_{lw}), \quad \forall l > k
```
