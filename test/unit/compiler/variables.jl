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

function test_compiler_variables()
    @testset "→ Variables" begin
        test_compiler_variables_semiinteger()
        test_compiler_variables_semicontinuous()
    end

    return nothing
end
