# -*- QUBO Validation -*-

@doc raw"""
    isqubo(model::MOI.ModelLike)
    isqubo(T::Type{<:Any}, model::MOI.ModelLike)
    
Tells if a given model is ready to be interpreted as a QUBO model.

For it to be true, a few conditions must be met:
 1. All variables must be binary (`MOI.VariableIndex ∈ MOI.ZeroOne`)
 2. No other constraints are allowed
 3. The objective function must be either `MOI.ScalarQuadraticFunction`, `MOI.ScalarAffineFunction` or `MOI.VariableIndex`
"""
function isqubo(model::MOI.ModelLike)
    F = MOI.get(model, MOI.ObjectiveFunctionType()) 
    
    if !(F <: Union{SQF, SAF, VI})
        return false
    end

    # List of Variables
    v = Set{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        if !(F === VI && S === MOI.ZeroOne)
            # Non VariableIndex-in-ZeroOne Constraint
            return false
        else
            for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                vᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                
                # Account for variable as binary
                delete!(v, vᵢ)
            end

            if !isempty(v)
                # Some variable is not covered by binary constraints
                return false
            end
        end
    end

    return true
end

isqubo(::QUBOModel) = true
isqubo(::VirtualQUBOModel) = true

# -*- toqubo: MOI.ModelLike -> QUBO.Model -*-
@doc raw"""
    toqubo(
        T::Type{<:S},
        model::MOI.ModelLike,
        optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing;
        tol::S=zero(S)
    ) where {S}

Low-level interface to create a `::VirtualQUBOModel{T}` from `::MOI.ModelLike` instance. If provided, an `::MOI.AbstractOptimizer` is attached to the model.

The `tol` parameter defines the tolerance imposed for turning the problem's coefficients into integers.

!!! warning "Warning"
    Be careful with the `tol` parameter. When equal to zero, truncates all entries.
"""
function toqubo(T::Type{<: S}, model::MOI.ModelLike, optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing; tol::S=zero(S)) where {S}
    virt_model = VirtualQUBOModel{T}(optimizer; tol=tol)

    # -*- Copy to PreQUBOModel + Trigger Bridges -*-
    preq_lbopt = MOIB.full_bridge_optimizer(virt_model.preq_model, T)

    MOI.copy_to(preq_lbopt, model)

    # -*- Assemble Virtual Model -*-
    toqubo!(virt_model)
 
    return virt_model
end

function toqubo(model::MOI.ModelLike, optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing; tol::Float64=0.0)
    return toqubo(Float64, model, optimizer; tol=tol)
end

# -*- :: toqubo!(...) :: -*-
# ::: QUBO Conversion :::
# -*- From ModelLike to QUBO -*-

function toqubo!(model::VirtualQUBOModel{T}) where {T}
    # :: Problem Variables ::
    toqubo_variables!(model)

    # :: Objective Analysis ::
    F = MOI.get(model, MOI.ObjectiveFunctionType())

    toqubo_objective!(model, F)

    # :: Constraint Analysis ::

    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        toqubo_constraint!(model, F, S)
    end

    toqubo_sense!(model)

    # -*- Objective Function Assembly -*-
    Q = Vector{SQT{T}}()
    a = Vector{SAT{T}}()
    b = zero(T)

    ρ = gap(model.ℍ₀) + one(T)

    if MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE
        model.ℍ = model.ℍ₀ - ρ * sum(model.ℍᵢ)
    else
        model.ℍ = model.ℍ₀ + ρ * sum(model.ℍᵢ)
    end

    for (ω, c) in model.ℍ
        if length(ω) == 0
            b += c
        elseif length(ω) == 1
            push!(a, SAT{T}(c, ω...))
        elseif length(ω) == 2
            push!(Q, SQT{T}(c, ω...))
        else
            throw(QUBOError("Quadratization failed"))
        end
    end

    MOI.set(
        model.qubo_model,
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(Q, a, b)
    )

    return model
end

function toqubo_slack(model::VirtualQUBOModel)
    function slack(n::Union{Int, Nothing}=nothing)
        if n === nothing
            return first(target(slack𝔹!(model; name=:w)))
        else
            return [first(target(slack𝔹!(model; name=:w))) for _ = 1:n]
        end
    end

    return slack
end

function toqubo_sense!(model::VirtualQUBOModel)
    MOI.set(model.qubo_model, MOI.ObjectiveSense(), MOI.get(model, MOI.ObjectiveSense()))
end

# -*- Variables -*-
function toqubo_variables!(model::VirtualQUBOModel{T}) where {T}
    # ::: Variable Analysis :::

    # Set of all source variables
    Ω = Set{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    # Variable Sets and Bounds (Boolean, Integer, Real)
    𝔹 = Set{VI}()
    ℤ = Dict{VI, Tuple{Union{T, Missing}, Union{T, Missing}}}()
    ℝ = Dict{VI, Tuple{Union{T, Missing}, Union{T, Missing}}}()

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
        ℤ[xᵢ] = (missing, missing)
    end

    for xᵢ in setdiff(Ω, 𝔹, ℤ)
        # -*- Real Variable 😢 -*-
        ℝ[xᵢ] = (missing, missing)
    end

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.Interval}())
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

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.LessThan}())
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

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.GreaterThan}())
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
        if aᵢ === missing || bᵢ === missing
            error("Unbounded variable $xᵢ ∈ ℝ")
        else
            bits = 3 # TODO: Solve this bit-guessing magic???
            name = Symbol(MOI.get(model, MOI.VariableName(), xᵢ))
            expandℝ!(model, xᵢ; α=aᵢ, β=bᵢ, name=name, bits=bits)
        end
    end

    # -*- Discretize Integer Variables 🤔 -*-
    for (xᵢ, (aᵢ, bᵢ)) in ℤ
        if aᵢ === missing || bᵢ === missing
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
end

# -*- Objective Function -*-
function toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:VI}) where {T}
    # -*- Single Variable -*-
    xᵢ = MOI.get(model, MOI.ObjectiveFunction{F}())

    for (yᵢ, cᵢ) ∈ model.source[xᵢ]
        model.ℍ₀[yᵢ] += cᵢ
    end
end

function toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SAF{T}}) where {T}
    # -*- Affine Terms -*-
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    for aᵢ in f.terms
        cᵢ = aᵢ.coefficient
        xᵢ = aᵢ.variable

        for (yᵢ, dᵢ) ∈ model.source[xᵢ]
            model.ℍ₀[yᵢ] += cᵢ * dᵢ
        end
    end

    # -*- Constant -*-
    model.ℍ₀ += f.constant
end

function toqubo_objective!(model::VirtualQUBOModel{T}, F::Type{<:SQF{T}}) where {T}
    # -*- Affine Terms -*-
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    # Quadratic Terms
    for Qᵢ in f.quadratic_terms
        cᵢ = Qᵢ.coefficient
        xᵢ = Qᵢ.variable_1
        xⱼ = Qᵢ.variable_2

        for (yᵢ, dᵢ) ∈ model.source[xᵢ], (yⱼ, dⱼ) ∈ model.source[xⱼ]
            model.ℍ₀[yᵢ × yⱼ] += cᵢ * dᵢ * dⱼ
        end
    end

    for aᵢ in f.affine_terms
        cᵢ = aᵢ.coefficient
        xᵢ = aᵢ.variable

        for (yᵢ, dᵢ) in model.source[xᵢ]
            model.ℍ₀[yᵢ] += cᵢ * dᵢ
        end
    end

    # -*- Constant -*-
    model.ℍ₀ += f.constant
end

# -*- Constraints -*-
function toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<: SAF{T}}, S::Type{<:EQ{T}}) where {T}
    # -*- Scalar Affine Function: Ax = b 😄 -*-
    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        𝕒ᵢ = ℱ{T}()

        Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).value

        for aⱼ in Aᵢ.terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            for (yⱼ, dⱼ) ∈ model.source[xⱼ]
                𝕒ᵢ[yⱼ] += cⱼ * dⱼ
            end
        end

        𝕓ᵢ, ϵᵢ = discretize(𝕒ᵢ - bᵢ; tol=model.tol)

        ℍᵢ = quadratize(
            𝕓ᵢ ^ 2;
            slack = toqubo_slack(model)
        )

        push!(model.ℍᵢ, ℍᵢ)
    end
end

function toqubo_constraint!(model::VirtualQUBOModel{T}, F::Type{<: SAF{T}}, S::Type{<:LT{T}}) where {T}
    # -*- Scalar Affine Function: Ax <= b 🤔 -*-

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        𝕒ᵢ = ℱ{T}()

        Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).upper

        for aⱼ in Aᵢ.terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            for (yⱼ, dⱼ) ∈ model.source[xⱼ]
                𝕒ᵢ[yⱼ] += cⱼ * dⱼ
            end 
        end

        𝕓ᵢ, ϵᵢ = discretize(𝕒ᵢ - bᵢ; tol=model.tol)
    
        # -*- Introduce Slack Variable -*-
        α = sum(c for (ω, c) ∈ 𝕓ᵢ if !isempty(ω) && c < zero(T); init=zero(T))
        β = - 𝕓ᵢ[∅]

        𝕤ᵢ = ℱ{T}(Dict{Set{VI}, Float64}(Set{VI}([sᵢ]) => c for (sᵢ, c) ∈ slackℤ!(model; α=α, β=β, name=:s)))

        ℍᵢ = quadratize(
            (𝕓ᵢ + 𝕤ᵢ) ^ 2;
            slack = toqubo_slack(model)
        )

        # Incremental Interface: Use Dict instead
        push!(model.ℍᵢ, ℍᵢ)
    end
end

function toqubo_constraint!(::VirtualQUBOModel{T}, ::Type{<:VI}, ::Type{<:Union{MOI.ZeroOne, MOI.Interval, MOI.LessThan{T}, MOI.GreaterThan{T}}}) where {T} end