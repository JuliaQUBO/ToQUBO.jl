struct Tol <: MOI.AbstractOptimizerAttribute end

function MOI.get(model::VirtualQUBOModel{T}, ::Tol) where T
    model.attrs.tol::T
end

function MOI.set(model::VirtualQUBOModel{T}, ::Tol, tol::T) where T
    @assert tol > zero(T)

    model.attrs.tol = tol
end