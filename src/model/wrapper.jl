# Notes on the optimize! interface
# After `JuMP.optimize!(model)` there are a few layers before reaching
#   1. `MOI.optimize!(::VirtualModel, ::MOI.ModelLike)`
# Then, 
#   2. `MOI.copy_to(::VirtualModel, ::MOI.ModelLike)`
#   3. `MOI.optimize!(::VirtualModel)`
# is called.

function MOI.optimize!(model::VirtualModel)
    source_model = model.source_model
    target_model = model.target_model
    index_map    = MOIU.identity_index_map(source_model)

    # De facto JuMP to QUBO Compilation
    ToQUBO.toqubo!(model)

    if !isnothing(model.optimizer)
        MOI.optimize!(model.optimizer, target_model)
    end

    return (index_map, false)
end

function MOI.copy_to(model::VirtualModel{T}, source::MOI.ModelLike) where {T}
    if !MOI.is_empty(model)
        error("QUBO Model is not empty")
    end

    # Copy to PreQUBOModel + Add Bridges
    bridge_model = MOIB.full_bridge_optimizer(model.source_model, T)

    # Copy to source using bridges
    return MOI.copy_to(bridge_model, source) # index_map
end

# Objective Function Support
MOI.supports(
    ::VirtualModel{T},
    ::MOI.ObjectiveFunction{<:Union{VI,SAF{T},SQF{T}}},
) where {T} = true

# Constraint Support
MOI.supports_constraint(
    ::VirtualModel{T},
    ::Type{VI},
    ::Type{
        <:Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T},MOI.LessThan{T},MOI.GreaterThan{T}},
    },
) where {T} = true

MOI.supports_constraint(
    ::VirtualModel{T},
    ::Type{<:Union{SAF{T},SQF{T}}},
    ::Type{<:Union{MOI.EqualTo{T},MOI.LessThan{T}}},
) where {T} = true

MOI.supports_constraint(
    ::VirtualModel{T},
    ::Type{<:MOI.VectorOfVariables},
    ::Type{<:MOI.SOS1},
) where {T} = true

MOI.supports_add_constrained_variable(
    ::VirtualModel{T},
    ::Type{
        <:Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T},MOI.LessThan{T},MOI.GreaterThan{T}},
    },
) where {T} = true


PBO.showvar(x::VI) = PBO.showvar(x.value)

PBO.varlt(x::VI, y::VI) = PBO.varlt(x.value, y.value)

function PBO.varlt(x::Set{V}, y::Set{V}) where {V}
    if length(x) == length(y)
        xv = sort!(collect(x); lt = PBO.varlt)
        yv = sort!(collect(y); lt = PBO.varlt)

        for (xi, yi) in zip(xv, yv)
            if xi == yi
                continue
            else
                return PBO.varlt(xi, yi)
            end
        end

        return false
    else
        return length(x) < length(y)
    end
end

const Optimizer{T} = VirtualModel{T}

# QUBOTools
function qubo(model, type::Type = Dict)
    n, L, Q, α, β = MOI.get(model, QUBOTOOLS_NORMAL_FORM())

    return QUBOTools.qubo(type, n, L, Q, α, β)
end

function ising(model, type::Type = Dict)
    n, L̄, Q̄, ᾱ, β̄ = MOI.get(model, QUBOTOOLS_NORMAL_FORM())
    L, Q, α, β    = QUBOTools.cast(QUBOTools.𝔹, QUBOTools.𝕊, L̄, Q̄, ᾱ, β̄)

    return QUBOTools.ising(type, n, L, Q, α, β)
end
