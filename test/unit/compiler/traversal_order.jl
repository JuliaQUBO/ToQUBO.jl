import Random

# Probe types for canonical type-name collisions (value and type-variable parameters).
struct _TraversalParam{N} end
struct _TraversalTwo{A,B} end

function _rehash_differently!(d::Dict)
    # Reinsert in reverse into a larger table so that iteration order changes,
    # as it can between Julia versions or precompile caches.
    entries = collect(d)
    for capacity in (64, 256, 1024, 4096)
        empty!(d)
        sizehint!(d, capacity)
        for (k, v) in reverse(entries)
            d[k] = v
        end
        collect(keys(d)) != first.(entries) && return true
    end
    return false
end

function test_compiler_traversal_order()
    @testset "Deterministic traversal order" begin
        ordered = ToQUBO.Compiler._ordered_pairs
        key = ToQUBO.Compiler._traversal_key
        SAF = MOI.ScalarAffineFunction{Float64}

        @testset "Ordered pairs ignore insertion order and table size" begin
            cis = MOI.ConstraintIndex[
                MOI.ConstraintIndex{SAF,MOI.EqualTo{Float64}}(2),
                MOI.ConstraintIndex{SAF,MOI.LessThan{Float64}}(1),
                MOI.ConstraintIndex{SAF,MOI.EqualTo{Float64}}(1),
                MOI.ConstraintIndex{SAF,MOI.GreaterThan{Float64}}(1),
                MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}(3),
                MOI.ConstraintIndex{SAF,MOI.LessThan{Float64}}(10),
            ]
            # Specified independently of the helper: index value, then canonical
            # function type name, then canonical set type name.
            expected = MOI.ConstraintIndex[
                MOI.ConstraintIndex{SAF,MOI.EqualTo{Float64}}(1),
                MOI.ConstraintIndex{SAF,MOI.GreaterThan{Float64}}(1),
                MOI.ConstraintIndex{SAF,MOI.LessThan{Float64}}(1),
                MOI.ConstraintIndex{SAF,MOI.EqualTo{Float64}}(2),
                MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}(3),
                MOI.ConstraintIndex{SAF,MOI.LessThan{Float64}}(10),
            ]
            rng = Random.MersenneTwister(0x0273)
            for capacity in (0, 16, 1024), _ = 1:20
                d = Dict{MOI.ConstraintIndex,Int}()
                sizehint!(d, capacity)
                for ci in Random.shuffle(rng, cis)
                    d[ci] = ci.value
                end
                @test first.(ordered(d)) == expected
            end
            # Canonical names do not depend on what is imported into Main.
            name = ToQUBO.Compiler._canonical_type_name
            @test name(MOI.GreaterThan{Float64}) == "MathOptInterface.GreaterThan{Core.Float64}"
            @test name(SAF) == "MathOptInterface.ScalarAffineFunction{Core.Float64}"
            @test name(MOI.ZeroOne) == "MathOptInterface.ZeroOne"
            # Value parameters are structural: indicator activation enums by value,
            # numbers tagged by their type, type-variable binders kept explicit.
            VAF = MOI.VectorAffineFunction{Float64}
            on_one = MOI.ConstraintIndex{VAF,MOI.Indicator{MOI.ACTIVATE_ON_ONE,MOI.LessThan{Float64}}}(1)
            on_zero = MOI.ConstraintIndex{VAF,MOI.Indicator{MOI.ACTIVATE_ON_ZERO,MOI.LessThan{Float64}}}(1)
            @test last(key(on_zero)) ==
                  "MathOptInterface.Indicator{MathOptInterface.ActivationCondition(0),MathOptInterface.LessThan{Core.Float64}}"
            @test key(on_zero) < key(on_one)
            @test name(_TraversalParam{Int8(1)}) != name(_TraversalParam{1})
            @test name(_TraversalTwo{T,T} where {T}) != name(_TraversalTwo{T,S} where {T,S})
            @test name(Tuple{Vararg{_TraversalParam{1}}}) ==
                  "Core.Tuple{Vararg($(name(_TraversalParam{1})))}"
            @test name(Tuple{Vararg{Int,2}}) == "Core.Tuple{Core.Int64,Core.Int64}"
            @test key(MOI.ConstraintIndex{SAF,MOI.LessThan{Float64}}(4)) ==
                  (4, "MathOptInterface.ScalarAffineFunction{Core.Float64}", "MathOptInterface.LessThan{Core.Float64}")

            vis = MOI.VariableIndex.([7, 1, 3, 12, 2])
            for _ = 1:10
                d = Dict{MOI.VariableIndex,Int}(vi => 0 for vi in Random.shuffle(rng, vis))
                @test first.(ordered(d)) == sort(vis; by = vi -> vi.value)
            end
            @test isempty(ordered(Dict{MOI.VariableIndex,Int}()))
        end

        @testset "Hamiltonian accumulation follows the specified order" begin
            T = Float64
            V = MOI.VariableIndex
            EQ = MOI.ConstraintIndex{SAF,MOI.EqualTo{T}}(1)
            GT = MOI.ConstraintIndex{SAF,MOI.GreaterThan{T}}(1)
            LT = MOI.ConstraintIndex{SAF,MOI.LessThan{T}}(1)
            # Constant contributions 2^53, 1, -2^53. In the specified order
            # (EqualTo, GreaterThan, LessThan) the float sum is
            # ((2^53 + 1) - 2^53) = 0 after rounding; other orders give 1.
            contribution = Dict(EQ => T(2)^53, GT => one(T), LT => -T(2)^53)
            arch = QUBOTools.GenericArchitecture()
            verdicts = Set{Any}()
            raw_orders = Set{Any}()
            rng = Random.MersenneTwister(0x2731)
            for capacity in (0, 16, 256), _ = 1:8
                m = ToQUBO.Optimizer{T}()
                MOI.set(m, MOI.ObjectiveFunction{SAF}(), MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{T}[], zero(T)))
                sizehint!(m.g, capacity)
                for ci in Random.shuffle(rng, [EQ, GT, LT])
                    g = PBO.PBF{V,T}()
                    g[nothing] = contribution[ci]
                    m.g[ci] = g
                    m.ρ[ci] = one(T)
                end
                push!(raw_orders, collect(keys(m.g)))
                ToQUBO.Compiler.objective_function(m, arch)
                @test m.H[nothing] == zero(T)
                push!(verdicts, ToQUBO.Compiler._verify_hamiltonian_assembly_exact(m, m.ρ, m.θ, m.η))
            end
            # The float assembly (0) differs from the exact sum (1), so it is
            # rejected, with the same verdict for every insertion order.
            @test length(raw_orders) > 1  # the Dict order really varied
            @test length(verdicts) == 1
            @test first(verdicts) ==
                  (false, "Assembled Hamiltonian coefficients lost precision in floating-point arithmetic")
        end

        @testset "SOS1 ties ignore expansion order" begin
            model = ToQUBO.Virtual.Model{Float64}()
            arch = QUBOTools.GenericArchitecture()
            x = MOI.add_variable(model.source_model)
            f = MOI.VectorOfVariables([x])
            s = MOI.SOS1([1.0])
            ci = MOI.add_constraint(model.source_model, f, s)
            v = ToQUBO.Encoding.encode!(model, x, ToQUBO.Encoding.OneHot(), [-1.0, 1.0])
            y = ToQUBO.Virtual.target(v)
            expansion = ToQUBO.Virtual.expansion(v)

            # Both coefficients have the same magnitude, so the lower target index wins.
            first_penalty = @test_logs (:warn, r"always non-zero") ToQUBO.Compiler.constraint(
                model, ci, f, s, arch,
            )
            @test _rehash_differently!(PBO.data(expansion))
            second_penalty = @test_logs (:warn, r"always non-zero") ToQUBO.Compiler.constraint(
                model, ci, f, s, arch,
            )
            for penalty in (first_penalty, second_penalty)
                @test penalty[y[1]] == -1.0
                @test iszero(penalty[y[2]])
            end
        end

        @testset "Penalty metadata and Hamiltonian do not depend on Dict order" begin
            model = ToQUBO.Optimizer{Float64}()
            x = MOI.add_variables(model, 5)
            for xi in x
                MOI.add_constraint(model, xi, MOI.ZeroOne())
            end
            f(c) = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(c, x), 0.0)
            MOI.add_constraint(model, f([1.0, 1.0, 0.0, 0.0, 0.0]), MOI.EqualTo(1.0))
            MOI.add_constraint(model, f([0.0, 1.0, 1.0, 1.0, 0.0]), MOI.EqualTo(1.0))
            MOI.add_constraint(model, f([1.0, 0.0, 1.0, 0.0, 1.0]), MOI.LessThan(2.0))
            MOI.add_constraint(model, f([0.0, 2.0, 0.0, 1.0, 1.0]), MOI.LessThan(3.0))
            MOI.add_constraint(model, f([1.0, 1.0, 1.0, 0.0, 0.0]), MOI.GreaterThan(1.0))
            MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
            MOI.set(model, MOI.ObjectiveFunction{SAF}(), f([3.0, -2.0, 1.0, 4.0, -1.0]))
            MOI.optimize!(model)

            meta = deepcopy(MOI.get(model, Attributes.PenaltyPolicyMetadata()))
            H = copy(model.H)
            inferred = meta["inferred_penalties"]["constraints"]
            @test length(inferred) == 5
            @test issorted([e["id"] for e in inferred])

            arch = MOI.get(model, Attributes.Architecture())
            @test _rehash_differently!(model.g)
            _rehash_differently!(model.s)
            ToQUBO.Compiler.penalties!(model, arch)
            ToQUBO.Compiler.objective_function(model, arch)
            @test MOI.get(model, Attributes.PenaltyPolicyMetadata()) == meta
            @test model.H == H
        end
    end

    return nothing
end
