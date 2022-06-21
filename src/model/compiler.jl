# -*- QUBO Validation -*-
@doc raw"""
    isqubo(model::MOI.ModelLike)
    
Tells if a given model is ready to be interpreted as a QUBO model.

For it to be true, a few conditions must be met:
 1. All variables must be binary (`MOI.VariableIndex ∈ MOI.ZeroOne`)
 2. No other constraints are allowed
 3. The objective function must be of type `MOI.ScalarQuadraticFunction`, `MOI.ScalarAffineFunction` or `MOI.VariableIndex`
 4. The objective sense must be either `MOI.MIN_SENSE` or `MOI.MAX_SENSE`
"""
function isqubo(model::MOI.ModelLike)
    F = MOI.get(model, MOI.ObjectiveFunctionType())

    if !(F <: Union{SQF,SAF,VI})
        return false
    end

    S = MOI.get(model, MOI.ObjectiveSense())

    if !(S === MOI.MAX_SENSE || S === MOI.MIN_SENSE)
        return false
    end

    # List of Variables
    v = Set{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        if (F === VI && S === MOI.ZeroOne)
            for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
                vᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)

                # Account for variable as binary
                delete!(v, vᵢ)
            end
        else
            # Non VariableIndex-in-ZeroOne Constraint
            return false
        end
    end

    if !isempty(v)
        # Some variable is not covered by binary constraints
        return false
    end

    true
end

isqubo(::QUBOModel) = true
isqubo(::VirtualQUBOModel) = true

# -*- toqubo: MOI.ModelLike -> QUBO.Model -*-
@doc raw"""
    toqubo(T::Type, source::MOI.ModelLike, optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing)
    toqubo(source::MOI.ModelLike, optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing)

Low-level interface to create a `::VirtualQUBOModel{T}` from `::MOI.ModelLike` instance. If provided, an `::MOI.AbstractOptimizer` is attached to the model.
"""
function toqubo(T::Type, source::MOI.ModelLike, Optimizer::Union{Type{<:MOI.AbstractOptimizer}, Nothing} = nothing)
    model = VirtualQUBOModel{T}(Optimizer)

    MOI.copy_to(model, source)

    toqubo!(model)
end

function toqubo(source::MOI.ModelLike, Optimizer::Union{Type{<:MOI.AbstractOptimizer}, Nothing} = nothing)
    toqubo(Float64, source, Optimizer)
end

@doc raw"""
    toqubo!(model::VirtualQUBOModel{T}) where {T}
"""
function toqubo! end

function toqubo!(model::VirtualQUBOModel{T}) where {T}
    # :: Problem Variables ::
    toqubo_variables!(model)

    # :: Objective Analysis ::
    let F = MOI.get(model, MOI.ObjectiveFunctionType())
        toqubo_objective!(model, F)
    end

    # :: Constraint Analysis ::
    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        toqubo_constraints!(model, F, S)
    end

    # :: Objective Sense ::
    toqubo_sense!(model)

    # :: Add Encoding Constraints ::
    toqubo_encoding_constraints!(model)

    # :: Compute penalties ::
    toqubo_penalties!(model)

    toqubo_moi!(model)

    model
end

@doc raw"""
    toqubo_sense!(model::VirtualQUBOModel)

Copies `MOI.ObjectiveSense` from `model.source_model` to `model.target_model`.
"""
function toqubo_sense! end

function toqubo_sense!(model::VirtualQUBOModel)
    MOI.set(
        model.target_model, MOI.ObjectiveSense(),
        MOI.get(
            model,
            MOI.ObjectiveSense()
        )
    )

    nothing
end

@doc raw"""
    toqubo_variables!(model::VirtualQUBOModel{T}) where {T}
"""
function toqubo_variables! end

function toqubo_variables!(model::VirtualQUBOModel{T}) where {T}
    # ::: Variable Analysis :::

    # Set of all source variables
    Ω = Vector{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    # Variable Sets and Bounds (Boolean, Integer, Real)
    𝔹 = Vector{VI}()
    ℤ = Dict{VI, Tuple{Union{T, Nothing}, Union{T, Nothing}}}()
    ℝ = Dict{VI, Tuple{Union{T, Nothing}, Union{T, Nothing}}}()

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.ZeroOne}())
        # -*- Binary Variable 😄 -*-
        x = MOI.get(model, MOI.ConstraintFunction(), ci)

        # Add to set
        push!(𝔹, x)
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.Integer}())
        # -*- Integer Variable 🤔 -*-
        x = MOI.get(model, MOI.ConstraintFunction(), ci)

        # Add to dict as unbounded
        ℤ[x] = (nothing, nothing)
    end

    for x in setdiff(Ω, 𝔹, keys(ℤ))
        # -*- Real Variable 😢 -*-
        ℝ[x] = (nothing, nothing)
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.Interval{T}}())
        # -*- Interval 😄 -*-
        x = MOI.get(model, MOI.ConstraintFunction(), ci)
        I = MOI.get(model, MOI.ConstraintSet(), ci) 

        a = I.lower
        b = I.upper

        if haskey(ℤ, x)
            ℤ[x] = (a, b)
        elseif haskey(ℝ, x)
            ℝ[x] = (a, b)
        end
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI, LT{T}}())
        # -*- Upper Bound 🤔 -*-
        x = MOI.get(model, MOI.ConstraintFunction(), ci)
        I = MOI.get(model, MOI.ConstraintSet(), ci)

        b = I.upper

        if haskey(ℤ, x)
            ℤ[x] = (first(ℤ[x]), b)
        elseif haskey(ℝ, xᵢ)
            ℝ[x] = (first(ℝ[x]), b)
        end
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI, GT{T}}())
        # -*- Lower Bound 🤔 -*-
        x = MOI.get(model, MOI.ConstraintFunction(), ci)
        I = MOI.get(model, MOI.ConstraintSet(), ci)

        a = I.lower

        if haskey(ℤ, x)
            ℤ[x] = (a, last(ℤ[x]))
        elseif haskey(ℝ, x)
            ℝ[x] = (a, last(ℝ[x]))
        end
    end

    # -*- Discretize Real Ones 🤔 -*-
    for (x, (a, b)) in ℝ
        if isnothing(a) || isnothing(b) 
            error("Unbounded variable $(x) ∈ ℝ")
        else
            # TODO: Solve this bit-guessing magic???
            # IDEA: 
            #     Let x̂ ~ U[a, b], K = 2ᴺ, γ = [a, b]
            #       𝔼[|xᵢ - x̂|] = ∫ᵧ |xᵢ - x̂| f(x̂) dx̂
            #                   = 1 / |b - a| ∫ᵧ |xᵢ - x̂| dx̂
            #                   = |b - a| / 4 (K - 1)
            #
            #     For 𝔼[|xᵢ - x̂|] ≤ τ we have
            #       N ≥ log₂(1 + |b - a| / 4τ)
            #
            # where τ is the (absolute) tolerance
            τ = 0.25 # TODO: Add τ as parameter
            VM.encode!(VM.Binary, model, x, a, b, τ)
        end
    end

    # -*- Discretize Integer Variables 🤔 -*-
    for (x, (a, b)) in ℤ
        if isnothing(a) || isnothing(b) 
            error("Unbounded variable $(x) ∈ ℤ")
        else
            VM.encode!(VM.Binary, model, x, a, b)
        end
    end

    # -*- Mirror Boolean Variables 😄 -*-
    for x in 𝔹
        VM.encode!(VM.Mirror, model, x)
    end

    nothing
end

@doc raw"""
    toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:VI}) where {T}
    toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}) where {T}
    toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}) where {T}
"""
function toqubo_objective! end

function toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:VI}) where T
    x = MOI.get(model, MOI.ObjectiveFunction{F}())

    for (ω, c) in VM.expansion(MOI.get(model, VM.Source(), x))
        model.f[ω] += c
    end

    nothing
end

function toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}) where T
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    for t in f.terms
        c = t.coefficient
        x = t.variable

        for (ω, d) in VM.expansion(MOI.get(model, VM.Source(), x))
            model.f[ω] += c * d
        end
    end

    model.f[nothing] += f.constant

    nothing
end

function toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}) where T
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    for q in f.quadratic_terms
        c = q.coefficient
        xᵢ = q.variable_1
        xⱼ = q.variable_2

        # MOI convetion is to write ScalarQuadraticFunction as
        #     ½ x' Q x + a x + b
        # ∴ every coefficient in the main diagonal is doubled
        if xᵢ === xⱼ
            c /= 2
        end

        for (ωᵢ, dᵢ) in VM.expansion(MOI.get(model, VM.Source(), xᵢ))
            for (ωⱼ, dⱼ) in VM.expansion(MOI.get(model, VM.Source(), xⱼ))
                model.f[union(ωᵢ, ωⱼ)] += c * dᵢ * dⱼ
            end
        end
    end

    for a in f.affine_terms
        c = a.coefficient
        x = a.variable

        for (ω, d) in VM.expansion(MOI.get(model, VM.Source(), x))
            model.f[ω] += c * d
        end
    end

    model.f[nothing] += f.constant

    nothing
end

@doc raw"""
    toqubo_constraints!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}, S::Type{<:EQ{T}}) where {T}
    toqubo_constraints!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}, S::Type{<:LT{T}}) where {T}
    toqubo_constraints!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}, S::Type{<:EQ{T}}) where {T}
    toqubo_constraints!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}, S::Type{<:LT{T}}) where {T}
    toqubo_constraints!(::VirtualQUBOModel{T}, ::Type{<:VI}, ::Type{<:Union{MOI.ZeroOne, MOI.Integer, MOI.Interval{T}, MOI.LessThan{T}, MOI.GreaterThan{T}}}) where {T}
"""
function toqubo_constraints! end

function toqubo_constraints!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}, S::Type{<:EQ{T}}) where {T}
    # -*- Scalar Affine Function: Ax = b 😄 -*-
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        g = PBO.PBF{T}()

        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        b = MOI.get(model, MOI.ConstraintSet(), ci).value

        for a in f.terms
            c = a.coefficient
            x = a.variable

            for (ω, d) in VM.expansion(MOI.get(model, VM.Source(), x))
                g[ω] += c * d
            end
        end

        g[nothing] -= b

        model.g[ci] = g ^ 2
    end

    nothing
end

function toqubo_constraints!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}, S::Type{<:LT{T}}) where T
    # -*- Scalar Affine Function: Ax <= b 🤔 -*-
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        g = PBO.PBF{T}()

        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        b = MOI.get(model, MOI.ConstraintSet(), ci).upper

        for a in f.terms
            c = a.coefficient
            x = a.variable

            for (ω, d) in VM.expansion(MOI.get(model, VM.Source(), x))
                g[ω] += c * d
            end
        end

        g[nothing] -= b

        g = PBO.discretize(g)
    
        # -*- Introduce Slack Variable -*-
        v = VM.encode!(VM.Binary, model, nothing, zero(T), PBO.sup(g))
        s = VM.expansion(v)

        model.g[ci] = (g - s) ^ 2
    end

    nothing
end

function toqubo_constraints!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}, S::Type{<:EQ{T}}) where {T}
    # -*- Scalar Quadratic Function: x Q x + a x = b 😢 -*-
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        g = PBO.PBF{T}()

        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        b = MOI.get(model, MOI.ConstraintSet(), ci).value

        for q in f.quadratic_terms
            c = q.coefficient
            xᵢ = q.variable_1
            xⱼ = q.variable_2

            if xᵢ === xⱼ
                ci /= 2
            end

            for (ωᵢ, dᵢ) in VM.expansion(MOI.get(model, VM.Source(), xᵢ))
                for (ωⱼ, dⱼ) in VM.expansion(MOI.get(model, VM.Source(), xⱼ))
                    g[union(ωᵢ, ωⱼ)] += c * dᵢ * dⱼ
                end
            end
        end

        for a in f.affine_terms
            c = a.coefficient
            x = a.variable

            for (ω, d) in VM.expansion(MOI.get(model, VM.Source(), x))
                g[ω] += c * d
            end
        end

        g[nothing] -= b

        g = PBO.discretize(g)

        model.g[ci] = g ^ 2
    end

    nothing
end

function toqubo_constraints!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}, S::Type{<:LT{T}}) where {T}
    # -*- Scalar Quadratic Function: x Q x + a x <= b 😢 -*-
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        g = PBO.PBF{T}()

        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        b = MOI.get(model, MOI.ConstraintSet(), ci).value

        for q in f.quadratic_terms
            c = q.coefficient
            xᵢ = q.variable_1
            xⱼ = q.variable_2

            if xᵢ === xⱼ
                ci /= 2
            end

            for (ωᵢ, dᵢ) in VM.expansion(MOI.get(model, VM.Source(), xᵢ))
                for (ωⱼ, dⱼ) in VM.expansion(MOI.get(model, VM.Source(), xⱼ))
                    g[union(ωᵢ, ωⱼ)] += c * dᵢ * dⱼ
                end
            end
        end

        for a in f.affine_terms
            c = a.coefficient
            x = a.variable

            for (ω, d) in VM.expansion(MOI.get(model, VM.Source(), x))
                g[ω] += c * d
            end
        end

        g[nothing] -= b

        g = PBO.discretize(g)
    
        # -*- Introduce Slack Variable -*-
        v = VM.encode!(VM.Binary, model, nothing, zero(T), PBO.sup(g))
        s = VM.expansion(v)

        model.g[ci] = (g - s) ^ 2
    end

    nothing
end

function toqubo_constraints!(
    ::VirtualQUBOModel{T},
    ::Type{<:VI},
    ::Type{<:Union{MOI.ZeroOne, MOI.Integer, MOI.Interval{T}, MOI.LessThan{T}, MOI.GreaterThan{T}}}
) where T end

function toqubo_encoding_constraints!(model::VirtualQUBOModel{T}) where T
    for v in MOI.get(model, VM.Variables())
        h = if VM.isslack(v)
            nothing
        else
            VM.penaltyfn(v)
        end
        
        if !isnothing(h)
            x = VM.source(v)
            model.h[x] = h
        end
    end
end

function toqubo_penalties!(model::VirtualQUBOModel{T}) where T
    # -*- :: Invert Sign::  -*- #
    s = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1

    β = one(T) # TODO: This should be made a parameter too? Yes!
    δ = PBO.gap(model.f)

    for (vi, g) in model.g
        model.ρ[vi] = s * (δ / PBO.sharpness(g) + β)
    end

    for (ci, h) in model.h
        model.ρ[ci] = s * (δ / PBO.sharpness(h) + β)
    end
end

function toqubo_moi!(model::VirtualQUBOModel{T}) where T
    # -*- Assemble Objective Function -*-
    H = PBO.PBF{VI, T}()

    for (vi, g) in model.g
        H += model.ρ[vi] * g
    end

    for (ci, h) in model.h
        H += model.ρ[ci] * h
    end

    H = PBO.quadratize(
        H;
        slack = (n::Integer) -> (
        MOI.add_variables(MOI.get(model, VM.TargetModel()), n)
        )
    )

    # -*- Write to MathOptInterface -*-
    Q = SQT{T}[]
    a = SAT{T}[]
    b = zero(T)

    for (ω, c) in H
        if isempty(ω)
            b += c
        elseif length(ω) == 1
            push!(a, SAT{T}(c, ω...))
        elseif length(ω) == 2
            push!(Q, SQT{T}(c, ω...))
        else
            # NOTE: This should never happen in production.
            # During implementation of new quadratization methods and constraint reformulation
            # higher degree terms might be introduced by mistake. That's why it's important to 
            # have this condition here.
            throw(QUBOError("Quadratization failed"))
        end
    end

    MOI.set(
        MOI.get(model, VM.TargetModel()),
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(Q, a, b)
    )
end