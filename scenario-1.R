# Load packages and functions --------------------------------------------------
library(xfun)
pkg_attach2("tidyverse", "bayesAB", "pscl", "parallel", "gghighlight")
theme_set(theme_linedraw())

source("functions.R")

# Scenario 1 simulations -------------------------------------------------------
#
# One set of simulations with all the estimation methods
scenario1_ls_one <- lapply(seq(1e5, 8e5, by = 2e5), FUN = one_ab_sim,
                       b_prob_non_zero = 0.555)

scenario1_stats <- mclapply(scenario1_ls_one, compare_inference, 
                            include_binary = TRUE,
                            mc.cores = 4) %>% bind_rows

# Plot p-values
ggplot(scenario1_stats, aes(observations, p_value, group = estimate,
                            linetype = estimate)) +
    geom_hline(yintercept = 0.05, color = "green") +
    geom_line()
ggsave(filename = "figs/p_values_scen1.png")

# P-values from linear model across many simulations
linear_only_list <- list()
for (i in 1:10) {
    message(i)
    scenario1_tmp <- lapply(seq(1e5, 8e5, by = 2e5), FUN = one_ab_sim,
                           b_prob_non_zero = 0.555)
    linear_only_list[[i]] <- mclapply(scenario1_tmp, compare_inference,
                                      include_binary = TRUE,
                                      mc.cores = 4) %>% bind_rows
}
linear_only_df <- bind_rows(linear_only_list, .id = "column_label")

# Rate central tendancy
linear_only_df$sig_05 <- linear_only_df$p_value < 0.05
fnr <- linear_only_df %>% group_by(estimate, observations) %>%
    summarise(p_value = 1 - mean(sig_05))
fnr$column_label <- "fnr"

scen1_fnr <- bind_rows(
    linear_only_df[, c("column_label", "estimate", "observations", "p_value")], 
    fnr)

# ggplot(scen1_fnr, aes(observations, p_value, 
#                       group = column_label)) +
#     geom_hline(yintercept = 0.05, color = "green") +
#     geom_line(alpha = 0.5) +
#     ggtitle("Scenario 1: 1% Difference in Pr(B) > Pr(A)\n(10 simulations per observation level)")

fnr_sub <- subset(fnr, estimate != "zero-inf (count)")

ggplot(fnr_sub, aes(observations, p_value)) +
    facet_wrap(.~ estimate) +
    geom_line() +
    geom_hline(yintercept = 0.2, linetype = "dotted") +
    ggtitle("Scenario 1 (10 simulations)") +
    xlab("\nSample Size") +
    ylab("Power (post hoc, for any difference A vs. B)\n")
ggsave(filename = "figs/scen1_power.png")
