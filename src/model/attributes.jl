struct Tol <: MOI.AbstractOptimizerAttribute end

function MOI.get(model::VirtualQUBOModel{T}, ::Tol) where T
    return model.settings.atol[nothing]::T
end

function MOI.set(model::VirtualQUBOModel{T}, ::Tol, atol::T) where T
    @assert atol > zero(T)

    model.settings.atol[nothing] = atol
end

struct Penalty <: MOI.AbstractOptimizerAttribute end

function MOI.get(model::VirtualQUBOModel{T}, ::Penalty, ci::CI) where T
    return model.ρ[ci]
end

function MOI.set(model::VirtualQUBOModel{T}, ::Penalty, ci::CI, ρ::T) where T
    model.ρ[ci] = ρ
end

function MOI.get(model::VirtualQUBOModel{T}, ::Penalty, vi::VI) where T
    return model.ρ[vi]
end

function MOI.set(model::VirtualQUBOModel{T}, ::Penalty, vi::VI, ρ::T) where T
    model.ρ[vi] = ρ
end

struct GlobalEncoding <: MOI.AbstractOptimizerAttribute end

function MOI.get(model::VirtualQUBOModel, ::GlobalEncoding)
    return model.settings.encoding[nothing]
end

function MOI.set(model::VirtualQUBOModel, ::GlobalEncoding, e::Encoding)
    model.settings.encoding[nothing] = e
end

struct VariableEncoding <: MOI.AbstractVariableAttribute end

function MOI.get(model::VirtualQUBOModel, ::VariableEncoding, vi::VI)
    if haskey(model.settings.encoding, vi)
        return model.settings.encoding[vi]
    else
        return model.settings.encoding[nothing]
    end
end

function MOI.set(model::VirtualQUBOModel, ::VariableEncoding, vi::VI, e::Encoding)
    model.settings.encoding[vi] = e
end

struct ConstraintEncoding <: MOI.AbstractConstraintAttribute end

function MOI.get(model::VirtualQUBOModel, ::ConstraintEncoding, ci::CI)
    if haskey(model.settings.encoding, ci)
        return model.settings.encoding[ci]
    else
        return MOI.get(model, GlobalEncoding())
    end
end

function MOI.set(model::VirtualQUBOModel, ::ConstraintEncoding, ci::CI, e::Encoding)
    model.settings.encoding[ci] = e
end