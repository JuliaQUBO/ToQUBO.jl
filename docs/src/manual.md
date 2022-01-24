# Manual

## Quick Start Guide

*Aenean cursus justo est, at fringilla ex dictum at. Nullam porta faucibus luctus. Duis aliquet, augue dignissim ultrices tempus, tortor neque tincidunt nunc, vel eleifend orci diam vel neque. Maecenas ullamcorper enim et tellus venenatis, et gravida libero porttitor. Aenean vitae arcu iaculis, venenatis nulla ac, accumsan felis. Phasellus eu felis velit. Nullam ut enim porta, commodo magna nec, blandit nulla. Cras facilisis molestie bibendum. Maecenas sit amet ullamcorper lacus. Vivamus nisl metus, posuere eget erat non, interdum auctor nibh. Phasellus a semper nisl.*

```julia
import Pkg

Pkg.add("ToQUBO")

using ToQUBO
```

## Models

*Proin vel maximus tellus. Maecenas suscipit in risus at pharetra. Donec placerat pretium metus. Fusce orci leo, accumsan vitae felis sit amet, mattis gravida sapien. Phasellus convallis tristique dui, in vehicula ante ullamcorper ut. Nullam nec sodales justo. Aenean convallis quis neque in convallis. Etiam sit amet dui sit amet nisi faucibus porttitor. Proin scelerisque dui sed magna porta maximus. Cras nulla neque, venenatis vulputate eros a, malesuada tristique elit. Curabitur tincidunt tristique dui, ac vestibulum lectus congue vel. Morbi in laoreet diam, ut lacinia sapien. Nam a rhoncus felis. Etiam fringilla vestibulum venenatis. Quisque vehicula ut neque vel aliquam. Nunc tincidunt urna in velit accumsan pulvinar.*

## QUBO

*In in auctor nunc, nec commodo dolor. Fusce vel mi semper libero imperdiet luctus in vel nisl. Nullam sed urna pharetra, rhoncus diam vel, fringilla ipsum. In tempus ligula vel enim condimentum tristique. Nulla blandit congue laoreet. Aenean sagittis ipsum a imperdiet suscipit. Duis in interdum augue, vel volutpat odio. Donec lorem risus, malesuada id consequat in, pretium ut sem. Vestibulum suscipit tempor nibh, nec sodales quam. Curabitur quis condimentum ipsum, quis tincidunt lorem. Sed aliquet ex fermentum, rutrum dolor quis, lacinia elit.*

```@docs
isqubo
toqubo
```

## Pseudo-Boolean Optimization

Internally, problems are represented through a Pseudo-Boolean Optimization (PBO) framework. The main goal is to represent a given problem using a Pseudo-Boolean Function (PBF) since there is an imediate correspondence between PBFs and QUBO forms.

```@docs
PseudoBooleanFunction
reduce_degree
Δ 
```

## Virtual Mapping

*Proin at felis eu odio fringilla maximus a a diam. Sed sit amet lorem a ex finibus ultrices. Praesent mattis neque eu neque venenatis, nec congue enim mollis. Suspendisse urna tellus, aliquet ut orci a, vulputate vulputate sapien.*

### Virtual Variables

*Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam aliquet nec mauris nec mattis. Aenean pretium mauris elementum nisl sodales elementum. Etiam urna sapien, vehicula ac enim non, egestas accumsan orci.*

```@docs
VirtualVariable
mapvar!
expandℝ!
expandℤ!
slackℤ!
mirror𝔹!
```

### Virtual Models

*Aenean condimentum a libero a condimentum. Aliquam ac nisi id risus malesuada placerat at et diam. Nam eget nibh elit. Cras nec mollis elit, sit amet imperdiet magna. Suspendisse tempor est eu tortor sodales porta.*

```@docs
VirtualQUBOModel
```

## Annealing

*Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc a congue tortor. Praesent vestibulum sapien id nunc pulvinar feugiat. Mauris at turpis vel lacus pretium accumsan. Curabitur pretium consectetur lobortis. Nunc pretium ornare arcu, et accumsan metus aliquet et. Quisque efficitur nunc justo, vitae eleifend tortor rhoncus a. Sed nec maximus orci. Aliquam auctor placerat massa, sed posuere leo volutpat eget. Donec quis feugiat nulla, vitae porta eros.*

## MILP Solvers

*Nam justo dui, dignissim eget interdum eget, fermentum fermentum lectus. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Quisque urna enim, semper at elit non, consequat tempus lorem. Phasellus placerat mi ipsum, eu pellentesque erat imperdiet in. Fusce nec mauris ac purus auctor porttitor at nec ligula. Suspendisse vitae molestie felis. In hac habitasse platea dictumst. Vestibulum leo lectus, rutrum sit amet molestie vel, posuere vel ex. Vestibulum imperdiet sollicitudin metus ut venenatis.*

## Visualization

Some user friendly plot recipes are defined using [RecipesBase.jl](https://github.com/JuliaPlots/RecipesBase.jl). If you have any suggestions do not hesitate to post it as an issue.

```@example
using ToQUBO
```

## Datasets

The package provides some datasets to illustrate the funtionalities and models. These datasets are stored as csv files and the path to these files can be obtained through their names as seen below. In the examples we illustrate the datasets using [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) and [CSV.jl](https://github.com/JuliaData/CSV.jl)