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
    function toqubo(model::MOI.ModelLike, quantum::Bool=false)::QUBOModel

        T = Float64 # TODO: Use MOIU.Model{T} where T ??
        ∅ = Set{VI}()

        # -*- Support Validation -*-
        supported_objective(model)
        supported_constraints(model)

        # -*- Create QUBO Model -*-
        # This allows one to use MOI.copy_to afterwards
        qubo = QUBOModel{T}(quantum=quantum)

        # -*- Variable Analysis -*-

        # Set of all model variables
        u = Set{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

        # Set of binary variables
        v = Set{VI}()

        for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, ZO}())
            # Account for variable as binary
            vᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)


            push!(v, vᵢ)
        end

        # Non-binary variables
        w = setdiff(u, v)

        if !isempty(w)
            error("I don't know what to do with non-binary variables.")
            # expansion
            # for wᵢ in w
            #   Dict{VI}[wᵢ] = expand(wᵢ)
            # end
        else
            @info "Original Binary Variables: $u"
        end

        # -*- Objective Analysis -*-

        # OS() -> ObjectiveSense()
        MOI.set(qubo, OS(), MOI.get(model, OS()))

        F = MOI.get(model, MOI.ObjectiveFunctionType())
        f = MOI.get(model, MOI.ObjectiveFunction{F}())

        p = Posiform{VI, T}()

        if F === VI
            # Constant
            p[f] = T(1)
        elseif F === SAF{T}
            # Affine Terms
            for tᵢ in f.terms
                cᵢ = tᵢ.coefficient
                vᵢ = tᵢ.variable
                if vᵢ in v
                    p[vᵢ] += cᵢ
                else
                    @warn "Variable 'v$(subscript(vᵢ))' is not binary and may need expansion"
                end
            end

            # Constant
            p += f.constant
        elseif F === SQF{T}
            # Quadratic Terms
            for tᵢ in f.quadratic_terms
                cᵢ = tᵢ.coefficient
                vᵢ = Set{Vi}([tᵢ.variable_1, tᵢ.variable_2])

                for vᵢⱼ in vᵢ
                    if vᵢⱼ in v # is binary
                        continue
                    elseif vᵢ in w # non-binary
                        # for wᵢ in exp[vᵢ]
                        #   p[wᵢ] += cᵢ
                        # end
                    end
                end

                if all([vᵢⱼ in v ]) # is binary
                    p[vᵢ] += cᵢ
                else
                    @warn "Variable 'v$(subscript(vᵢ))' is not binary and may need expansion"
                end
            end

            # Affine Terms
            for tᵢ in f.affine_terms
                cᵢ = tᵢ.coefficient
                vᵢ = tᵢ.variable
                if isbinary(model, vᵢ)
                    p[vᵢ] += cᵢ
                else
                    @warn "Variable 'v$(subscript(vᵢ))' is not binary and may need expansion"
                end
            end

            # Constant
            p += f.constant
        else
            error("I Don't know how to deal with objective functions of type '$F'")
        end

        if sense == MOI.MAX_SENSE
            ρ = -penalty(p)
        else
            ρ = penalty(p)
        end

        # Constraints
        for (F, S) in MOI.get(model, MOI.ListOfConstraints())
            if F === VI
                if S === ZO
                    continue # These were already accounted for..
                elseif S === INT # Integer (Need expansion with offset = 0)
                    error("Not Implemented")
                elseif S === EQ{T}
                    # Fixed Variable!
                    error("There are Fixed variables!")
                end
            elseif F === SAF{T}
                if S === EQ{T}
                    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                        qᵢ = Posiform{VI, T}()

                        Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).value

                        for aⱼ in Aᵢ.terms
                            cⱼ = aⱼ.coefficient
                            vⱼ = aⱼ.variable

                            if vⱼ in v
                                qᵢ[vⱼ] += cⱼ
                            else
                                error("Non-Binary variable '$(vᵢ)' needs expansion")
                            end
                        end

                        p += ρ * (qᵢ - bᵢ) ^ 2
                    end
                elseif S === LT{T}
                    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                        qᵢ = Posiform{VI, T}()

                        Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                        bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).upper

                        for aⱼ in Aᵢ.terms
                            cⱼ = aⱼ.coefficient
                            vⱼ = aⱼ.variable

                            if vⱼ in v
                                qᵢ[vⱼ] += cⱼ
                            else
                                error("Non-Binary variable '$(vᵢ)' needs expansion")
                            end
                        end

                        # Introduce Slack Variables
                        s = add_slack(model, bᵢ)

                        sᵢ = Posiform{VI, T}()

                        for (k, v) in zip(keys(s), expand(s))
                            sᵢ[k] += v
                        end

                        println(sᵢ)

                        p += ρ * (qᵢ + sᵢ - bᵢ) ^ 2
                    end
                end
            else
                error("Unkown Constraint Type $F")
            end
        end

        if p.degree > 2
            error("Degree reduction is needed (degree = $(p.degree))")
        end

        M = Dict{VI, VI}(v => VI(i) for (i, v) in enumerate(vars(p)))
        N = Dict{VI, VI}(VI(i) => v for (i, v) in enumerate(vars(p)))
        
        n = length(M)

        Q = []
        a = []
        b = T(0)       

        qubo_model = MOIU.Model{T}()

        y = MOI.add_variables(qubo_model, n); # n <= numero de variaveis originais

        for yᵢ in y
            MOI.add_constraint(qubo_model, yᵢ, MOI.ZeroOne())
        end

        if invert_sense
            s = -1.0
            MOI.set(qubo_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
        else
            s = 1.0
            MOI.set(qubo_model, MOI.ObjectiveSense(), sense)
        end

        for (k, v) in p
            # var mapping
            x = [M[x] for x in k]

            u = v * s

            n = length(x) # degree

            if n == 0
                b += u
            elseif n == 1
                push!(a, SAT{T}(u, x...))
            elseif n == 2
                push!(Q, SQT{T}(u, x...))
            else
                error("Degree reduction failed!")
            end
        end

        MOI.set(
            qubo_model,
            MOI.ObjectiveFunction{SQF{T}}(),
            SQF{T}(Q, a, b),
        )
        
        return qubo_model
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