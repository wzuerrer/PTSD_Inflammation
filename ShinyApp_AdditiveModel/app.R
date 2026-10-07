# =============================================================================
# app.R
# Shiny app: Influence of inflammation on symptom heterogeneity (additive model)
#
# To run locally: open this file in RStudio and click "Run App".
# model_functions.R must be in the same folder.
# =============================================================================

library(shiny)
library(ggplot2)
library(dplyr)

source("model_functions.R")

symptoms <- c("S1", "S2", "M", "W1", "W2")
symptom_names <- c(S1 = "S1 (strong indicator)", S2 = "S2 (strong indicator)",
                   M = "M (medium indicator)",  W1 = "W1 (weak indicator)",
                   W2 = "W2 (weak indicator)")

col_with    <- "#F97134"   # orange: with inflammation
col_without <- "#3498db"   # blue: without inflammation

# -----------------------------------------------------------------------------
# User interface
# -----------------------------------------------------------------------------
ui <- fluidPage(
  tags$head(tags$style(HTML("
    .purpose { color: #555; font-size: 15px; margin-bottom: 20px; }
    .check   { color: #555; font-size: 13px; margin: 6px 0 14px 0; }
    .btn-run { width: 100%; font-weight: bold; margin-bottom: 8px; }
    .btn-aux { width: 49%; }
    h4 { margin-top: 22px; }
    .explain { color: #555; font-size: 14px; margin-top: 30px; }
  "))),

  titlePanel("Simulation: Inflammation and symptom heterogeneity (additive model)"),

  div(class = "purpose",
      "Purpose: This simulation demonstrates how the effect of a biological factor ",
      "(inflammation, I) on each symptom changes the heterogeneity of symptom ",
      "combinations in a fictitious disorder. Diagnosed individuals with and without ",
      "inflammation are matched on total symptom severity, so that differences in ",
      "heterogeneity are not caused by differences in severity. Each run simulates ",
      format(FIXED$n, big.mark = ","), " individuals and is repeated ",
      DEFAULTS$n_sims, " times."),

  sidebarLayout(
    sidebarPanel(
      width = 4,
      h4("Effect of inflammation on each symptom (β", tags$sub("I"), ")",
         style = "margin-top: 0;"),
      lapply(symptoms, function(s) {
        sliderInput(paste0("beta_", s), symptom_names[s],
                    min = 0, max = 2, step = 0.1, value = DEFAULTS$beta_I[s])
      }),
      h4("Inflammation in the population"),
      sliderInput("p_I", "Probability of inflammation p(I)",
                  min = 0.1, max = 0.9, step = 0.1, value = DEFAULTS$p_I),
      sliderInput("cor_LI", "Correlation between disorder (L) and inflammation (I)",
                  min = 0, max = 0.9, step = 0.1, value = DEFAULTS$cor_LI),
      hr(),
      actionButton("run", "Run simulation", class = "btn-primary btn-run"),
      actionButton("reset", "Reset to defaults", class = "btn-aux"),
      actionButton("null", "Null scenario", class = "btn-aux"),
      helpText("The null scenario sets the effect of inflammation on all symptoms ",
               "to 0. Any remaining difference is not caused by inflammation itself.")
    ),

    mainPanel(
      width = 8,
      h4("Heterogeneity (Hill numbers)", style = "margin-top: 0;"),
      uiOutput("check_line"),
      tableOutput("hill_table"),
      h4("Probability of the symptom combinations"),
      plotOutput("combination_plot", height = "420px"),
      h4("Symptom combinations meeting diagnostic criteria"),
      tableOutput("combination_table")
    )
  ),

  div(class = "explain",
      tags$b("Inputs:"),
      tags$ul(
        tags$li("Effect of inflammation (β", tags$sub("I"), ") on each symptom, ",
                "from 0 (no effect) to 2. The effect of the disorder (β",
                tags$sub("L"), ") is fixed: strong for S1 and S2 (2.0, 1.8), medium ",
                "for M (1.2) and weak for W1 and W2 (0.6, 0.4)."),
        tags$li("Probability of inflammation p(I): share of the simulated population ",
                "with inflammation."),
        tags$li("Correlation between L and I: applies to the underlying continuous ",
                "values from which the binary variables are derived.")),
      tags$b("Fixed:"),
      tags$ul(
        tags$li(paste0("Probability of the disorder p(L) = ", FIXED$p_L,
                "; noise SD per symptom = 0.5, 0.5, 0.8, 1.0, 1.0 (S1, S2, M, W1, W2).")),
        tags$li(paste0("Symptom ratings 0–4; a symptom is present if its rating is ≥ ",
                FIXED$threshold, "; diagnosis requires ≥ ", FIXED$min_crit,
                " of 5 symptoms.")),
        tags$li(paste0("Matching: both groups are matched on the full distribution of total ",
                "severity (bins of ", FIXED$bin_width, ")."))),
      tags$b("Outputs:"),
      tags$ul(
        tags$li("Hill numbers: effective number of symptom combinations. q = 0 counts ",
                "all combinations equally (richness), q = 1 weights them by frequency ",
                "(exponential of Shannon), q = 2 emphasizes common combinations ",
                "(inverse Simpson). Difference = with minus without inflammation, ",
                "with 95% confidence interval across rounds. A negative difference ",
                "means the group with inflammation is less heterogeneous."),
        tags$li("Plot and table: mean share of each symptom combination per group ",
                "(error bars: SD across rounds). Combination codes give the presence ",
                "(1) or absence (0) of the symptoms in the order S1, S2, W1, W2, M."))
  )
)

# -----------------------------------------------------------------------------
# Server
# -----------------------------------------------------------------------------
server <- function(input, output, session) {

  # Buttons that set the sliders (the simulation runs only after "Run")
  observeEvent(input$reset, {
    for (s in symptoms) updateSliderInput(session, paste0("beta_", s),
                                          value = DEFAULTS$beta_I[s])
    updateSliderInput(session, "p_I", value = DEFAULTS$p_I)
    updateSliderInput(session, "cor_LI", value = DEFAULTS$cor_LI)
  })
  observeEvent(input$null, {
    for (s in symptoms) updateSliderInput(session, paste0("beta_", s), value = 0)
  })

  # Run the simulation when "Run" is clicked (and once at start with defaults)
  results <- eventReactive(input$run, {
    beta_I <- sapply(symptoms, function(s) input[[paste0("beta_", s)]])
    names(beta_I) <- symptoms
    withProgress(message = "Running simulation", value = 0, {
      run_additive_model(beta_I = beta_I, p_I = input$p_I, cor_LI = input$cor_LI,
                         progress = function(sim, n_sims) incProgress(1 / n_sims))
    })
  }, ignoreNULL = FALSE)

  output$check_line <- renderUI({
    r <- results()
    p <- r$params
    div(class = "check", HTML(paste0(
        "Settings of this run: &beta;<sub>I</sub> = ",
        paste(p$beta_I, collapse = " / "), " (S1/S2/M/W1/W2); p(I) = ", p$p_I,
        "; correlation = ", p$cor_LI, ".<br>",
        "Matched groups: ", round(r$checks$Mean_group_size[1]),
        " individuals each; mean severity ",
        sprintf("%.2f", r$checks$Mean_severity[1]), " (with I) vs ",
        sprintf("%.2f", r$checks$Mean_severity[2]), " (without I).")))
  })

  output$hill_table <- renderTable({
    h <- results()$hill_summary
    data.frame(
      Measure = h$Measure,
      `With inflammation` = sprintf("%.2f (%.2f)", h$With_I_Mean, h$With_I_SD),
      `Without inflammation` = sprintf("%.2f (%.2f)", h$Without_I_Mean, h$Without_I_SD),
      Difference = sprintf("%.2f", h$Difference),
      `95% CI` = sprintf("[%.2f, %.2f]", h$CI_95_Lower, h$CI_95_Upper),
      check.names = FALSE)
  }, align = "lcccc", striped = TRUE, width = "100%")

  output$combination_plot <- renderPlot({
    ct <- results()$combinations
    plot_data <- rbind(
      data.frame(Combination = ct$Combination, Mean = ct$With_I_Mean,
                 SD = ct$With_I_SD, Group = "With inflammation"),
      data.frame(Combination = ct$Combination, Mean = ct$Without_I_Mean,
                 SD = ct$Without_I_SD, Group = "Without inflammation"))
    plot_data$Combination <- factor(plot_data$Combination, levels = ct$Combination)

    ggplot(plot_data, aes(x = Combination, y = Mean, fill = Group)) +
      geom_col(position = position_dodge(width = 0.9)) +
      geom_errorbar(aes(ymin = pmax(Mean - SD, 0), ymax = Mean + SD),
                    position = position_dodge(width = 0.9), width = 0.25) +
      scale_fill_manual(values = c("With inflammation" = col_with,
                                   "Without inflammation" = col_without)) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
      labs(x = "Symptom combination (S1, S2, W1, W2, M)", y = "Probability",
           fill = NULL) +
      theme_bw(base_size = 13) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 10),
            panel.grid.major.x = element_blank(),
            panel.grid.minor = element_blank(),
            legend.position = "bottom")
  })

  output$combination_table <- renderTable({
    ct <- results()$combinations
    data.frame(
      Combination = ct$Combination,
      `With I: mean` = ct$With_I_Mean, `With I: SD` = ct$With_I_SD,
      `Without I: mean` = ct$Without_I_Mean, `Without I: SD` = ct$Without_I_SD,
      Difference = ct$Difference,
      check.names = FALSE)
  }, digits = 3, striped = TRUE)
}

shinyApp(ui, server)
