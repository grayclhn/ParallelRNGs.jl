module ParallelRNGs

import
    Base.pmap
export
    replicate,
    pmap

include("pmap.jl")
include("replicate.jl")
end # module
