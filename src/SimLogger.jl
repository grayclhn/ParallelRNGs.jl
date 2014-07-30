immutable SimLogger
    logfile::String
    rngfile::String
    SimLogger(logfile, rngfile) =  new(logfile,rngfile)
    SimLogger(logfile) = SimLogger(logfile, splitext(logfile)[1] * ".rng")
    SimLogger() = SimLogger(".default.log")
end

function write(s::SimLogger, msg::String...)
    logstream = open(s.logfile, "a")
    write(logstream, string(strftime("\n%FT%R> ", time()), msg...))
    close(logstream)
end

function write(s::SimLogger, rng::AbstractRNG, ext="")
    rngstream = open(string(s.rngfile, ext), "w")
    serialize(rngstream, rng)
    close(rngstream)
end
