library(proffer)
library(malariasimulation)
pprof({
  set.seed(123)
  parameters <- get_parameters(list(human_population=1e6)) |>
    set_equilibrium(init_EIR = 5)
  run_simulation(1000, parameters)
}, browse=FALSE)
