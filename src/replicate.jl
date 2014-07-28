function makelogger(filename, mode)
    isempty(filename) && return((msg::String...) -> nothing)
    (msg::String...) -> begin
        logstream = open(filename, mode)
        write(logstream, string(strftime("\n%FT%R> ", time()), msg...))
        close(logstream)
        true
    end
end

# `replicate` calls `sim` on the output of the `dgp` function `n`
# times.
function replicate(sim::Function, dgp::Function, n::Integer;
                   logstem="", err_retry=true, err_stop=false)

    logger = makelogger(logstem * ".log", "a")
    if !isempty(logstem)
        function prelog(wid)
            logger("Passing to worker ", wid)
            return(nothing)
        end
        function postlog(wid, result)
            restext = isa(result, Exception) ? "FAILED" : "succeeded"
            logger("Worker ", wid, " finished, ", restext)
        end
    else
        prelog(wid, result=true) = return(nothing)
        postlog(wid, result=true) = return(nothing)
    end

    # Write initial message to the log file. This message is appended
    # to the end; you should manually delete it if you want to
    # overwrite the previous log entries.
    logger("Starting simulations")

    rvproducer = @task for i = 1:n
        logger("Starting sim ", i)
        produce(dgp())
    end

    results = pmap(sim, prelog, postlog, rvproducer,
                   err_retry=err_retry, err_stop=err_stop)
    logger("Simulations over.\n\n")
    return(results)
end

function replicate(sim::Function, dgp::Function, n::Integer, rng::AbstractRNG;
                   logstem="", err_retry=true, err_stop=false)

    logger = makelogger(logstem * ".log", "a")
    function rngsave(filename)
        rngstream = open(filename, "w")
        serialize(rngstream, rng)
        close(rngstream)
        return(nothing)
    end

    if !isempty(logstem)
        function prelog(wid)
            logger("Passing to worker ", wid)
            rngsave(string(logstem, ".rng", wid))
            return(nothing)
        end
        function postlog(wid, result)
            logger("Worker ", wid, " finished, ",
                   isa(result, Exception) ? "FAILED" : "succeeded")
        end
    else
        prelog(wid, result=true) = return(nothing)
        function postlog(wid, result=true)
            rngsave(string("default.rng", wid))
            return(nothing)
        end
    end

    # Write initial message to log file. This message is appended to
    # the end; you should manually delete it if you want to overwrite
    # the previous log entries.
    logger("Starting simulations")
    rvproducer = @task for i = 1:n
        logger("Starting sim ", i)
        produce(dgp(rng))
    end

    results = pmap(sim, prelog, postlog, rvproducer,
         err_retry=err_retry, err_stop=err_stop)
    logger("Simulations over.\n\n")
    rngsave(string(logstem, ".rng"))
    return(results)
end

replicate(dgp::Function, n::Integer; err_retry=true, err_stop=false) =
    replicate(identity, dgp, n, err_retry=err_retry, err_stop=err_stop)
