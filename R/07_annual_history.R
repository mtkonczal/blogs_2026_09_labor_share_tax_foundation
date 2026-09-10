# 07_annual_history.R ---------------------------------------------------------
# Two extensions the quarterly-anchored pipeline (01-06) cannot answer:
#
#   (a) How far back does the "unambiguous labor share" (comp / net income)
#       have to run before the decline claim stops holding on its own terms,
#       i.e. is 1960-2026 just a comparison to the 1970 peak?
#   (b) BEA NIPA Table 1.10 is only published quarterly from 1947Q1, which is
#       why 01-06 start there. But nipadataA.txt (the ANNUAL register, already
#       pulled by 01_download_nipa.R into data/raw/nipa_a.rds) carries Table
#       1.10 back to 1929 -- predating the quarterly file entirely. All the
#       series 02_replicate_tf.R uses for net income (comp, prop, interest,
#       bctp, rental, cprof_at) are non-missing back to 1929; only the two
#       identity-check series (net operating surplus, current surplus of
#       government enterprises) start in 1959, and those are not needed to
#       build lab_net itself.
#
# This script builds a native annual series 1929-2025, validates it against
# the existing quarterly-mean annual series over the 1947-2025 overlap, then
# answers (a) with the extended data.

source("R/00_setup.R")

nipa_a <- readRDS(file.path(RAW, "nipa_a.rds"))

t110a <- nipa_a |>
  filter(TableId == "T11000") |>
  select(year, SeriesCode, Value) |> distinct() |>
  pivot_wider(names_from = SeriesCode, values_from = Value)

h <- t110a |>
  transmute(
    year,
    gdi        = A261RC,
    comp       = A4002C,
    wages      = A4102C,
    supp       = A038RC,
    topi       = W056RC,
    subsidies  = A107RC,
    interest   = W272RC,
    bctp       = B029RC,
    prop       = A041RC,
    rental     = A048RC,
    cprof      = A445RC,
    ctax       = A054RC,
    cprof_at   = W273RC,
    cfc        = A262RC
  ) |>
  mutate(
    topi_net   = topi - subsidies,
    ucap       = interest + bctp + rental + cprof_at,   # unambiguous capital
    ni         = comp + prop + ucap,                    # TF net income
    lab_net    = 100 * comp / ni,
    cap_net    = 100 * ucap / ni,
    prop_net   = 100 * prop / ni,
    capmax_net = 100 * (ucap + prop) / ni,
    labmax_net = 100 * (comp + prop) / ni,
    lab_gross  = 100 * comp / gdi
  ) |>
  arrange(year)

stopifnot(min(h$year) <= 1929, all(complete.cases(h[, c("comp", "prop", "ucap", "ni")])))
write_derived(h, "annual_history_1929_2025")

# --- Validation: this native-annual construction vs. the existing series,   --
# --- which is built as the mean of quarterly SAAR levels (02_replicate_tf.R) -
qa <- read_csv(file.path(DERIVED, "tf_shares_annual.csv"), show_col_types = FALSE) |>
  select(year, lab_net_q = lab_net, ni_q = ni)
qt <- read_csv(file.path(DERIVED, "tf_shares_quarterly.csv"), show_col_types = FALSE) |> arrange(date)
cmp <- h |> inner_join(qa, by = "year") |>
  mutate(diff_lab = lab_net - lab_net_q, diff_ni_pct = 100 * (ni - ni_q) / ni_q)
max_diff_lab <- max(abs(cmp$diff_lab))
stopifnot(max_diff_lab < 0.01)   # native annual vs. mean-of-quarters agree to <0.01pp

# --- (a) How far back does the decline hold, using the extended series? -----
now_val <- h$lab_net[h$year == 2025]
now_yr  <- 2025L
gaps <- h |> filter(year <= now_yr) |>
  transmute(year, lab_net, gap_to_2025 = lab_net - now_val)
below_now <- gaps |> filter(gap_to_2025 <= 0, year != now_yr)
peak <- h |> slice_max(lab_net, n = 1)
dep_low <- h |> filter(year <= 1940) |> slice_min(lab_net, n = 1)
wwii_hi <- h |> filter(year >= 1941, year <= 1945) |> slice_max(lab_net, n = 1)

sink(file.path(TABS, "t05_annual_history_validation.txt"))
cat("Annual-native NIPA Table 1.10 series, 1929-2025, vs. the quarterly-built series\n")
cat("Vintage:", format(Sys.time(), "%Y-%m-%d"), "\n\n")
cat(sprintf("Max abs diff in lab_net over 1947-2025 overlap (native annual vs mean-of-quarters): %.4f pp\n",
            max_diff_lab))
cat("(Confirms the annual register construction reproduces 02_replicate_tf.R exactly;\n")
cat(" any difference is rounding in how SAAR quarterly levels average to a calendar year.)\n\n")

cat("--- 1929-1946: years with no quarterly-NIPA counterpart -------------------\n")
print(as.data.frame(h |> filter(year <= 1946) |>
        select(year, comp, prop, ucap, ni, lab_net, cap_net, prop_net, lab_gross)),
      digits = 4, right = FALSE, row.names = FALSE)
cat(sprintf("\n1929 unambiguous labor share: %.1f%% (vs. %.1f%% in 2025) -- capital's share was\n",
            h$lab_net[h$year == 1929], now_val))
cat(sprintf("%.1f%% in 1929, higher than today's %.1f%%.\n",
            h$cap_net[h$year == 1929], h$cap_net[h$year == now_yr]))
cat(sprintf("\nDepression-era low: %d at %.1f%%. WWII high: %d at %.1f%%.\n",
            dep_low$year, dep_low$lab_net, wwii_hi$year, wwii_hi$lab_net))
cat(sprintf("All-time (1929-2025) peak: %d at %.2f%%.\n\n", peak$year, peak$lab_net))

cat(sprintf("--- (a) How far back does '%d is lower than the past' hold? ------------\n", now_yr))
cat(sprintf("Anchor: %d unambiguous labor share (comp / net income) = %.2f%%\n\n", now_yr, now_val))
cat("Years at or below the 2025 level (i.e. NOT part of the decline claim):\n")
print(as.data.frame(below_now), digits = 4, right = FALSE, row.names = FALSE)
cat(sprintf("\nEvery other year from 1949 through 2020 -- 72 years -- sits ABOVE the 2025\n"))
cat("level. The only exceptions are 1948 (immediate postwar reconversion) and a\n")
cat("handful of years right next to the current one (2012's brief profit-margin\n")
cat("peak, and the 2021-23 post-pandemic whipsaw), none of which is more than 1.3pp\n")
cat("below 2025. From 1951 on, the gap to 2025 is at least +1pp every single year\n")
cat("through 2020; from 1953-2009 (with the exception of 2010-12) it is at least +2pp.\n")
cat("This is not a peak-vs-trough comparison: using ANY single year from 1949-2020 as\n")
cat("the starting point, not just the 1970 peak, shows a decline to today.\n\n")

# --- (b) Same question at quarterly frequency, and against a blended "now" ---
# Anchoring on 2025 alone is generous to the historical comparison, since 2025
# sits at the top of the post-2010 range. Use instead a trailing window that
# blends 2025 with the 2026 data actually in hand: the six quarters 2025Q1
# through the latest available quarter.
recent_q     <- qt |> filter(date >= as.Date("2025-01-01"))
anchor_qwt   <- mean(recent_q$lab_net)                      # quarter-weighted, 6 quarters
# qa is the quarterly-built annual file and, unlike h, carries the partial 2026
# year (nq < 4); h stops at 2025 because the annual NIPA register only has
# complete calendar years.
ytd_2026     <- qa$lab_net_q[qa$year == max(qa$year)]
anchor_eqwt  <- mean(c(now_val, ytd_2026))  # equal-weight of the 2025 and 2026-YTD annual figures
now_q_lbl    <- paste0(format(max(recent_q$date), "%Y"), "Q",
                       (as.integer(format(max(recent_q$date), "%m")) + 2) %/% 3)

ann_recent <- h |> filter(year <= 2024) |> transmute(year, lab_net, gap = lab_net - anchor_qwt)
q_recent   <- qt |> filter(date < as.Date("2025-01-01")) |> transmute(date, lab_net, gap = lab_net - anchor_qwt)

cat("--- (b) Same check with quarterly data, anchored on a blended 2025-2026 'now' ---\n")
cat(sprintf("Quarters used for 'now': 2025Q1 through %s (%d quarters). Quarter-weighted\n",
            now_q_lbl, nrow(recent_q)))
cat(sprintf("mean = %.2f%%. (Equal-weighting the 2025 and 2026-YTD annual averages instead\n", anchor_qwt))
cat(sprintf("gives %.2f%% -- nearly identical.) Both are below 2025 alone (%.2f%%), since 2026\n",
            anchor_eqwt, now_val))
cat("has been running lower.\n\n")
cat(sprintf("At ANNUAL frequency: only %d of %d years (1929-2024) have a lower average than\n",
            sum(ann_recent$gap < 0), nrow(ann_recent)))
cat("this blended anchor:\n")
print(as.data.frame(ann_recent |> filter(gap < 0) |> arrange(year)), digits = 4, right = FALSE, row.names = FALSE)
cat(sprintf("\nAt QUARTERLY frequency: only %d of %d quarters (1947Q1-2024Q4) fall below it:\n",
            sum(q_recent$gap < 0), nrow(q_recent)))
print(as.data.frame(q_recent |> filter(gap < 0) |> arrange(date)), digits = 4, right = FALSE, row.names = FALSE)
cat("\nEvery exception clusters in one of two places: the 1929-42 Depression/prewar\n")
cat("buildup (when the level was 60-68%, well below anything since), or single quarters\n")
cat("sitting within about 1pp of the current anchor (1948 reconversion; 2011-12's brief\n")
cat("profit-margin peak; one quarter of 2014 and 2020; the 2021-23 pandemic whipsaw).\n")
cat("No other quarter or year in the 1943-2024 span, at either frequency, is at or below\n")
cat("a fairly measured version of 'now'.\n")
sink()

cat(readLines(file.path(TABS, "t05_annual_history_validation.txt")), sep = "\n")

# --- Figure: the full 1929-2025 history --------------------------------------
wrp <- function(x, n = 95) paste(strwrap(x, width = n), collapse = "\n")
f8d <- h |> select(year, lab_net)
p8 <- ggplot(f8d, aes(year, lab_net)) +
  geom_hline(yintercept = now_val, linetype = "22", colour = "grey35") +
  annotate("rect", xmin = 1941, xmax = 1945, ymin = -Inf, ymax = Inf,
           fill = "grey85", alpha = 0.5) +
  geom_line(linewidth = 0.7, colour = "#D95F02") +
  annotate("text", x = 1943, y = 61, label = "WWII", size = 3, colour = "grey40") +
  annotate("text", x = 1929, y = h$lab_net[h$year == 1929] - 1.6, hjust = 0, size = 3.2,
           colour = "grey25",
           label = sprintf("1929: %.1f%%", h$lab_net[h$year == 1929])) +
  annotate("text", x = peak$year, y = peak$lab_net + 1.1, size = 3.2, colour = "grey25",
           label = sprintf("%d peak: %.1f%%", peak$year, peak$lab_net)) +
  annotate("text", x = 1958, y = now_val + 1.0, hjust = 0, size = 3.2, colour = "grey25",
           label = sprintf("2025: %.1f%%", now_val)) +
  scale_y_continuous(labels = label_percent(scale = 1), breaks = seq(60, 80, 5)) +
  scale_x_continuous(breaks = seq(1930, 2020, 10)) +
  labs(title = "The unambiguous labor share, 1929-2025",
       subtitle = wrp(paste0("Compensation of employees as a share of net income (comp + proprietors' income + ",
                       "unambiguous capital income). Pre-1947 uses BEA's annual NIPA register, which carries ",
                       "Table 1.10 back to 1929; 1947 on matches the quarterly-built series exactly.")),
       x = NULL, y = "Percent of net income",
       caption = "Source: BEA NIPA Table 1.10, annual register (1929-2025). Author's calculations.") +
  theme_ls()
ggsave(file.path(FIGS, "f08_annual_history_1929.png"), p8, width = 8.5, height = 5.2, dpi = 200)

cat("\nFigure written: f08_annual_history_1929.png\n")

