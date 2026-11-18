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

# Reference copies of the released (v0.8.1) rational implementations. The exact
# shortcuts must reach the same decisions and reasons, or fall back to them.
function _reference_penalty_scaling(p, coeff, kind, id, T)
    C = ToQUBO.Compiler
    coeff_q = C._exact_rational(coeff)
    (isnothing(coeff) || !isfinite(coeff) || isnothing(coeff_q)) &&
        return false, "Applied penalty on $(kind) $(id) is not finite in exact arithmetic"
    for (_, c) in p
        cq = C._exact_rational(c)
        isnothing(cq) && return false, "Penalty polynomial coefficient on $(kind) $(id) is not finite"
        prod_t = T(coeff) * c
        if !isfinite(prod_t) || C._exact_rational(prod_t) != coeff_q * cq
            return false,
            "Scaled penalty term on $(kind) $(id) lost precision or overflowed in floating-point arithmetic"
        end
    end
    return true, nothing
end

function _reference_hamiltonian_assembly(model, ρ_map, θ_map, η_map, T)
    C = ToQUBO.Compiler
    V = MOI.VariableIndex
    obj_ok, obj_reason = C._verify_objective_exact_rational(model)
    obj_ok || return false, obj_reason
    H_float = PBO.PBF{V,T}()
    H_exact = PBO.PBF{V,Rational{BigInt}}()
    for (ω, c) in model.f
        cq = C._exact_rational(c)
        isnothing(cq) && return false, "Objective coefficient is not finite in exact arithmetic"
        H_float[ω] += c
        H_exact[ω] += cq
    end
    for (maps, polys, kind) in ((ρ_map, model.g, "constraint"), (θ_map, model.h, "variable"), (η_map, model.s, "slack_variable"))
        for (ref, poly) in polys
            haskey(maps, ref) || continue
            factor = maps[ref]
            ok, reason = _reference_penalty_scaling(poly, factor, kind, ref.value, T)
            ok || return false, reason
            for (ω, c) in poly
                product = factor * c
                H_float[ω] += product
                H_exact[ω] += C._exact_rational(product)
            end
        end
    end
    C._pbf_matches_exact_rational(H_float, H_exact) ||
        return false, "Assembled Hamiltonian coefficients lost precision in floating-point arithmetic"
    return true, nothing
end

function test_compiler_exact_certification_fast_paths()
    @testset "Exact certification fast paths match rational arithmetic" begin
        C = ToQUBO.Compiler
        V = MOI.VariableIndex
        R = Rational{BigInt}
        rng = Random.MersenneTwister(0x5157)

        @testset "Term slot traversal matches PBF iteration" begin
            for _ in 1:50
                data = Dict{PBO.Term{V},Float64}()
                for _ in 1:rand(rng, 0:400)
                    data[PBO.Term(V[V(i) for i in rand(rng, 1:30, rand(rng, 0:3))])] = rand(rng, (0.0, -1.5, 2.0, 7.0))
                end
                p = PBO.PBF{V,Float64,Dict{PBO.Term{V},Float64}}(data)
                for ω in collect(keys(data))[1:2:end]
                    rand(rng) < 0.3 && delete!(PBO.data(p), ω)
                end
                @test collect(C._term_slots(p)) == [(ω, c) for (ω, c) in p]
            end
        end

        @testset "IEEE product exactness" begin
            for (T, U) in ((Float32, UInt32), (Float64, UInt64))
                pool = T[0, -0.0, 1, -1, 2, 3, 0.1, 0.5, floatmin(T), nextfloat(zero(T)), floatmax(T),
                    T(2)^(precision(T) - 1), T(2)^precision(T) + 2, ldexp(one(T), exponent(floatmin(T)) + 2 * precision(T))]
                append!(pool, reinterpret.(T, rand(rng, U, 300)))
                append!(pool, T.(rand(rng, -2^20:2^20, 200)))
                checked = 0
                for x in pool, y in pool
                    (isfinite(x) && isfinite(y)) || continue
                    p = x * y
                    got = C._ieee_product_is_exact(x, y, p)
                    truth = isfinite(p) && R(p) == R(x) * R(y)
                    isnothing(got) && continue
                    checked += 1
                    got == truth || @test got == truth
                end
                @test checked > 10_000
            end
        end

        @testset "Penalty scaling verification" begin
            term(ids) = PBO.Term(V[V(i) for i in ids])
            for T in (Float32, Float64), _ in 1:300
                data = Dict{PBO.Term{V},T}()
                kind = rand(rng, 1:4)
                for _ in 1:rand(rng, 0:12)
                    c = kind == 1 ? T(rand(rng, -1000:1000)) : kind == 2 ? T(rand(rng, -1000:1000)) / T(2)^rand(rng, 0:30) :
                        kind == 3 ? reinterpret(T, rand(rng, T === Float32 ? UInt32 : UInt64)) : T(0.1) * rand(rng, 1:9)
                    data[term(rand(rng, 1:6, rand(rng, 0:2)))] = c
                end
                rand(rng) < 0.1 && (data[term(Int[])] = zero(T))
                p = PBO.PBF{V,T,Dict{PBO.Term{V},T}}(data)
                factor = rand(rng, (T(2), T(3), T(0.1), T(2)^rand(rng, -200:200), floatmax(T), reinterpret(T, rand(rng, T === Float32 ? UInt32 : UInt64))))
                @test C._verify_penalty_scaling_exact(p, factor, "constraint", 7) ==
                      _reference_penalty_scaling(p, factor, "constraint", 7, T)
            end
        end

        @testset "Hamiltonian assembly" begin
            function model_with(T; size, scale, fractional, huge)
                m = ToQUBO.Optimizer{T}()
                coeff() = (fractional && rand(rng) < 0.3) ? T(rand(rng, -64:64)) / T(4) :
                    huge ? T(rand(rng, -9:9)) * T(2)^rand(rng, 100:125) : T(rand(rng, -scale:scale))
                # The objective must match its source for the objective check to pass,
                # as in the fixture above; randomness lives in the penalty polynomials.
                objective = coeff()
                MOI.set(m, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}}(),
                    MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{T}[], objective))
                m.f[nothing] = objective
                for k in 1:3
                    ci = MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},MOI.EqualTo{T}}(k)
                    g = PBO.PBF{V,T}()
                    for _ in 1:size
                        g[PBO.Term(V[V(i) for i in rand(rng, 1:8, rand(rng, 0:2))])] += coeff()
                    end
                    m.g[ci] = g
                    m.ρ[ci] = rand(rng, (T(1), T(2), T(25), T(0.5), T(0.1)))
                end
                vi = V(1)
                m.h[vi] = PBO.PBF{V,T}(V(1) => coeff(), V(2) => coeff())
                m.θ[vi] = T(3)
                return m
            end
            outcomes = Dict{Any,Int}()
            bound_paths = Dict{Bool,Int}()
            for T in (Float32, Float64), _ in 1:300
                m = model_with(T; size = rand(rng, 1:30), scale = rand(rng, (10, 10^6, 2^40, 2^52)),
                    fractional = rand(rng) < 0.3, huge = rand(rng) < 0.1)
                got = C._verify_hamiltonian_assembly_exact(m, m.ρ, m.θ, m.η)
                expected = _reference_hamiltonian_assembly(m, m.ρ, m.θ, m.η, T)
                @test got == expected
                outcomes[got] = get(outcomes, got, 0) + 1
                # The magnitude bound may only ever certify assemblies the exact
                # rational verification accepts.
                bound = C._assembly_exact_by_magnitude_bound(m, m.ρ, m.θ, m.η)
                bound && @test expected == (true, nothing)
                bound_paths[bound] = get(bound_paths, bound, 0) + 1
            end
            @test length(outcomes) >= 2
            @test get(outcomes, (true, nothing), 0) >= 50
            # Small integral models with integral factors: the bound must certify.
            for T in (Float32, Float64), _ in 1:50
                m = model_with(T; size = rand(rng, 1:30), scale = 10, fractional = false, huge = false)
                for ci in keys(m.ρ)
                    m.ρ[ci] = T(rand(rng, 1:25))
                end
                bound = C._assembly_exact_by_magnitude_bound(m, m.ρ, m.θ, m.η)
                @test bound
                @test _reference_hamiltonian_assembly(m, m.ρ, m.θ, m.η, T) == (true, nothing)
                @test C._verify_hamiltonian_assembly_exact(m, m.ρ, m.θ, m.η) == (true, nothing)
                bound_paths[bound] = get(bound_paths, bound, 0) + 1
            end
            # Both the bound and the per-term integral path are exercised.
            @test get(bound_paths, true, 0) >= 100
            @test get(bound_paths, false, 0) >= 50
        end

        @testset "Squared linear residual certificate" begin
            hits = 0
            for _ in 1:300
                k = rand(rng, (5, 11, 12, 30, 80))
                ids = sort!(unique(rand(rng, 1:200, k)))
                big_coeffs = rand(rng) < 0.1
                r = PBO.PBF{V,R}()
                for i in ids
                    a = big_coeffs ? R(rand(rng, (big(2)^61, -big(2)^61 + 3, big(2)^62))) : R(rand(rng, (-3:-1..., 1:5..., 16, 1024)))
                    r[V(i)] = a
                end
                rand(rng) < 0.8 && (r[nothing] = R(rand(rng, -40:40)))
                rand(rng) < 0.05 && (r[V(ids[1]), V(ids[end])] = R(2))
                rand(rng) < 0.05 && (r[V(ids[1])] = R(1, 3))
                sq = r^2
                for mutation in (:none, :none, :drop, :perturb, :extra, :zero)
                    data = Dict{PBO.Term{V},Float64}(ω => Float64(c) for (ω, c) in sq)
                    if mutation == :drop && !isempty(data)
                        delete!(data, first(keys(data)))
                    elseif mutation == :perturb && !isempty(data)
                        ω = first(keys(data)); data[ω] = nextfloat(data[ω])
                    elseif mutation == :extra
                        data[PBO.Term(V[V(1000), V(1001)])] = 4.0
                    elseif mutation == :zero
                        data[PBO.Term(V[V(2000)])] = 0.0
                    end
                    p = PBO.PBF{V,Float64,Dict{PBO.Term{V},Float64}}(data)
                    fast = C._linear_square_certificate_int128(p, r)
                    isnothing(fast) && continue
                    hits += 1
                    p_q = C._pbf_to_rational(p)
                    matches = p_q == sq
                    @test fast[1] == matches
                    if matches
                        g_r = C._pbf_all_coeff_gcd(r)
                        @test fast[2] == C._certify_nonnegative_linear_or_square_gap(sq, g_r^2)
                    end
                end
            end
            @test hits > 300
        end

        @testset "Inequality slack piece certificate" begin
            hits = 0
            for trial in 1:40
                n = rand(rng, 11:16)
                jm = Model(ToQUBO.Optimizer)
                @variable(jm, x[1:n], Bin)
                a = rand(rng, 1:7, n)
                rhs = rand(rng, 3:(sum(a) - 1))
                if isodd(trial)
                    @constraint(jm, sum(a[i] * x[i] for i in 1:n) <= rhs)
                else
                    @constraint(jm, sum(a[i] * x[i] for i in 1:n) >= rhs)
                end
                @objective(jm, Min, sum(x))
                optimize!(jm)
                vm = unsafe_backend(jm)
                arch = MOI.get(vm, Attributes.Architecture())
                for (ci, p) in vm.g
                    s = MOI.get(vm, MOI.ConstraintSet(), ci)
                    s isa Union{MOI.LessThan{Float64},MOI.GreaterThan{Float64}} || continue
                    f = MOI.get(vm, MOI.ConstraintFunction(), ci)
                    slack = [v for v in vm.variables if ToQUBO.Virtual.source(v) == ci]
                    length(slack) == 1 || continue
                    exact = C._certify_scalar_inequality_piece_rational(vm, f, s, only(slack), arch, ci.value)
                    fast = C._certify_scalar_inequality_piece_rational(vm, f, s, only(slack), arch, ci.value; p_float = p)
                    if fast[1] isa C._VerifiedSquarePiece
                        hits += 1
                        # The proven piece is the exact square the caller compares against.
                        @test exact[1] isa PBO.PBF && C._pbf_to_rational(p) == exact[1]
                        @test fast[2] == exact[2]
                        @test fast[3] === exact[3] === nothing
                    else
                        @test isequal(fast, exact)
                    end
                    # A perturbed compiled penalty must never be accepted as the square.
                    q = copy(p)
                    ω = first(ω for (ω, c) in q if length(ω) == 2)
                    q[ω] = nextfloat(q[ω])
                    perturbed = C._certify_scalar_inequality_piece_rational(vm, f, s, only(slack), arch, ci.value; p_float = q)
                    @test !(perturbed[1] isa C._VerifiedSquarePiece)
                    @test isequal(perturbed, exact)
                end
            end
            @test hits >= 20
        end
    end
end
