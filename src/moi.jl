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
    # ∂ᵢf(x) = 0 ∀i ?
    model.moi.termination_status = annealer.moi.termination_status

    # -*- Primal Status -*-
    γ = sum(convert(T, ℍᵢ(y)) for ℍᵢ ∈ model.ℍᵢ; init=zero(T))

    if γ ≈ zero(T)
        model.moi.primal_status = MOI.FEASIBLE_POINT
    elseif γ <= model.ϵ
        model.moi.primal_status = MOI.NEARLY_FEASIBLE_POINT
    else
        model.moi.primal_status = MOI.INFEASIBLE_POINT
    end

    # -*- Raw Status String -*-
    model.moi.raw_status_str = annealer.moi.raw_status_str
end

function MOI.optimize!(model::VirtualQUBOModel)
    if model.optimizer === nothing
        throw(ExceptionError("No optimizer in qubo model"))
    end

    MOI.optimize!(model.optimizer, model)
end

Base.isless(i::MOI.VariableIndex, j::MOI.VariableIndex) = isless(i.value, j.value)
