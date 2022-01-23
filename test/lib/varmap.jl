const 𝒱{T} = VirtualVariable{VI, T}

struct VirtualModel{T <: Any}
    varvec::Vector{𝒱{T}}
    source::Dict{Symbol, 𝒱{T}}
    target::Dict{Symbol, 𝒱{T}}
    varnum::Int

    model::MOI.ModelLike

    function VirtualModel{T}() where {T}
        return new{T}(
            Vector{𝒱{T}}(),
            Dict{Symbol, 𝒱{T}}(),
            Dict{Symbol, 𝒱{T}}(),
            0,
            MOIU.Model{T}()
        )
    end
end

const 𝕋 = Float64

ℳ = VirtualModel{𝕋}()

# -*- Expansion: Binary Mirroring (:𝔹)-*-
𝓍 = VI(1)
𝓊 = 𝒱{𝕋}((n) -> MOI.add_variables(ℳ.model, n), 𝓍; name=:x, tech=:𝔹)

@test coefficient(𝓊, 1) == 1.0
@test coefficients(𝓊) == [1.0]
@test offset(𝓊) == 0.0

# -*- Expansion: Integer, unary (:ℤ₁) -*-
𝓎 = VI(2)
𝓋 = 𝒱{𝕋}((n) -> MOI.add_variables(ℳ.model, n), 𝓎; name=:y, tech=:ℤ₁, α=2.0, β=5.0)

@test coefficients(𝓋) == [1.0, 1.0, 1.0]
@test offset(𝓋) == 2.0

# -*- Expansion: Integer, binary (:ℤ₂) -*-
𝓏 = VI(3)
𝓌 = 𝒱{𝕋}((n) -> MOI.add_variables(ℳ.model, n), 𝓏; name=:z, tech=:ℤ₂, α=3.0, β=38.0)

@test coefficients(𝓌) == [1.0, 2.0, 4.0, 8.0, 16.0, 4.0]
@test offset(𝓌) == 3.0

# -*- Expansion: Real, unary (:ℝ₁) -*-
α = VI(4)
ℵ = 𝒱{𝕋}((n) -> MOI.add_variables(ℳ.model, n), α; name=:α, tech=:ℝ₁, α=-1.0, β=1.0, bits=5)

@test coefficients(ℵ) ≈ [0.5, 0.5, 0.5, 0.5, 0.5]
@test offset(ℵ) ≈ -1.0

# -*- Expansion: Real, binary (:ℝ₂) -*-
β = VI(5)
ℶ = 𝒱{𝕋}((n) -> MOI.add_variables(ℳ.model, n), β; name=:α, tech=:ℝ₂, α=-1.0, β=1.0, bits=3)

@test coefficients(ℶ) ≈ [2/7, 4/7, 8/7]
@test offset(ℶ) ≈ -1.0


