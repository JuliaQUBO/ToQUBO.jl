import neal
import json

sampler = neal.SimulatedAnnealingSampler()

h = {}
J = {}

sampling = sampler.sample_ising(h, J)