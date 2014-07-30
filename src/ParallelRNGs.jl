module ParallelRNGs

import
    Base.pmap,
    Base.write
export
    replicate,
    pmap

include("SimLogger.jl")
include("pmap.jl")
include("replicate.jl")
end # module
