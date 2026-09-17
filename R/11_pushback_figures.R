# 11_pushback_figures.R -------------------------------------------------------
# Figures for labor_share_pushback.md. All quarterly, full 1947Q1-latest
# history -- no annual aggregation, matching how the post itself argues.
# Reads only already-committed derived CSVs (tf_shares_quarterly.csv,
# variants_quarterly.csv, measures_survey_quarterly.csv); does not require
# re-running 01_download_nipa.R.

source("R/00_setup.R")

qt <- read_csv(file.path(DERIVED, "tf_shares_quarterly.csv"),      show_col_types = FALSE)
qv <- read_csv(file.path(DERIVED, "variants_quarterly.csv"),       show_col_types = FALSE)
ms <- read_csv(file.path(DERIVED, "measures_survey_quarterly.csv"), show_col_types = FALSE)

qt <- qt |> mutate(v50 = 100 * (comp + 0.5 * prop) / ni)

lastq <- paste0(format(max(qt$date), "%Y"), "Q", (as.integer(format(max(qt$date), "%m")) + 2) %/% 3)
cap_src <- paste0("Source: BEA NIPA Table 1.10 (1.14 for the nonfinancial-corporate line). Quarterly, 1947Q1-", lastq, ".")

sv <- function(p, f, w = 8, h = 5) ggsave(file.path(FIGS_BLOG, f), p, width = w, height = h, dpi = 200)

# Datawrapper CSV per figure, same convention as 09_datawrapper_export.R (one
# tidy wide file per chart, numbers rounded to 3dp), just written alongside
# the figures they match instead of duplicating their construction there.
DW_BLOG <- file.path(PROJ, "output", "datawrapper", "blogpost")
dir.create(DW_BLOG, recursive = TRUE, showWarnings = FALSE)
dw <- function(x, name) {
  x <- x |> mutate(across(where(is.double), \(v) round(v, 3)))
  write_csv(x, file.path(DW_BLOG, paste0(name, ".csv")))
  invisible(x)
}

dmin <- min(qt$date); dmax <- max(qt$date)
brks <- seq(as.Date("1950-01-01"), dmax, by = "10 years")
xr   <- function(frac) scale_x_date(limits = c(dmin, dmax + frac * as.numeric(dmax - dmin)),
                                    breaks = brks, date_labels = "%Y", expand = expansion(0))
wrp  <- function(x, n = 95) paste(strwrap(x, width = n), collapse = "\n")

# --- Validation stats printed alongside the figures, so the numbers quoted in
# --- the post are pinned to this exact run ------------------------------------
era <- function(x, d, lo, hi) mean(x[d >= as.Date(lo) & d <= as.Date(hi)])
rank_low <- function(x) sum(x <= dplyr::last(x))

# Net of depreciation only, not production taxes: comp / net value added
# (NIPA Table 1.14), the standard net-value-added convention.
nf <- ms |> filter(id == "l_nfcorp_net_std") |> arrange(date)

cat("=== Stats for labor_share_pushback.md ===\n")
cat(sprintf("TF net labor share (0%% prop): 1950-99 quarterly avg %.1f, 2000-%s avg %.1f, latest %.1f, rank %d of %d\n",
            era(qt$lab_net, qt$date, "1950-01-01", "1999-12-01"), lastq,
            era(qt$lab_net, qt$date, "2000-01-01", "2100-01-01"),
            dplyr::last(qt$lab_net), rank_low(qt$lab_net), nrow(qt)))
cat(sprintf("50%% prop:  latest %.2f, rank %d of %d (1 = record low)\n", dplyr::last(qt$v50), rank_low(qt$v50), nrow(qt)))
cat(sprintf("100%% prop: latest %.2f, rank %d of %d\n", dplyr::last(qv$v2_labmax), rank_low(qv$v2_labmax), nrow(qv)))
cat(sprintf("50%% prop, total economy: 1947-49 avg %.1f, 2010s avg %.1f, latest %.1f (record low, %s)\n",
            era(qt$v50, qt$date, "1947-01-01", "1949-12-01"), era(qt$v50, qt$date, "2010-01-01", "2019-12-01"),
            dplyr::last(qt$v50), format(qt$date[which.min(qt$v50)])))
cat(sprintf("Nonfinancial corporate, net: 1947-49 avg %.1f, 2010s avg %.1f, latest %.1f (record low, %s)\n",
            era(nf$value, nf$date, "1947-01-01", "1949-12-01"), era(nf$value, nf$date, "2010-01-01", "2019-12-01"),
            dplyr::last(nf$value), format(nf$date[which.min(nf$value)])))

# Figure 1 - the Tax Foundation's own measure, full quarterly arc ------------------
f10d <- qt |> select(date, lab_net)
lab10 <- f10d |> slice_max(date, n = 1)
p10 <- ggplot(f10d, aes(date, lab_net)) +
  geom_line(linewidth = 0.7, colour = "#D95F02") +
  geom_point(data = lab10, size = 1.8, colour = "#D95F02") +
  geom_text(data = lab10, aes(label = sprintf("%s: %.1f%%", lastq, lab_net)),
            hjust = 0, nudge_x = 400, size = 3.4, fontface = "bold", colour = "#D95F02") +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  xr(0.14) +
  coord_cartesian(clip = "off") +
  labs(title = "Figure 1. The Tax Foundation's own \"unambiguous\" labor share",
       subtitle = wrp("Compensation of employees as a share of net income (gross domestic income less depreciation and taxes), their exact convention, every quarter since 1947"),
       x = NULL, y = "Percent of net income", caption = cap_src) +
  theme_ls() + theme(plot.margin = margin(6, 95, 6, 6))
sv(p10, "figure1_tf_share_quarterly.png", w = 8.5)
f10d |> transmute(date, `Labor share of net income (TF convention)` = lab_net) |>
  dw("figure1_tf_share_quarterly")

# Figure 2 - 0% / 50% / 100% of proprietors' income to labor -----------------------
f11w <- qt |> transmute(date, `0% (their measure)` = lab_net, `50%` = v50) |>
  left_join(qv |> transmute(date, `100%` = v2_labmax), by = "date")
dw(f11w, "figure2_proprietor_0_50_100_quarterly")
f11d <- f11w |> pivot_longer(-date)
f11d$name <- factor(f11d$name, levels = c("0% (their measure)", "50%", "100%"))
lab11 <- f11d |> group_by(name) |> slice_max(date, n = 1)
p11 <- ggplot(f11d, aes(date, value, colour = name)) +
  geom_line(linewidth = 0.7) +
  geom_text(data = lab11, aes(label = sprintf("%s\n%.1f%%", name, value)),
            hjust = 0, nudge_x = 400, size = 3.1, fontface = "bold", lineheight = 0.95) +
  scale_colour_brewer(palette = "Dark2") +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  xr(0.20) +
  coord_cartesian(clip = "off") +
  labs(title = "Figure 2. Their measure with 0%, 50%, and 100% of proprietors' income as labor income",
       subtitle = wrp("Same net-income denominator throughout; only how proprietors' income is split between labor and capital changes"),
       x = NULL, y = "Percent of net income", caption = cap_src) +
  theme_ls() + theme(plot.margin = margin(6, 105, 6, 6))
sv(p11, "figure2_proprietor_0_50_100_quarterly.png", w = 8.5)

# Figure 3 - the nonfinancial corporate measure that shows the "not without precedent" claim breaking -
f12d <- nf |> select(date, value)
ref12 <- mean(f12d$value[f12d$date <= as.Date("1949-12-01")])
lab12 <- f12d |> slice_max(date, n = 1)
p12 <- ggplot(f12d, aes(date, value)) +
  geom_hline(yintercept = ref12, linetype = "22", linewidth = 0.4, colour = "#B54708") +
  geom_line(linewidth = 0.7, colour = "#B54708") +
  geom_point(data = lab12, size = 1.8, colour = "#B54708") +
  geom_text(data = lab12, aes(label = sprintf("%s: %.1f%%", lastq, value)),
            hjust = 0, nudge_x = 400, size = 3.4, fontface = "bold", colour = "#B54708") +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  xr(0.16) +
  coord_cartesian(clip = "off") +
  labs(title = "Figure 3. The \"not without precedent\" measure, updated",
       subtitle = wrp(paste0("Nonfinancial corporate net labor share (net of depreciation only). Dotted line marks its own ",
                             "1947-49 average -- the basis for the literature's \"net share is within its historical range\" ",
                             "finding (Bridgman 2018; Rognlie 2015) -- and it is now below it, at the lowest reading in the series."), 88),
       x = NULL, y = "Percent of net value added", caption = cap_src) +
  theme_ls() + theme(plot.margin = margin(6, 95, 6, 6))
sv(p12, "figure3_not_without_precedent_quarterly.png", w = 8.5, h = 5)
f12d |> transmute(date,
                   `Nonfinancial corporate net labor share (net of depreciation)` = value,
                   `1947-49 average` = ref12) |>
  dw("figure3_not_without_precedent_quarterly")

cat("\nFigures written: figure1_tf_share_quarterly.png, figure2_proprietor_0_50_100_quarterly.png, figure3_not_without_precedent_quarterly.png\n")
cat("Datawrapper CSVs written to", DW_BLOG, ":", list.files(DW_BLOG), "\n")
