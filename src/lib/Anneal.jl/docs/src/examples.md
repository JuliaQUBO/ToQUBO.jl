# Examples

```@example
import MathOptInterface as MOI
using Anneal

annealer = SimulatedAnnealer{MOI.VariableIndex, Float64}()

MOI.set(annealer, NumSweeps, 1000)
MOI.set(annealer, NumReads, 1000)

MOI.optimize!(annealer, model)
```