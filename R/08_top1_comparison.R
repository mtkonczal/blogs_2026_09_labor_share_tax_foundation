# 08_top1_comparison.R --------------------------------------------------------
# Does the labor/capital split mirror top-1% income concentration?
#
# Top-1% series: share of *wage income only* (Table B2, wages/salaries/tips,
# including bonuses and exercised stock options), from Thomas Piketty and
# Emmanuel Saez, "Income Inequality in the United States, 1913-1998," QJE
# 118(1), 2003, 1-39, updated tables (TabFig2024.xlsx, eml.berkeley.edu/~saez).
# Chosen over the WID total-pretax-income top-1% share used previously because
# that series mixes labor and capital income -- a chunk of it *is* the same
# capital income being compared against, so co-movement was partly mechanical.
# Wage income has no such overlap with the capital share.
#
# The tradeoff: Table B2 is not updated past 2011 (the SSA-based Table B5
# alternative only starts in 1990 and stops in 2016 -- shorter on both ends).
# So the wage-income line here necessarily stops in 2011; the capital-share
# line runs the full 1929-2024 as before. Two series, two different end
# points, plotted on their own line each rather than joined/truncated to a
# common range, so the recent (2012-2024) capital-share move still shows even
# though there's no post-2011 wage-only comparison for it.

source("R/00_setup.R")
suppressPackageStartupMessages(library(readxl))

# Downloaded fresh each run, like the WID pull this replaces -- data/raw/ is
# gitignored as regenerable, and this file is too large (2.7MB) to want
# committed anyway. Saez posts it at a stable URL under his own site.
xlsx_url  <- "https://eml.berkeley.edu/~saez/TabFig2024.xlsx"
xlsx_path <- file.path(RAW, "TabFig2024.xlsx")
download.file(xlsx_url, xlsx_path, quiet = TRUE, mode = "wb")
writeLines(
  c(paste("vintage:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste("source:", xlsx_url),
    "series: Table B2, P99-100 (top 1% share of wage income: wages, salaries, tips, bonuses, exercised stock options)"),
  file.path(RAW, "TabFig2024.vintage.txt"))

wage <- read_excel(xlsx_path, sheet = "Table B2", skip = 4, col_names = FALSE) |>
  transmute(year = as.integer(...1), top1_wage = ...5) |>
  filter(!is.na(year), !is.na(top1_wage))
stopifnot(nrow(wage) > 0)
cat(sprintf("Table B2 top-1%% wage share: %d-%d (%d years)\n", min(wage$year), max(wage$year), nrow(wage)))

h <- read_csv(file.path(DERIVED, "annual_history_1929_2025.csv"), show_col_types = FALSE) |>
  select(year, cap_net)

# Full range from the capital-share series; wage share is NA past 2011 so its
# line simply stops there rather than truncating the capital-share line too.
d <- h |> left_join(wage, by = "year") |> arrange(year)

ov <- d |> filter(!is.na(top1_wage))
cat(sprintf("Overlap with wage data: %d-%d (%d years)\n", min(ov$year), max(ov$year), nrow(ov)))
r_level  <- cor(ov$cap_net, ov$top1_wage)
r_change <- cor(diff(ov$cap_net), diff(ov$top1_wage))
cat(sprintf("Correlation, capital share of net income vs. top-1%% wage-income share, %d-%d:\n",
            min(ov$year), max(ov$year)))
cat(sprintf("  levels: r = %.2f\n", r_level))
cat(sprintf("  year-over-year changes: r = %.2f\n", r_change))

write_derived(d, "top1_vs_capital_annual")

sink(file.path(TABS_BLOG, "t06_top1_vs_capital.txt"))
cat("Capital share of net income (TF convention) vs. Piketty-Saez top-1% wage-income share\n")
cat("Vintage:", format(Sys.time(), "%Y-%m-%d"), "\n\n")
cat(sprintf("Wage-income series covers %d-%d (Table B2, TabFig2024.xlsx); capital share runs 1929-%d.\n",
            min(wage$year), max(wage$year), max(d$year)))
cat(sprintf("Overlap %d-%d (%d years). Correlation of levels: r = %.2f. Of annual changes: r = %.2f.\n\n",
            min(ov$year), max(ov$year), nrow(ov), r_level, r_change))
cat("Selected years:\n")
print(as.data.frame(d |> filter(year %in% c(1929, 1944, 1970, 1980, 2000, 2007, 2010, max(ov$year)))),
      digits = 4, right = FALSE, row.names = FALSE)
sink()
cat(readLines(file.path(TABS_BLOG, "t06_top1_vs_capital.txt")), sep = "\n")

# Figure: capital share (full 1929-2024 arc) against top-1% wage-income share
# (1929-2011, where the underlying tax-return tabulation stops). Two separate
# line layers, not one joined-then-pivoted series, so the capital-share line
# isn't truncated to match the shorter wage series.
wrp <- function(x, n = 95) paste(strwrap(x, width = n), collapse = "\n")
lab_cap  <- d |> slice_max(year, n = 1)
lab_wage <- ov |> slice_max(year, n = 1)

p8 <- ggplot() +
  annotate("rect", xmin = 1941, xmax = 1945, ymin = -Inf, ymax = Inf,
           fill = "grey90", alpha = 0.5) +
  geom_line(data = d,  aes(year, cap_net),  colour = "#1B4F72", linewidth = 0.7) +
  geom_line(data = ov, aes(year, top1_wage), colour = "#B54708", linewidth = 0.7) +
  geom_text(data = lab_cap, hjust = 0, nudge_x = 1.2, size = 3.2, fontface = "bold",
            colour = "#1B4F72", aes(year, cap_net, label = sprintf("Capital share (TF)  %.1f%%", cap_net))) +
  geom_text(data = lab_wage, hjust = 0, nudge_x = 1.2, size = 3.2, fontface = "bold",
            colour = "#B54708", aes(year, top1_wage, label = sprintf("Top 1%% wage share, %d  %.1f%%", year, top1_wage))) +
  scale_x_continuous(breaks = seq(1930, 2020, 10), limits = c(1929, max(d$year) + 20),
                     expand = expansion(0)) +
  coord_cartesian(clip = "off") +
  labs(title = "Figure 5. The capital share and top-1% income concentration move together",
       subtitle = wrp(sprintf(paste0("Annual. Capital share of net income, 1929-%d. Top 1%% share of wage income only ",
                                     "(no capital income), 1929-%d -- the tax-return tabulation this relies on is not ",
                                     "updated past %d. Correlation over the %d-%d overlap: levels r = %.2f, ",
                                     "year-over-year changes r = %.2f."),
                              max(d$year), max(ov$year), max(ov$year), min(ov$year), max(ov$year), r_level, r_change), 100),
       x = NULL, y = "Percent",
       caption = wrp(paste0("Source: BEA NIPA Table 1.10 (annual register); Piketty & Saez (2003, QJE), updated ",
                            "tables, Table B2, wage income only. Author's calculations."), 100)) +
  theme_ls() + theme(plot.margin = margin(6, 90, 6, 6))
ggsave(file.path(FIGS_BLOG, "figure5_top1_vs_capital.png"), p8, width = 9, height = 5.3, dpi = 200)
cat("\nFigure written: figure5_top1_vs_capital.png\n")
