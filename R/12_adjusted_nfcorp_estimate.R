# 12_adjusted_nfcorp_estimate.R -----------------------------------------------
# Ad hoc, illustrative exercise (not a vetted pipeline figure): take the
# nonfinancial corporate net labor share exactly as used in Figure 3, and
# build a "best estimate" adjusted line applying two measurement critiques
# raised in the Twitter exchange (Pomerleau/Schneider/York) about the post:
#
#   (1) S-corp profit that's really disguised owner-manager wages
#       (Smith, Yagan, Zidar & Zwick 2022, AER: Insights)
#   (2) Equity-based compensation undercounted relative to true pay
#       (Eisfeldt, Falato & Xiaolan 2022, NBER Macroeconomics Annual)
#
# Both adjustments are built from the papers' own headline point estimates,
# scaled onto our own series with explicit, stated assumptions (documented
# inline and in the chart notes) -- this is NOT a replication of either
# paper's methodology on our data. Treat the adjusted line as a labeled
# back-of-envelope estimate, not a rigorously derived series.

source("R/00_setup.R")

ms <- read_csv(file.path(DERIVED, "measures_survey_quarterly.csv"), show_col_types = FALSE)
nf <- ms |> filter(id == "l_nfcorp_net_std") |> arrange(date) |>
  mutate(year = as.integer(format(date, "%Y")))

ann <- nf |> group_by(year) |> summarise(observed = mean(value), nq = n())
base <- mean(ann$observed[ann$year %in% 1947:1949])
latest_q <- nf |> slice_max(date, n = 1)
lastq_lbl <- paste0(format(latest_q$date, "%Y"), "Q", (as.integer(format(latest_q$date, "%m")) + 2) %/% 3)

cat(sprintf("1947-49 baseline: %.2f%%\n", base))
cat(sprintf("Latest quarter (%s): %.2f%%\n", lastq_lbl, latest_q$value))
cat(sprintf("Observed decline: %.2fpp\n\n", base - latest_q$value))

# --- Adjustment (1): S-corp recharacterized wages -----------------------------
# Smith/Yagan/Zidar/Zwick estimate $99B of aggregate S-corp profit was really
# owner-manager wages in 2017. We scale that dollar figure onto our own
# nonfinancial-corporate net-value-added base (rather than reuse their 0.89pp,
# which is measured against their broader all-corporate GROSS series) --
# nearly all S-corps are nonfinancial, so this is a reasonable rescaling.
nq_raw <- readRDS(file.path(RAW, "nipa_q.rds"))
t114 <- nq_raw |> filter(TableId == "T11400") |> select(date, SeriesCode, Value) |> distinct() |>
  pivot_wider(names_from = SeriesCode, values_from = Value)
x2017 <- t114 |> filter(format(date, "%Y") == "2017") |> summarise(nva = mean(A457RC), comp = mean(A460RC))
scorp_pp_2017 <- 100 * (x2017$comp + 99000) / x2017$nva - 100 * x2017$comp / x2017$nva
cat(sprintf("(1) S-corp adjustment, scaled to our NFC base: +%.2fpp in 2017\n", scorp_pp_2017))

# Phase-in: ~0 before the Tax Reform Act of 1986 (when S-corp election became
# broadly tax-advantaged), ramps linearly to the estimated 2017 value, held
# flat after 2017 (their paper doesn't extend further; no evidence used here
# to extrapolate a trend past their sample).
adj1 <- function(yr) {
  case_when(
    yr <= 1986 ~ 0,
    yr >= 2017 ~ scorp_pp_2017,
    TRUE ~ scorp_pp_2017 * (yr - 1986) / (2017 - 1986)
  )
}

# --- Adjustment (2): equity-based compensation --------------------------------
# Eisfeldt/Falato/Xiaolan find including equity pay reduces the MANUFACTURING
# labor-share decline (since the 1980s) by "about one-third." Manufacturing is
# their only tested sector; scaling this to the whole nonfinancial-corporate
# sector requires an assumption about how much of NFC activity is similarly
# equity-comp-heavy. Manufacturing alone has shrunk from roughly a third of
# nonfinancial-corporate value added in 1980 to under a fifth today (BEA
# manufacturing/GDP share, scaled by NFC's share of GDP) -- using that literal
# scope is a conservative floor, since it ignores that stock comp is at least
# as prevalent in information/tech and professional services today. Our "best
# estimate" widens the scope by assumption to roughly double manufacturing's
# weight, to proxy for those equity-comp-heavy nonmanufacturing sectors --
# this specific widening is our judgment call, not the paper's finding.
observed_decline_now <- base - latest_q$value
mfg_share_now  <- 0.17 * 2   # manufacturing alone ~17% of NFC value added today; doubled for tech/prof-services judgment call
mfg_share_1980 <- 0.33 * 2   # ~33% in 1980, same doubling
equity_pp_now  <- mfg_share_now * (1/3) * observed_decline_now
cat(sprintf("(2) Equity-comp adjustment, best estimate for latest quarter: +%.2fpp\n", equity_pp_now))

adj2 <- function(yr) {
  share <- case_when(
    yr <= 1980 ~ 0,
    yr >= max(ann$year) ~ mfg_share_now,
    TRUE ~ mfg_share_1980 + (mfg_share_now - mfg_share_1980) * (yr - 1980) / (max(ann$year) - 1980)
  )
  share * (1/3) * observed_decline_now
}

ann <- ann |> mutate(
  adj_scorp  = adj1(year),
  adj_equity = adj2(year),
  adjusted   = observed + adj_scorp + adj_equity
)

latest_adj <- ann |> slice_max(year, n = 1)
cat(sprintf("\nLatest year (%d) observed: %.2f%%, adjusted: %.2f%% (+%.2fpp total)\n",
            latest_adj$year, latest_adj$observed, latest_adj$adjusted,
            latest_adj$adj_scorp + latest_adj$adj_equity))
cat(sprintf("Observed decline from 1947-49: %.2fpp. Adjusted decline: %.2fpp.\n",
            base - latest_adj$observed, base - latest_adj$adjusted))
cat(sprintf("Share of the observed decline these two adjustments explain: %.0f%%\n",
            100 * (1 - (base - latest_adj$adjusted) / (base - latest_adj$observed))))

# --- Chart ---------------------------------------------------------------
wrp <- function(x, n = 100) paste(strwrap(x, width = n), collapse = "\n")
d <- ann |> select(year, Observed = observed, Adjusted = adjusted) |> pivot_longer(-year)
lab <- d |> group_by(name) |> slice_max(year, n = 1)

p <- ggplot(d, aes(year, value, colour = name)) +
  geom_line(linewidth = 0.8) +
  geom_point(data = lab, size = 1.8) +
  geom_text(data = lab, aes(label = sprintf("%s: %.1f%%", name, value)),
            hjust = 0, nudge_x = 1.5, size = 3.3, fontface = "bold") +
  scale_colour_manual(values = c(Observed = "#B54708", Adjusted = "#1B4F72")) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  scale_x_continuous(breaks = seq(1950, 2020, 10), limits = c(1947, max(d$year) + 14),
                     expand = expansion(0)) +
  coord_cartesian(clip = "off") +
  labs(title = "Nonfinancial corporate net labor share: observed vs. adjusted",
       subtitle = wrp(paste0(
         "Illustrative, author's back-of-envelope estimate -- not a replication of either paper's own method. ",
         "Adjustments: (1) S-corp profit that is really disguised owner-manager wages, phased in 1986-2017 ",
         "(Smith, Yagan, Zidar & Zwick 2022, AER: Insights, scaled from their $99B/2017 estimate); ",
         "(2) equity-based compensation undercounted as capital income, phased in 1980-present, scope widened ",
         "by assumption beyond the paper's manufacturing-only finding (Eisfeldt, Falato & Xiaolan 2022, NBER Macro Annual)."), 105),
       x = NULL, y = "Percent of net value added",
       caption = wrp(paste0("Source: BEA NIPA Table 1.14. Adjustment inputs from the cited papers; ",
                            "phase-in timing, dollar-to-our-series rescaling, and sector-scope widening are the author's assumptions, ",
                            "not the papers' own estimates -- treat as illustrative, not a rigorous correction."), 110)) +
  theme_ls() + theme(plot.margin = margin(6, 90, 6, 6), legend.position = "none")

ggsave(file.path(PROJ, "output", "figures", "exploratory", "adjusted_nfcorp_labor_share.png"),
       p, width = 9, height = 5.6, dpi = 200)
cat("\nFigure written: output/figures/exploratory/adjusted_nfcorp_labor_share.png\n")
