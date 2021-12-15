module ToQUBO
    # -*- ToQUBO.jl -*-
    using Documenter, Logging
    using JuMP, MathOptInterface

    # MOI Aliases
    const MOI = MathOptInterface
    const MOIU = MathOptInterface.Utilities
    const MOIB = MathOptInterface.Bridges

    # const SVF = MOI.SingleVariable - Deprecated since MOI >= 0.10
    const SAF{T} = MOI.ScalarAffineFunction{T}
    const SQF{T} = MOI.ScalarQuadraticFunction{T}

    const SAT{T} = MOI.ScalarAffineTerm{T}
    const SQT{T} = MOI.ScalarQuadraticTerm{T}

    const EQ{T} = MOI.EqualTo{T}
    const LT{T} = MOI.LessThan{T}
    const GT{T} = MOI.GreaterThan{T}

    const VI = MOI.VariableIndex
    const CI = MOI.ConstraintIndex
    const ZO = MOI.ZeroOne
    const OS = MOI.ObjectiveSense

    export toqubo, isqubo
    
    include("./posiform.jl")
    include("./supported.jl")
    include("./virtualvar.jl")
    include("./qubomodel.jl")

    """
        subscript(v::VI)

    Adds support for VariableIndex Subscript Visualization.
    """
    function subscript(v::VI; var::Union{String, Symbol, Nothing}=nothing)
        if var === nothing
            return subscript(v.value)
        else
            return "$var$(subscript(v.value))"
        end
    end

    """
    """
    function Base.show(io::IO, s::Set{VI})
        print(io, join(sort([subscript(sᵢ, var=:x) for sᵢ in s]), " "))
    end

    """
    """
    function penalty(p::Posiform{S, T}) where {S, T}
        return sum(abs(v) for (k, v) in p if !isempty(k))
    end

    """
    """
    function penalty(p::Posiform{S, T}, ::Posiform{S, T}) where {S, T}
        return sum(abs(v) for (k, v) in p if !isempty(k))
    end

    """
    """
    function toqubo(model::MOI.ModelLike, quantum::Bool=false)::QUBOModel

        T = Float64 # TODO: Use MOIU.Model{T} where T ??

        # -*- Support Validation -*-
        supported_objective(model)
        supported_constraints(model)

        # -*- Create QUBO Model -*-
        # This allows one to use MOI.copy_to afterwards
        qubo = QUBOModel{T}(quantum=quantum)

        # -*- Variable Analysis -*-

        # Set of all model variables
        X = Set{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

        # Set of binary variables
        B = Set{VI}()

        for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, ZO}())
            # Account for variable as binary
            push!(B, MOI.get(model, MOI.ConstraintFunction(), cᵢ))
        end

        # Non-binary variables
        W = setdiff(X, B)

        @info "Original Binary Variables: $B"

        for bᵢ in B
            # TODO: Enhance naming
            expand(qubo, bᵢ, 1)
        end

        # TODO: bit size heuristics
        bits = 3

        for wᵢ in W
            expand(qubo, wᵢ, bits)
        end

        # -*- Objective Analysis -*-

        # OS() -> ObjectiveSense()
        MOI.set(qubo.model, OS(), MOI.get(model, OS()))

        F = MOI.get(model, MOI.ObjectiveFunctionType())

        # -*- Objective Function Posiform -*-
        p = Posiform{VI, T}()

        if F === VI
            # -*- Single Variable -*-
            x = MOI.get(model, MOI.ObjectiveFunction{F}())

            for (xᵢ, cᵢ) in qubo.varmap[x]
                p[xᵢ] += cᵢ
            end

        elseif F === SAF{T}
            # -*- Affine Terms -*-
            f = MOI.get(model, MOI.ObjectiveFunction{F}())

            for aᵢ in f.terms
                cᵢ = aᵢ.coefficient
                xᵢ = aᵢ.variable

                for (xᵢⱼ, dⱼ) in qubo.varmap[xᵢ]
                    p[xᵢⱼ] += cᵢ * dⱼ
                end
            end

            # Constant
            p += f.constant

        elseif F === SQF{T}
            # -*- Affine Terms -*-
            f = MOI.get(model, MOI.ObjectiveFunction{F}())

            # Quadratic Terms
            for Qᵢ in f.quadratic_terms
                cᵢ = Qᵢ.coefficient
                xᵢ = Qᵢ.variable_1
                yᵢ = Qᵢ.variable_2

                for (xᵢⱼ, dⱼ) in qubo.varmap[xᵢ]
                    for (yᵢₖ, dₖ) in qubo.varmap[yᵢ]
                        zⱼₖ = Set{VI}([xᵢⱼ, yᵢₖ])
                        p[zⱼₖ] += cᵢ * dⱼ * dₖ
                    end
                end
            end

            for aᵢ in f.affine_terms
                cᵢ = aᵢ.coefficient
                xᵢ = aᵢ.variable

                for (xᵢⱼ, dⱼ) in qubo.varmap[xᵢ]
                    p[xᵢⱼ] += cᵢ * dⱼ
                end
            end

            # Constant
            p += f.constant
        else
            error("I Don't know how to deal with objective functions of type '$F'")
        end

        # -*- Constraint Analysis -*-
        q = Posiform{VI, T}()

        # Constraints
        for (F, S) in MOI.get(model, MOI.ListOfConstraints())
            if F === VI
                # -*- Single Variable -*-
                if S === ZO
                    continue # These were already accounted for..
                else
                    error("Panic! I don't know how to deal with non-binary constraints over variables (yet...)")
                end

            elseif F === SAF{T}
                # -*- Scalar Affine Function -*-
                if S === EQ{T} # Ax = b :)
                    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                        rᵢ = Posiform{VI, T}()

                        Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).value

                        for aⱼ in Aᵢ.terms
                            cⱼ = aⱼ.coefficient
                            vⱼ = aⱼ.variable

                            for (vⱼₖ, dₖ) in qubo.varmap[vⱼ]
                                rᵢ[vⱼₖ] += cⱼ * dₖ
                            end
                        end

                        qᵢ = (rᵢ - bᵢ) ^ 2
                        ρᵢ = penalty(p, qᵢ)
                        q += ρᵢ * qᵢ
                    end
                elseif S === LT{T} # Ax <= b :(
                    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                        rᵢ = Posiform{VI, T}()
                        sᵢ = Posiform{VI, T}()

                        Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).upper

                        for aⱼ in Aᵢ.terms
                            cⱼ = aⱼ.coefficient
                            vⱼ = aⱼ.variable

                            for (vⱼₖ, dₖ) in qubo.varmap[vⱼ]
                                rᵢ[vⱼₖ] += cⱼ * dₖ
                            end
                        end

                        # -*- Introduce Slack Variable -*-
                        # TODO: Heavy Inference going on!
                        bits = ndigits(ceil(Int, log(2, bᵢ)), base=2)

                        for (sⱼ, dⱼ) in addslack(qubo, bits)
                            sᵢ[sⱼ] += dⱼ
                        end

                        qᵢ = (rᵢ + sᵢ - bᵢ) ^ 2
                        ρᵢ = penalty(p, qᵢ)
                        q += ρᵢ * qᵢ
                    end
                elseif S === GT{T} # Ax >= b :(
                    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                        rᵢ = Posiform{VI, T}()
                        sᵢ = Posiform{VI, T}()

                        Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).lower

                        for aⱼ in Aᵢ.terms
                            cⱼ = aⱼ.coefficient
                            vⱼ = aⱼ.variable

                            for (vⱼₖ, dₖ) in qubo.varmap[vⱼ]
                                rᵢ[vⱼₖ] += cⱼ * dₖ
                            end
                        end

                        # -*- Introduce Slack Variable -*-
                        # TODO: Heavy Inference going on!
                        bits = ndigits(ceil(Int, log(2, bᵢ)), base=2)

                        for (sⱼ, dⱼ) in addslack(qubo, bits)
                            sᵢ[sⱼ] += dⱼ
                        end

                        qᵢ = (rᵢ - sᵢ - bᵢ) ^ 2
                        ρᵢ = penalty(p, qᵢ)
                        q += ρᵢ * qᵢ
                    end
                else
                    error("Panic! I'm confused with this kind of constraint set: '$S'")
                end
            else
                error("Unkown Constraint Type $F")
            end
        end

        # -*- Objective Function Assembly -*-
        e = p + q
        e = e / maximum(values(e))

        println(e)

        return qubo   
    end


    """
        function isqubo(model::MOI.ModelLike)::Bool

    Tells if `model` is ready as QUBO Model. A few conditions must be met:
        1. All variables must be binary (VariableIndex-in-ZeroOne)
        2. No other constraints are allowed
        3. The objective function must be either ScalarQuadratic, ScalarAffine or VariableIndex
    """
    function isqubo(model::MOI.ModelLike)::Bool
        
        T = Float64 # TODO?

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
end