function test_compiler_variables_semiinteger()
    model = ToQUBO.Virtual.Model{Float64}()
    arch = ToQUBO.Compiler.GenericArchitecture()
    x = MOI.add_variable(model.source_model)
    s = MOI.Semiinteger{Float64}(2.0, 4.0)
    c = MOI.add_constraint(model.source_model, x, s)

    ToQUBO.Compiler.variables!(model, arch)

    v = model.source[x]
    y = ToQUBO.Virtual.target(v)

    @test ToQUBO.Virtual.encoding(v) isa Encoding.Semi
    @test ToQUBO.Virtual.encoding(v).e isa Encoding.Binary
    @test length(y) == 3
    @test ToQUBO.Virtual.expansion(v) == PBO.PBF{VI,Float64}(
        y[3] => 2.0,
        [y[1], y[3]] => 1.0,
        [y[2], y[3]] => 1.0,
    )
    @test isnothing(ToQUBO.Compiler.constraint(model, c, x, s, arch))
    @test MOI.get(model, Attributes.Quadratize()) === true

    return nothing
end

function test_compiler_variables_semicontinuous()
    model = ToQUBO.Virtual.Model{Float64}()
    arch = ToQUBO.Compiler.GenericArchitecture()
    x = MOI.add_variable(model.source_model)
    s = MOI.Semicontinuous{Float64}(1.0, 2.0)
    c = MOI.add_constraint(model.source_model, x, s)

    MOI.set(model, Attributes.VariableEncodingBits(), x, 2)

    ToQUBO.Compiler.variables!(model, arch)

    v = model.source[x]
    y = ToQUBO.Virtual.target(v)

    @test ToQUBO.Virtual.encoding(v) isa Encoding.Semi
    @test ToQUBO.Virtual.encoding(v).e isa Encoding.Binary
    @test length(y) == 3
    @test ToQUBO.Virtual.expansion(v) == PBO.PBF{VI,Float64}(
        y[3] => 1.0,
        [y[1], y[3]] => 1 / 3,
        [y[2], y[3]] => 2 / 3,
    )
    @test isnothing(ToQUBO.Compiler.constraint(model, c, x, s, arch))
    @test MOI.get(model, Attributes.Quadratize()) === true

    return nothing
end

function test_compiler_variables_value_set_onehot()
    model = ToQUBO.Virtual.Model{Float64}()
    arch = ToQUBO.Compiler.GenericArchitecture()
    x = MOI.add_variable(model.source_model)

    MOI.add_constraint(model.source_model, x, MOI.Integer())
    MOI.set(model, Attributes.VariableEncodingMethod(), x, Encoding.OneHot())
    MOI.set(model, Attributes.VariableEncodingSet(), x, [-1.0, 1.0, 3.0])

    ToQUBO.Compiler.variables!(model, arch)

    v = model.source[x]
    y = ToQUBO.Virtual.target(v)

    @test ToQUBO.Virtual.encoding(v) isa Encoding.OneHot
    @test length(y) == 3
    @test ToQUBO.Virtual.expansion(v) ==
          PBO.PBF{VI,Float64}(y[1] => -1.0, y[2] => 1.0, y[3] => 3.0)
    @test haskey(model.h, x) # exactly-one penalty registered

    return nothing
end

function test_compiler_variables_value_set_domain_wall()
    model = ToQUBO.Virtual.Model{Float64}()
    arch = ToQUBO.Compiler.GenericArchitecture()
    x = MOI.add_variable(model.source_model)

    MOI.add_constraint(model.source_model, x, MOI.Integer())
    MOI.set(model, Attributes.VariableEncodingMethod(), x, Encoding.DomainWall())
    MOI.set(model, Attributes.VariableEncodingSet(), x, [-1.0, 1.0, 3.0])

    ToQUBO.Compiler.variables!(model, arch)

    v = model.source[x]
    y = ToQUBO.Virtual.target(v)
    ξ = ToQUBO.Virtual.expansion(v)

    @test ToQUBO.Virtual.encoding(v) isa Encoding.DomainWall
    @test length(y) == 2
    # The three feasible wall states decode to the three set members.
    @test ξ(Dict{VI,Integer}(y[1] => 0, y[2] => 0))[nothing] ≈ -1.0
    @test ξ(Dict{VI,Integer}(y[1] => 1, y[2] => 0))[nothing] ≈ 1.0
    @test ξ(Dict{VI,Integer}(y[1] => 1, y[2] => 1))[nothing] ≈ 3.0
    @test haskey(model.h, x) # wall penalty registered

    return nothing
end

function test_compiler_variables_value_set_continuous()
    model = ToQUBO.Virtual.Model{Float64}()
    arch = ToQUBO.Compiler.GenericArchitecture()
    x = MOI.add_variable(model.source_model)
    γ = [0.1, 1.0, 10.0, 100.0] # non-uniform (log-spaced) grid

    MOI.set(model, Attributes.VariableEncodingMethod(), x, Encoding.OneHot())
    MOI.set(model, Attributes.VariableEncodingSet(), x, γ)

    ToQUBO.Compiler.variables!(model, arch)

    v = model.source[x]
    y = ToQUBO.Virtual.target(v)

    # Unbounded continuous variable: the set itself defines the domain.
    @test length(y) == 4
    @test ToQUBO.Virtual.expansion(v) ==
          PBO.PBF{VI,Float64}([y[i] => γ[i] for i in eachindex(γ)])

    return nothing
end

function test_compiler_variables_value_set_continuous_domain_wall()
    model = ToQUBO.Virtual.Model{Float64}()
    arch = ToQUBO.Compiler.GenericArchitecture()
    x = MOI.add_variable(model.source_model)
    γ = [0.1, 1.0, 10.0] # non-uniform grid through the wall encoding

    MOI.set(model, Attributes.VariableEncodingMethod(), x, Encoding.DomainWall())
    MOI.set(model, Attributes.VariableEncodingSet(), x, γ)

    ToQUBO.Compiler.variables!(model, arch)

    v = model.source[x]
    y = ToQUBO.Virtual.target(v)
    ξ = ToQUBO.Virtual.expansion(v)

    @test ToQUBO.Virtual.encoding(v) isa Encoding.DomainWall
    @test length(y) == 2
    @test ξ(Dict{VI,Integer}(y[1] => 0, y[2] => 0))[nothing] ≈ 0.1
    @test ξ(Dict{VI,Integer}(y[1] => 1, y[2] => 0))[nothing] ≈ 1.0
    @test ξ(Dict{VI,Integer}(y[1] => 1, y[2] => 1))[nothing] ≈ 10.0
    @test haskey(model.h, x)

    return nothing
end

function _value_set_error_model(γ; method = Encoding.OneHot(), integer = true, bounds = nothing)
    model = ToQUBO.Virtual.Model{Float64}()
    x = MOI.add_variable(model.source_model)

    integer && MOI.add_constraint(model.source_model, x, MOI.Integer())
    isnothing(bounds) ||
        MOI.add_constraint(model.source_model, x, MOI.Interval{Float64}(bounds...))
    isnothing(method) || MOI.set(model, Attributes.VariableEncodingMethod(), x, method)
    MOI.set(model, Attributes.VariableEncodingSet(), x, γ)

    return model
end

function test_compiler_variables_value_set_errors()
    arch = ToQUBO.Compiler.GenericArchitecture()

    # Interval-only encoding methods reject value sets, including the
    # Bounded wrapper around an interval method.
    for method in (
        nothing,
        Encoding.Unary(),
        Encoding.Arithmetic(),
        Encoding.Bounded(Encoding.Binary(), 2.0),
    )
        model = _value_set_error_model([-1.0, 1.0, 3.0]; method)

        @test_throws ToQUBO.Compiler.CompilationError ToQUBO.Compiler.variables!(
            model,
            arch,
        )
    end

    # Non-integer entries for an integer variable.
    let model = _value_set_error_model([-1.0, 0.5, 3.0])
        @test_throws ToQUBO.Compiler.CompilationError ToQUBO.Compiler.variables!(
            model,
            arch,
        )
    end

    # Entries outside declared bounds.
    let model = _value_set_error_model([-1.0, 1.0, 3.0]; bounds = (0.0, 2.0))
        @test_throws ToQUBO.Compiler.CompilationError ToQUBO.Compiler.variables!(
            model,
            arch,
        )
    end

    # Empty, non-finite, and duplicate sets.
    for γ in (Float64[], [1.0, NaN], [1.0, 1.0, 3.0])
        model = _value_set_error_model(γ)

        @test_throws ToQUBO.Compiler.CompilationError ToQUBO.Compiler.variables!(
            model,
            arch,
        )
    end

    # Binary variables do not accept value sets.
    let model = ToQUBO.Virtual.Model{Float64}()
        x = MOI.add_variable(model.source_model)

        MOI.add_constraint(model.source_model, x, MOI.ZeroOne())
        MOI.set(model, Attributes.VariableEncodingSet(), x, [0.0, 1.0])

        @test_throws ToQUBO.Compiler.CompilationError ToQUBO.Compiler.variables!(
            model,
            arch,
        )
    end

    return nothing
end

function test_compiler_variables_value_set_solve()
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x, Int)
    @objective(model, Min, x)

    set_attribute(x, Attributes.VariableEncodingMethod(), Encoding.OneHot())
    set_attribute(x, Attributes.VariableEncodingSet(), [-1.0, 1.0, 3.0])

    optimize!(model)

    @test objective_value(model) ≈ -1.0
    @test value(x) ≈ -1.0

    # Every encoding-feasible sample (exactly one hot bit) decodes to a
    # member of the set; encoding-violating states are penalized by χ and
    # decode outside it, which is inherent to one-hot encodings.
    backend = JuMP.unsafe_backend(model)
    y = ToQUBO.Virtual.target(backend.source[JuMP.index(x)])
    encoding_feasible = 0

    for i in 1:result_count(model)
        hot = sum(MOI.get(backend.optimizer, MOI.VariablePrimal(i), yj) for yj in y)

        if hot ≈ 1.0
            encoding_feasible += 1
            @test value(x; result = i) in [-1.0, 1.0, 3.0]
        end
    end

    @test encoding_feasible == 3 # one sample per set member

    return nothing
end

function test_compiler_variables()
    @testset "→ Variables" begin
        test_compiler_variables_semiinteger()
        test_compiler_variables_semicontinuous()
        test_compiler_variables_value_set_onehot()
        test_compiler_variables_value_set_domain_wall()
        test_compiler_variables_value_set_continuous()
        test_compiler_variables_value_set_continuous_domain_wall()
        test_compiler_variables_value_set_errors()
        test_compiler_variables_value_set_solve()
    end

    return nothing
end
