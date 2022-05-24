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

    return true
end

isqubo(::QUBOModel) = true
isqubo(::VirtualQUBOModel) = true

# -*- toqubo: MOI.ModelLike -> QUBO.Model -*-
@doc raw"""
    toqubo(T::Type, source::MOI.ModelLike, optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing)
    toqubo(source::MOI.ModelLike, optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing)

Low-level interface to create a `::VirtualQUBOModel{T}` from `::MOI.ModelLike` instance. If provided, an `::MOI.AbstractOptimizer` is attached to the model.
"""
function toqubo(T::Type, source::MOI.ModelLike, optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing)
    model = VirtualQUBOModel{T}(optimizer)

    MOI.copy_to(model, source)

    return toqubo!(model)
end

function toqubo(source::MOI.ModelLike, optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing)
    return toqubo(Float64, source, optimizer)
end


@doc raw"""
    toqubo!(model::VirtualQUBOModel{T}) where {T}
"""
function toqubo!(model::VirtualQUBOModel{T}) where {T}
    # :: Problem Variables ::
    toqubo_variables!(model)

    # :: Objective Analysis ::
    F = MOI.get(model, MOI.ObjectiveFunctionType())

    toqubo_objective!(model, F)

    # :: Constraint Analysis ::
    for (F, S) ∈ MOI.get(model, MOI.ListOfConstraintTypesPresent())
        toqubo_constraint!(model, F, S)
    end

    # :: Objective Sense ::
    toqubo_sense!(model)

    # -*- :: Objective Function Assembly :: -*-
    ε = convert(T, 1.0) # TODO: This should be made a parameter too?

    ρᵢ = δ(model.H₀) ./ ϵ.(model.Hᵢ; tol=model.settings.Tol) .+ ε

    if MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE
        ρᵢ *= -1.0
    end

    model.H = model.H₀ + sum(ρᵢ .* model.Hᵢ; init=zero(T))

    Q = SQT{T}[]
    a = SAT{T}[]
    b = zero(T)

    for (ω, c) in model.H
        if length(ω) == 0
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
        model.target_model,
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(Q, a, b)
    )

    return model
end

@doc raw"""
    toqubo_sense!(model::VirtualQUBOModel)

Copies `MOI.ObjectiveSense` from `model.source_model` to `model.target_model`.
"""
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
function toqubo_variables!(model::VirtualQUBOModel{T}) where {T}
    # ::: Variable Analysis :::

    # Set of all source variables
    Ω = Vector{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    # Variable Sets and Bounds (Boolean, Integer, Real)
    𝔹 = Vector{VI}()
    ℤ = Dict{VI, Tuple{Union{T, Nothing}, Union{T, Nothing}}}()
    ℝ = Dict{VI, Tuple{Union{T, Nothing}, Union{T, Nothing}}}()

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.ZeroOne}())
        # -*- Binary Variable 😄 -*-
        xᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)

        # Add to set
        push!(𝔹, xᵢ)
    end

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.Integer}())
        # -*- Integer Variable 🤔 -*-
        xᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)

        # Add to dict as unbounded
        ℤ[xᵢ] = (nothing, nothing)
    end

    for xᵢ in setdiff(Ω, 𝔹, keys(ℤ))
        # -*- Real Variable 😢 -*-
        ℝ[xᵢ] = (nothing, nothing)
    end

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.Interval{T}}())
        # -*- Interval 😄 -*-
        xᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
        Iᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ) 

        aᵢ = Iᵢ.lower
        bᵢ = Iᵢ.upper

        if haskey(ℤ, xᵢ)
            ℤ[xᵢ] = (aᵢ, bᵢ)
        elseif haskey(ℝ, xᵢ)
            ℝ[xᵢ] = (aᵢ, bᵢ)
        end
    end

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, LT{T}}())
        # -*- Upper Bound 🤔 -*-
        xᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
        Iᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ) 

        bᵢ = Iᵢ.upper

        if haskey(ℤ, xᵢ)
            ℤ[xᵢ] = (ℤ[xᵢ][1], bᵢ)
        elseif haskey(ℝ, xᵢ)
            ℝ[xᵢ] = (ℝ[xᵢ][1], bᵢ)
        end
    end

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, GT{T}}())
        # -*- Lower Bound 🤔 -*-
        xᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
        Iᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ)

        aᵢ = Iᵢ.lower

        if haskey(ℤ, xᵢ)
            ℤ[xᵢ] = (aᵢ, ℤ[xᵢ][2])
        elseif haskey(ℝ, xᵢ)
            ℝ[xᵢ] = (aᵢ, ℝ[xᵢ][2])
        end
    end

    # -*- Discretize Real Ones 🤔 -*-
    for (xᵢ, (aᵢ, bᵢ)) in ℝ
        if isnothing(aᵢ) || isnothing(bᵢ) 
            error("Unbounded variable $xᵢ ∈ ℝ")
        else
            # bits = 3
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
                    
            bits = ceil(Int, log2(1 + abs(bᵢ - aᵢ) / 4τ))
            name = Symbol(MOI.get(model, MOI.VariableName(), xᵢ))
            expandℝ!(model, xᵢ; α=aᵢ, β=bᵢ, name=name, bits=bits)
        end
    end

    # -*- Discretize Integer Variables 🤔 -*-
    for (xᵢ, (aᵢ, bᵢ)) in ℤ
        if isnothing(aᵢ) || isnothing(bᵢ) 
            error("Unbounded variable $xᵢ ∈ ℤ")
        else
            name = Symbol(MOI.get(model, MOI.VariableName(), xᵢ))
            expandℤ!(model, xᵢ; α=aᵢ, β=bᵢ, name=name)
        end
    end

    # -*- Mirror Boolean Variables 😄 -*-
    for xᵢ in 𝔹
        name = Symbol(MOI.get(model, MOI.VariableName(), xᵢ))
        mirror𝔹!(model, xᵢ; name=name)
    end

    nothing
end

@doc raw"""
    toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:VI}) where {T}
    toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}) where {T}
    toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}) where {T}
"""
function toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:VI}) where {T}
    # -*- Single Variable -*-
    xᵢ = MOI.get(model, MOI.ObjectiveFunction{F}())

    for (ωᵢ, cᵢ) ∈ model.source[xᵢ]
        model.H₀[ωᵢ] += cᵢ
    end
end

function toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}) where {T}
    # -*- Affine Terms -*-
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    for aᵢ in f.terms
        cᵢ = aᵢ.coefficient
        xᵢ = aᵢ.variable

        for (ωᵢ, dᵢ) ∈ model.source[xᵢ]
            model.H₀[ωᵢ] += cᵢ * dᵢ
        end
    end

    # -*- Constant -*-
    model.H₀ += f.constant
end

function toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}) where {T}
    # -*- Affine Terms -*-
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    # Quadratic Terms
    for Qᵢ ∈ f.quadratic_terms
        cᵢ = Qᵢ.coefficient
        xᵢ = Qᵢ.variable_1
        xⱼ = Qᵢ.variable_2

        # MOI convetion is to write ScalarQuadraticFunction as
        #     ½ x' Q x + a x + b
        # ∴ every coefficient in the main diagonal is doubled
        if xᵢ === xⱼ
            cᵢ /= 2
        end

        for (ωᵢ, dᵢ) ∈ model.source[xᵢ], (ωⱼ, dⱼ) ∈ model.source[xⱼ]
            model.H₀[ωᵢ × ωⱼ] += cᵢ * dᵢ * dⱼ
        end
    end

    for aᵢ ∈ f.affine_terms
        cᵢ = aᵢ.coefficient
        xᵢ = aᵢ.variable

        for (ωᵢ, dᵢ) in model.source[xᵢ]
            model.H₀[ωᵢ] += cᵢ * dᵢ
        end
    end

    # -*- Constant -*-
    model.H₀ += f.constant
end

@doc raw"""
    toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}, S::Type{<:EQ{T}}) where {T}
    toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}, S::Type{<:LT{T}}) where {T}
    toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}, S::Type{<:EQ{T}}) where {T}
    toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}, S::Type{<:LT{T}}) where {T}
    toqubo_constraint!(::VirtualQUBOModel{T}, ::Type{<:VI}, ::Type{<:Union{MOI.ZeroOne, MOI.Integer, MOI.Interval{T}, MOI.LessThan{T}, MOI.GreaterThan{T}}}) where {T}
"""
function toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}, S::Type{<:EQ{T}}) where {T}
    # -*- Scalar Affine Function: Ax = b 😄 -*-
    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        gᵢ = ℱ{T}()

        Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).value

        for aⱼ ∈ Aᵢ.terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            for (yⱼ, dⱼ) ∈ model.source[xⱼ]
                gᵢ[yⱼ] += cⱼ * dⱼ
            end
        end

        gᵢ = PBO.discretize((gᵢ - bᵢ) ^ 2; tol=model.settings.Tol)
        hᵢ = PBO.quadratize(gᵢ; slack = slack_factory(model))

        push!(model.Hᵢ, hᵢ)
    end

    nothing
end

function toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}, S::Type{<:LT{T}}) where {T}
    # -*- Scalar Affine Function: Ax <= b 🤔 -*-

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        gᵢ = ℱ{T}()

        Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).upper

        for aⱼ ∈ Aᵢ.terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            for (yⱼ, dⱼ) ∈ model.source[xⱼ]
                gᵢ[yⱼ] += cⱼ * dⱼ
            end
        end

        gᵢ = PBO.discretize(gᵢ - bᵢ; tol=model.settings.Tol)
    
        # -*- Introduce Slack Variable -*-
        αᵢ = sum(c for (ω, c) ∈ gᵢ if !isempty(ω) && c < zero(T); init=zero(T))
        βᵢ = -gᵢ[nothing]

        sᵢ = ℱ{T}(collect(slackℤ!(model; α=αᵢ, β=βᵢ, name=:s)))
        hᵢ = PBO.quadratize((gᵢ + sᵢ) ^ 2;slack = slack_factory(model))

        push!(model.Hᵢ, hᵢ)
    end

    nothing
end

function toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}, S::Type{<:EQ{T}}) where {T}
    # -*- Scalar Quadratic Function: x Q x + a x = b 😢 -*-
    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        gᵢ = ℱ{T}()

        fᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).value

        for Qⱼ ∈ fᵢ.quadratic_terms
            cⱼ = Qⱼ.coefficient
            xⱼ = Qⱼ.variable_1
            yⱼ = Qⱼ.variable_2

            if xᵢ === xⱼ
                cᵢ /= 2
            end

            for (ωⱼ, dⱼ) ∈ model.source[xⱼ], (ηⱼ, eⱼ) ∈ model.source[yⱼ]
                gᵢ[ωⱼ × ηⱼ] += cⱼ * dⱼ * eⱼ
            end
        end

        for aⱼ ∈ fᵢ.affine_terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            for (ωⱼ, dⱼ) ∈ model.source[xⱼ]
                gᵢ[ωⱼ] += cⱼ * dⱼ
            end
        end

        gᵢ = PBO.discretize((gᵢ - bᵢ) ^ 2; tol=model.settings.Tol)
        hᵢ = PBO.quadratize(gᵢ; slack = slack_factory(model))

        push!(model.Hᵢ, hᵢ)
    end

    nothing
end

function toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}, S::Type{<:LT{T}}) where {T}
    # -*- Scalar Quadratic Function: x Q x + a x <= b 😢 -*-
    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        gᵢ = ℱ{T}()

        fᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).upper

        for Qⱼ ∈ fᵢ.quadratic_terms
            cⱼ = Qⱼ.coefficient
            xⱼ = Qⱼ.variable_1
            yⱼ = Qⱼ.variable_2

            if xᵢ === xⱼ
                cᵢ /= 2
            end

            for (ωⱼ, dⱼ) ∈ model.source[xⱼ], (ηⱼ, eⱼ) ∈ model.source[yⱼ]
                gᵢ[ωⱼ × ηⱼ] += cⱼ * dⱼ * eⱼ
            end
        end

        for aⱼ ∈ fᵢ.affine_terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            for (ωⱼ, dⱼ) ∈ model.source[xⱼ]
                gᵢ[ωⱼ] += cⱼ * dⱼ
            end
        end

        gᵢ = PBO.discretize(gᵢ - bᵢ; tol=model.settings.Tol)

        # -*- Introduce Slack Variable -*-
        αᵢ = sum(c for (ω, c) ∈ gᵢ if !isempty(ω) && c < zero(T); init=zero(T))
        βᵢ = -gᵢ[nothing] # PBF constant term

        sᵢ = ℱ{T}(collect(slackℤ!(model; α=αᵢ, β=βᵢ, name=:s)))
        hᵢ = PBO.quadratize((gᵢ + sᵢ) ^ 2; slack = slack_factory(model))

        push!(model.Hᵢ, hᵢ)
    end
end

function toqubo_constraint!(
    ::VirtualQUBOModel{T},
    ::Type{<:VI},
    ::Type{<:Union{MOI.ZeroOne, MOI.Integer, MOI.Interval{T}, MOI.LessThan{T}, MOI.GreaterThan{T}}}
) where {T} end