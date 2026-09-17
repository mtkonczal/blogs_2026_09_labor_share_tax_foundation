# 04_decomposition.R ---------------------------------------------------------
# Why does the TF measure show a "round trip" while the corporate-sector
# labor share shows a large decline? Shift-share the TF net labor share into
# three sectors that partition its own net-income denominator:
#
#   corporate        net value added less production taxes less corporate tax
#   govt + nonprofit compensation of general government, household and
#                    nonprofit employees (labor share = 1 by construction)
#   other private    the residual: noncorporate business, including
#                    proprietors' income and owner-occupied housing
#
# ΔL = Σ_s w̄_s Δl_s   (within-sector)  +  Σ_s l̄_s Δw_s   (between-sector)
# using endpoint averages for the bars, so the two parts sum to ΔL exactly.

source("R/00_setup.R")

q  <- read_csv(file.path(DERIVED, "tf_shares_quarterly.csv"), show_col_types = FALSE)
nq <- readRDS(file.path(RAW, "nipa_q.rds"))

grab <- function(codes) {
  nq |> filter(SeriesCode %in% codes) |> select(date, SeriesCode, Value) |>
    distinct() |> pivot_wider(names_from = SeriesCode, values_from = Value)
}
s <- grab(c("A439RC", "A442RC", "W321RC", "A194RC", "W151RC", "W152RC"))

d <- q |> select(date, comp, ni, prop, rental, ucap, ctax) |>
  left_join(s, by = "date") |>
  mutate(
    ni_corp   = A439RC - W321RC - ctax,
    lab_corp  = A442RC,
    ni_govnp  = A194RC + W151RC + W152RC,
    lab_govnp = ni_govnp,
    ni_oth    = ni - ni_corp - ni_govnp,
    lab_oth   = comp - lab_corp - lab_govnp,
    year      = as.integer(format(date, "%Y")))

stopifnot(all(d$ni_oth > 0, na.rm = TRUE),
          all(d$lab_oth > 0, na.rm = TRUE),
          max(abs(with(d, ni_corp + ni_govnp + ni_oth - ni)), na.rm = TRUE) < 3)

a <- d |> group_by(year) |>
  summarise(nq = n(), across(c(ni, comp, ni_corp, lab_corp, ni_govnp, lab_govnp,
                               ni_oth, lab_oth), mean)) |>
  mutate(L      = 100 * comp / ni,
         w_corp = ni_corp / ni,  l_corp = 100 * lab_corp / ni_corp,
         w_gov  = ni_govnp / ni, l_gov  = 100 * lab_govnp / ni_govnp,
         w_oth  = ni_oth / ni,   l_oth  = 100 * lab_oth / ni_oth)

write_derived(a, "sector_decomposition_annual")

# Era aggregates are built from mean LEVELS, then ratios, so that
# L = sum_s w_s * l_s holds exactly and the decomposition closes.
era_agg <- function(a, yrs) {
  z <- a |> filter(year %in% yrs) |>
    summarise(across(c(ni, comp, ni_corp, lab_corp, ni_govnp, lab_govnp,
                       ni_oth, lab_oth), mean))
  z |> mutate(L      = 100 * comp / ni,
              w_corp = ni_corp / ni,  l_corp = 100 * lab_corp / ni_corp,
              w_gov  = ni_govnp / ni, l_gov  = 100 * lab_govnp / ni_govnp,
              w_oth  = ni_oth / ni,   l_oth  = 100 * lab_oth / ni_oth)
}

shift_share <- function(a, y0, y1, lab0, lab1) {
  A <- era_agg(a, y0); B <- era_agg(a, y1)
  sec <- c("corp", "gov", "oth")
  wi <- sapply(sec, function(s) mean(c(A[[paste0("w_", s)]], B[[paste0("w_", s)]])) *
                                 (B[[paste0("l_", s)]] - A[[paste0("l_", s)]]))
  bw <- sapply(sec, function(s) mean(c(A[[paste0("l_", s)]], B[[paste0("l_", s)]])) *
                                 (B[[paste0("w_", s)]] - A[[paste0("w_", s)]]))
  tibble(period = paste(lab0, "->", lab1),
         dL = B$L - A$L,
         within_corp = wi[["corp"]], within_gov = wi[["gov"]], within_oth = wi[["oth"]],
         between_corp = bw[["corp"]], between_gov = bw[["gov"]], between_oth = bw[["oth"]],
         within_tot = sum(wi), between_tot = sum(bw))
}

# Endpoint. The final calendar year is partial, so also run the decomposition
# against the latest single quarter, which is the value TF themselves report.
ymax <- max(a$year)
lastq_lbl <- paste0(format(max(d$date), "%Y"), "Q",
                    (as.integer(format(max(d$date), "%m")) + 2) %/% 3)

dec <- bind_rows(
  shift_share(a, 1947:1949, ymax,      "1947-49", paste0(ymax, " (", a$nq[a$year==ymax], "q)")),
  shift_share(a, 1947:1949, 1970:1979, "1947-49", "1970s"),
  shift_share(a, 1970:1979, ymax,      "1970s",   paste0(ymax)),
  shift_share(a, 2000:2007, ymax,      "2000-07", paste0(ymax))
)

# Same decomposition with the latest QUARTER as the endpoint, so it lines up
# with the 2026Q2 levels quoted elsewhere.
a_q <- bind_rows(a, d |> slice_max(date, n = 1) |>
  transmute(year = 9999L, nq = 1L, ni, comp, ni_corp, lab_corp,
            ni_govnp, lab_govnp, ni_oth, lab_oth))
dec_q <- shift_share(a_q, 1947:1949, 9999L, "1947-49", lastq_lbl)
stopifnot(max(abs(dec$dL - dec$within_tot - dec$between_tot)) < 1e-8,
          abs(dec_q$dL - dec_q$within_tot - dec_q$between_tot) < 1e-8)

sink(file.path(TABS_SEC, "t03_sector_decomposition.txt"))
cat("Shift-share of the Tax Foundation net labor share, percentage points\n")
cat("Vintage:", format(Sys.time(), "%Y-%m-%d"), "\n\n")
cat("Sector labor shares and net-income weights, selected years:\n")
print(as.data.frame(a |> filter(year %in% c(1947,1948,1949,1970,1980,2000,2019,2025,ymax)) |>
        select(year, L, l_corp, l_gov, l_oth, w_corp, w_gov, w_oth)),
      digits = 3, right = FALSE, row.names = FALSE)
cat("\n\nDecomposition of the change in the TF net labor share:\n")
print(as.data.frame(bind_rows(dec, dec_q)), digits = 3, right = FALSE, row.names = FALSE)
cat("\nwithin_*  = sector labor share moved, holding its weight fixed\n")
cat("between_* = sector's weight in net income moved, holding its labor share fixed\n")
sink()

cat(readLines(file.path(TABS_SEC, "t03_sector_decomposition.txt")), sep = "\n")
