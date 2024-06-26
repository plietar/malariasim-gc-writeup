library(malariasimulation)

proc_start <- proc.time()[[3]]
gc_start <- gc.time()[[3]]

set.seed(123)
parameters <- get_parameters(list(human_population=1e6))
run_simulation(500, parameters)

proc_elapsed <- proc.time()[[3]] - proc_start
gc_elapsed <- gc.time()[[3]] - gc_start

cat(sprintf("Simulation: %.2fs GC: %.2fs Total: %.2fs Relative: %.2f%%\n",
            proc_elapsed - gc_elapsed,
            gc_elapsed,
            proc_elapsed,
            gc_elapsed / proc_elapsed * 100))
