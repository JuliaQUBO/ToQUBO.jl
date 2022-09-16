# Prime Factoring

```@setup prime-factoring
using JuMP
using ToQUBO
```

```@example prime-factoring
P = 3
Q = 5
R = P * Q

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, 0 <= p <= P, Integer)
@variable(model, 0 <= q <= Q, Integer)

@objective(model, Min, (R - p * q) ^ 2)

optimize!(model)
```