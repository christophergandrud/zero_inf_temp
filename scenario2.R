# Load packages and functions --------------------------------------------------
library(xfun)
pkg_attach2("tidyverse", "bayesAB", "pscl", "parallel", "pwr")
theme_set(theme_linedraw())

source("functions.R")

# Scenario 2 simulations -------------------------------------------------------
#
# One set of simulations with all the estimation methods
sample_sizes <- c(4e5, 6e5, 8e5)
b_mu = 6.0565

# Find mean and prop difference
true_pop_scen2 <- one_ab_sim(1e8, b_mu = b_mu)
true_diff_ab_scen2 <- mean(true_pop_scen2$a) - mean(true_pop_scen2$b)
true_sd_a <- sd(true_pop_scen2$a)
true_sd_b <- sd(true_pop_scen2$b)
true_diff_pop_scen2 <- mean(ifelse(true_pop_scen2$a == 0, 0, 1)) -
    mean(ifelse(true_pop_scen2$b == 0, 0, 1))
rm(true_pop_scen2)

# One set of sims
scenario2_ls_one <- lapply(sample_sizes, FUN = one_ab_sim,
                           b_mu = b_mu)
scenario2_stats <- mclapply(scenario2_ls_one, compare_inference,
                             include_binary = TRUE,
                             mc.cores = 4) %>% bind_rows

# # Plot p-values
ggplot(scenario2_stats, aes(observations, p_value, group = estimate,
                             linetype = estimate)) +
     geom_hline(yintercept = 0.05, color = "green") +
     geom_line()
# ggsave(filename = "figs/p_values_scen1.png")

# Many simulations =============================================================
scen2_stats_multi_sim_list <- list()
for (i in 1:50) {
    message(i)
    scenario2_tmp <- lapply(sample_sizes, FUN = one_ab_sim,
                            b_mu = b_mu)
    scen2_stats_multi_sim_list[[i]] <- mclapply(scenario2_tmp, compare_inference,
                                      include_binary = TRUE,
                                      mc.cores = 4) %>% bind_rows
}
scen2_stats_multi_sim_df <- bind_rows(scen2_stats_multi_sim_list, .id = "column_label")

# Power observed across simulations
scen2_stats_multi_sim_df$sig_05 <- scen2_stats_multi_sim_df$p_value < 0.05
fnr <- scen2_stats_multi_sim_df %>% group_by(estimate, observations) %>%
    summarise(power = mean(sig_05)) 
fnr$column_label <- "fnr"

# Plot p-values ----------------------------------------------------------------
ggplot(scen2_stats_multi_sim_df, aes(observations, p_value,
                           group = column_label)) +
    facet_wrap(.~estimate) +
    geom_hline(yintercept = 0.05, color = "green") +
    geom_line(alpha = 0.5) +
    ylab("P-Value\n") + xlab("\nSample Size per Treatment Arm") +
    ggtitle("Scenario 2: 3.1% Difference in mean(B) > mean(A)\n(50 simulations per observation level)")
ggsave(filename = "figs/scen2_pvalues.png")

# Power (can we find any difference of the distributions) ----------------------
fnr$estimate <- factor(fnr$estimate,
                           levels = c("linear regression",
                                      "linear probability", 
                                      "zero-inf (count)",
                                      "zero-inf (zero)"),
                           labels = c("linear regression (original outcome)",
                                      "linear probability (0, 1 transformed outcome)",
                                      "zero-inflated negative binomial (count)",
                                      "zero-inlated negative binomial (zero)"))

ggplot(fnr, aes(observations, power)) +
    facet_wrap(.~ estimate) +
    geom_line() +
    geom_hline(yintercept = 0.8, linetype = "dotted") +
    scale_y_continuous(labels = scales::percent, breaks = seq(0.2, 1, 0.2)) +
    ggtitle("Power of Identifying A != B (50 simulations)",
            subtitle = "Scenario 2: Treatment causes a relative mean difference of 3.1%\nLeading to a difference of probability of non-zero outcome of 0.07%") +
    xlab("\nSample Size per Treatment Arm") +
    ylab("Power (for any difference A vs. B)\n")
ggsave(filename = "figs/scen2_power.png", width = 8, height = 8)
