using ParallelRNGs
using Base.Test

rngstate = 1344328
nprocs() < 2 && addprocs(2)

## Test minimal functionality: do we get the same random variables
## from the default RNG with parallel execution as we would get
## sequentially? Note that if nprocs() > 2 the order they're returned
## may be different than the order that they're produced, so we sort
## them.
srand(rngstate)
a = replicate(rand, 4)
srand(rngstate)

@test sort(a) == sort(rand(4))

## Test basics of logging (i.e. that the code runs at all)
logstem = tempname()
a2 = replicate(identity, rand, 4, logstem=logstem)
