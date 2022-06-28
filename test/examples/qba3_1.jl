@testset "Number Partitioning" begin

#=
Quote from [1]:

The Number Partitioning problem has numerous applications cited in the bibliography. A
common version of this problem involves partitioning a set of numbers into two subsets
such that the subset sums are as close to each other as possible.
=#

# :: Data ::
S = Int[25, 7, 13, 31, 42, 17, 21, 10]
m = 8

# :: Results ::
Q̄ = [ -3525   175   325   775  1050   425   525   250
        175 -1113    91   217   294   119   147    70
        325    91 -1989   403   546   221   273   130
        775   217   403 -4185  1302   527   651   310
       1050   294   546  1302 -5208   714   882   420
        425   119   221   527   714 -2533   357   170
        525   147   273   651   882   357 -3045   210
        250    70   130   310   420   170   210 -1560 ]

c̄ = 27_556

x̄ = [0, 0, 0, 1, 1, 0, 0, 1]
ȳ = -6889

# :: Model ::
model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[j = 1:m], Bin)
@objective(model, Min, sum(S[j] * (2x[j] - 1) for j = 1:m) ^ 2)

optimize!(model)

vqm = unsafe_backend(model)

# Here we may need some introspection tools!
_, Q, c = ToQUBO.PBO.qubo_normal_form(vqm)

x̂ = value.(x)
ŷ = objective_value(model)

# :: Reformulation ::
@test c == c̄
@test Q == 4Q̄

# :: Solution ::
@test x̂ == x̄
@test ŷ == 4ȳ + c̄

end