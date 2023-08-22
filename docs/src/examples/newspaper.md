
# Newspaper

## Risk Measures 

```@example newspaper
using Distributions, Random
using JuMP
using PySA
using ToQUBO
```

## Parameters
```@example newspaper
q           = 40;                       # Newspaper Selling Price
c           = 25;                       # Newspaper Cost
r           = 15;                       # Newspaper Re-Selling Price
u           = 300;                      # Buying Capacity

Rmin        = -1000;                    # Risk Budget

flagVaR     = 1;                        # Allow VaR Constraints
flagCVaR    = 0;                        # Allow CVaR Constraints

α           = 0.95;                     # Confidence Level
M           = 1e6;                      # Large Number - VaR
```

## Sampling Process
```@example newspaper
nCenarios = 5;                      # Number of Scenarios
Ω = 1:nCenarios;                    # Set of Scenarios
p = ones(nCenarios)*(1/nCenarios);  # Equal Probability

dmin = 100;
dmax = 300;
```

# ===================================
#      =====> Using Julia <=====     
# ===================================

# -> https://juliastats.org/Distributions.jl/stable/ <- #

Random.seed!(1);
d  = rand(Uniform(dmin, dmax), nCenarios);

# ============================================================================ #

# ============================================================================ #
# =======================     Problema Amostral     ========================== #
# ============================================================================ #

m = Model(GLPK.Optimizer);
#m = Model(Gurobi.Optimizer);
# #m = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer));
# m = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer));
MM = 2000;
#MOI.set(m, DefaultVariableEncodingATol(), 1e-3);

# ========== Variáveis de Decisão ========== #

@variable(m, 0 <= x <= u, Int);
#@variable(m, y[Ω] >= 0);
#@variable(m, z[Ω] >= 0);
#@variable(m, R[Ω]);

@variable(m, 0 ≤ y[Ω] ≤ MM);
@variable(m, 0 ≤ z[Ω] ≤ MM);
@variable(m, -MM ≤ R[Ω] ≤ MM);

# ========== Restrições ========== #

@constraint(m, Rest1[ω in Ω], R[ω] == q*y[ω] + r*z[ω] - c*x);
@constraint(m, Rest2[ω in Ω], y[ω] <= d[ω]);
@constraint(m, Rest3[ω in Ω], y[ω] + z[ω] <= x);

# ========== VaR Constraints ========== #

if (flagVaR == 1)

    @variable(m, η[Ω], Bin)
    #@variable(m, z_VaR);
    @variable(m, -MM ≤ z_VaR ≤ MM);

    @constraint(m, Rest4, sum(η[ω]*p[ω] for ω in Ω) >= α);
    @constraint(m, Rest5[ω in Ω], R[ω] >= z_VaR - M*(1 - η[ω]));
    @constraint(m, Rest6, z_VaR >= -Rmin);

end;

# ========== CVaR Constraints ========== #

if (flagCVaR == 1)

    @variable(m, z_CVaR);
    @variable(m, β[Ω] >= 0);
    
    @constraint(m, Rest7, z_CVaR - sum(p[ω]*β[ω] for ω in Ω)/(1-α) >= -Rmin);
    @constraint(m, Rest8[ω in Ω], β[ω] >= z_CVaR - R[ω]);

end;

# ========== Função Objetivo ========== #

@objective(m, Max, sum(R[ω]*p[ω] for ω in Ω));

optimize!(m);

status      = termination_status(m);

ExpRevenue  = JuMP.objective_value(m);

ROpt        = JuMP.value.(R);
xOpt        = JuMP.value.(x);

ROrd        = sort!(ROpt[:]);
nStar       = Int(floor((1 - α)*nCenarios));

println(" ===================================== \n")

println(" Newspaper - Buy:           ", xOpt);
println(" Expected Revenue:          ", ExpRevenue, "\n");
println(" Value at Risk:             ", -ROrd[nStar + 1]);
println(" Conditional Value at Risk: ", -mean(ROrd[nStar]));

println(" ===================================== \n")
