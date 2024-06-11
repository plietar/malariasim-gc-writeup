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
    "|tick=(?<tick>[\\d-]+) elapsed=(?<time>[\\d.]+) rss=(?<rss>[\\d.]+) maxrss=(?<maxrss>[\\d.]+)",
    "|event=(?<event>.*) level=(?<levelX>\\d) R_Collected=.* size_needed=.* R_VSize=(?<vsizeX>\\d*) VHEAP_FREE=(?<vheapfreeX>\\d*)"
  )
)[[1]][,-1] %>% data.frame()

saveRDS(data_raw, "gcinfo.rds")
data <- data_raw %>%
  mutate(across(!event, as.numeric)) %>%
  mutate(event = case_when(!is.na(n) ~ "gc", .default = event)) %>%
  mutate(vsize = case_when(event == "gcagain" ~ vsizeX, .default = vsize)) %>%
  mutate(level = case_when(event == "gcagain" ~ levelX - 1, .default = level)) %>%
  mutate(vheapfree = case_when(event == "gcagain" ~ vheapfreeX, .default = vheapfree)) %>%

  select(!c(vsizeX, levelX, vheapfreeX)) %>%
  mutate(across(c(level, event), as.factor)) %>%

  mutate(across(c(n), na.approx)) %>%
  mutate(across(c(nvectors, ncells), ~ . * 1024*1024)) %>%
  mutate(across(c(vsize, vheapfree), ~ . * 8)) %>%
  #mutate(across(c(tick, time), na.approx)) %>%
  mutate(cells_total = ncells / cellspct * 100,
         vectors_total = nvectors / vectorspct * 100) %>%
  mutate(vsize80 = vsize * 0.8)

gcdata <- data %>% filter(is.na(rss))

ggplot(gcdata %>% filter(event=="gc"), aes(n)) +
  geom_point(aes(y=vsize - vheapfree, colour=level)) +
  labs(x="GC Cycle", y="Vectors used", colour="Level") +
  scale_y_continuous(labels = scales::label_bytes())
ggsave("gcinfo.png", width=20, scale=0.5)

ggplot(gcdata %>% filter(event=="gc"), aes(n)) +
  geom_point(aes(y=vsize - vheapfree, colour=level)) +
  geom_line(aes(y = value, linetype=name),
            data = ~ pivot_longer(., cols=c("vsize", "vsize80"))) +
  labs(x="GC Cycle", y="Vectors used", linetype="R_VSize", colour="Level") +
  scale_linetype_manual(values = c("solid", "dashed"), labels=c("100%", "80%")) +
  scale_y_continuous(labels = scales::label_bytes()) +
  guides(linetype = guide_legend(order=1),
         colour = guide_legend(order=2))
ggsave("gcinfo-line.png", width=20, scale=0.5)

ggplot(gcdata %>% filter(n >= 1000 & n < 1050), aes(n)) +
  geom_line(aes(y=vsize - vheapfree), colour="grey") +
  geom_point(aes(y=vsize - vheapfree, colour=level, shape=event), size = 3) +
  geom_line(aes(y = value, linetype=name),
            data = ~ pivot_longer(., cols=c("vsize", "vsize80"))) +
  labs(x="GC Cycle", y="Vectors used", linetype="R_VSize", colour="Level", shape="Will retry") +
  scale_linetype_manual(values = c("solid", "dashed"), labels=c("100%", "80%")) +
  scale_shape_manual(values = c("circle", "triangle"), labels=c("No", "Yes")) +
  scale_y_continuous(labels = scales::label_bytes()) +
  guides(linetype = guide_legend(order=1),
         colour = guide_legend(order=2),
         shape = guide_legend(order=3))
ggsave("gcinfo-line2.png", width=20, scale=0.7)
