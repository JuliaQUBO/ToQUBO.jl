import Random

function test_compiler_exact_rational_conversion()
    @testset "Exact rational coefficient conversion" begin
        exact = ToQUBO.Compiler._exact_rational
        rng = Random.MersenneTwister(0x4137)
        for (T, U) in ((Float16, UInt16), (Float32, UInt32), (Float64, UInt64))
            cases = T[0, -0.0, 1, -1, 2, -2, 0.5, -0.5, 0.1,
                floatmin(T), nextfloat(zero(T)), floatmax(T), -floatmax(T)]
            append!(cases, reinterpret.(T, rand(rng, U, 200)))
            for x in cases
                @test exact(x) == (isfinite(x) ? Rational{BigInt}(x) : nothing)
            end
            for x in (T(Inf), T(-Inf), T(NaN))
                @test exact(x) === nothing
            end
        end
        for x in (typemin(Int), typemax(Int), big(2)^200, 3//7,
                  big(5)//big(11), BigFloat("0.125"), 2.0^100, -2.0^100)
            @test exact(x) == Rational{BigInt}(x)
        end
        for x in (true, false, 1 + 0im, nothing, "1")
            @test exact(x) === nothing
        end
        a, b = exact(7.0), exact(7.0)
        @test a == b == 7//1
        @test numerator(a) !== numerator(b)
        @test denominator(a) !== denominator(b)
    end
end

function test_compiler_streaming_exact_polynomial_comparison()
    @testset "Streaming exact polynomial comparison" begin
        C = ToQUBO.Compiler
        V = MOI.VariableIndex
        R = Rational{BigInt}
        term(i) = i == 0 ? PBO.Term(V[]) : PBO.Term(V[V(i)])
        # The inner constructor retains explicit stored zeros, allowing this
        # contract to be tested even though normal insertion removes them.
        raw(T, entries) = PBO.PBF{V,T,Dict{PBO.Term{V},T}}(
            Dict{PBO.Term{V},T}(term(i) => T(c) for (i,c) in entries))
        legacy(p, q) = let converted = C._pbf_to_rational(p)
            !isnothing(converted) && converted == q
        end
        cases = [
            (Float64, [], [], true),
            (Float64, [(0, 1.0), (1, 0.5)], [(0, 1//1), (1, 1//2)], true),
            (Float64, [(1, 0.5), (0, 1.0)], [(0, 1//1), (1, 1//2)], true),
            (Float64, [(1, 0.5)], [(1, 3//4)], false),
            (Float64, [(1, 0.5)], [(2, 1//2)], false),
            (Float64, [(1, 0.5)], [(1, 1//2), (2, 1//1)], false),
            (Float64, [(1, 0.5), (2, 1.0)], [(1, 1//2)], false),
            (Float64, [(1, 0.5), (2, NaN)], [(1, 1//2)], false),
            (Float64, [(1, 0.0), (2, NaN)], [], false),
            (Float64, [(1, 0.0), (2, -0.0)], [], true),
            (Float64, [(1, 0.0), (2, 0.5)], [(2, 1//2)], true),
            (Float64, [(1, 0.0)], [(1, 0//1)], false),
            (Float64, [(1, 0.1)], [(1, 1//10)], false),
            (Float64, [(1, 0.1)], [(1, Rational{BigInt}(0.1))], true),
            (Float64, [(1, Inf)], [], false),
            (Float64, [(1, NaN)], [], false),
            (Bool, [(1, false)], [], false),
            (Bool, [(1, true)], [(1, 1//1)], false),
            (Int, [(1, 2), (0, -3)], [(0, -3//1), (1, 2//1)], true),
            (BigInt, [(1, big(2)^100)], [(1, (big(2)^100)//1)], true),
            (Rational{Int}, [(1, 2//3)], [(1, 2//3)], true),
            (R, [(1, big(2)//big(3))], [(1, 2//3)], true),
        ]
        for (T, entries, exact_entries, expected) in cases
            p, q = raw(T, entries), raw(R, exact_entries)
            saved_p, saved_q = deepcopy(collect(p)), deepcopy(collect(q))
            @test legacy(p, q) == expected
            @test C._pbf_matches_exact_rational(p, q) == expected
            @test C._pbf_matches_exact_rational(p, q) == expected
            @test isequal(collect(p), saved_p)
            @test isequal(collect(q), saved_q)
        end
        # Choose the matching prefix from the actual dictionary iteration order
        # so premature success cannot be masked by hash-order differences.
        for extra in (1.0, Inf, NaN)
            p = raw(Float64, [(1, 0.5), (2, 0.5)])
            entries = collect(p)
            prefix, trailing = first(entries[1]), first(entries[2])
            p[trailing] = extra
            q = raw(R, [])
            q[prefix] = 1//2
            @test first(first(p)) == prefix
            @test !legacy(p, q)
            @test !C._pbf_matches_exact_rational(p, q)
        end
        shared = big(9)//big(13)
        p = raw(R, [(1, shared), (2, shared)])
        q = raw(R, [(2, shared), (1, shared)])
        stored = [c for (_,c) in p]
        @test C._pbf_matches_exact_rational(p, q)
        @test all(c -> c === shared, stored)
        @test numerator(shared) == 9 && denominator(shared) == 13
    end
end

function test_compiler_exact_assembly_arithmetic()
    @testset "Exact assembly arithmetic and generic fallback" begin
        C = ToQUBO.Compiler
        # Constant terms isolate multiplication and accumulation from encodings.
        function fixture(T, objective, penalty, factor; slot)
            m = ToQUBO.Optimizer{T}()
            MOI.set(m, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}}(),
                MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{T}[], T(objective)))
            m.f[nothing] = T(objective)
            ci = MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},MOI.EqualTo{T}}(1)
            p = PBO.PBF{MOI.VariableIndex,T}()
            p[nothing] = T(penalty)
            if slot == :constraint
                m.g[ci] = p
                m.ρ[ci] = factor
            elseif slot == :variable
                vi = MOI.VariableIndex(1)
                m.h[vi] = p
                m.θ[vi] = factor
            else
                @assert slot == :slack
                m.s[ci] = p
                m.η[ci] = factor
            end
            return m
        end
        for slot in (:constraint, :variable, :slack)
            for T in (Float32, Float64, BigFloat, Rational{BigInt})
                m = fixture(T, 1, 3, T(2); slot)
                @test C._verify_objective_exact_rational(m) == (true, nothing)
                @test C._verify_hamiltonian_assembly_exact(m, m.ρ, m.θ, m.η) == (true, nothing)
            end
            for T in (Float32, Float64, BigFloat)
                large = T(2)^precision(T)
                m = fixture(T, large, 1, one(T); slot)
                ok, reason = C._verify_hamiltonian_assembly_exact(m, m.ρ, m.θ, m.η)
                @test !ok
                @test reason == "Assembled Hamiltonian coefficients lost precision in floating-point arithmetic"
            end
            m = fixture(Float64, 0, 0.1, 0.1; slot)
            ok, reason = C._verify_hamiltonian_assembly_exact(m, m.ρ, m.θ, m.η)
            @test !ok
            @test occursin("Scaled penalty term", reason)
            m = fixture(Float64, 0, 2, floatmax(Float64); slot)
            ok, reason = C._verify_hamiltonian_assembly_exact(m, m.ρ, m.θ, m.η)
            @test !ok
            @test occursin("overflowed", reason)
            high_precision_factor = setprecision(BigFloat, 256) do
                one(BigFloat) + BigFloat(2)^(-100)
            end
            setprecision(BigFloat, 64) do
                m = fixture(BigFloat, 0, 1, high_precision_factor; slot)
                factors = slot == :constraint ? m.ρ : slot == :variable ? m.θ : m.η
                @test precision(only(values(factors))) == 256
                ok, reason = C._verify_hamiltonian_assembly_exact(m, m.ρ, m.θ, m.η)
                # The original verifier accepts this exactly representable product
                # even when the factor carries a different precision.
                @test ok
                @test reason === nothing
            end
        end
    end
end
