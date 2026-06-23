function _compiler_quadratization_binary_sets(vars::Vector{VI})
    sets = Vector{Set{VI}}()

    for mask = 0:(2^length(vars)-1)
        push!(
            sets,
            Set(vars[i] for i in eachindex(vars) if !iszero(mask & (1 << (i - 1)))),
        )
    end

    return sets
end

function _compiler_quadratization_value(f::PBO.AbstractPBF, true_vars::Set{VI})
    return convert(Float64, f(true_vars))
end

function test_compiler_quadratization_max_sense_high_order_objective()
    model = ToQUBO.Optimizer{Float64}()

    x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
    y = MOI.add_variable(model)
    MOI.add_constraint(model, y, MOI.Semiinteger(2.0, 4.0))

    f = MOI.ScalarQuadraticFunction{Float64}(
        [MOI.ScalarQuadraticTerm(2.0, x, y)],
        MOI.ScalarAffineTerm{Float64}[],
        0.0,
    )

    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)
    MOI.optimize!(model)

    compiled = MOI.get(model, Attributes.CompiledObjectiveFunction())
    hamiltonian = MOI.get(model, Attributes.CompiledHamiltonian())

    source_vars = vcat(
        only(MOI.get(model, Attributes.VariableTargetVariables(), x)),
        MOI.get(model, Attributes.VariableTargetVariables(), y),
    )
    target_vars = MOI.get(model.target_model, MOI.ListOfVariableIndices())
    aux_vars = setdiff(target_vars, source_vars)

    @test MOI.get(model.target_model, MOI.ObjectiveSense()) == MOI.MAX_SENSE
    @test PBO.degree(compiled) == 3
    @test PBO.degree(hamiltonian) == 2
    @test !isempty(aux_vars)

    for source_true in _compiler_quadratization_binary_sets(source_vars)
        expected = _compiler_quadratization_value(compiled, source_true)
        actual = maximum(
            _compiler_quadratization_value(hamiltonian, union(source_true, aux_true)) for
            aux_true in _compiler_quadratization_binary_sets(aux_vars)
        )

        @test actual ≈ expected
    end

    return nothing
end

function test_compiler_quadratization()
    @testset "→ Quadratization" begin
        test_compiler_quadratization_max_sense_high_order_objective()
    end

    return nothing
end
