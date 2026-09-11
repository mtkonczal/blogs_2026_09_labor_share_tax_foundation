# 08_top1_comparison.R --------------------------------------------------------
# Does the labor/capital split mirror top-1% income concentration?
#
# Source: World Inequality Database (WID.world), variable sptinc992j
# (share of pretax national income, equal-split adults), percentile p99p100,
# area USA. Pulled via Our World in Data's WID mirror, which republishes the
# WID bulk extract as a flat CSV and requires no API key (WID's own API does,
# via wid_set_key()/WID_API_KEY, which this environment does not have).
# https://ourworldindata.org/grapher/income-share-top-1-before-tax-wid
#
# WID marks its most recent 1-2 years per country as nowcast/extrapolated
# from national-accounts growth rather than realized tax-return data; for the
# US that shows up as 2023 and 2024 repeating the identical 2022 value
# (20.73%). Flagged below and in the figure; not trimmed, consistent with how
# the rest of this project treats the partial-year 2026 observation.

source("R/00_setup.R")

wid_url  <- "https://ourworldindata.org/grapher/income-share-top-1-before-tax-wid.csv?country=USA"
wid_raw  <- file.path(RAW, "wid_top1_owid.csv")
download.file(wid_url, wid_raw, quiet = TRUE)
writeLines(
  c(paste("vintage:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste("source:", wid_url),
    "series: WID sptinc992j, p99p100, USA (share of pretax national income, equal-split adults)"),
  file.path(RAW, "wid_top1_owid.vintage.txt"))

top1 <- read_csv(wid_raw, show_col_types = FALSE) |>
  filter(Code == "USA") |>
  transmute(year = Year, top1 = `Share (richest 1%, before tax)`)

stopifnot(nrow(top1) > 0)
gaps <- setdiff(min(top1$year):max(top1$year), top1$year)
if (length(gaps) > 0) cat("WID USA series has gaps at:", gaps, "\n")

h <- read_csv(file.path(DERIVED, "annual_history_1929_2025.csv"), show_col_types = FALSE) |>
  select(year, cap_net)

d <- inner_join(h, top1, by = "year") |> arrange(year)
cat(sprintf("Overlap: %d-%d (%d years)\n", min(d$year), max(d$year), nrow(d)))

nowcast_yrs <- top1 |> filter(year >= 2023, top1 == top1[year == 2022]) |> pull(year)
if (length(nowcast_yrs) > 0)
  cat("WID nowcast years (repeat prior value, treat as provisional):", nowcast_yrs, "\n")

r_level  <- cor(d$cap_net, d$top1)
r_change <- cor(diff(d$cap_net), diff(d$top1))
cat(sprintf("Correlation, capital share of net income vs. top-1%% pretax national income share:\n"))
cat(sprintf("  levels 1929-%d: r = %.2f\n", max(d$year), r_level))
cat(sprintf("  year-over-year changes: r = %.2f\n", r_change))

write_derived(d, "top1_vs_capital_annual")

sink(file.path(TABS, "t06_top1_vs_capital.txt"))
cat("Capital share of net income (TF convention) vs. WID top-1% pretax national income share\n")
cat("Vintage:", format(Sys.time(), "%Y-%m-%d"), "\n\n")
cat(sprintf("Overlap: %d-%d (%d years). Correlation of levels: r = %.2f. Of annual changes: r = %.2f.\n\n",
            min(d$year), max(d$year), nrow(d), r_level, r_change))
cat("Selected years:\n")
print(as.data.frame(d |> filter(year %in% c(1929, 1944, 1970, 1980, 2000, 2007, 2010,
                                            2019, max(d$year)))),
      digits = 4, right = FALSE, row.names = FALSE)
cat(sprintf("\nWID's most recent %d year(s) for the US (%s) repeat the prior observation and are\n",
            length(nowcast_yrs), paste(nowcast_yrs, collapse = ", ")))
cat("WID nowcasts, not realized tax-return data; treat as provisional, as this project does\n")
cat("with its own partial-year 2026 observation elsewhere.\n")
sink()
cat(readLines(file.path(TABS, "t06_top1_vs_capital.txt")), sep = "\n")

# Figure: two stacked panels sharing an x-axis, not a dual-axis overlay -- a
# single scaled overlay lets you pick axis ranges to manufacture visual
# agreement, which is exactly the kind of trick this piece is arguing against
# elsewhere. Two panels, shared x range, let the reader compare co-movement
# in turning points without that.
wrp <- function(x, n = 95) paste(strwrap(x, width = n), collapse = "\n")
d8 <- d |>
  transmute(year,
            `Capital share of net income\n(TF convention)` = cap_net,
            `Top 1% share of pretax\nnational income (WID)` = top1) |>
  pivot_longer(-year)
lab8 <- d8 |> group_by(name) |> slice_max(year, n = 1) |> ungroup() |>
  mutate(short  = if_else(grepl("^Capital", name), "Capital share (TF)", "Top 1% share (WID)"),
         lab    = sprintf("%s  %.1f%%", short, value),
         y_lab  = value + if_else(short == "Capital share (TF)", 0.55, -0.55))

# Both series are already in comparable units -- percent of a national income
# aggregate -- and cover almost the same 10-23% range (see the correlation
# check above), so one shared axis is not a rescale-to-taste; a dual axis
# with independently chosen ranges would be.
p8 <- ggplot(d8, aes(year, value, colour = name)) +
  annotate("rect", xmin = 1941, xmax = 1945, ymin = -Inf, ymax = Inf,
           fill = "grey90", alpha = 0.5) +
  geom_vline(xintercept = min(nowcast_yrs) - 0.5, linetype = "22", colour = "grey70") +
  geom_line(linewidth = 0.7) +
  geom_text(data = lab8, aes(label = lab, y = y_lab),
            hjust = 0, nudge_x = 1.2, size = 3.2, fontface = "bold") +
  scale_colour_manual(values = c("Capital share of net income\n(TF convention)"  = "#1B4F72",
                                 "Top 1% share of pretax\nnational income (WID)" = "#B54708")) +
  scale_x_continuous(breaks = seq(1930, 2020, 10), limits = c(1929, max(d8$year) + 16),
                     expand = expansion(0)) +
  coord_cartesian(clip = "off") +
  labs(title = "The capital share and top-1% income concentration move together",
       subtitle = wrp(sprintf(paste0("Annual, 1929-%d. Correlation of levels r = %.2f; of year-over-year changes ",
                                     "r = %.2f. Dashed line marks WID's nowcast years for the US (%s), which ",
                                     "repeat the last observed value rather than realized tax data."),
                              max(d$year), r_level, r_change, paste(nowcast_yrs, collapse = "-")), 100),
       x = NULL, y = "Percent",
       caption = wrp(paste0("Source: BEA NIPA Table 1.10 (annual register); World Inequality Database, ",
                            "sptinc992j, p99p100, USA, via Our World in Data. Author's calculations."), 100)) +
  theme_ls() + theme(plot.margin = margin(6, 70, 6, 6))
ggsave(file.path(FIGS, "f09_top1_vs_capital.png"), p8, width = 9, height = 5.3, dpi = 200)
cat("\nFigure written: f09_top1_vs_capital.png\n")
