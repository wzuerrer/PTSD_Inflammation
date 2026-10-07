# =============================================================================
# model_functions.R
# Additive model: influence of inflammation (I) on symptom heterogeneity
#
# This file contains the simulation from Inflammation_AdditiveModel_Code.Rmd,
# packaged as one function, run_additive_model(). The code inside is the same
# as in the .Rmd; only the parameters that the user may change are now
# function arguments. Everything else is fixed (see "Fixed parameters" below).
#
# Used by: app.R (Shiny app). Can also be used for the flexibility analyses.
# =============================================================================

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(MASS))

# -----------------------------------------------------------------------------
# Fixed parameters (assumptions of the model, not adjustable in the app)
# -----------------------------------------------------------------------------
FIXED <- list(
  n          = 10000,                                    # individuals per round
  p_L        = 0.8,                                      # probability of the disorder (L)
  beta_L     = c(S1 = 2.0, S2 = 1.8, M = 1.2, W1 = 0.6, W2 = 0.4),  # effect of L
  sd_noise   = c(S1 = 0.5, S2 = 0.5, M = 0.8, W1 = 1.0, W2 = 1.0),  # noise SD
  mean_noise = 2,                                        # noise mean
  threshold  = 2,                                        # rating >= 2: symptom present
  min_crit   = 2,                                        # >= 2 of 5 symptoms: diagnosis
  bin_width  = 0.5                                       # severity matching bins
)

# Default values of the adjustable parameters (= values of the .Rmd)
DEFAULTS <- list(
  beta_I = c(S1 = 0.6, S2 = 0.5, M = 0.7, W1 = 0.5, W2 = 0.3),
  p_I    = 0.5,
  cor_LI = 0.6,
  n_sims = 100,
  seed   = 123
)

# All 32 possible combinations of the 5 binary symptom criteria
# Labels such as "11001" (order: S1, S2, W1, W2, M)
combinations <- expand.grid(S1 = c(0, 1), S2 = c(0, 1), W1 = c(0, 1),
                            W2 = c(0, 1), M = c(0, 1))
combination_labels <- apply(combinations, 1, paste0, collapse = "")

# -----------------------------------------------------------------------------
# Helper functions (unchanged from the .Rmd)
# -----------------------------------------------------------------------------

# Linearly rescale values to a range from 0 to 4
rescale <- function(x) {
  (x - min(x)) / (max(x) - min(x)) * 4
}

# Generate two correlated binary variables (correlation of underlying normals)
generate_correlated_binary <- function(n, p1, p2, cor) {
  sigma <- matrix(c(1, cor, cor, 1), 2, 2)
  bvn <- mvrnorm(n, mu = c(0, 0), Sigma = sigma)
  L <- ifelse(bvn[, 1] > qnorm(1 - p1), 1, 0)
  I <- ifelse(bvn[, 2] > qnorm(1 - p2), 1, 0)
  data.frame(L = L, I = I)
}

# Hill number of order q (effective number of combinations)
calculate_hill <- function(probabilities, q) {
  p <- probabilities[probabilities > 0]
  p <- p / sum(p)
  if (q == 1) exp(-sum(p * log(p))) else sum(p^q)^(1 / (1 - q))
}

# Share of each of the 32 symptom combinations in a group
calculate_combination_shares <- function(data) {
  combination <- paste0(as.integer(data$S1_positive),
                        as.integer(data$S2_positive),
                        as.integer(data$W1_positive),
                        as.integer(data$W2_positive),
                        as.integer(data$M_positive))
  counts <- table(factor(combination, levels = combination_labels))
  as.numeric(counts) / sum(counts)
}

# -----------------------------------------------------------------------------
# Main function
# -----------------------------------------------------------------------------
# Arguments (the adjustable parameters):
#   beta_I   named vector: effect of I on S1, S2, M, W1, W2
#   p_I      probability of inflammation
#   cor_LI   correlation between L and I (underlying continuous values)
#   n_sims   number of simulation rounds
#   seed     random seed (same inputs + same seed = same results)
#   progress optional function called after each round, e.g. for a
#            progress bar in Shiny: progress(sim, n_sims)
#
# Returns a list with:
#   hill_summary  table: Hill q = 0, 1, 2 per group, difference, 95% CI
#   hill_rounds   Hill numbers of every round (for plots or further analyses)
#   combinations  mean and SD share of each combination per group
#   checks        mean group size and mean severity per group
#   params        the parameters used in this run
# -----------------------------------------------------------------------------
run_additive_model <- function(beta_I   = DEFAULTS$beta_I,
                               p_I      = DEFAULTS$p_I,
                               cor_LI   = DEFAULTS$cor_LI,
                               n_sims   = DEFAULTS$n_sims,
                               seed     = DEFAULTS$seed,
                               progress = NULL) {

  set.seed(seed)
  n <- FIXED$n
  bL <- FIXED$beta_L
  sdn <- FIXED$sd_noise
  mn <- FIXED$mean_noise

  # Storage
  shares_WITH    <- matrix(0, nrow = n_sims, ncol = 32)
  shares_WITHOUT <- matrix(0, nrow = n_sims, ncol = 32)
  hill_rounds <- data.frame(round = 1:n_sims,
                            q0_with = NA, q1_with = NA, q2_with = NA,
                            q0_without = NA, q1_without = NA, q2_without = NA)
  n_WITH <- n_WITHOUT <- sev_WITH <- sev_WITHOUT <- numeric(n_sims)

  for (sim in 1:n_sims) {
    # Latent variables L (disorder) and I (inflammation)
    latent <- generate_correlated_binary(n, p1 = FIXED$p_L, p2 = p_I, cor = cor_LI)
    L <- latent$L
    I <- latent$I

    # Symptoms: additive effects of L and I plus noise, rescaled to 0-4
    S1 <- rescale(bL["S1"] * L + beta_I["S1"] * I + rnorm(n, mn, sdn["S1"]))
    S2 <- rescale(bL["S2"] * L + beta_I["S2"] * I + rnorm(n, mn, sdn["S2"]))
    M  <- rescale(bL["M"]  * L + beta_I["M"]  * I + rnorm(n, mn, sdn["M"]))
    W1 <- rescale(bL["W1"] * L + beta_I["W1"] * I + rnorm(n, mn, sdn["W1"]))
    W2 <- rescale(bL["W2"] * L + beta_I["W2"] * I + rnorm(n, mn, sdn["W2"]))

    # Symptom presence, diagnosis and severity
    data <- data.frame(L, I, S1, S2, W1, W2, M) %>%
      mutate(S1_positive = S1 >= FIXED$threshold,
             S2_positive = S2 >= FIXED$threshold,
             W1_positive = W1 >= FIXED$threshold,
             W2_positive = W2 >= FIXED$threshold,
             M_positive  = M  >= FIXED$threshold,
             criteria_met = S1_positive + S2_positive + W1_positive +
                            W2_positive + M_positive)

    filtered_data <- data %>%
      filter(criteria_met >= FIXED$min_crit) %>%
      mutate(severity = S1 + S2 + M + W1 + W2)

    filtered_WITH_I    <- filtered_data %>% filter(I == 1)
    filtered_WITHOUT_I <- filtered_data %>% filter(I == 0)

    # Severity matching on the full distribution (bins of 0.5)
    breaks <- seq(0, 20, by = FIXED$bin_width)
    filtered_WITH_I <- filtered_WITH_I %>%
      mutate(bin = cut(severity, breaks, include.lowest = TRUE))
    filtered_WITHOUT_I <- filtered_WITHOUT_I %>%
      mutate(bin = cut(severity, breaks, include.lowest = TRUE))

    n_per_bin <- inner_join(count(filtered_WITH_I, bin, name = "n_with"),
                            count(filtered_WITHOUT_I, bin, name = "n_without"),
                            by = "bin") %>%
      mutate(n_take = pmin(n_with, n_without))

    filtered_WITH_I <- filtered_WITH_I %>%
      inner_join(n_per_bin, by = "bin") %>%
      group_by(bin) %>%
      filter(row_number() %in% sample(n(), first(n_take))) %>%
      ungroup()
    filtered_WITHOUT_I <- filtered_WITHOUT_I %>%
      inner_join(n_per_bin, by = "bin") %>%
      group_by(bin) %>%
      filter(row_number() %in% sample(n(), first(n_take))) %>%
      ungroup()

    # Group sizes and severity (check that matching worked)
    n_WITH[sim]      <- nrow(filtered_WITH_I)
    n_WITHOUT[sim]   <- nrow(filtered_WITHOUT_I)
    sev_WITH[sim]    <- mean(filtered_WITH_I$severity)
    sev_WITHOUT[sim] <- mean(filtered_WITHOUT_I$severity)

    # Combination shares and Hill numbers
    shares_WITH[sim, ]    <- calculate_combination_shares(filtered_WITH_I)
    shares_WITHOUT[sim, ] <- calculate_combination_shares(filtered_WITHOUT_I)
    for (q in 0:2) {
      hill_rounds[sim, paste0("q", q, "_with")]    <- calculate_hill(shares_WITH[sim, ], q)
      hill_rounds[sim, paste0("q", q, "_without")] <- calculate_hill(shares_WITHOUT[sim, ], q)
    }

    if (!is.null(progress)) progress(sim, n_sims)
  }

  # --- Summary of Hill numbers: mean, SD, difference and 95% CI ---
  hill_summary <- do.call(rbind, lapply(0:2, function(q) {
    w  <- hill_rounds[[paste0("q", q, "_with")]]
    wo <- hill_rounds[[paste0("q", q, "_without")]]
    d  <- w - wo
    se <- sd(d) / sqrt(n_sims)
    data.frame(Measure = c("Hill q = 0 (richness)",
                           "Hill q = 1 (exp Shannon)",
                           "Hill q = 2 (inverse Simpson)")[q + 1],
               With_I_Mean = mean(w),  With_I_SD = sd(w),
               Without_I_Mean = mean(wo), Without_I_SD = sd(wo),
               Difference = mean(d),
               CI_95_Lower = mean(d) - 1.96 * se,
               CI_95_Upper = mean(d) + 1.96 * se)
  }))

  # --- Mean and SD share of each combination (only >= 2 symptoms) ---
  combination_table <- data.frame(
    Combination  = combination_labels,
    With_I_Mean    = colMeans(shares_WITH),
    With_I_SD      = apply(shares_WITH, 2, sd),
    Without_I_Mean = colMeans(shares_WITHOUT),
    Without_I_SD   = apply(shares_WITHOUT, 2, sd)) %>%
    filter(rowSums(combinations) >= FIXED$min_crit) %>%
    mutate(Difference = With_I_Mean - Without_I_Mean) %>%
    arrange(desc(With_I_Mean + Without_I_Mean))
  rownames(combination_table) <- NULL

  list(hill_summary = hill_summary,
       hill_rounds  = hill_rounds,
       combinations = combination_table,
       checks = data.frame(Group = c("With inflammation", "Without inflammation"),
                           Mean_group_size = c(mean(n_WITH), mean(n_WITHOUT)),
                           Mean_severity   = c(mean(sev_WITH), mean(sev_WITHOUT))),
       params = list(beta_I = beta_I, p_I = p_I, cor_LI = cor_LI,
                     n_sims = n_sims, seed = seed))
}
