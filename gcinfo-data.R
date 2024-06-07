library(tidyverse)
library(zoo)

output_file <- tempfile()
simulation_data <- callr::r(function() {
  ticks <- 500
  #write(sprintf("tick=%d elapsed=%f rss=%f maxrss=%f", -1, proc.time()[3], bench::bench_process_memory()[1], bench::bench_process_memory()[2]), stderr())
  library(malariasimulation)
  set.seed(123)
  parameters <- get_parameters(list(human_population=1e6)) # |> set_equilibrium(init_EIR = 5)
  #write(sprintf("tick=%d elapsed=%f rss=%f maxrss=%f", 0, proc.time()[3], bench::bench_process_memory()[1], bench::bench_process_memory()[2]), stderr())
  gcinfo(TRUE)
  run_simulation(ticks, parameters)
  gc()
  gcinfo(FALSE)
  #write(sprintf("tick=%d elapsed=%f rss=%f maxrss=%f", ticks+1, proc.time()[3], bench::bench_process_memory()[1], bench::bench_process_memory()[2]), stderr())
}, stderr=output_file) #, env=c(R_VSIZE="256MB"))

output <- paste0(readLines(output_file), collapse="\n")
data_raw <- str_match_all(
  output,
  paste0(
    "Garbage collection (?<n>\\d*) = (?<level1>\\d*)\\+(?<level2>\\d*)\\+(?<level3>\\d*) \\(level (?<level>\\d)\\) \\.\\.\\. \n",
    "(?<ncells>[\\d.]*) Mbytes of cons cells used \\((?<cellspct>\\d*)%\\)\\n(?<nvectors>[\\d.]*) Mbytes of vectors used \\((?<vectorspct>\\d*)%\\)",
    "(?:\nR_VSize=(?<vsize>\\d*) VHEAP_FREE=(?<vheapfree>\\d*))?",
    "|tick=(?<tick>[\\d-]+) elapsed=(?<time>[\\d.]+) rss=(?<rss>[\\d.]+) maxrss=(?<maxrss>[\\d.]+)"
  )
)[[1]][,-1] %>% data.frame()

saveRDS(data_raw, "gcinfo.rds")
data <- data_raw %>%
  mutate(across(everything(), as.numeric)) %>%
  mutate(across(c(nvectors, ncells), ~ . * 1024*1024)) %>%
  mutate(across(c(vsize, vheapfree), ~ . * 8)) %>%
  
  #mutate(across(c(tick, time), na.approx)) %>%
  mutate(cells_total = ncells / cellspct * 100,
         vectors_total = nvectors / vectorspct * 100) %>%
  mutate(level = as.factor(level))

gcdata <- data %>% filter(is.na(rss))

ggplot(gcdata, aes(n)) +
  geom_point(aes(y=nvectors, colour=level)) +
  labs(x="GC Cycle", y="Vectors used", colour="Level") +
  ggplot2::scale_y_continuous(labels = scales::label_bytes())
ggsave("gcinfo.png", width=20, scale=0.5)

ggplot(gcdata, aes(n)) +
  geom_point(aes(y=nvectors, colour=level)) +
  geom_line(aes(y=vsize), colour="black") +
  geom_line(aes(y=0.8 * vsize), colour="black", linetype=2) +
  ggplot2::scale_y_continuous(labels = scales::label_bytes())
ggsave("gcinfo-line.png", width=20, scale=0.5)

ggplot(gcdata, aes(tick)) +
  geom_point(data = ~ filter(., level == 0),
             aes(y=vectorspct,
                 colour=as.factor(vectorspct >= 80))) +
  geom_hline(yintercept=80)


#gcdata %>%
#  mutate(vincrement = vectors_total - lag(vectors_total)) %>%
#  select(n, vincrement, level) %>%
#  ggplot(., aes(n)) + geom_point(aes(y=vincrement, colour=level))

#(gcdata %>% filter(level == 0 & vectorspct >= 80) %>% count()) +
#(gcdata %>% filter(level == 0 & vectorspct < 80) %>% count() / 20)
#gcdata %>% filter(level == 1) %>% count()

+
  (gcdata %>% filter(level == 1 & vectorspct < 80) %>% count() / 5)

gcdata %>% filter(level == 2) %>% count()

gcdata %>% filter(level == 1) %>% count()
