struct Tol <: MOI.AbstractOptimizerAttribute end

function MOI.get(model::VirtualQUBOModel{T}, ::Tol) where T
    model.attrs.tol::T
end

function MOI.set(model::VirtualQUBOModel{T}, ::Tol, tol::T) where T
    @assert tol > zero(T)

    model.attrs.tol = tol
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

function MOI.get(model::VirtualQUBOModel{T}, ::Penalty, vi::VI, ρ::T) where T
    model.ρ[vi] = ρ
end