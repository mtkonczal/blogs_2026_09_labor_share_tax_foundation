# 05_figures.R ---------------------------------------------------------------
source("R/00_setup.R")

qv <- read_csv(file.path(DERIVED, "variants_quarterly.csv"), show_col_types = FALSE)
qt <- read_csv(file.path(DERIVED, "tf_shares_quarterly.csv"), show_col_types = FALSE)
va <- read_csv(file.path(DERIVED, "variants_annual.csv"),   show_col_types = FALSE)
sd <- read_csv(file.path(DERIVED, "sector_decomposition_annual.csv"), show_col_types = FALSE)

lastq  <- paste0(format(max(qt$date), "%Y"), "Q",
                 (as.integer(format(max(qt$date), "%m")) + 2) %/% 3)
# label for the partial final year used in the annual/decomposition series
nq_last  <- sum(as.integer(format(qt$date, "%Y")) == max(as.integer(format(qt$date, "%Y"))))
yr_last  <- max(as.integer(format(qt$date, "%Y")))
lasty_lb <- if (nq_last == 4) as.character(yr_last) else
            paste0(yr_last, if (nq_last <= 2) "H1" else paste0("Q1-Q", nq_last))
cap_src <- paste0("Source: BEA NIPA Tables 1.10, 1.13, 1.14. Quarterly, SAAR, through ",
                  lastq, ". Author's calculations.")

sv <- function(p, f, w = 8, h = 5) ggsave(file.path(FIGS, f), p, width = w, height = h, dpi = 200)

# Right-margin labelling helpers: extend the x range for direct labels but keep
# axis breaks inside the data range so the panel does not show empty decades.
dmin <- min(qt$date); dmax <- max(qt$date)
brks <- seq(as.Date("1950-01-01"), dmax, by = "10 years")
xr   <- function(frac) scale_x_date(limits = c(dmin, dmax + frac * as.numeric(dmax - dmin)),
                                    breaks = brks, date_labels = "%Y", expand = expansion(0))
wrp  <- function(x, n = 95) paste(strwrap(x, width = n), collapse = "\n")

# F1 - replication of the TF three-way split ---------------------------------
f1d <- qt |> select(date, Labor = lab_net, Capital = cap_net, Proprietors = prop_net) |>
  pivot_longer(-date)
lab1 <- f1d |> group_by(name) |> slice_max(date, n = 1)
p1 <- ggplot(f1d, aes(date, value, colour = name)) +
  geom_line(linewidth = 0.7) +
  geom_text(data = lab1, aes(label = sprintf("%s  %.1f%%", name, value)),
            hjust = 0, nudge_x = 400, size = 3.4, fontface = "bold") +
  scale_colour_brewer(palette = "Dark2") +
  scale_y_continuous(labels = label_percent(scale = 1), breaks = seq(0, 80, 10)) +
  xr(0.15) +
  coord_cartesian(clip = "off") +
  labs(title = "Replication: the Tax Foundation three-way split of net income",
       subtitle = wrp("Shares of net income: GDI less depreciation, taxes on production and imports, and corporate income taxes"),
       x = NULL, y = "Percent of net income", caption = cap_src) +
  theme_ls() + theme(plot.margin = margin(6, 90, 6, 6))
sv(p1, "f01_tf_replication.png")

# F2 - net vs gross ----------------------------------------------------------
f2d <- qt |> select(date, `Net income (TF)` = lab_net, `Gross domestic income` = lab_gross) |>
  pivot_longer(-date)
lab2 <- f2d |> group_by(name) |> slice_max(date, n = 1)
p2 <- ggplot(f2d, aes(date, value, colour = name)) +
  geom_line(linewidth = 0.7) +
  geom_text(data = lab2, aes(label = sprintf("%s\n%.1f%%", name, value)),
            hjust = 0, nudge_x = 400, size = 3.3, fontface = "bold", lineheight = 0.95) +
  scale_colour_brewer(palette = "Set1") +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  xr(0.16) +
  coord_cartesian(clip = "off") +
  labs(title = "The gross-versus-net correction raises the level, not much else",
       subtitle = wrp("Compensation of employees as a share of net income and of gross domestic income"),
       x = NULL, y = "Percent", caption = cap_src) +
  theme_ls() + theme(plot.margin = margin(6, 100, 6, 6))
sv(p2, "f02_net_vs_gross.png")

# F3 - the bounds close over time (the Gollin problem) -----------------------
f3d <- qv |> select(date, `All proprietors' income to labor` = v2_labmax,
                    `Proprietors' income 75% labor` = v3_prop75,
                    `Compensation only (TF headline)` = v1_tf) |>
  pivot_longer(-date)
lab3 <- f3d |> group_by(name) |> slice_max(date, n = 1)
p3 <- ggplot(f3d, aes(date, value, colour = name)) +
  geom_line(linewidth = 0.7) +
  geom_text(data = lab3, aes(label = sprintf("%s\n%.1f%%", name, value)),
            hjust = 0, nudge_x = 400, size = 3.1, fontface = "bold", lineheight = 0.95) +
  scale_colour_brewer(palette = "Dark2") +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  xr(0.20) +
  coord_cartesian(clip = "off") +
  labs(title = "The \"round trip\" survives only if proprietors' income is treated as capital",
       subtitle = wrp(paste0("Labor share of net income under three allocations of proprietors' income, which fell ",
                            "from 18% of net income in 1947-49 to 9% today")),
       x = NULL, y = "Percent of net income", caption = cap_src) +
  theme_ls() + theme(plot.margin = margin(6, 118, 6, 6))
sv(p3, "f03_proprietor_bounds.png")

# F3b - two-line version, 1960 onward, proprietors' income split 50/50 -------
f3bd <- qt |>
  filter(date >= as.Date("1960-01-01")) |>
  transmute(date,
            # TF's own label: their chart calls the mirror series the
            # "unambiguous capital share", so this is the matching name.
            `Unambiguous labor share`       = 100 * comp / ni,
            `Proprietors' income 50% labor` = 100 * (comp + 0.5 * prop) / ni) |>
  pivot_longer(-date)
lab3b <- f3bd |> group_by(name) |> slice_max(date, n = 1)
d60   <- min(f3bd$date)
# subtitle arithmetic, computed so it cannot drift from the data
b60 <- qt |> filter(format(date, "%Y") == "1960") |>
  summarise(tf = mean(100 * comp / ni), p50 = mean(100 * (comp + 0.5 * prop) / ni),
            prop = mean(prop_net))
bnw <- qt |> slice_max(date, n = 1) |>
  transmute(tf = 100 * comp / ni, p50 = 100 * (comp + 0.5 * prop) / ni, prop = prop_net)
d3b <- list(chg_tf = bnw$tf - b60$tf, chg_50 = bnw$p50 - b60$p50,
            prop60 = b60$prop, prop_now = bnw$prop)
p3b <- ggplot(f3bd, aes(date, value, colour = name)) +
  geom_line(linewidth = 0.7) +
  geom_text(data = lab3b, aes(label = sprintf("%s\n%.1f%%", name, value)),
            hjust = 0, nudge_x = 300, size = 3.2, fontface = "bold", lineheight = 0.95) +
  scale_colour_manual(values = c("Unambiguous labor share"       = "#D95F02",
                                 "Proprietors' income 50% labor" = "#7570B3")) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  scale_x_date(limits = c(d60, dmax + 0.20 * as.numeric(dmax - d60)),
               breaks = seq(as.Date("1960-01-01"), dmax, by = "10 years"),
               date_labels = "%Y", expand = expansion(0)) +
  coord_cartesian(clip = "off") +
  labs(title = "The labor share since 1960, splitting proprietors' income down the middle",
       subtitle = wrp(paste0("Unambiguous labor share = compensation of employees / net income. Net income = ",
                             "gross domestic income less depreciation, production taxes net of subsidies, ",
                             "corporate income taxes and the government enterprise surplus. The second line ",
                             "adds half of proprietors' income to the numerator."),
                      82),
       x = NULL, y = "Percent of net income", caption = cap_src) +
  theme_ls() + theme(plot.margin = margin(6, 118, 6, 6))
sv(p3b, "f03b_proprietor_bounds_1960.png", h = 5.3)

# F4 - corporate sector ------------------------------------------------------
f4d <- qv |> select(date, `TF convention (net of production and corporate tax)` = v8_corp_tf,
                    `Net of production taxes` = v8_corp_extax,
                    `Compensation / net value added` = v8_corp_std) |>
  pivot_longer(-date)
lab4 <- f4d |> group_by(name) |> slice_max(date, n = 1)
p4 <- ggplot(f4d, aes(date, value, colour = name)) +
  geom_line(linewidth = 0.7) +
  geom_text(data = lab4, aes(label = sprintf("%.1f%%", value)),
            hjust = 0, nudge_x = 300, size = 3.3, fontface = "bold") +
  scale_colour_brewer(palette = "Dark2", name = NULL) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  xr(0.05) +
  coord_cartesian(clip = "off") +
  labs(title = "In the corporate sector there is no round trip",
       subtitle = wrp("Corporate labor share: no proprietors' income and no imputed rent to allocate"),
       x = NULL, y = "Percent", caption = cap_src) +
  theme_ls() + theme(legend.position = "top", legend.text = element_text(size = 8),
                     plot.margin = margin(6, 34, 6, 6))
sv(p4, "f04_corporate_sector.png")

# F5 - shift-share -----------------------------------------------------------
era <- function(yrs) {
  sd |> filter(year %in% yrs) |>
    summarise(across(c(ni, comp, ni_corp, lab_corp, ni_govnp, lab_govnp, ni_oth, lab_oth), mean))
}
A <- era(1947:1949); B <- era(max(sd$year))
mk <- function(z) with(z, tibble(
  L = 100 * comp / ni,
  w_corp = ni_corp/ni, l_corp = 100*lab_corp/ni_corp,
  w_gov  = ni_govnp/ni, l_gov = 100*lab_govnp/ni_govnp,
  w_oth  = ni_oth/ni,  l_oth = 100*lab_oth/ni_oth))
A <- mk(A); B <- mk(B)
sec <- c("corp","gov","oth")
nm  <- c(corp = "Corporate", gov = "Government &\nnonprofit", oth = "Other private\n(noncorporate)")
f5d <- bind_rows(
  tibble(sector = nm[sec], part = "Within sector\n(labor share moved)",
         v = sapply(sec, function(s) mean(c(A[[paste0("w_",s)]], B[[paste0("w_",s)]])) *
                                     (B[[paste0("l_",s)]] - A[[paste0("l_",s)]]))),
  tibble(sector = nm[sec], part = "Between sector\n(weight moved)",
         v = sapply(sec, function(s) mean(c(A[[paste0("l_",s)]], B[[paste0("l_",s)]])) *
                                     (B[[paste0("w_",s)]] - A[[paste0("w_",s)]]))))
p5 <- ggplot(f5d, aes(sector, v, fill = part)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_col(position = position_dodge(0.75), width = 0.65) +
  geom_text(aes(label = sprintf("%+.1f", v), vjust = ifelse(v > 0, -0.4, 1.3)),
            position = position_dodge(0.75), size = 3.2) +
  scale_fill_brewer(palette = "Paired", name = NULL) +
  labs(title = "The round trip is a cancellation, not a stable labor share",
       subtitle = wrp(sprintf(paste0("Change in the TF net labor share, 1947-49 to %s: %+.1f pp, the sum of %+.1f pp ",
                                     "within sectors and %+.1f pp from shifting composition"),
                          lasty_lb, B$L - A$L, sum(f5d$v[f5d$part == "Within sector\n(labor share moved)"]),
                          sum(f5d$v[f5d$part == "Between sector\n(weight moved)"])), 88),
       x = NULL, y = "Contribution, percentage points", caption = cap_src) +
  theme_ls() + theme(legend.position = "top")
sv(p5, "f05_shift_share.png", w = 8, h = 5.2)

# F6 - capital share, with and without rental income of persons --------------
f6d <- qv |> mutate(`Unambiguous capital (TF)` = 100 * NA) |>
  select(date, `Ex rental income of persons` = cap_exhouse) |>
  left_join(qt |> select(date, `Unambiguous capital (TF)` = cap_net), by = "date") |>
  pivot_longer(-date)
lab6 <- f6d |> group_by(name) |> slice_max(date, n = 1)
p6 <- ggplot(f6d, aes(date, value, colour = name)) +
  geom_line(linewidth = 0.7) +
  geom_text(data = lab6, aes(label = sprintf("%s\n%.1f%%", name, value)),
            hjust = 0, nudge_x = 400, size = 3.2, fontface = "bold", lineheight = 0.95) +
  scale_colour_brewer(palette = "Set2") +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  xr(0.19) +
  coord_cartesian(clip = "off") +
  labs(title = "Taking housing out lowers the capital share but not its rise",
       subtitle = wrp("Unambiguous capital share of net income, as published and excluding rental income of persons"),
       x = NULL, y = "Percent of net income", caption = cap_src) +
  theme_ls() + theme(plot.margin = margin(6, 112, 6, 6))
sv(p6, "f06_capital_ex_housing.png")

# F7 - the level claim: how precedented is today, on their own measure? -------
# Annual series, with a reference line at the latest quarter. The point of the
# figure is that exactly one year in 79 sits at or below it, and it is 1948.
a7   <- read_csv(file.path(DERIVED, "tf_shares_annual.csv"), show_col_types = FALSE)
now7 <- qt |> slice_max(date, n = 1) |> pull(lab_net)
below <- a7 |> filter(lab_net <= now7, year < max(year))
m0007 <- mean(a7$lab_net[a7$year >= 2000 & a7$year <= 2007])
pk7   <- a7 |> slice_max(lab_net, n = 1)

p7 <- ggplot(a7 |> filter(year < max(year)), aes(year, lab_net)) +
  geom_hline(yintercept = now7, linetype = "22", colour = "grey35") +
  geom_line(linewidth = 0.8, colour = "#D95F02") +
  geom_point(data = below, size = 2.6, colour = "#1B4F72") +
  geom_text(data = below, aes(label = year), vjust = 1.9, size = 3.1,
            colour = "#1B4F72", fontface = "bold") +
  annotate("text", x = 1952, y = now7 + 0.45, hjust = 0, size = 3.3, colour = "grey25",
           label = sprintf("2026Q2: %.1f%%", now7)) +
  annotate("segment", x = 2003.5, xend = 2003.5, y = m0007, yend = now7,
           arrow = arrow(length = unit(0.16, "cm"), ends = "both"), colour = "grey35") +
  annotate("text", x = 2001.5, y = (m0007 + now7) / 2, hjust = 1, size = 3.2, colour = "grey25",
           label = sprintf("2000-07 avg\nto now:\n%.1f pp", now7 - m0007)) +
  annotate("text", x = pk7$year + 1.5, y = pk7$lab_net + 0.35, hjust = 0, size = 3.2,
           colour = "grey25", label = sprintf("%d peak: %.1f%%", pk7$year, pk7$lab_net)) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  scale_x_continuous(breaks = seq(1950, 2020, 10), limits = c(1946, 2029)) +
  labs(title = wrp(sprintf(paste0("On the Tax Foundation's own measure, %d of 79 years sits at or below ",
                                  "today's labor share"), nrow(below)), 78),
       subtitle = wrp(paste0("Compensation of employees as a share of net income, annual. Dashed line is the ",
                             "latest quarter. The only precedent for it is 1948.")),
       x = NULL, y = "Percent of net income", caption = cap_src) +
  theme_ls()
sv(p7, "f07_how_precedented.png", w = 8, h = 5)

cat("Figures written to", FIGS, "\n"); print(list.files(FIGS))
