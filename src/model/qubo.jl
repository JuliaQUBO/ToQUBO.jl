# -*- QUBO Validation -*-
@doc raw"""
    isqubo(T::Type{<:Any}, model::MOI.ModelLike)
    isqubo(model::MOI.ModelLike)
    isqubo(::Model)
    isqubo(::QUBOModel)

Tells if `model` is ready as QUBO Model. A few conditions must be met:
    1. All variables must be binary (VariableIndex-in-ZeroOne)
    2. No other constraints are allowed
    3. The objective function must be either ScalarQuadratic, ScalarAffine or VariableIndex
"""
function isqubo(T::Type{<:Any}, model::MOI.ModelLike)
    F = MOI.get(model, MOI.ObjectiveFunctionType()) 
    
    if !(F === SQF{T} || F === SAF{T} || F === VI)
        return false
    end

    # List of Variables
    v = Set{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        if !(F === VI && S === ZO)
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

function isqubo(model::MOI.ModelLike)
    return isqubo(Float64, model)
end

isqubo(::Model) = true
isqubo(::QUBOModel) = true

# -*- toqubo: MOI.ModelLike -> QUBO.Model -*-
function toqubo(T::Type{<: Any}, model::MOI.ModelLike)
    qubo_model = Model{T}()

    # -*- Copy To: PreQUBOModel + Trigger Bridges -*-
    MOI.copy_to(qubo_model.preq_model, model)

    toqubo!(qubo_model.qubo_model, qubo_model.preq_model)

    return qubo_model
end

function toqubo(model::MOI.ModelLike)
    return toqubo(Float64, model)
end

# -*- :: toqubo!(...) :: -*-
# ::: QUBO Conversion :::
# -*- From ModelLike to QUBO -*-

"""
"""
function toqubo!(𝒬::QUBOModel{T}, ℳ::PreQUBOModel{T}) where {T}

    # -*- Support Validation -*-
    supported_objective(ℳ)
    supported_constraints(ℳ)

    # :: Problem Variables ::
    toqubo_variables!(ℳ, 𝒬)

    # :: Objective Analysis ::
    F = MOI.get(ℳ, MOI.ObjectiveFunctionType())

    toqubo_objective!(ℳ, 𝒬, F)

    # :: Constraint Analysis ::

    for (F, S) in MOI.get(ℳ, MOI.ListOfConstraints())
        toqubo_constraint!(ℳ, 𝒬, F, S)
    end

    # -*- Objective Function Assembly -*-
    MOI.set(
        𝒬.model,
        MOI.ObjectiveSense(),
        MOI.get(ℳ, MOI.ObjectiveSense())
    )

    Q = []
    a = []
    b = zero(T)

    ρ = Δ(𝒬.ℍ₀) / δ(𝒬.ℍᵢ)

    𝒬.ℍ = 𝒬.ℍ₀ + ρ * 𝒬.ℍᵢ # Total Energy

    for (ω, c) in 𝒬.ℍ
        n = length(ω)

        if n == 0
            b += c
        elseif n == 1
            push!(a, SAT{T}(c, ω...))
        elseif n == 2
            push!(Q, SQT{T}(c, ω...))
        else
            error("Degree reduction failed!")
        end
    end

    MOI.set(
        𝒬.model,
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(Q, a, b)
    )

    return 𝒬   
end

# -*- Variables -*-
function toqubo_variables!(ℳ::PreQUBOModel{T}, 𝒬::QUBOModel{T}) where {T}
    # ::: Variable Analysis :::

    # Set of all source variables
    Ω = Set{VI}(MOI.get(ℳ, MOI.ListOfVariableIndices()))

    𝕋 = Union{Missing, T}

    # Variable Sets and Bounds (Boolean, Integer, Real)
    𝔹 = Set{VI}()
    ℤ = Dict{VI, Tuple{𝕋, 𝕋}}()
    ℝ = Dict{VI, Tuple{𝕋, 𝕋}}()

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, ZO}())
        # -*- Binary Variable 😄 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)

        # Add to set
        push!(𝔹, xᵢ)
    end

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, MOI.Integer}())
        # -*- Integer Variable 🤔 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)

        # Add to dict as unbounded
        ℤ[xᵢ] = (missing, missing)
    end

    for xᵢ in setdiff(Ω, 𝔹, ℤ)
        # -*- Real Variable 😢 -*-
        ℝ[xᵢ] = (missing, missing)
    end

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, MOI.Interval}())
        # -*- Interval 😄 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        Iᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ) 

        aᵢ = Iᵢ.lower
        bᵢ = Iᵢ.upper

        if haskey(ℤ, xᵢ)
            ℤ[xᵢ] = (aᵢ, bᵢ)
        elseif haskey(ℝ, xᵢ)
            ℝ[xᵢ] = (aᵢ, bᵢ)
        end
    end

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, MOI.LessThan}())
        # -*- Upper Bound 🤔 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        Iᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ) 

        bᵢ = Iᵢ.upper

        if haskey(ℤ, xᵢ)
            ℤ[xᵢ] = (ℤ[xᵢ][0], bᵢ)
        elseif haskey(ℝ, xᵢ)
            ℝ[xᵢ] = (ℝ[xᵢ][0], bᵢ)
        end
    end

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, MOI.GreaterThan}())
        # -*- Lower Bound 🤔 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        Iᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ)

        aᵢ = Iᵢ.lower

        if haskey(ℤ, xᵢ)
            ℤ[xᵢ] = (aᵢ, ℤ[xᵢ][1])
        elseif haskey(ℝ, xᵢ)
            ℝ[xᵢ] = (aᵢ, ℤ[xᵢ][1])
        end
    end


    # -*- Discretize Real Ones 🤔 -*-
    for (xᵢ, (aᵢ, bᵢ)) in ℝ
        if aᵢ === missing || bᵢ === missing
            error("Unbounded variable $xᵢ ∈ ℝ")
        else
            bits = 3 # TODO: Solve this bit-guessing magic???
            name = Symbol(MOI.get(ℳ, MOI.VariableName(), xᵢ))
            expandℝ!(𝒬, xᵢ; α=aᵢ, β=bᵢ, name=name, bits=bits)
        end
    end

    # -*- Discretize Integer Variables 🤔 -*-
    for (xᵢ, (aᵢ, bᵢ)) in ℤ
        if aᵢ === missing || bᵢ === missing
            error("Unbounded variable $xᵢ ∈ ℤ")
        else
            name = Symbol(MOI.get(ℳ, MOI.VariableName(), xᵢ))
            expandℤ!(𝒬, xᵢ; α=aᵢ, β=bᵢ, name=name)
        end
    end

    # -*- Mirror Boolean Variables 😄 -*-
    for xᵢ in 𝔹
        name = Symbol(MOI.get(ℳ, MOI.VariableName(), xᵢ))
        mirror𝔹!(𝒬, xᵢ; name=name)
    end
end

# -*- Objective Function -*-
function toqubo_objective!(ℳ::PreQUBOModel{T}, 𝒬::QUBOModel{T}, F::Type{<:VI}) where {T}
    # -*- Single Variable -*-
    xᵢ = MOI.get(ℳ, MOI.ObjectiveFunction{F}())
    vᵢ = 𝒬.source[xᵢ]

    for (xᵢⱼ, cᵢⱼ) in vᵢ
        𝒬.ℍ₀[xᵢⱼ] += cᵢⱼ
    end
end

function toqubo_objective!(ℳ::PreQUBOModel{T}, 𝒬::QUBOModel{T}, F::Type{<:SAF{T}}) where {T}
    # -*- Affine Terms -*-
    f = MOI.get(ℳ, MOI.ObjectiveFunction{F}())

    for aᵢ in f.terms
        cᵢ = aᵢ.coefficient
        xᵢ = aᵢ.variable

        vᵢ = 𝒬.source[xᵢ]

        for (xᵢⱼ, dᵢⱼ) in vᵢ
            𝒬.ℍ₀[xᵢⱼ] += cᵢ * dᵢⱼ
        end
    end

    # -*- Constant -*-
    𝒬.ℍ₀ += f.constant
end

function toqubo_objective!(ℳ::PreQUBOModel{T}, 𝒬::QUBOModel{T}, F::Type{<:SQF{T}}) where {T}
    # -*- Affine Terms -*-
    f = MOI.get(ℳ, MOI.ObjectiveFunction{F}())

    # Quadratic Terms
    for Qᵢ in f.quadratic_terms
        cᵢ = Qᵢ.coefficient
        xᵢ = Qᵢ.variable_1
        yᵢ = Qᵢ.variable_2

        uᵢ = 𝒬.source[xᵢ]
        vᵢ = 𝒬.source[yᵢ]

        for (xᵢⱼ, dᵢⱼ) in uᵢ
            for (yᵢₖ, dᵢₖ) in vᵢ
                𝒬.ℍ₀[xᵢⱼ × yᵢₖ] += cᵢ * dᵢⱼ * dᵢₖ
            end
        end
    end

    for aᵢ in f.affine_terms
        cᵢ = aᵢ.coefficient
        xᵢ = aᵢ.variable

        vᵢ = 𝒬.source[xᵢ]

        for (xᵢⱼ, dᵢⱼ) in vᵢ
            𝒬.ℍ₀[xᵢⱼ] += cᵢ * dᵢⱼ
        end
    end

    # -*- Constant -*-
    𝒬.ℍ₀ += f.constant
end

# -*- Constraints -*-
function toqubo_constraint!(ℳ::PreQUBOModel{T}, 𝒬::QUBOModel{T}, F::Type{<: SAF{T}}, S::Type{<:EQ{T}}) where {T}
    # -*- Scalar Affine Function: Ax = b 😄 -*-
    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{F, S}())
        rᵢ = ℱ{T}()

        Aᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ).value

        for aⱼ in Aᵢ.terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            vⱼ = 𝒬.source[xⱼ]

            for (yⱼₖ, dⱼₖ) in vⱼ
                rᵢ[yⱼₖ] += cⱼ * dⱼₖ
            end 
        end

        qᵢ = reduce_degree(
            (rᵢ - bᵢ) ^ 2;
            cache=𝒬.cache,
            slack=()->addslack(𝒬, 1, name=:w)
        )

        𝒬.ℍᵢ += qᵢ
    end
end

function toqubo_constraint!(ℳ::PreQUBOModel{T}, 𝒬::QUBOModel{T}, F::Type{<: SAF{T}}, S::Type{<:LT{T}}) where {T}
    # -*- Scalar Affine Function: Ax <= b 🤔 -*-

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{F, S}())
        rᵢ = ℱ{T}()

        Aᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ).upper

        for aⱼ in Aᵢ.terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            vⱼ = 𝒬.source[xⱼ]

            for (yⱼₖ, dⱼₖ) in vⱼ
                rᵢ[yⱼₖ] += cⱼ * dⱼₖ
            end 
        end

        # -*- Introduce Slack Variable -*-
        sᵢ = ℱ{T}()

        # TODO: Heavy Inference going on!
        bits = ceil(Int, log(2, bᵢ))

        α = zero(T)
        β = bᵢ

        for (sᵢⱼ, dᵢⱼ) in addslack(𝒬, bits, domain=(α, β), name=:s)
            sᵢ[sᵢⱼ] += dᵢⱼ
        end

        qᵢ = reduce_degree(
            (rᵢ + sᵢ - bᵢ) ^ 2;
            cache=𝒬.cache,
            slack=()->addslack(𝒬, 1, name=:w)
        )

        𝒬.ℍᵢ += qᵢ
    end
end

function toqubo_constraint!(::MOI.PreQUBOModel, ::QUBOModel{T}, ::Type{<: VI}, ::Type{<:ZO}) where {T} end