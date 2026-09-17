# 09_datawrapper_export.R ------------------------------------------------------
# Tidy, wide, human-labeled CSVs for each figure -- one file per chart, ready to
# drop straight into Datawrapper's "Upload data" step. Reads only the tracked
# data/derived/ files, not the raw NIPA/WID pulls, so this doesn't require
# re-running 01-08.

source("R/00_setup.R")

# Split the same way as output/figures/ and output/tables/: "blogpost" (F8-F9,
# which feed labor_share_pushback.md) vs. "secondary" (F1-F7, which feed
# docs/replication_and_literature.md and docs/factcheck.qmd).
DW_BLOG <- file.path(PROJ, "output", "datawrapper", "blogpost")
DW_SEC  <- file.path(PROJ, "output", "datawrapper", "secondary")
for (d in c(DW_BLOG, DW_SEC)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

qt <- read_csv(file.path(DERIVED, "tf_shares_quarterly.csv"), show_col_types = FALSE)
qa <- read_csv(file.path(DERIVED, "tf_shares_annual.csv"),   show_col_types = FALSE)
qv <- read_csv(file.path(DERIVED, "variants_quarterly.csv"), show_col_types = FALSE)
sd <- read_csv(file.path(DERIVED, "sector_decomposition_annual.csv"), show_col_types = FALSE)
h  <- read_csv(file.path(DERIVED, "annual_history_1929_2025.csv"), show_col_types = FALSE)
t1 <- read_csv(file.path(DERIVED, "top1_vs_capital_annual.csv"), show_col_types = FALSE)

dw <- function(x, name, dir = DW_SEC) {
  x <- x |> mutate(across(where(is.double), \(v) round(v, 3)))
  write_csv(x, file.path(dir, paste0(name, ".csv")))
  invisible(x)
}

# F1 - the three-way split -----------------------------------------------------
qt |>
  transmute(date, Labor = lab_net, Capital = cap_net, Proprietors = prop_net) |>
  dw("f01_tf_replication")

# F2 - net vs gross --------------------------------------------------------
qt |>
  transmute(date, `Net income (TF)` = lab_net, `Gross domestic income` = lab_gross) |>
  dw("f02_net_vs_gross")

# F3 - proprietor-income bounds ------------------------------------------------
qv |>
  transmute(date,
            `All proprietors' income to labor`  = v2_labmax,
            `Proprietors' income 75% labor`      = v3_prop75,
            `Compensation only (TF headline)`    = v1_tf) |>
  dw("f03_proprietor_bounds")

# F3b - 1960 on, 50/50 split ---------------------------------------------------
qt |>
  filter(date >= as.Date("1960-01-01")) |>
  transmute(date,
            `Unambiguous labor share`       = 100 * comp / ni,
            `Proprietors' income 50% labor` = 100 * (comp + 0.5 * prop) / ni) |>
  dw("f03b_proprietor_bounds_1960")

# F4 - corporate sector ---------------------------------------------------
qv |>
  transmute(date,
            `TF convention (net of production and corporate tax)` = v8_corp_tf,
            `Net of production taxes`                             = v8_corp_extax,
            `Compensation / net value added`                      = v8_corp_std) |>
  dw("f04_corporate_sector")

# F5 - shift-share, 1947-49 to latest year -------------------------------------
era <- function(yrs) {
  sd |> filter(year %in% yrs) |>
    summarise(across(c(ni, comp, ni_corp, lab_corp, ni_govnp, lab_govnp, ni_oth, lab_oth), mean))
}
mk <- function(z) with(z, tibble(
  w_corp = ni_corp/ni, l_corp = 100*lab_corp/ni_corp,
  w_gov  = ni_govnp/ni, l_gov = 100*lab_govnp/ni_govnp,
  w_oth  = ni_oth/ni,  l_oth = 100*lab_oth/ni_oth))
A <- mk(era(1947:1949)); B <- mk(era(max(sd$year)))
sec <- c("corp","gov","oth")
nm  <- c(corp = "Corporate", gov = "Government & nonprofit", oth = "Other private (noncorporate)")
tibble(
  Sector = nm[sec],
  `Within sector (labor share moved)`  = sapply(sec, function(s) mean(c(A[[paste0("w_",s)]], B[[paste0("w_",s)]])) *
                                                (B[[paste0("l_",s)]] - A[[paste0("l_",s)]])),
  `Between sector (weight moved)`      = sapply(sec, function(s) mean(c(A[[paste0("l_",s)]], B[[paste0("l_",s)]])) *
                                                (B[[paste0("w_",s)]] - A[[paste0("w_",s)]]))) |>
  dw("f05_shift_share")

# F6 - capital share, with and without housing ---------------------------------
qv |> select(date, `Ex rental income of persons` = cap_exhouse) |>
  left_join(qt |> select(date, `Unambiguous capital (TF)` = cap_net), by = "date") |>
  dw("f06_capital_ex_housing")

# F7 - how precedented is today, on their own measure --------------------------
qa |> filter(year < max(year)) |>
  transmute(year, `Labor share of net income (annual)` = lab_net) |>
  dw("f07_how_precedented")

# F8 - the unambiguous labor share, 1929-2025 ----------------------------------
h |> transmute(year, `Unambiguous labor share` = lab_net) |>
  dw("figure4_annual_history_1929", dir = DW_BLOG)

# F9 - capital share vs. top 1% wage-income share (Piketty-Saez Table B2, ends 2011) --
t1 |> transmute(year,
                `Capital share of net income (TF convention)` = cap_net,
                `Top 1% share of wage income (Piketty-Saez, through 2011)` = top1_wage) |>
  dw("figure5_top1_vs_capital", dir = DW_BLOG)

cat("Datawrapper CSVs written to", DW_BLOG, "and", DW_SEC, "\n")
cat("blogpost:", list.files(DW_BLOG), "\n")
cat("secondary:", list.files(DW_SEC), "\n")
