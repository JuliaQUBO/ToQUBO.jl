function PBO.PBF{VI, T}(model::VirtualQUBOModel{T}) where T
    Ω = Dict{Set{VI}, T}()
    f = MOI.get(MOI.get(model, VM.TargetModel()), MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{T}}())

    for q in f.quadratic_terms
        c = q.coefficient
        xᵢ = q.variable_1
        xⱼ = q.variable_2

        Ω[Set{VI}([xᵢ, xⱼ])] = c
    end

    for a in f.affine_terms
        c = a.coefficient
        x = a.variable

        Ω[Set{VI}([x])] = c
    end

    Ω[Set{VI}()] = f.constant

    PBO.PBF{VI, T}(Ω)
end

function PBO.qubo_normal_form(model::VirtualQUBOModel{T}) where T
    PBO.qubo_normal_form(Array, PBO.PBF{VI, T}(model))
end

function PBO.qubo_normal_form(A::Type, model::VirtualQUBOModel{T}) where T
    PBO.qubo_normal_form(A, PBO.PBF{VI, T}(model))
end