# 03_variants.R --------------------------------------------------------------
# Sensitivity of the Tax Foundation measure to the conventions it chooses.
# Each variant changes exactly one convention, so the level and trend effects
# are attributable. None of these change data vintage or sample.
#
# V1 TF baseline        comp / net income                     (as published)
# V2 Labor upper bound  (comp + proprietors) / net income     Gollin (2002) bound
# V3 Prop split 75/25   proprietors 75% labor                 Smith et al. (2019)
# V4 Pre-corporate-tax  corporate taxes back in denominator,  net national
#                       profits measured pre-tax              income convention
# V5 Ex-housing         rental income of persons out of both  Rognlie (2015)
#                       capital and the denominator
# V6 V5 + V2            both adjustments
# V7 Business sector    government + households & institutions removed
# V8 Corporate sector   NIPA Table 1.14, no proprietors, no imputed rent
# V9 Gross              comp / GDI  (the "50-50" framing TF criticizes)

source("R/00_setup.R")

nipa_q <- readRDS(file.path(RAW, "nipa_q.rds"))
q_tf   <- read_csv(file.path(DERIVED, "tf_shares_quarterly.csv"), show_col_types = FALSE)

grab <- function(codes) {
  nipa_q |> filter(SeriesCode %in% codes) |>
    select(date, SeriesCode, Value) |> distinct() |>
    pivot_wider(names_from = SeriesCode, values_from = Value)
}

# Sectoral compensation (NIPA Table 1.13) and corporate sector (Table 1.14).
# Net value added of general government is compensation of general government
# employees by NIPA construction; for households and nonprofits it is
# compensation plus a negligible surplus, so removing compensation from both
# numerator and denominator removes the sector to a close approximation.
sect <- grab(c("A194RC",   # 1.13 L56  compensation of general government employees
               "W151RC",   # 1.13 L43  compensation of employees, households
               "W152RC",   # 1.13 L50  compensation of employees, nonprofit institutions
               "A451RC",   # 1.14 L1   gross value added of corporate business
               "A439RC",   # 1.14 L3   net value added of corporate business
               "A442RC",   # 1.14 L4   corporate compensation of employees
               "W321RC",   # 1.14 L7   corporate TOPI less subsidies
               "W322RC",   # 1.14 L8   corporate net operating surplus
               "A2009C"))  # 7.4.5 L7  gross housing value added

d <- q_tf |> left_join(sect, by = "date")

v <- d |> transmute(
  date,
  year = as.integer(format(date, "%Y")),

  # V1 -----------------------------------------------------------------
  v1_tf        = 100 * comp / ni,
  # V2 -----------------------------------------------------------------
  v2_labmax    = 100 * (comp + prop) / ni,
  # V3 -----------------------------------------------------------------
  v3_prop75    = 100 * (comp + 0.75 * prop) / ni,
  # V4 pre-corporate-tax: put corporate income taxes back in the denominator
  #    and measure profits before tax. Denominator becomes net domestic income
  #    net of production taxes, the concept used in Rognlie/Bridgman.
  ni_pretax    = comp + prop + interest + bctp + rental + cprof,
  v4_pretax    = 100 * comp / ni_pretax,
  # V5 ex-housing: rental income of persons is overwhelmingly the net imputed
  #    return to owner-occupied housing plus noncorporate landlords. TF flag it
  #    as "not what people typically think of as capital income" but keep it in.
  ni_exh       = ni - rental,
  v5_exhouse   = 100 * comp / ni_exh,
  cap_exhouse  = 100 * (ucap - rental) / ni_exh,
  # V6 -----------------------------------------------------------------
  v6_exh_labmax = 100 * (comp + prop) / ni_exh,
  # V7 business sector only -------------------------------------------
  govnp        = A194RC + W151RC + W152RC,
  ni_bus       = ni - govnp,
  v7_business  = 100 * (comp - govnp) / ni_bus,
  v7_labmax    = 100 * (comp - govnp + prop) / ni_bus,
  # V8 corporate sector ------------------------------------------------
  corp_nva     = A439RC,
  corp_ni_tf   = A439RC - W321RC - (ctax),          # TF convention, corporate only
  v8_corp_tf   = 100 * A442RC / corp_ni_tf,
  v8_corp_std  = 100 * A442RC / A439RC,             # comp / net value added
  v8_corp_extax= 100 * A442RC / (A439RC - W321RC),  # net of production taxes only
  # V9 -----------------------------------------------------------------
  v9_gross     = 100 * comp / gdi,
  # context: housing gross value added as a share of GDI
  housing_gross = 100 * A2009C / gdi
)

# --- Annual ------------------------------------------------------------------
lev <- d |> mutate(year = as.integer(format(date, "%Y"))) |>
  group_by(year) |>
  summarise(nq = n(), across(c(gdi, comp, prop, ucap, ni, rental, interest, bctp,
                               cprof, ctax, cfc, A194RC, W151RC, W152RC,
                               A439RC, A442RC, W321RC, A451RC, A2009C), mean))

va <- lev |> mutate(
  ni_pretax = comp + prop + interest + bctp + rental + cprof,
  ni_exh    = ni - rental,
  govnp     = A194RC + W151RC + W152RC,
  ni_bus    = ni - govnp,
  v1_tf         = 100 * comp / ni,
  v2_labmax     = 100 * (comp + prop) / ni,
  v3_prop75     = 100 * (comp + 0.75 * prop) / ni,
  v4_pretax     = 100 * comp / ni_pretax,
  v5_exhouse    = 100 * comp / ni_exh,
  cap_exhouse   = 100 * (ucap - rental) / ni_exh,
  cap_tf        = 100 * ucap / ni,
  v6_exh_labmax = 100 * (comp + prop) / ni_exh,
  v7_business   = 100 * (comp - govnp) / ni_bus,
  v7_labmax     = 100 * (comp - govnp + prop) / ni_bus,
  v8_corp_tf    = 100 * A442RC / (A439RC - W321RC - ctax),
  v8_corp_std   = 100 * A442RC / A439RC,
  v8_corp_extax = 100 * A442RC / (A439RC - W321RC),
  v9_gross      = 100 * comp / gdi,
  govnp_share   = 100 * govnp / ni,
  prop_share    = 100 * prop / ni,
  rental_share  = 100 * rental / ni
)

write_derived(v,  "variants_quarterly")
write_derived(va, "variants_annual")

# --- Summary: level and trend under each convention -------------------------
vars <- c(v1_tf = "V1 TF baseline: comp / net income",
          v2_labmax = "V2 Labor upper bound: (comp+prop) / net income",
          v3_prop75 = "V3 Proprietors 75% labor (Smith et al. 2019)",
          v4_pretax = "V4 Pre-corporate-tax net income",
          v5_exhouse = "V5 Ex rental income of persons",
          v6_exh_labmax = "V6 Ex-housing + labor upper bound",
          v7_business = "V7 Business sector only (ex govt, nonprofits)",
          v7_labmax = "V7b Business sector, labor upper bound",
          v8_corp_tf = "V8 Corporate sector, TF convention",
          v8_corp_extax = "V8b Corporate sector, net of production taxes",
          v8_corp_std = "V8c Corporate sector, comp / net value added",
          v9_gross = "V9 Gross: comp / GDI")

era <- function(col) {
  x <- va[[col]]; yr <- va$year
  m <- function(lo, hi) mean(x[yr >= lo & yr <= hi])
  pk <- which.max(x)
  tibble(measure = vars[[col]],
         `1947-49` = m(1947, 1949), `1970s` = m(1970, 1979),
         `2000s`   = m(2000, 2009), `2015-19` = m(2015, 2019),
         latest    = x[length(x)],
         `chg vs 1947-49` = x[length(x)] - m(1947, 1949),
         `chg vs peak`    = x[length(x)] - x[pk],
         `peak yr`        = yr[pk])
}
summ <- bind_rows(lapply(names(vars), era))

# --- Where does the latest reading rank in 80 years? ------------------------
rk <- va |> transmute(year, v1_tf, v2_labmax, v3_prop75, v4_pretax, v5_exhouse,
                      v7_business, v8_corp_tf, v8_corp_std, v9_gross)
# Rank both the last full calendar year and the partial current year, since a
# two-quarter average is not comparable to an annual average.
full_yrs <- va$year[va$nq == 4]
rank_in <- function(cc, upto) {
  x <- rk[[cc]][rk$year <= upto]; sum(x <= x[length(x)])
}
yr_full <- max(full_yrs); yr_part <- max(va$year)
ranks <- tibble(measure = names(rk)[-1],
  full_year_value = sapply(names(rk)[-1], function(cc) rk[[cc]][rk$year == yr_full]),
  full_year_rank  = sapply(names(rk)[-1], rank_in, upto = yr_full),
  latest_value    = sapply(names(rk)[-1], function(cc) rk[[cc]][rk$year == yr_part]),
  n_obs_full      = sum(rk$year <= yr_full))

sink(file.path(TABS, "t02_variants_summary.txt"))
cat("Labor share under alternative conventions, all from NIPA\n")
cat("Vintage:", format(Sys.time(), "%Y-%m-%d"),
    "| latest annual point uses", va$nq[nrow(va)], "quarter(s) of",
    va$year[nrow(va)], "\n\n")
print(as.data.frame(summ), digits = 3, right = FALSE, row.names = FALSE)
cat("\n\nRank of", yr_full, "(last full calendar year) among", sum(rk$year <= yr_full),
    "annual observations, 1 = lowest ever.\n")
cat("latest_value is", yr_part, "to date and is shown for reference only.\n")
print(as.data.frame(ranks), digits = 4, right = FALSE, row.names = FALSE)
cat("\n\nComposition drift that the 'unambiguous labor' comparison ignores:\n")
print(as.data.frame(va |> filter(year %in% c(1947,1948,1949,1970,1980,2000,2019,max(year))) |>
  select(year, prop_share, rental_share, govnp_share, cap_tf, cap_exhouse)),
  digits = 3, right = FALSE, row.names = FALSE)
sink()

cat(readLines(file.path(TABS, "t02_variants_summary.txt")), sep = "\n")
