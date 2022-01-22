module Knapsack

import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

# Model definition
# References:
# [1] https://jump.dev/MathOptInterface.jl/stable/tutorials/example/

export model

model = MOIU.Model{Float64}()

n = 3;
c = [1.0, 2.0, 3.0]
w = [0.3, 0.5, 1.0] * 10.0
C = 3.2 * 10.0;

x = MOI.add_variables(model, n);

# ---------
# Objective
# ---------
MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)

MOI.set(
   model,
   MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
   MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(c, x), 0.0),
);

# -----------
# Constraints
# -----------
MOI.add_constraint(
   model,
   MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(w, x), 0.0),
   MOI.LessThan(C),
);

for xᵢ in x
   MOI.add_constraint(model, xᵢ, MOI.ZeroOne())
end

end # module