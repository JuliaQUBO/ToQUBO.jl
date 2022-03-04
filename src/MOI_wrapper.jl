# -*- :: Model Methods :: -*-
function MOI.empty!(model::VirtualQUBOModel)
    # -*- Models -*-
    MOI.empty!(model.source_model)
    MOI.empty!(model.target_model)

    # -*- Virtual Variables -*-
    empty!(model.varvec)
    empty!(model.source)
    empty!(model.target)

    # -*- Underlying Optimizer -*-
    isnothing(model.optimizer) || MOI.empty!(model.optimizer)

    # -*- PBFs -*-
    empty!(model.ℍ)
    empty!(model.ℍ₀)
    empty!(model.ℍᵢ)

    # -*- MathOptInterface -*-
    empty!(model.moi)
end

function MOI.is_empty(model::VirtualQUBOModel)
    return MOI.is_empty(model.target_model) || isempty(model.ℍ)
end

function MOI.optimize!(model::VirtualQUBOModel)
    if isnothing(model.optimizer)
        error("Find me the appropriate MOI Error!!!")
    end

    MOI.optimize!(model.optimizer, model.target_model)

    # :: ObjectiveValue ::
    model.moi.objective_value    = MOI.get(model.optimizer, MOI.ObjectiveValue())
    model.moi.solve_time_sec     = MOI.get(model.optimizer, MOI.SolverTimeSec())
    model.moi.termination_status = MOI.get(model.optimizer, MOI.TerminationStatus())
    model.moi.primal_status      = MOI.get(model.optimizer, MOI.PrimalStatus())
    model.moi.raw_status_string  = MOI.get(model.optimizer, MOI.RawStatusString())
    
    nothing 
end

function Base.show(io::IO, model::VirtualQUBOModel)
    print(io, 
    """
    A Virtual QUBO Model
    with source:
        $(model.source_model)
    with target:
        $(model.target_model)
    """
    )
end

# -*- :: Model Attributes :: -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintAttributesSet)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintIndices)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintTypesPresent)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfModelAttributesSet)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfVariableAttributesSet)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfVariableIndices)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.NumberOfConstraints)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.NumberOfVariables)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.Name)
    return MOI.get(model.source_model, attr)
end

function MOI.set(model::VirtualQUBOModel, attr::MOI.Name, name::String)
    MOI.set(model.source_model, attr, name)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ObjectiveFunction)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ObjectiveFunctionType)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ObjectiveSense)
    return MOI.get(model.source_model, attr)
end



# function MOI.get(model::VirtualQUBOModel, ::MOI.ListOfVariableIndices)
#     return Vector{VI}([source(𝓋) for 𝓋 ∈ model.varvec if !isslack(𝓋)])
# end

function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveValue)
    return model.moi.objective_value
end

function MOI.set(model::VirtualQUBOModel{T}, ::MOI.ObjectiveValue, value::T) where {T}
    model.moi.objective_value = value
    nothing
end

# -*- SolveTimeSec
function MOI.get(model::VirtualQUBOModel, ::MOI.SolveTimeSec)
    return model.moi.solve_time_sec
end

function MOI.get(model::VirtualQUBOModel, ::MOI.SolveTimeSec, time_sec::Float64)
    model.moi.solve_time_sec = time_sec
    nothing
end

MOI.supports(::VirtualQUBOModel, ::MOI.SolveTimeSec) = true

# -*- PrimalStatus -*-
function MOI.get(model::VirtualQUBOModel, ::MOI.PrimalStatus)
    return model.moi.primal_status
end

function MOI.set(model::VirtualQUBOModel, ::MOI.PrimalStatus, status::MOI.ResultStatusCode)
    model.moi.primal_status = status
    nothing
end

# -*- TerminationStatus -*-
function MOI.get(model::VirtualQUBOModel, ::MOI.TerminationStatus)
    return model.moi.termination_status
end

function MOI.set(model::VirtualQUBOModel, ::MOI.TerminationStatus, status::MOI.TerminationStatusCode)
    model.moi.termination_status = status
    nothing
end

function MOI.get(model::VirtualQUBOModel, ::MOI.RawStatusString)
    return model.moi.raw_status_str
end

function MOI.set(model::VirtualQUBOModel, ::MOI.RawStatusString, str::String)
    model.moi.raw_status_str = str
    nothing
end

function MOI.get(model::VirtualQUBOModel, rc::MOI.ResultCount)
    if model.optimizer === nothing
        return 0
    else
        return MOI.get(model.optimizer, rc)
    end
end

MOI.supports(::VirtualQUBOModel, ::MOI.ResultCount) = true

# -*- Get: ObjectiveFunctionType -*-
function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveSense)
    return MOI.get(model.preq_model, MOI.ObjectiveSense())
end

function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveFunctionType)
    return MOI.get(model.preq_model, MOI.ObjectiveFunctionType())
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ObjectiveFunction{F}) where F <: MOI.AbstractScalarFunction
    return MOI.get(model.preq_model, attr)
end

# -*- Get: ListOfVariableIndices -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfVariableIndices)
    return MOI.get(model.preq_model, attr)
end

# -*- Get: ListOfConstraints -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintTypesPresent)
    return MOI.get(model.preq_model, attr)
end

# -*- Get: ListOfConstraintIndices{S, T} -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintIndices)
    return MOI.get(model.preq_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintIndices{MOI.VariableIndex, S}) where {S}
    return MOI.get(model.preq_model, attr)
end

# -*- Get: ConstraintFunction -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ConstraintFunction, cᵢ::MOI.ConstraintIndex)
    return MOI.get(model.preq_model, attr, cᵢ)
end

# -*- Get: ConstraintSet -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ConstraintSet, cᵢ::MOI.ConstraintIndex)
    return MOI.get(model.preq_model, attr, cᵢ)
end

# -*- Get: VariablePrimal -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.VariableName, xᵢ::MOI.VariableIndex)
    return MOI.get(model.preq_model, attr, xᵢ)
end

# -*- Get: ObjectiveFunction{F} -*-
function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveFunction{F}) where {F}
    return MOI.get(model.preq_model, MOI.ObjectiveFunction{F}())
end

function MOI.get(model::VirtualQUBOModel{T}, vp::MOI.VariablePrimal, xᵢ::MOI.VariableIndex) where {T}
    if model.optimizer === nothing
        throw(ErrorException("No underlying optimizer for model"))
    end

    return sum((MOI.get(model.optimizer, vp, yⱼ) * cⱼ for (yⱼ, cⱼ) ∈ model.source[xᵢ]); init=zero(T))
end

# -*- :: Bind Annealer and QUBOModel :: -*-
function MOI.copy_to(annealer::AbstractAnnealer{S, T}, model::VirtualQUBOModel{T}) where {S, T}
    x, Q, c = qubo(model.ℍ)

    annealer.x = x

    sense = MOI.get(model, MOI.ObjectiveSense())

    if sense === MOI.MIN_SENSE || sense === MOI.FEASIBILITY_SENSE
        annealer.Q = Q
        annealer.c = c
    elseif sense === MOI.MAX_SENSE
        annealer.Q = Dict{Tuple{Int, Int}, T}(ij => -q for (ij, q) ∈ Q)
        annealer.c = -c
    end

    nothing
end

function MOI.copy_to(optimizer::MOI.AbstractOptimizer, model::VirtualQUBOModel)
    MOI.copy_to(optimizer, model.target_model)
end

function MOI.optimize!(annealer::AbstractAnnealer{S, T}, model::VirtualQUBOModel{T}) where {S, T}
    MOI.copy_to(annealer, model)
    MOI.optimize!(annealer)

    # -*- Objective Value -*-
    s = annealer.sample_set.samples[1].states
    y = Dict{S, Int}(yᵢ => s[i]  for (yᵢ, i) ∈ annealer.x)
    
    model.moi.objective_value = convert(T, model.ℍ₀(y))

    # -*- Solve Time (Annealing Time) -*-
    model.moi.solve_time_sec = annealer.moi.solve_time_sec

    # -*- Termination Status -*-
    # Candidates:
    # 1. LOCALLY_SOLVED: The algorithm converged to a stationary point, local optimal solution, could not find directions for improvement, or otherwise completed its search without global guarantees.
    # 2. LOCALLY_INFEASIBLE: The algorithm converged to an infeasible point or otherwise completed its search without finding a feasible solution, without guarantees that no feasible solution exists.
    # 3. SOLUTION_LIMIT: The algorithm stopped because it found the required number of solutions. This is often used in MIPs to get the solver to return the first feasible solution it encounters.
    # 4. OTHER_LIMIT: The algorithm stopped due to a limit not covered by one of the above.
    #
    # MIP Solvers: Also check fesibility
    #
    # References:
    # [1] https://jump.dev/MathOptInterface.jl/stable/reference/models/#MathOptInterface.TerminationStatusCode
    #
    # PS:   
    # ∂ᵢf(x) = 0 ∀i ?
    model.moi.termination_status = annealer.moi.termination_status

    # -*- Primal Status -*-
    γ = sum(convert(T, ℍᵢ(y)) for ℍᵢ ∈ model.ℍᵢ; init=zero(T))

    if γ ≈ zero(T)
        model.moi.primal_status = MOI.FEASIBLE_POINT
    elseif γ <= model.tol
        model.moi.primal_status = MOI.NEARLY_FEASIBLE_POINT
    else
        model.moi.primal_status = MOI.INFEASIBLE_POINT
    end

    # -*- Raw Status String -*-
    model.moi.raw_status_str = annealer.moi.raw_status_str

    nothing
end

function MOI.optimize!(model::VirtualQUBOModel)
    if model.optimizer === nothing
        throw(ExceptionError("No optimizer in qubo model"))
    end

    MOI.optimize!(model.optimizer, model)
end

Base.isless(i::MOI.VariableIndex, j::MOI.VariableIndex) = isless(i.value, j.value)