# The pre-cache implementation is an independent compatibility oracle.
function _reference_metadata_terms(f)
    terms = Dict{String,Any}[]
    for (term, coefficient) in f
        iszero(coefficient) && continue
        variables = term === nothing || isempty(term) ? Int[] : sort!([vi.value for vi in term])
        push!(terms, Dict{String,Any}("variables" => variables, "coefficient" => coefficient))
    end
    return sort!(terms; by = entry -> (length(entry["variables"]), join(entry["variables"], ",")))
end

# Distinct variable identities can expose the same metadata ID, exercising ties.
struct _MetadataVariable{T<:Integer}
    value::T
    tag::Int
end

Base.:(==)(a::_MetadataVariable, b::_MetadataVariable) = a.value == b.value && a.tag == b.tag
Base.isequal(a::_MetadataVariable, b::_MetadataVariable) = isequal(a.value, b.value) && a.tag == b.tag
Base.hash(a::_MetadataVariable, h::UInt) = hash(a.tag, hash(a.value, h))
Base.isless(a::_MetadataVariable, b::_MetadataVariable) = isless((a.value, a.tag), (b.value, b.tag))

function _check_metadata_terms(f)
    before = deepcopy(collect(f))
    expected = _reference_metadata_terms(f)
    actual = ToQUBO._pbf_terms(f)
    again = ToQUBO._pbf_terms(f)
    @test actual isa Vector{Dict{String,Any}}
    @test isequal(actual, expected)
    @test length(actual) == count(entry -> !iszero(last(entry)), f)
    for (entry, reference, later) in zip(actual, expected, again)
        @test Set(keys(entry)) == Set(["variables", "coefficient"])
        @test typeof(entry["variables"]) === typeof(reference["variables"])
        @test typeof(entry["coefficient"]) === typeof(reference["coefficient"])
        @test entry["coefficient"] === reference["coefficient"]
        @test entry["variables"] !== reference["variables"]
        @test entry["variables"] !== later["variables"]
        @test all(other -> other === entry || other["variables"] !== entry["variables"], actual)
    end
    @test isequal(collect(f), before)
    if !isempty(actual)
        for i in unique([firstindex(actual), lastindex(actual)])
            variables = actual[i]["variables"]
            push!(variables, oneunit(eltype(variables)))
            @test isequal(ToQUBO._pbf_terms(f), expected)
            @test isequal(collect(f), before)
        end
    end
    return again
end

function test_metadata_terms()
    @testset "Metadata term compatibility" begin
        ids = [Int[], [1], [2], [10], [100], [-1], [-10], [-2],
               [20, 1], [3, 1], [9, 1], [20, 10], [-1, 5], [-10, 5],
               [10, 2], [100, 10, 2]]
        for T in (Int, Float32, Float64, BigInt, BigFloat, Rational{BigInt}), reverse_order in (false, true)
            pairs = [PBO.Term{VI}(VI.(v)) => T(i) for (i, v) in enumerate(ids)]
            reverse_order && reverse!(pairs)
            data = Dict{PBO.Term{VI},T}(pairs)
            # Bypass zero-eliding constructors to exercise explicitly stored zero.
            data[PBO.Term{VI}([VI(999)])] = zero(T)
            f = PBO.PBF{VI,T,typeof(data)}(data)
            actual = _check_metadata_terms(f)
            @test [entry["variables"] for entry in actual] ==
                  [Int[], [-1], [-10], [-2], [1], [10], [100], [2],
                   [-1, 5], [-10, 5], [1, 20], [1, 3], [1, 9], [10, 20],
                   [2, 10], [2, 10, 100]]
            empty_data = Dict{PBO.Term{VI},T}()
            _check_metadata_terms(PBO.PBF{VI,T,typeof(empty_data)}(empty_data))
            zero_data = Dict{PBO.Term{VI},T}(PBO.Term{VI}() => zero(T))
            _check_metadata_terms(PBO.PBF{VI,T,typeof(zero_data)}(zero_data))
        end

        # Exercise the normal PBO interface as well as raw zero-retaining storage.
        public_f = PBO.PBF{VI,Float64}()
        public_f[nothing] = 2.0
        public_f[VI(10)] = 3.0
        public_f[VI(2), VI(1)] = -4.0
        _check_metadata_terms(public_f)
        constant_free = PBO.PBF{VI,Float64}()
        constant_free[VI(2)] = 2.0
        constant_free[VI(-1), VI(5)] = 4.0
        _check_metadata_terms(constant_free)

        for T in (Float32, Float64, BigFloat)
            data = Dict{PBO.Term{VI},T}(
                PBO.Term{VI}([VI(1)]) => -zero(T),
                PBO.Term{VI}([VI(2)]) => T(Inf),
                PBO.Term{VI}([VI(10)]) => T(-Inf),
                PBO.Term{VI}([VI(100)]) => T(NaN),
            )
            _check_metadata_terms(PBO.PBF{VI,T,typeof(data)}(data))
        end

        # Abstract coefficient storage must retain each concrete value and alias.
        for T in (Real, Any)
            data = Dict{PBO.Term{VI},T}(
                PBO.Term{VI}() => big(7),
                PBO.Term{VI}([VI(2)]) => BigFloat("1.25"),
                PBO.Term{VI}([VI(10)]) => big(3) // big(7),
                PBO.Term{VI}([VI(100)]) => Float32(2),
                PBO.Term{VI}([VI(-1)]) => -0.0,
                PBO.Term{VI}([VI(-10)]) => Inf,
                PBO.Term{VI}([VI(-100)]) => -Inf,
                PBO.Term{VI}([VI(1), VI(2)]) => NaN,
            )
            _check_metadata_terms(PBO.PBF{VI,T,typeof(data)}(data))
        end

        for I in (Int32, Int128, BigInt)
            V = _MetadataVariable{I}
            data = Dict{PBO.Term{V},Any}(
                PBO.Term{V}() => big(2),
                PBO.Term{V}([V(I(10), 1)]) => BigFloat("2.5"),
                PBO.Term{V}([V(I(-10), 4), V(I(100), 5)]) => 4.0,
            )
            for tag in 1:6
                data[PBO.Term([V(I(2), tag)])] = big(tag) // big(11)
                data[PBO.Term([V(I(2), tag), V(I(20), tag)])] = BigFloat(tag)
            end
            actual = _check_metadata_terms(PBO.PBF{V,Any,typeof(data)}(data))
            @test first(actual)["variables"] isa Vector{Int}
            @test all(entry -> entry["variables"] isa Vector{I}, actual[2:end])
            # Stable ties follow the actual polynomial iteration order.
            for variables in ([2], [2, 20])
                tied = [c for (term, c) in data if sort!([v.value for v in term]) == variables]
                returned = [entry["coefficient"] for entry in actual if entry["variables"] == variables]
                @test length(returned) == length(tied) == 6
                @test all(a === b for (a,b) in zip(returned, tied))
            end
        end
    end
    return nothing
end
