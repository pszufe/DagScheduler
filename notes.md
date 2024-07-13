
Discussion - planning Przemyslaw Szufel & Guillaume Dalle

Areas to work on:
1. Models for data transfer - note that there are clusters of similar transfer times $\gamma$. This homogeneity can greatly decrease the amount of experiments with estimating parameter values
2. Estimation execution and transfer times
   1. Bayesian?
   2. Different execution times
   3. Static code analysis?
3.  Execution time uncertainty vs DAG's stability

Hypothesis:

1. The gap between the longest critical-path (CP) and the 2nd longest CP is significant for some parameters which are typical for real-world problems.
   1. Should be shown via Monte-Carlo experiments
   2. Can this be proved for some specific cases?
2. The heuristic based on finding the CP in the first step can provide very good approximations for the optimal solution.
   1. Easy and natural reformulation the model to CSP
   2. Slack makes even imperfect solutions completely optimal
