function test_corner_1()
    @testset "→ Variable Indicies in Constraints" begin
        @testset "Continuous First" begin
            let model = Model(ToQUBO.Optimizer)
                @variable(model, 0 <= x[1:2] <= 1)
                @variable(model, y[1:2], Bin)

                @constraint(model, cy, sum(y) == 1)
                @constraint(model, cx, sum(x) == 2)

                xi = Set{VI}(map(u -> u.index, x))
                xs = Set{VI}(map(u -> u.index, collect(keys(constraint_object(cx).func.terms))))
                yi = Set{VI}(map(u -> u.index, y))
                ys = Set{VI}(map(u -> u.index, collect(keys(constraint_object(cy).func.terms))))

                @test xi == xs
                @test yi == ys

                let virtual_model = unsafe_backend(model)
                    virtual_model.compiler_settings[:setup_callback] = m -> begin
                        yf = MOI.get(m, MOI.ConstraintFunction(), cy.index)
                        xf = MOI.get(m, MOI.ConstraintFunction(), cx.index)

                        ys = MOI.get(m, MOI.ConstraintSet(), cy.index)
                        xs = MOI.get(m, MOI.ConstraintSet(), cx.index)

                        @test ys isa MOI.EqualTo{Float64}
                        @test ys.value == 1.0
                        @test xs isa MOI.EqualTo{Float64}
                        @test xs.value == 2.0

                        yc = Set{VI}(map(t->t.variable, yf.terms))
                        xc = Set{VI}(map(t->t.variable, xf.terms))

                        @test xc == xi
                        @test yc == yi
                        @test xc != yi
                        @test yc != xi

                        return m
                    end
                end

                optimize!(model)
            end
        end

        @testset "Binary First" begin
            let model = Model(ToQUBO.Optimizer)
                @variable(model, y[1:2], Bin)
                @variable(model, 0 <= x[1:2] <= 1)

                @constraint(model, cy, sum(y) == 1)
                @constraint(model, cx, sum(x) == 2)

                xi = Set{VI}(map(u -> u.index, x))
                xs = Set{VI}(map(u -> u.index, collect(keys(constraint_object(cx).func.terms))))
                yi = Set{VI}(map(u -> u.index, y))
                ys = Set{VI}(map(u -> u.index, collect(keys(constraint_object(cy).func.terms))))

                @test xi == xs
                @test yi == ys

                let virtual_model = unsafe_backend(model)
                    virtual_model.compiler_settings[:setup_callback] = m -> begin
                        yf = MOI.get(m, MOI.ConstraintFunction(), cy.index)
                        xf = MOI.get(m, MOI.ConstraintFunction(), cx.index)

                        ys = MOI.get(m, MOI.ConstraintSet(), cy.index)
                        xs = MOI.get(m, MOI.ConstraintSet(), cx.index)

                        @test ys isa MOI.EqualTo{Float64}
                        @test ys.value == 1.0
                        @test xs isa MOI.EqualTo{Float64}
                        @test xs.value == 2.0

                        yc = Set{VI}(map(t->t.variable, yf.terms))
                        xc = Set{VI}(map(t->t.variable, xf.terms))

                        @test xc == xi
                        @test yc == yi
                        @test xc != yi
                        @test yc != xi

                        return m
                    end
                end

                optimize!(model)
            end
        end
    end

    return nothing
end
