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
    MOI.copy_to(optimizer, model.qubo_model)
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
