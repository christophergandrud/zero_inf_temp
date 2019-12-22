# Load packages and functions --------------------------------------------------
library(xfun)
pkg_attach2("tidyverse", "bayesAB", "pscl", "parallel", "pwr")
theme_set(theme_linedraw())

source("functions.R")

# Scenario 1 simulations -------------------------------------------------------
#
# One set of simulations with all the estimation methods
sample_sizes <- c(1e5, 2e5, 3e5, 4e5, 6e5, 8e5) 
b_prob_non_zero <- 0.555

# Find mean and prop difference
true_pop_scen1 <- one_ab_sim(1e8, b_prob_non_zero = b_prob_non_zero)
true_diff_ab_scen1 <- mean(true_pop_scen1$a) - mean(true_pop_scen1$b)
prop_1_a <- mean(ifelse(true_pop_scen1$a == 0, 0, 1))
prop_1_b <- mean(ifelse(true_pop_scen1$b == 0, 0, 1))
true_diff_pop_scen1 <- prop_1_a - prop_1_b
rm(true_pop_scen1)

# scenario1_ls_one <- lapply(sample_sizes, FUN = one_ab_sim,
#                        b_prob_non_zero = b_prob_non_zero)
# 
# scenario1_stats <- mclapply(list(scenario1_ls_one[[1]]), compare_inference, 
#                             include_binary = TRUE, 
#                             mc.cores = 4) %>% bind_rows
# 
# test <- scenario1_ls_one[[6]]



# # Plot p-values
# ggplot(scenario1_stats, aes(observations, p_value, group = estimate,
#                             linetype = estimate)) +
#     geom_hline(yintercept = 0.05, color = "green") +
#     geom_line()
# ggsave(filename = "figs/p_values_scen1.png")

# Many simulations =============================================================
scen1_stats_multi_sim__list <- list()
for (i in 1:50) {
    message(i)
    scenario1_tmp <- lapply(sample_sizes, FUN = one_ab_sim,
                           b_prob_non_zero = b_prob_non_zero)
    scen1_stats_multi_sim__list[[i]] <- mclapply(scenario1_tmp, compare_inference,
                                      include_binary = TRUE, 
                                      include_zero_prob = TRUE,
                                      mc.cores = 4) %>% bind_rows
}
scen1_stats_multi_sim__df <- bind_rows(scen1_stats_multi_sim__list, .id = "column_label")

# scen1_fnr <- bind_rows(
#     scen1_stats_multi_sim__df[, c("column_label", "estimate", "observations", "p_value")], 
#     fnr)

# Plot p-values ----------------------------------------------------------------
ggplot(scen1_stats_multi_sim__df, aes(observations, p_value,
                      group = column_label)) +
    facet_wrap(.~estimate) +
    geom_hline(yintercept = 0.05, color = "green") +
    geom_line(alpha = 0.5) +
    ylab("P-Value\n") + xlab("\nSample Size per Treatment Arm") +
    ggtitle("Scenario 1: 1% Difference in Pr(B) > Pr(A)\n(50 simulations per observation level)")
ggsave(filename = "figs/scen1_pvalues.png")

# Power (can we find any difference of the distributions) ----------------------

# Power observed across simulations
scen1_stats_multi_sim__df$sig_05 <- scen1_stats_multi_sim__df$p_value < 0.05
fnr <- scen1_stats_multi_sim__df %>% group_by(estimate, observations) %>%
    summarise(power = mean(sig_05)) 
fnr$column_label <- "fnr"

# Difference of means power test
cohens_d <- true_diff_ab_scen1 / sqrt((6.722465^2 + 6.749058^2) / 2)
power_t <- function(x, d = cohens_d) {
    pwr.t.test(n = x, d = cohens_d)$power
}

# Difference of proportions power test
h <- 2 * asin(sqrt(prop_1_a)) - 2 * asin(sqrt(prop_1_b))
power_prop <- function(x) {
    pwr.2p.test(h = h, n = x)$power
}

t_power <- tibble(
    estimate = "t-test power",
    observations = sample_sizes,
    power = modify(sample_sizes, power_t),
    column_label = "fnr"
)

prop_power <- tibble(
    estimate = "difference of proportions power",
    observations = sample_sizes,
    power = modify(sample_sizes, power_prop),
    column_label = "fnr"
)

fnr <- bind_rows(fnr, t_power, prop_power)

# fnr_sub <- subset(fnr, estimate != "zero-inf (count)")
fnr$estimate <- factor(fnr$estimate, 
                           levels = c("t-test power", 
                                      "difference of proportions power", 
                                      "linear regression", 
                                      "linear probability", 
                                      "zero-inf (count)",
                                      "zero-inf (zero)"),
                           labels = c("t-test power (not from simulation)", 
                                      "difference of prop. power (not from sim.)",
                                      "linear regression (original outcome)",
                                      "linear probability (0, 1 transformed outcome)", 
                                      "zero-inflated negative binomial (count)",
                                      "zero-inflated negative binomial (zero)"))

ggplot(fnr, aes(observations, power)) +
    facet_wrap(.~ estimate, ncol = 2) +
    geom_line() +
    geom_hline(yintercept = 0.8, linetype = "dotted") +
    scale_y_continuous(labels = scales::percent, breaks = seq(0.2, 1, 0.2)) +
    ggtitle("Power of Identifying A != B (50 simulations)",
            subtitle = "Scenario 1: Treatment causes 0.1% increase in probability of a non-zero outcome.\nThis creates a relative mean difference of 3.1%") +
    xlab("\nSample Size per Treatment Arm") +
    ylab("Power (post hoc, for any difference A vs. B)\n")
ggsave(filename = "figs/scen1_power.png", width = 6, height = 8)

# # Bias of parameter point estimate 
# # (either difference of means or probability of any non-zero values)
# true_diff_mean <- abs(true_diff_ab_scen1)
# true_diff_prob <- b_prob_non_zero - 0.55
# 
# logit2prob <- function(beta){
#     odds <- exp(beta)
#     odds / (1 + odds)
# }
# 
# logit2prob <- function(odds){
#      odds / (1 + odds)
# }
# 
# 
# linear <- scen1_stats_multi_sim__df %>% filter(estimate == "linear regression")
# hist(linear$param_est - true_diff_mean)
# 
# linear_prob <- scen1_stats_multi_sim__df %>% filter(estimate == "linear probability")
# hist(linear_prob$param_est - true_diff_prob)
# 
# zero_prob <- scen1_stats_multi_sim__df %>% filter(estimate == "zero-inf (zero)")
# zero_prob <- logit2prob(zero_prob$param_est)
# 
# hist(zero_prob$param_est -  true_diff_prob)
