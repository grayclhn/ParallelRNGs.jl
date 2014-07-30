# `replicate` calls `sim` on the output of the `dgp` function `n`
# times.
function replicate(sim::Function, dgp::Function, n::Integer;
                   logstem="", err_retry=true, err_stop=false)

    logger = SimLogger(logstem * ".log")
    write(logger, "Starting simulations")

    rvproducer = @task for i = 1:n
        write(logger, string("Starting sim ", i))
        produce(dgp())
    end

    results = pmap(sim,
                   id -> write(logger, string("Passing to worker ", id)),
                   (id, result) ->
                       write(logger, string("Worker ", id, " finished, ",
                           isa(result, Exception) ? "FAILED" : "succeeded")),
                   rvproducer, err_retry=err_retry, err_stop=err_stop)
    write(logger, "Simulations over.\n\n")
    return(results)
end

function replicate(sim::Function, dgp::Function, n::Integer, rng::AbstractRNG;
                   logstem="", err_retry=true, err_stop=false)

    logger = SimLogger(logstem * ".log")
    write(logger, "Starting simulations")

    function looptop(id)
        write(logger, string("Passing to worker ", id))
        write(logger, rng, id)
    end

    function loopbottom(id, result)
        write(logger, string("Worker ", id, " finished, ",
                             isa(result, Exception) ? "FAILED" : "succeeded"))
    end

    rvproducer = @task for i = 1:n
        write(logger, string("Starting sim ", i))
        produce(dgp(rng))
    end

    results = pmap(sim, looptop, loopbottom, rvproducer,
                   err_retry=err_retry, err_stop=err_stop)
    write(logger, "Simulations over.\n\n")
    write(logger, rng)
    return(results)
end

replicate(dgp::Function, n::Integer; err_retry=true, err_stop=false) =
    replicate(identity, dgp, n, err_retry=err_retry, err_stop=err_stop)
