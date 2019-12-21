# Simulate data from a zero-inflated negative binomial
sim_zeroinf <- function(nsims = 100000, prob_non_zero = 0.55, mu = 6, size = 0.6) {
    # Zeros or not
    z <- rbinom(n = nsims, size = 1, prob = prob_non_zero)

    ifelse(z == 0, 0, rnbinom(n = nsims, mu = mu, size = size))
}

one_ab_sim <- function(nsims = 100000,
                       a_prob_non_zero = 0.55, a_mu = 6, a_size = 0.6,
                       b_prob_non_zero = 0.55, b_mu = 6, b_size = 0.6) {
    data.frame(
        a = sim_zeroinf(
            nsims = nsims, prob_non_zero = a_prob_non_zero, mu = a_mu, size = a_size
        ),
        b = sim_zeroinf(
            nsims = nsims, prob_non_zero = b_prob_non_zero, mu = b_mu, size = b_size
        )
    )
}

compare_inference <- function(data, only_linear = FALSE,
                              include_binary = FALSE) {
    obs <- nrow(data)
    message(obs)

    data_long <- pivot_longer(data, everything(), names_to = "variant",
                              values_to = "y")
    # Linear regression
    fitted_linear <- lm(y ~ variant, data = data_long)
    linear_stats <- tibble(
        estimate = "linear regression",
        param_est = fitted_linear$coefficients[[2]],
        p_value = summary(fitted_linear)$coefficients[2, 4]
    )
    out <- linear_stats
    
    if (!isTRUE(only_linear)) {
        # Zero-inflated negative binomial
        fitted_zeroinf <- zeroinfl(y ~ variant, dist = "negbin", data = data_long)
        sum_zeroinf <- summary(fitted_zeroinf)
        zeroinf_stats_count <- tibble(
            estimate = "zero-inf (count)",
            param_est = sum_zeroinf$coefficients$count[2, 1],
            p_value = sum_zeroinf$coefficients$count[2, 4]
        )
        zeroinf_stats_zero <- tibble(
            estimate = "zero-inf (zero)",
            param_est = sum_zeroinf$coefficients$zero[2, 1],
            p_value = sum_zeroinf$coefficients$zero[2, 4]
        )
        out <- bind_rows(out, zeroinf_stats_count, zeroinf_stats_zero)
    }
    if (include_binary) {
        data_long$binary <- ifelse(data_long$y == 0, 0, 1)
        fitted_linear_prob <- lm(binary ~ variant, data = data_long)
        linear_stats_prob <- tibble(
            estimate = "linear probability",
            param_est = fitted_linear_prob$coefficients[[2]],
            p_value = summary(fitted_linear_prob)$coefficients[2, 4]
        )
        out <- bind_rows(out, linear_stats_prob)
    }

    out$observations <- obs
    return(out)
}
