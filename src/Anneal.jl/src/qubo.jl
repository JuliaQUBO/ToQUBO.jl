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

@doc raw"""
    toqubo(model::MOI.ModelLike)
    toqubo(T::Type{<:Any}, model::MOI.ModelLike)

Returns a triple ``(x, Q, c)`` where:
 * `x::Dict{MOI.VariableIndex, Int}` maps each of the model's variables to an integer index, to be used when interacting with `Q`.
 * `Q::Dict{Tuple{Int, Int}, T}` is a sparse representation of the QUBO Matrix.
 * `c::T` is the constant term associated with the problem.
"""
function toqubo(T::Type{<:Any}, model::MOI.ModelLike; sense::MOI.OptimizationSense = MOI.MIN_SENSE)
    if sense === MOI.FEASIBILITY_SENSE
        throw(ArgumentError("'FEASIBILITY' is not a valid sense for QUBO models"))
    end

    if !isqubo(model)
        throw(QUBOError())
    end

    x = Dict{VI,Int}(xᵢ => i for (i, xᵢ) ∈ enumerate(MOI.get(model, MOI.ListOfVariableIndices())))
    Q = Dict{Tuple{Int,Int},T}()
    c = zero(T)

    F = MOI.get(model, MOI.ObjectiveFunctionType())
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    if F <: VI
        iᵢ = (x[xᵢ], x[xᵢ])
        Q[iᵢ] = one(T)
    elseif F <: SAF
        for aᵢ ∈ f.terms
            cᵢ = aᵢ.coefficient
            xᵢ = aᵢ.variable

            iᵢ = (x[xᵢ], x[xᵢ])

            Q[iᵢ] = get(Q, iᵢ, zero(T)) + cᵢ
        end

        c += f.constant
    elseif F <: SQF
        for aᵢ ∈ f.affine_terms
            cᵢ = aᵢ.coefficient
            xᵢ = aᵢ.variable

            ii = (x[xᵢ], x[xᵢ])

            Q[ii] = get(Q, ii, zero(T)) + cᵢ
        end

        for aᵢ ∈ f.quadratic_terms
            cᵢ = aᵢ.coefficient
            xᵢ = aᵢ.variable_1
            xⱼ = aᵢ.variable_2

            ij = (x[xᵢ], x[xⱼ])

            Q[ij] = get(Q, ij, zero(T)) + cᵢ
        end

        c += f.constant
    end

    if MOI.get(model, MOI.ObjectiveSense()) != sense
        # Invert QUBO Signals
        # Note: (isqubo(model) == true) => objective sense is not FEASIBILITY
        for (ij, cᵢⱼ) ∈ Q
            Q[ij] = -cᵢⱼ
        end

        c = -c
    end

    return (x, Q, c)
end

function toqubo(model::MOI.ModelLike; sense::MOI.OptimizationSense = MOI.MIN_SENSE)
    return toqubo(Float64, model; sense = sense)
end