using Revise
using JuMP, ToQUBO

const TQA = ToQUBO.Attributes

const CEP = TQA.ConstraintEncodingPenalty

model = Model(() -> ToQUBO.Optimizer(nothing))

@variable(model, 0 <= x <= 5, Int)
@variable(model, 0 <= y <= 5, Int)

@objective(model, Max, x + y)

@constraint(model, c, x + y <= 7)

set_attribute(c, CEP(), 2.0)

optimize!(model)
