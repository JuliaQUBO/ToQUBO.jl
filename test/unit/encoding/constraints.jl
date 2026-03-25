function _target_var(model::ToQUBO.Virtual.Model{Float64}, x::VI)
    return only(ToQUBO.Virtual.target(model.source[x]))
end

function _minimum_penalty(g::PBO.PBF{VI,Float64}, fixed::Dict{VI,Int})
    vars = [x for x in PBO.variables(g) if !haskey(fixed, x)]
    best = Inf

    for mask in 0:(2^length(vars) - 1)
        assignment = copy(fixed)

        for (i, x) in enumerate(vars)
            assignment[x] = (mask >> (i - 1)) & 1
        end

        best = min(best, convert(Float64, g(assignment)))
    end

    return best
end

function test_constraint_encoding_methods()
    @testset "→ Constraints" begin
        @testset "Scalar Affine Equality" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                arch = ToQUBO.Compiler.GenericArchitecture()

                # Add binary variables
                vi1, _ = MOI.add_constrained_variable(model.source_model, MOI.ZeroOne())
                vi2, _ = MOI.add_constrained_variable(model.source_model, MOI.ZeroOne())
                vi3, _ = MOI.add_constrained_variable(model.source_model, MOI.ZeroOne())

                ToQUBO.Compiler.variables!(model, arch)

                # Constraint: x1 + x2 + x3 = 2
                f = MOI.ScalarAffineFunction{Float64}(
                    [
                        MOI.ScalarAffineTerm(1.0, vi1),
                        MOI.ScalarAffineTerm(1.0, vi2),
                        MOI.ScalarAffineTerm(1.0, vi3),
                    ],
                    0.0
                )
                s = MOI.EqualTo{Float64}(2.0)
                ci = MOI.add_constraint(model.source_model, f, s)

                g = ToQUBO.Compiler.constraint(model, ci, f, s, arch)

                @test g isa PBO.PBF{VI,Float64}
                @test _minimum_penalty(
                    g,
                    Dict(
                        _target_var(model, vi1) => 1,
                        _target_var(model, vi2) => 1,
                        _target_var(model, vi3) => 0,
                    ),
                ) == 0.0
                @test _minimum_penalty(
                    g,
                    Dict(
                        _target_var(model, vi1) => 1,
                        _target_var(model, vi2) => 0,
                        _target_var(model, vi3) => 0,
                    ),
                ) > 0.0
            end
        end

        @testset "Scalar Affine Less Than" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                arch = ToQUBO.Compiler.GenericArchitecture()

                vi1, _ = MOI.add_constrained_variable(model.source_model, MOI.ZeroOne())
                vi2, _ = MOI.add_constrained_variable(model.source_model, MOI.ZeroOne())

                ToQUBO.Compiler.variables!(model, arch)

                # Constraint: x1 + x2 <= 1
                f = MOI.ScalarAffineFunction{Float64}(
                    [
                        MOI.ScalarAffineTerm(1.0, vi1),
                        MOI.ScalarAffineTerm(1.0, vi2),
                    ],
                    0.0
                )
                s = MOI.LessThan{Float64}(1.0)
                ci = MOI.add_constraint(model.source_model, f, s)

                g = ToQUBO.Compiler.constraint(model, ci, f, s, arch)

                @test g isa PBO.PBF{VI,Float64}
                @test _minimum_penalty(
                    g,
                    Dict(
                        _target_var(model, vi1) => 1,
                        _target_var(model, vi2) => 0,
                    ),
                ) == 0.0
                @test _minimum_penalty(
                    g,
                    Dict(
                        _target_var(model, vi1) => 1,
                        _target_var(model, vi2) => 1,
                    ),
                ) > 0.0
            end
        end

        @testset "Scalar Affine Greater Than" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                arch = ToQUBO.Compiler.GenericArchitecture()

                vi1, _ = MOI.add_constrained_variable(model.source_model, MOI.ZeroOne())
                vi2, _ = MOI.add_constrained_variable(model.source_model, MOI.ZeroOne())

                ToQUBO.Compiler.variables!(model, arch)

                # Constraint: x1 + x2 >= 1
                f = MOI.ScalarAffineFunction{Float64}(
                    [
                        MOI.ScalarAffineTerm(1.0, vi1),
                        MOI.ScalarAffineTerm(1.0, vi2),
                    ],
                    0.0
                )
                s = MOI.GreaterThan{Float64}(1.0)
                ci = MOI.add_constraint(model.source_model, f, s)

                g = ToQUBO.Compiler.constraint(model, ci, f, s, arch)

                @test g isa PBO.PBF{VI,Float64}
                @test _minimum_penalty(
                    g,
                    Dict(
                        _target_var(model, vi1) => 1,
                        _target_var(model, vi2) => 0,
                    ),
                ) == 0.0
                @test _minimum_penalty(
                    g,
                    Dict(
                        _target_var(model, vi1) => 0,
                        _target_var(model, vi2) => 0,
                    ),
                ) > 0.0
            end
        end

        @testset "Variable bound constraints (skipped)" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                arch = ToQUBO.Compiler.GenericArchitecture()

                vi, _ = MOI.add_constrained_variable(model.source_model, MOI.ZeroOne())

                ToQUBO.Compiler.variables!(model, arch)

                # ZeroOne constraint on variable should return nothing
                ci = MOI.ConstraintIndex{VI, MOI.ZeroOne}(vi.value)
                g = ToQUBO.Compiler.constraint(model, ci, vi, MOI.ZeroOne(), arch)
                @test isnothing(g)

                # Integer constraint on variable should return nothing
                ci_int = MOI.ConstraintIndex{VI, MOI.Integer}(vi.value)
                g_int = ToQUBO.Compiler.constraint(model, ci_int, vi, MOI.Integer(), arch)
                @test isnothing(g_int)
            end
        end
    end

    return nothing
end
