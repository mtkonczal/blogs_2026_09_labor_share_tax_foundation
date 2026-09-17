# 10_measures_survey.R --------------------------------------------------------
# A broader survey of labor-share and corporate-profit measures, quarterly
# only (NIPA Table 1.10/1.14 data run 1947Q1-latest; no annual aggregation).
#
# Motivated by draft_deck_labor_share_trend_mkonczal (2).pptx, an internal
# deck that charts four different labor-share definitions (economy-wide gross,
# BLS nonfarm-business, nonfinancial-corporate net, and a corporate-profit-
# margin series) without settling on one. This script builds all of those,
# plus the "leading research" axes the deck raises but doesn't fully cross:
#   - gross vs. net (of depreciation)
#   - economy-wide vs. business-sector vs. corporate (all) vs. nonfinancial
#     corporate
#   - for economy-wide measures, how proprietors' income is allocated
#     (all-capital / 75% labor, Smith et al. 2019 / all-labor, Gollin 2002)
# and the mirror set of measures for corporate profits (pretax/after-tax,
# gross/net, nonfinancial/all-corporate/economy-wide-as-%-of-GDI).
#
# All NIPA series come from data/raw/nipa_q.rds (Table 1.10 and 1.14), already
# pulled by 01_download_nipa.R; this script adds one new external pull, the
# BLS official measure (PRS85006173, Nonfarm Business Sector: Labor Share for
# All Workers, index 2017=100, SA, quarterly), via the BLS public API v2
# (BLS_KEY in .Renviron). BLS caps a single v2 request at 20 years, so the
# 1947-2026 span is pulled in four chunks and stitched together.

source("R/00_setup.R")
suppressPackageStartupMessages({ library(httr); library(jsonlite) })

nq <- readRDS(file.path(RAW, "nipa_q.rds"))
grab <- function(codes) {
  nq |> filter(SeriesCode %in% codes) |> select(date, SeriesCode, Value) |>
    distinct() |> pivot_wider(names_from = SeriesCode, values_from = Value)
}

# NIPA Table 1.10 (economy-wide) + Table 1.14 (corporate / nonfinancial corporate)
d <- grab(c(
  "A4002C",  # 1.10 comp of employees, paid
  "A261RC",  # 1.10 GDI
  "A262RC",  # 1.10 consumption of fixed capital
  "A445RC",  # 1.10 corporate profits w/ IVA & CCAdj (all corp)
  "A451RC",  # 1.14 L1  gross value added, corporate business
  "A438RC",  # 1.14 L2  CFC, corporate business
  "A439RC",  # 1.14 L3  net value added, corporate business
  "A442RC",  # 1.14 L4  compensation, corporate business
  "W321RC",  # 1.14 L7  TOPI less subsidies, corporate business
  "W322RC",  # 1.14 L8  net operating surplus, corporate business
  "W273RC",  # 1.14 L13 profits after tax w/ IVA & CCAdj, corporate business
  "A455RC",  # 1.14 L17 gross value added, nonfinancial corporate business
  "A457RC",  # 1.14 L19 net value added, nonfinancial corporate business
  "A460RC",  # 1.14 L20 compensation, nonfinancial corporate business
  "W325RC",  # 1.14 L23 TOPI less subsidies, nonfinancial corporate business
  "W326RC",  # 1.14 L24 net operating surplus, nonfinancial corporate business
  "A463RC",  # 1.14 L27 corporate profits w/ IVA & CCAdj, nonfinancial corporate
  "W328RC"   # 1.14 L29 profits after tax w/ IVA & CCAdj, nonfinancial corporate
)) |>
  arrange(date)

stopifnot(nrow(d) > 300, min(d$date) == as.Date("1947-03-01"),
          all(complete.cases(d)))

# --- Accounting-identity sanity checks (fail loudly) -------------------------
mx <- function(x) max(abs(x), na.rm = TRUE)
stopifnot(
  mx(with(d, A451RC - A438RC - A439RC)) < 3,   # corporate: gross - CFC = net
  mx(with(d, A439RC - A442RC - W321RC - W322RC)) < 3,   # corporate net = comp + TOPI_net + NOS
  mx(with(d, A457RC - A460RC - W325RC - W326RC)) < 3    # nonfinancial: same identity
)

# --- BLS: Nonfarm Business Sector labor share, PRS85006173 -------------------
bls_series <- "PRS85006173"
bls_windows <- list(c(1947, 1966), c(1967, 1986), c(1987, 2006), c(2007, 2026))
key <- Sys.getenv("BLS_KEY")
stopifnot(nchar(key) > 0)

pull_bls <- function(y0, y1) {
  body <- list(seriesid = list(bls_series), startyear = as.character(y0),
               endyear = as.character(y1), registrationkey = key)
  resp <- httr::POST("https://api.bls.gov/publicAPI/v2/timeseries/data/",
                      body = jsonlite::toJSON(body, auto_unbox = TRUE),
                      httr::content_type_json())
  stopifnot(httr::status_code(resp) == 200)
  res <- httr::content(resp, as = "parsed", simplifyVector = TRUE)
  stopifnot(res$status == "REQUEST_SUCCEEDED")
  res$Results$series$data[[1]]
}

bls_raw <- bind_rows(lapply(bls_windows, function(w) pull_bls(w[1], w[2]))) |>
  distinct(year, period, .keep_all = TRUE)

# BLS labels quarters Q01-Q04; align to this project's BEA convention of
# dating each quarter by its LAST month (e.g. 1947Q1 -> 1947-03-01).
bls <- bls_raw |>
  filter(grepl("^Q0[1-4]$", period)) |>
  transmute(
    date = as.Date(sprintf("%s-%02d-01", year, as.integer(substr(period, 3, 4)) * 3)),
    l_bls_nfb = as.numeric(value)
  ) |>
  arrange(date) |>
  distinct(date, .keep_all = TRUE)

stopifnot(nrow(bls) > 300, min(bls$date) == as.Date("1947-03-01"))

writeLines(
  c(paste("vintage:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste("source: BLS public API v2, series", bls_series),
    paste("series: Nonfarm Business Sector: Labor Share for All Workers, index 2017=100, SA, quarterly"),
    paste("rows:", nrow(bls))),
  file.path(RAW, "bls_labor_share.vintage.txt"))

d <- d |> left_join(bls, by = "date")
stopifnot(sum(is.na(d$l_bls_nfb)) == 0)

# --- Build every measure ------------------------------------------------------
m <- d |> transmute(
  date,
  # Labor share -----------------------------------------------------------
  l_gross_econ      = 100 * A4002C / A261RC,
  l_net_econ_std     = 100 * A4002C / (A261RC - A262RC),
  l_bls_nfb          = l_bls_nfb,
  l_corp_gross       = 100 * A442RC / A451RC,
  l_corp_net_std     = 100 * A442RC / A439RC,
  l_corp_net_extax   = 100 * A442RC / (A439RC - W321RC),
  l_nfcorp_gross     = 100 * A460RC / A455RC,
  l_nfcorp_net_std   = 100 * A460RC / A457RC,
  l_nfcorp_net_extax = 100 * A460RC / (A457RC - W325RC),
  # Corporate profits -------------------------------------------------------
  p_all_pretax_gdi    = 100 * A445RC / A261RC,
  p_all_pretax_gross  = 100 * A445RC / A451RC,
  p_all_pretax_net    = 100 * A445RC / A439RC,
  p_all_aftertax_gross= 100 * W273RC / A451RC,
  p_all_aftertax_net  = 100 * W273RC / A439RC,
  p_nf_pretax_gross   = 100 * A463RC / A455RC,
  p_nf_pretax_net     = 100 * A463RC / A457RC,
  p_nf_aftertax_gross = 100 * W328RC / A455RC,
  p_nf_nos_net        = 100 * W326RC / A457RC
)

# The TF proprietor-income bounds (economy-wide net income, three allocations)
# are already built by 02_replicate_tf.R / 03_variants.R; pull them in rather
# than recompute so both pipelines agree on the number to the decimal.
tf   <- read_csv(file.path(DERIVED, "tf_shares_quarterly.csv"),  show_col_types = FALSE) |>
  select(date, l_net_tf = lab_net)
var  <- read_csv(file.path(DERIVED, "variants_quarterly.csv"),   show_col_types = FALSE) |>
  select(date, l_net_labmax = v2_labmax, l_net_prop75 = v3_prop75)

m <- m |> left_join(tf, by = "date") |> left_join(var, by = "date")
stopifnot(all(complete.cases(m)))

m_long <- m |> pivot_longer(-date, names_to = "id", values_to = "value") |> arrange(id, date)
write_derived(m_long, "measures_survey_quarterly")

# --- Metadata: name, description, grouping ------------------------------------
meta <- tribble(
  ~id,                  ~name,                                     ~description,
  "l_gross_econ",       "Economy-wide, gross",
    "Compensation of employees / gross domestic income. The broadest, whole-economy measure; the denominator includes depreciation, production taxes and corporate income taxes. This is the \"50-50 split\" framing the Tax Foundation post criticizes.",
  "l_net_econ_std",     "Economy-wide, net of depreciation",
    "Compensation of employees / (GDI - depreciation). Removes only consumption of fixed capital, leaving production and corporate taxes in the denominator; the standard \"net national income\" convention in Rognlie (2015) and Bridgman (2018).",
  "l_net_tf",           "Economy-wide, net, proprietors' income excluded",
    "Compensation / net income, where net income excludes depreciation, production taxes and corporate income taxes, and proprietors' income is treated as neither labor nor capital. This is the Tax Foundation's own headline convention.",
  "l_net_labmax",       "Economy-wide, net, all proprietors' income to labor",
    "Same net-income denominator as the Tax Foundation convention, but all of proprietors' income is added to the numerator  -  the upper bound flagged by Gollin (2002).",
  "l_net_prop75",       "Economy-wide, net, 75% of proprietors' income to labor",
    "Same net-income denominator, with 75% of proprietors' income added to the numerator, following Smith, Yagan, Zidar and Zwick (2019), who attribute roughly three-quarters of pass-through profit to human capital.",
  "l_bls_nfb",          "BLS official measure (nonfarm business)",
    "BLS's own \"Labor Share\" series for the nonfarm business sector (PRS85006173): labor compensation / current-dollar output, indexed to 2017=100. Adds an imputed wage equivalent for roughly half of proprietors' income; excludes government, nonprofits and owner-occupied housing.",
  "l_corp_gross",       "Corporate business (all corporations), gross",
    "Compensation / gross value added of corporate business (NIPA Table 1.14). Includes all corporations, financial and nonfinancial.",
  "l_corp_net_std",     "Corporate business (all corporations), net",
    "Compensation / net value added of corporate business (gross value added less depreciation).",
  "l_corp_net_extax",   "Corporate business (all corporations), net of production taxes",
    "Compensation / (compensation + net operating surplus), i.e. net value added with production taxes also removed from the denominator.",
  "l_nfcorp_gross",     "Nonfinancial corporate business, gross",
    "Compensation / gross value added of nonfinancial corporate business  -  excludes the financial sector and all proprietors' income and imputed rent.",
  "l_nfcorp_net_std",   "Nonfinancial corporate business, net",
    "Compensation / net value added of nonfinancial corporate business.",
  "l_nfcorp_net_extax", "Nonfinancial corporate business, net of production taxes",
    "Compensation / (compensation + net operating surplus), nonfinancial corporate business. This is the exact construction behind the deck's slide 5 and slide 16 charts.",
  "p_all_pretax_gdi",    "Corporate profits (pretax) as a share of GDI",
    "Corporate profits with IVA & CCAdj, all corporations / gross domestic income  -  the whole-economy \"profits as a share of GDP\" framing common in press coverage.",
  "p_all_pretax_gross",  "Corporate profit margin, pretax, gross",
    "Corporate profits with IVA & CCAdj / gross value added, all corporations.",
  "p_all_pretax_net",    "Corporate profit margin, pretax, net",
    "Corporate profits with IVA & CCAdj / net value added, all corporations.",
  "p_all_aftertax_gross","Corporate profit margin, after tax, gross",
    "Corporate profits after tax with IVA & CCAdj / gross value added, all corporations.",
  "p_all_aftertax_net",  "Corporate profit margin, after tax, net",
    "Corporate profits after tax with IVA & CCAdj / net value added, all corporations.",
  "p_nf_pretax_gross",   "Nonfinancial corporate profit margin, pretax, gross",
    "Corporate profits with IVA & CCAdj / gross value added, nonfinancial corporate business only. This is the exact construction behind the deck's slide 2 chart (\"Corporate Profits Remain Elevated\").",
  "p_nf_pretax_net",     "Nonfinancial corporate profit margin, pretax, net",
    "Corporate profits with IVA & CCAdj / net value added, nonfinancial corporate business.",
  "p_nf_aftertax_gross", "Nonfinancial corporate profit margin, after tax, gross",
    "Corporate profits after tax with IVA & CCAdj / gross value added, nonfinancial corporate business.",
  "p_nf_nos_net",        "Nonfinancial net operating surplus, net",
    "Net operating surplus (profits + net interest + business transfer payments  -  the broadest NIPA capital-income aggregate) / net value added, nonfinancial corporate business."
)
econ_ids <- c("l_gross_econ","l_net_econ_std","l_net_tf","l_net_labmax","l_net_prop75","p_all_pretax_gdi")
corp_ids <- c("l_corp_gross","l_corp_net_std","l_corp_net_extax",
              "p_all_pretax_gross","p_all_pretax_net","p_all_aftertax_gross","p_all_aftertax_net")
gross_ids <- c("l_gross_econ","p_all_pretax_gdi","l_corp_gross","l_nfcorp_gross",
               "p_all_pretax_gross","p_all_aftertax_gross","p_nf_pretax_gross","p_nf_aftertax_gross")

meta <- meta |> mutate(
  group  = if_else(startsWith(id, "l_"), "Labor share", "Corporate profits"),
  sector = case_when(
    id %in% econ_ids  ~ "Economy-wide",
    id == "l_bls_nfb" ~ "Nonfarm business (BLS)",
    id %in% corp_ids  ~ "Corporate (all)",
    TRUE ~ "Nonfinancial corporate"),
  basis  = if_else(id %in% gross_ids, "Gross", "Net"),
  unit   = if_else(id == "l_bls_nfb", "Index, 2017=100", "% of income base"),
  source = if_else(id == "l_bls_nfb", "BLS PRS85006173",
                    if_else(id %in% econ_ids, "BEA NIPA Table 1.10", "BEA NIPA Table 1.14"))
)
stopifnot(setequal(meta$id, unique(m_long$id)))
write_derived(meta, "measures_survey_meta")

# --- Ranking: is the latest quarter a record low? -----------------------------
rank_one <- function(id_) {
  x <- m_long |> filter(id == id_) |> arrange(date)
  v <- x$value
  latest <- last(v); latest_date <- last(x$date)
  rec_i  <- which.min(v); rec_hi_i <- which.max(v)
  rank_low  <- sum(v <= latest)                 # 1 = record low
  rank_high <- sum(v >= latest)                 # 1 = record high
  pctile    <- 100 * mean(v <= latest)          # 100 * share of history at/below latest
  # second-lowest / second-highest, for context when latest IS the record
  v_excl_latest <- v[-length(v)]
  tibble(
    id = id_, n = length(v),
    start_date = min(x$date), latest_date = latest_date, latest_value = latest,
    record_date = x$date[rec_i], record_value = v[rec_i], rank_low = rank_low,
    record_high_date = x$date[rec_hi_i], record_high_value = v[rec_hi_i], rank_high = rank_high,
    pctile_from_bottom = pctile,
    second_lowest_value = min(v_excl_latest), second_lowest_date = x$date[-length(v)][which.min(v_excl_latest)],
    second_highest_value = max(v_excl_latest), second_highest_date = x$date[-length(v)][which.max(v_excl_latest)],
    pre_pandemic_avg = mean(v[x$date >= as.Date("2017-01-01") & x$date <= as.Date("2019-12-01")]),
    full_avg = mean(v)
  )
}
rk <- bind_rows(lapply(unique(m_long$id), rank_one)) |> left_join(meta, by = "id")

stopifnot(all(rk$rank_low >= 1), all(rk$rank_low <= rk$n),
          all(rk$latest_value >= rk$record_value - 1e-9))

fmt_q <- function(dt) paste0(format(dt, "%Y"), "Q", (as.integer(format(dt, "%m")) + 2) %/% 3)

rk <- rk |> mutate(
  is_record_low = rank_low == 1,
  is_record_high = rank_high == 1,
  lowest_label = if_else(is_record_low, "Yes  -  record low", "No"),
  highest_label = if_else(is_record_high, "Yes  -  record high", "No"),
  # Context framed around the LOW end (used for the labor-share table).
  context = case_when(
    is_record_low ~ sprintf("Record low of the quarterly series (%s-%s). Previous low was %.1f in %s, so this is %.1f below that.",
                             fmt_q(start_date), fmt_q(latest_date), second_lowest_value, fmt_q(second_lowest_date),
                             second_lowest_value - latest_value),
    rank_low <= 5 ~ sprintf("%s-lowest of %d quarters since %s; %.1f above the record low set in %s.",
                            c("1st","2nd","3rd","4th","5th")[pmin(pmax(rank_low, 1), 5)], n, fmt_q(start_date),
                            latest_value - record_value, fmt_q(record_date)),
    pctile_from_bottom <= 10 ~ sprintf("In the bottom decile of its own history (%.0fth percentile from the bottom); %.1f above the record low set in %s.",
                                        pctile_from_bottom, latest_value - record_value, fmt_q(record_date)),
    pctile_from_bottom <= 25 ~ sprintf("Bottom quartile but not near the record (%.0fth percentile from the bottom); %.1f above the record low set in %s.",
                                        pctile_from_bottom, latest_value - record_value, fmt_q(record_date)),
    TRUE ~ sprintf("Not near the low end of its own history (%.0fth percentile from the bottom); %.1f above the record low set in %s, %s the 2017-19 average.",
                   pctile_from_bottom, latest_value - record_value, fmt_q(record_date),
                   if_else(latest_value >= pre_pandemic_avg, "at or above", "below"))
  ),
  # Context framed around the HIGH end (used for the corporate-profits table,
  # since a rising profit share is the mirror image of a falling labor share).
  context_high = case_when(
    is_record_high ~ sprintf("Record high of the quarterly series (%s-%s). Previous high was %.1f in %s, so this is %.1f above that.",
                              fmt_q(start_date), fmt_q(latest_date), second_highest_value, fmt_q(second_highest_date),
                              latest_value - second_highest_value),
    rank_high <= 5 ~ sprintf("%s-highest of %d quarters since %s; %.1f below the record high set in %s.",
                             c("1st","2nd","3rd","4th","5th")[pmin(pmax(rank_high, 1), 5)], n, fmt_q(start_date),
                             record_high_value - latest_value, fmt_q(record_high_date)),
    (100 - pctile_from_bottom) <= 10 ~ sprintf("In the top decile of its own history (%.0fth percentile from the bottom); %.1f below the record high set in %s.",
                                                pctile_from_bottom, record_high_value - latest_value, fmt_q(record_high_date)),
    (100 - pctile_from_bottom) <= 25 ~ sprintf("Top quartile but not near the record (%.0fth percentile from the bottom); %.1f below the record high set in %s.",
                                                pctile_from_bottom, record_high_value - latest_value, fmt_q(record_high_date)),
    TRUE ~ sprintf("Not near the high end of its own history (%.0fth percentile from the bottom); %.1f below the record high set in %s, %s the 2017-19 average.",
                   pctile_from_bottom, record_high_value - latest_value, fmt_q(record_high_date),
                   if_else(latest_value >= pre_pandemic_avg, "at or above", "below"))
  )
)

write_derived(rk |> select(id, name, group, sector, basis, unit, source, n, start_date, latest_date,
                            latest_value, record_date, record_value, rank_low, record_high_date,
                            record_high_value, rank_high, pctile_from_bottom,
                            second_lowest_value, second_lowest_date, second_highest_value, second_highest_date,
                            pre_pandemic_avg, full_avg,
                            is_record_low, is_record_high, lowest_label, highest_label, context, context_high),
              "measures_survey_ranking")

sink(file.path(TABS_SEC, "t07_measures_survey.txt"))
cat("Labor-share and corporate-profit measures survey, quarterly, 1947Q1-latest\n")
cat("Vintage:", format(Sys.time(), "%Y-%m-%d"), "\n\n")
cat("--- Labor share ---\n")
print(as.data.frame(rk |> filter(group == "Labor share") |>
        select(name, sector, basis, latest_value, rank_low, n, lowest_label)),
      digits = 3, right = FALSE, row.names = FALSE)
cat("\n--- Corporate profits (record-HIGH framing) ---\n")
print(as.data.frame(rk |> filter(group == "Corporate profits") |>
        select(name, sector, basis, latest_value, rank_high, n, highest_label)),
      digits = 3, right = FALSE, row.names = FALSE)
sink()

cat(readLines(file.path(TABS_SEC, "t07_measures_survey.txt")), sep = "\n")
