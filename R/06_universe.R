# 06_universe.R --------------------------------------------------------------
# What is inside the Tax Foundation's income universe, and how it compares to
# the universes the labor-share literature normally uses.
#
# Three facts this table is meant to establish:
#  (1) Their denominator is the whole domestic economy, 88% of net domestic
#      product (the rest is production taxes and corporate income taxes).
#  (2) About 30% of that denominator has a labor/capital split fixed by
#      accounting convention rather than by an observed transaction:
#      general government and nonprofits (labor share = 1 by construction),
#      owner-occupied housing (labor share = 0), and proprietors' income
#      (unsplit, so labor share = 0 in their headline).
#  (3) In the corporate sector that number is essentially zero, which is why
#      the literature works there.

source("R/00_setup.R")

nq <- readRDS(file.path(RAW, "nipa_q.rds"))
g  <- function(cs) nq |> filter(SeriesCode %in% cs) |> select(date, SeriesCode, Value) |>
  distinct() |> pivot_wider(names_from = SeriesCode, values_from = Value)

w <- g(c("A261RC",  # 1.10 L1   gross domestic income
         "A362RC",  # 1.9.5 L1  net domestic product
         "A4002C", "W272RC", "B029RC", "A041RC", "A048RC", "W273RC", "A054RC",
         "A439RC",  # 1.14 L3   net value added of corporate business
         "A442RC",  # 1.14 L4   corporate compensation
         "W321RC",  # 1.14 L7   corporate TOPI less subsidies
         "A457RC",  # 1.14 L19  net value added of nonfinancial corporate business
         "W325RC",  # 1.14 L23  nonfinancial corporate TOPI less subsidies
         "A460RC",  # 1.14 L20  nonfinancial corporate compensation
         "A194RC",  # 1.13 L56  compensation of general government employees
         "W151RC",  # 1.13 L43  compensation, households
         "W152RC",  # 1.13 L50  compensation, nonprofit institutions
         "A2009C",  # 7.4.5 L7  gross housing value added
         "DOWNRC")) # 7.4.5 L3  imputed rental of owner-occupied nonfarm housing

d <- w |> mutate(
  ucap      = W272RC + B029RC + A048RC + W273RC,
  ni        = A4002C + A041RC + ucap,
  ni_corp   = A439RC - W321RC - A054RC,
  govnp     = A194RC + W151RC + W152RC,
  ni_oth    = ni - ni_corp - govnp,
  comp_oth  = A4002C - A442RC - govnp,
  conv_set  = govnp + A041RC + A048RC,
  year      = as.integer(format(date, "%Y")))

stopifnot(all(d$ni_oth > 0), all(d$comp_oth > 0))

x <- d |> slice_max(date, n = 1)
pn <- function(v) 100 * v / x$ni
lq <- paste0(format(x$date, "%Y"), "Q", (as.integer(format(x$date, "%m")) + 2) %/% 3)

comp_tab <- tribble(
  ~component,                                    ~pct_of_TF_net_income, ~labor_share,
  "Corporate business",                           pn(x$ni_corp),         100 * x$A442RC / x$ni_corp,
  "General government",                           pn(x$A194RC),          100,
  "Nonprofit institutions serving households",    pn(x$W152RC),          100,
  "Households (domestic employees)",              pn(x$W151RC),          100,
  "Other private (noncorporate)",                 pn(x$ni_oth),          100 * x$comp_oth / x$ni_oth,
  "   of which proprietors' income",              pn(x$A041RC),           NA,
  "   of which rental income of persons",         pn(x$A048RC),           NA,
  "   of which noncorporate compensation",        pn(x$comp_oth),         NA,
  "   of which other noncorporate capital",       pn(x$ni_oth - x$A041RC - x$A048RC - x$comp_oth), NA)

univ_tab <- tribble(
  ~universe,                                        ~pct_of_net_domestic_product,
  "TF net income (whole domestic economy)",          100 * x$ni / x$A362RC,
  "Business sector (ex government and nonprofits)",  100 * (x$ni - x$govnp) / x$A362RC,
  "Corporate business, net value added",             100 * x$A439RC / x$A362RC,
  "Nonfinancial corporate business, net value added",100 * x$A457RC / x$A362RC)

# History of the universe weights that drive the aggregate trend
hist <- d |> group_by(year) |>
  summarise(across(c(ni, ni_corp, govnp, ni_oth, A041RC, A048RC, A442RC, comp_oth,
                     conv_set, A2009C, A261RC, DOWNRC), mean), nq = n()) |>
  transmute(year, nq,
            w_corp   = 100 * ni_corp / ni,
            w_govnp  = 100 * govnp / ni,
            w_oth    = 100 * ni_oth / ni,
            l_corp   = 100 * A442RC / ni_corp,
            l_oth    = 100 * comp_oth / ni_oth,
            conv_pct = 100 * conv_set / ni,
            oo_hous_gdi = 100 * DOWNRC / A261RC)

write_derived(hist, "universe_weights_annual")

sink(file.path(TABS, "t04_universe.txt"))
cat("What is inside the Tax Foundation income universe\n")
cat("BEA NIPA, vintage", format(Sys.time(), "%Y-%m-%d"), "| latest quarter", lq, "\n\n")
cat("Composition of their net-income denominator ($",
    sprintf("%.2f", x$ni / 1e6), " trillion SAAR):\n", sep = "")
print(as.data.frame(comp_tab), digits = 3, right = FALSE, row.names = FALSE)
cat("\nShare of the denominator whose labor/capital split is set by accounting\n")
cat("convention rather than an observed transaction (government + nonprofits +\n")
cat("households at a labor share of 1, rental income of persons at 0,\n")
cat("proprietors' income unsplit):", sprintf("%.1f%%", pn(x$conv_set)), "\n")
cat("Imputed rental of owner-occupied housing, gross output, share of GDI:",
    sprintf("%.1f%%", 100 * x$DOWNRC / x$A261RC), "\n\n")
cat("Universe size comparison:\n")
print(as.data.frame(univ_tab), digits = 3, right = FALSE, row.names = FALSE)
cat("\n\nUniverse weights and sector labor shares over time (percent):\n")
print(as.data.frame(hist |> filter(year %in% c(1948, 1960, 1970, 1980, 1986, 1990,
                                               2000, 2007, 2019, 2025, max(hist$year)))),
      digits = 3, right = FALSE, row.names = FALSE)
sink()

cat(readLines(file.path(TABS, "t04_universe.txt")), sep = "\n")
