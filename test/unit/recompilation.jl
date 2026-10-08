# Compare coefficients and expansions after naming bits by their owners. Internal
# MOI indices may change; stable compilation/quadratization makes the auxiliary
# roles reproducible for these small fixtures.
function _recompile_signature(model)
    roles = Dict{VI,String}()
    for x in sort!(collect(keys(model.source)); by = x -> x.value)
        for (i, y) in enumerate(ToQUBO.Virtual.target(model.source[x]))
            roles[y] = "source:$(x.value):$i"
        end
    end
    for c in sort!(collect(keys(model.slack)); by = c -> string(typeof(c), c.value))
        for (i, y) in enumerate(ToQUBO.Virtual.target(model.slack[c]))
            roles[y] = "slack:$(typeof(c)):$(c.value):$i"
        end
    end
    vars = MOI.get(model.target_model, MOI.ListOfVariableIndices())
    for (i, y) in enumerate(sort!(setdiff(vars, collect(keys(roles))); by = y -> y.value))
        roles[y] = "aux:$i"
    end
    canonical(f) = Dict(Tuple(sort!([roles[y] for y in term])) => c for (term, c) in f)
    return (;
        bits = length(vars),
        constraints = [
            (F, S, MOI.get(model.target_model, MOI.NumberOfConstraints{F,S}())) for
            (F, S) in MOI.get(model.target_model, MOI.ListOfConstraintTypesPresent())
        ],
        sense = MOI.get(model.target_model, MOI.ObjectiveSense()),
        objective = canonical(_target_objective_pbf(model)),
        source = Dict(
            x => canonical(ToQUBO.Virtual.expansion(v)) for (x, v) in model.source
        ),
        slack = Dict(c => canonical(ToQUBO.Virtual.expansion(v)) for (c, v) in model.slack),
        g = Dict(c => canonical(f) for (c, f) in model.g),
        h = Dict(x => canonical(f) for (x, f) in model.h),
        s = Dict(c => canonical(f) for (c, f) in model.s),
        penalties = (copy(model.ρ), copy(model.θ), copy(model.η)),
        owners = sort!(collect(values(roles))),
    )
end

function _recompile_binary(;
    sense = MOI.MAX_SENSE,
    coefficient = 3.0,
    hint = -0.1,
    solver = ExactSampler.Optimizer,
)
    model = ToQUBO.Optimizer(solver)
    MOI.set(model, Attributes.StableCompilation(), true)
    MOI.set(model, Attributes.StableQuadratization(), true)
    x = [first(MOI.add_constrained_variable(model, MOI.ZeroOne())) for _ = 1:2]
    f = MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(coefficient, v) for v in x], 5.0)
    _set_objective!(model, sense, f)
    c = MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(1.0, v) for v in x], 0.0),
        MOI.LessThan(1.0),
    )
    MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c, hint)
    return model, x, c
end

function _recompile_check_samples(model, x, coefficient)
    vars = MOI.get(model.target_model, MOI.ListOfVariableIndices())
    f = _target_objective_pbf(model)
    @test MOI.get(model, MOI.ResultCount()) > 0
    for result = 1:MOI.get(model, MOI.ResultCount())
        vp = MOI.VariablePrimal(result)
        bits = [MOI.get(model.optimizer, vp, y) for y in vars]
        @test all(b -> b in (0, 1), bits)
        decoded = [MOI.get(model, vp, v) for v in x]
        @test all(v -> v in (0, 1), decoded)
        @test ToQUBO.source_objective_value(model; result) ≈ 5 + coefficient * sum(decoded)
        @test MOI.get(model, MOI.ObjectiveValue(result)) ≈ sum(
            c * prod(MOI.get(model.optimizer, vp, y) for y in term; init = 1.0) for
            (term, c) in f;
            init = 0.0,
        )
        expected = sum(decoded) <= 1 ? MOI.FEASIBLE_POINT : MOI.INFEASIBLE_POINT
        @test MOI.get(model, MOI.PrimalStatus(result)) == expected
    end
end

function test_recompilation_repeated_slack()
    # Public #244 reproduction using a released local sampler, with four solves
    # to catch continuing accumulation rather than just a one-time cleanup.
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
    @variable(model, x[1:2], Bin)
    @objective(model, Max, 5 + 3x[1] + 3x[2])
    c = @constraint(model, x[1] + x[2] <= 1)
    set_attribute(c, Attributes.ConstraintEncodingPenaltyHint(), -0.1)
    fresh, _, _ = _recompile_binary()
    MOI.optimize!(fresh)
    for _ = 1:4
        optimize!(model)
        backend = JuMP.unsafe_backend(model)
        @test first(ToQUBO.qubo(model, :dict)) == 3
        @test _recompile_signature(backend) == _recompile_signature(fresh)
        @test value.(x) == [1, 1]
        @test ToQUBO.source_objective_value(model) ≈ 11
        @test objective_value(model) ≈ 10.9
        @test primal_status(model) == MOI.INFEASIBLE_POINT
    end
    MOIU.reset_optimizer(model)
    optimize!(model)
    @test first(ToQUBO.qubo(model, :dict)) == 3
end

function test_recompilation_changed_inputs()
    for sense in (MOI.MAX_SENSE, MOI.MIN_SENSE)
        sign = sense == MOI.MAX_SENSE ? 1.0 : -1.0
        model, x, c = _recompile_binary(; sense, coefficient = sign * 3, hint = -sign * 0.1)
        MOI.set(model, MOI.Silent(), true)
        MOI.set(model, Attributes.AutoFeasibilityReport(), true)
        MOI.optimize!(model)
        @test MOI.get(model, MOI.PrimalStatus()) == MOI.INFEASIBLE_POINT
        # Same dimensions, different coefficients and opposite feasibility.
        for (coefficient, hint) in ((sign * 2, -sign * 10), (sign * 4, -sign * 0.2))
            f = MOI.ScalarAffineFunction(
                [MOI.ScalarAffineTerm(coefficient, v) for v in x],
                5.0,
            )
            MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)
            MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c, hint)
            fresh, _, _ = _recompile_binary(; sense, coefficient, hint)
            MOI.optimize!(fresh)
            MOI.optimize!(model)
            @test _recompile_signature(model) == _recompile_signature(fresh)
            @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == hint
            @test MOI.get(model, MOI.Silent())
            @test MOI.get(model, Attributes.AutoFeasibilityReport())
            @test get(model.moi_settings, :feasibility_report, nothing) !== nothing
            _recompile_check_samples(model, x, coefficient)
        end
    end
end

function _recompile_integer(;
    method = Encoding.Binary(),
    values = [0.0, 1.0, 2.0],
    slack = Encoding.Binary(),
    solver = ExactSampler.Optimizer,
)
    model = ToQUBO.Optimizer(solver)
    MOI.set(model, Attributes.StableCompilation(), true)
    MOI.set(model, Attributes.StableQuadratization(), true)
    z = MOI.add_variable(model)
    MOI.add_constraint(model, z, MOI.Integer())
    MOI.add_constraint(model, z, MOI.Interval(0.0, 4.0))
    b, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
    MOI.set(model, Attributes.VariableEncodingMethod(), z, method)
    if method isa Union{Encoding.OneHot,Encoding.DomainWall}
        MOI.set(model, Attributes.VariableEncodingSet(), z, values)
    end
    f = MOI.ScalarAffineFunction(
        [MOI.ScalarAffineTerm(2.0, z), MOI.ScalarAffineTerm(1.0, b)],
        7.0,
    )
    _set_objective!(model, MOI.MAX_SENSE, f)
    c = MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction(
            [MOI.ScalarAffineTerm(1.0, z), MOI.ScalarAffineTerm(1.0, b)],
            0.0,
        ),
        MOI.LessThan(3.0),
    )
    MOI.set(model, Attributes.SlackVariableEncodingMethod(), c, slack)
    MOI.set(model, Attributes.ConstraintPenaltyScale(), c, 2.0)
    MOI.set(model, Attributes.VariableEncodingPenaltyHint(), z, -20.0)
    MOI.set(model, Attributes.SlackVariableEncodingPenaltyHint(), c, -30.0)
    return model, z, b, c
end

function test_recompilation_encodings()
    model, z, b, c = _recompile_integer()
    MOI.optimize!(model)
    dimensions = Int[]
    for (method, values, slack) in (
        (Encoding.Unary(), [0.0, 1.0, 2.0], Encoding.OneHot()),
        (Encoding.OneHot(), [0.0, 1.0, 4.0], Encoding.Binary()),
        # Same number of bits, different finite-value mapping.
        (Encoding.OneHot(), [0.0, 2.0, 4.0], Encoding.Binary()),
        (Encoding.DomainWall(), [0.0, 2.0, 4.0], Encoding.Unary()),
        (Encoding.Binary(), [0.0, 1.0, 2.0], Encoding.Binary()),
    )
        MOI.set(model, Attributes.VariableEncodingMethod(), z, method)
        MOI.set(
            model,
            Attributes.VariableEncodingSet(),
            z,
            method isa Union{Encoding.OneHot,Encoding.DomainWall} ? values : nothing,
        )
        MOI.set(model, Attributes.SlackVariableEncodingMethod(), c, slack)
        fresh, _, _, _ = _recompile_integer(; method, values, slack)
        MOI.optimize!(fresh)
        for _ = 1:3
            MOI.optimize!(model)
            @test _recompile_signature(model) == _recompile_signature(fresh)
            @test MOI.get(model, Attributes.VariableEncodingMethod(), z) == method
            @test MOI.get(model, Attributes.SlackVariableEncodingMethod(), c) == slack
            @test MOI.get(model, Attributes.ConstraintPenaltyScale(), c) == 2.0
            @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), z) == -20.0
            @test MOI.get(model, Attributes.SlackVariableEncodingPenaltyHint(), c) == -30.0
            zv, bv = MOI.get(model, MOI.VariablePrimal(), z),
            MOI.get(model, MOI.VariablePrimal(), b)
            @test zv in 0:4 && bv in (0, 1) && zv + bv <= 3
            @test ToQUBO.source_objective_value(model) ≈ 7 + 2zv + bv
            @test MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
        end
        push!(dimensions, MOI.get(model.target_model, MOI.NumberOfVariables()))
    end
    @test length(unique(dimensions)) > 1
end

function test_recompilation_auxiliary_and_no_solver()
    for sense in (MOI.MIN_SENSE, MOI.MAX_SENSE)
        function fixture()
            m = ToQUBO.Optimizer()
            MOI.set(m, Attributes.StableCompilation(), true)
            MOI.set(m, Attributes.StableQuadratization(), true)
            x, _ = MOI.add_constrained_variable(m, MOI.ZeroOne())
            y = MOI.add_variable(m)
            MOI.add_constraint(m, y, MOI.Semiinteger(2.0, 4.0))
            f = MOI.ScalarQuadraticFunction(
                [MOI.ScalarQuadraticTerm(2.0, x, y)],
                MOI.ScalarAffineTerm{Float64}[],
                5.0,
            )
            _set_objective!(m, sense, f)
            return m
        end
        model, fresh = fixture(), fixture()
        MOI.optimize!(fresh)
        for _ = 1:4
            MOI.optimize!(model)
            @test _recompile_signature(model) == _recompile_signature(fresh)
            @test any(v -> ToQUBO.Virtual.source(v) === nothing, model.variables)
            @test MOI.get(model, MOI.ResultCount()) == 0
            @test MOI.get(model, Attributes.CompilationStatus()) == MOI.LOCALLY_SOLVED
        end
    end
    # Fast-path cache must disappear when moving to a constrained compilation.
    model = ToQUBO.Optimizer()
    x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
    _set_objective!(
        model,
        MOI.MIN_SENSE,
        MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(1.0, x)], 2.0),
    )
    MOI.optimize!(model)
    @test model.qubo_backend_cache !== nothing
    MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(1.0, x)], 0.0),
        MOI.EqualTo(1.0),
    )
    MOI.optimize!(model)
    @test model.qubo_backend_cache === nothing
    @test _dense_qubo_data(model) ==
          _dense_qubo_data(QUBOTools.Model{Float64}(model.target_model))
end

function test_recompilation_refinement_persistence()
    for scaled in (false, true)
        model, x, c = _recompile_binary()
        if scaled
            MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c, nothing)
            MOI.set(model, Attributes.ConstraintPenaltyScale(), c, 0.01)
        end
        MOI.set(model, Attributes.MaxPenaltyUpdates(), 5)
        MOI.set(
            model,
            Attributes.PenaltyUpdateStrategy(),
            Attributes.MultiplicativeUpdate(10.0),
        )
        MOI.optimize!(model)
        @test MOI.get(model, Attributes.PenaltyUpdateCount()) == 2
        attr =
            scaled ? Attributes.ConstraintPenaltyScale() :
            Attributes.ConstraintEncodingPenaltyHint()
        final = MOI.get(model, attr, c)
        @test final ≈ (scaled ? 1.0 : -10.0)
        signature = _recompile_signature(model)
        for _ = 1:3
            MOI.optimize!(model)
            @test MOI.get(model, Attributes.PenaltyUpdateCount()) == 0
            @test MOI.get(model, attr, c) == final
            @test MOI.get(model, Attributes.MaxPenaltyUpdates()) == 5
            @test MOI.get(model, Attributes.PenaltyUpdateStrategy()).factor == 10.0
            @test _recompile_signature(model) == signature
            _recompile_check_samples(model, x, 3.0)
        end
    end
    model, _, c = _refinement_subgradient_model(; step = 0.4)
    optimize!(model)
    backend = JuMP.unsafe_backend(model)
    method = MOI.get(backend, Attributes.ConstraintEncodingMethod(), JuMP.index(c))
    for _ = 1:3
        optimize!(model)
        @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 0
        @test MOI.get(backend, Attributes.ConstraintEncodingMethod(), JuMP.index(c)) ==
              method
        @test primal_status(model) == MOI.FEASIBLE_POINT
    end
end

function test_recompilation_failure_recovery()
    model, x, c = _recompile_binary()
    MOI.optimize!(model)
    @test MOI.get(model, MOI.ResultCount()) > 0
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.INFEASIBLE_POINT
    ToQUBO.feasibility_report(model)
    @test haskey(model.moi_settings, :primal_feasibility)
    @test haskey(model.moi_settings, :feasibility_report)
    MOI.set(model, Attributes.ConstraintEncodingMethod(), c, Attributes.UnbalancedPenalty())
    MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c, nothing)
    @test_throws ToQUBO.Compiler.CompilationError MOI.optimize!(model)
    @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OTHER_ERROR
    @test MOI.get(model, MOI.ResultCount()) == 0
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.NO_SOLUTION
    @test_throws ErrorException MOI.get(model, MOI.ObjectiveValue())
    @test_throws ErrorException MOI.get(model, MOI.VariablePrimal(), first(x))
    @test !haskey(model.moi_settings, :primal_feasibility)
    @test !haskey(model.moi_settings, :feasibility_report)
    @test MOI.get(model, Attributes.CompilationTime()) === nothing
    @test MOI.get(model, Attributes.PenaltyUpdateCount()) === nothing
    MOI.set(model, Attributes.ConstraintEncodingMethod(), c, nothing)
    MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c, -0.1)
    MOI.optimize!(model)
    fresh, _, _ = _recompile_binary()
    MOI.optimize!(fresh)
    @test _recompile_signature(model) == _recompile_signature(fresh)
    _recompile_check_samples(model, x, 3.0)
    MOI.empty!(model)
    @test MOI.is_empty(model)
    @test MOI.get(model, MOI.ResultCount()) == 0
    MOI.copy_to(model, fresh.source_model)
    MOI.optimize!(model)
    @test MOI.get(model.target_model, MOI.NumberOfVariables()) == 3
end

function test_recompilation()
    @testset "→ Recompilation lifecycle" begin
        @testset "Repeated binary/slack" test_recompilation_repeated_slack()
        @testset "Changed coefficients/penalties" test_recompilation_changed_inputs()
        @testset "Changed encoding/mapping" test_recompilation_encodings()
        @testset "Auxiliaries/compiler only" test_recompilation_auxiliary_and_no_solver()
        @testset "Persistent refined settings" test_recompilation_refinement_persistence()
        @testset "Failed compilation/recovery/copy" test_recompilation_failure_recovery()
    end
end
