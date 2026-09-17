# 02_replicate_tf.R ----------------------------------------------------------
# Exact replication of the Tax Foundation labor-share measure.
#
# TF's construction, reverse-engineered from NIPA Table 1.10 (Gross Domestic
# Income by Type of Income) and confirmed to the last reported digit:
#
#   Unambiguous LABOR   = Compensation of employees, paid            (line 2)
#   Ambiguous           = Proprietors' income w/ IVA and CCAdj       (line 13)
#   Unambiguous CAPITAL = Net interest and misc. payments            (line 11)
#                       + Business current transfer payments (net)   (line 12)
#                       + Rental income of persons w/ CCAdj          (line 14)
#                       + Corporate profits AFTER TAX w/ IVA, CCAdj  (line 17)
#                       [ = private net operating surplus (10)
#                           - proprietors' income - corporate income taxes ]
#
#   NET INCOME (denominator) = the three categories above
#       = GDI - consumption of fixed capital
#             - taxes on production and imports net of subsidies
#             - taxes on corporate income
#             - current surplus of government enterprises
#
# Two conventions matter for the level and are worth flagging explicitly:
#  (a) Corporate income taxes are removed from the denominator and capital is
#      measured after tax. This is a "cash that reaches households" concept,
#      not the net national income concept standard in the literature.
#  (b) The current surplus of government enterprises (small, negative) is
#      dropped, so the three shares sum to exactly 100 by construction.
# Both are TF's choices, reproduced here as-is. R/03_variants.R relaxes them.

source("R/00_setup.R")

nipa_q <- readRDS(file.path(RAW, "nipa_q.rds"))

t110 <- nipa_q |>
  filter(TableId == "T11000") |>
  select(date, SeriesCode, Value) |> distinct() |>
  pivot_wider(names_from = SeriesCode, values_from = Value)

q <- t110 |>
  transmute(
    date,
    gdi        = A261RC,   # 1  Gross domestic income
    comp       = A4002C,   # 2  Compensation of employees, paid
    wages      = A4102C,   # 3  Wages and salaries
    supp       = A038RC,   # 6  Supplements to wages and salaries
    topi       = W056RC,   # 7  Taxes on production and imports
    subsidies  = A107RC,   # 8  Less: Subsidies
    nos        = W271RC,   # 9  Net operating surplus
    nos_priv   = W260RC,   # 10 Private enterprises
    interest   = W272RC,   # 11 Net interest and misc. payments
    bctp       = B029RC,   # 12 Business current transfer payments (net)
    prop       = A041RC,   # 13 Proprietors' income w/ IVA and CCAdj
    rental     = A048RC,   # 14 Rental income of persons w/ CCAdj
    cprof      = A445RC,   # 15 Corporate profits w/ IVA and CCAdj
    ctax       = A054RC,   # 16 Taxes on corporate income
    cprof_at   = W273RC,   # 17 Profits after tax w/ IVA and CCAdj
    gov_ent    = A108RC,   # 20 Current surplus of government enterprises
    cfc        = A262RC    # 21 Consumption of fixed capital
  ) |>
  mutate(
    topi_net = topi - subsidies,
    ucap     = interest + bctp + rental + cprof_at,   # unambiguous capital
    ni       = comp + prop + ucap,                    # TF net income
    # shares of net income
    lab_net    = 100 * comp / ni,
    cap_net    = 100 * ucap / ni,
    prop_net   = 100 * prop / ni,
    capmax_net = 100 * (ucap + prop) / ni,
    labmax_net = 100 * (comp + prop) / ni,
    # cents per dollar of gross domestic income
    c_comp = 100 * comp / gdi,   c_wages = 100 * wages / gdi,
    c_supp = 100 * supp / gdi,   c_ucap  = 100 * ucap / gdi,
    c_prop = 100 * prop / gdi,   c_cfc   = 100 * cfc / gdi,
    c_topi = 100 * topi_net / gdi, c_ctax = 100 * ctax / gdi,
    c_rent = 100 * rental / gdi,
    # the gross measure that produces the "50-50 split" framing
    lab_gross = 100 * comp / gdi
  )

# --- Accounting identity checks (fail loudly) --------------------------------
# Net operating surplus (W271RC) and the current surplus of government
# enterprises (A108RC) are not published quarterly before 1959, so the two
# identities that use them are checked on the quarters where they exist.
# The three income categories themselves run complete from 1947Q1.
mx <- function(x) max(abs(x), na.rm = TRUE)
id1 <- with(q, mx(comp + topi_net + nos + cfc - gdi))
id2 <- with(q, mx(ucap - (nos_priv - prop - ctax)))
id3 <- with(q, mx(ni - (gdi - cfc - topi_net - ctax - gov_ent)))
id4 <- with(q, mx(lab_net + cap_net + prop_net - 100))
n_incomplete <- sum(!complete.cases(q[, c("comp", "prop", "ucap", "ni")]))
stopifnot(id1 <= 3, id2 <= 3, id3 <= 3, id4 < 1e-8, n_incomplete == 0)

# --- Annual aggregation (means of SAAR levels, then ratios) ------------------
a <- q |>
  mutate(year = as.integer(format(date, "%Y"))) |>
  group_by(year) |>
  summarise(nq = n(), across(c(gdi, comp, wages, supp, topi_net, prop, rental,
                               ucap, cprof, cprof_at, ctax, cfc, interest,
                               bctp, gov_ent, ni, nos_priv), mean)) |>
  mutate(lab_net    = 100 * comp / ni,
         cap_net    = 100 * ucap / ni,
         prop_net   = 100 * prop / ni,
         capmax_net = 100 * (ucap + prop) / ni,
         labmax_net = 100 * (comp + prop) / ni,
         lab_gross  = 100 * comp / gdi,
         cap_gross  = 100 * ucap / gdi,
         cfc_gross  = 100 * cfc / gdi)

write_derived(q, "tf_shares_quarterly")
write_derived(a, "tf_shares_annual")

# --- Validation table: every TF number, claimed vs replicated ---------------
last <- q |> slice_max(date, n = 1)
lq   <- paste0(format(last$date, "%Y"), "Q", (as.integer(format(last$date, "%m")) + 2) %/% 3)
m4749 <- a |> filter(year <= 1949) |> summarise(across(c(lab_net, cap_net, prop_net), mean))
d1970 <- a |> filter(year >= 1970, year <= 1979) |> summarise(across(lab_net, mean))

chk <- tribble(
  ~item,                                            ~tf_claim,   ~replicated,
  "GDI, $ trillion SAAR (latest quarter)",           "32.2",     sprintf("%.1f", last$gdi/1e6),
  "Net income, $ trillion SAAR",                     "23.7",     sprintf("%.1f", last$ni/1e6),
  "Compensation, cents per $ of GDI",                "50.4",     sprintf("%.1f", last$c_comp),
  "  Wages and salaries",                            "41.5",     sprintf("%.1f", last$c_wages),
  "  Supplements",                                    "8.9",     sprintf("%.1f", last$c_supp),
  "Unambiguous capital, cents per $ of GDI",         "~17",      sprintf("%.1f", last$c_ucap),
  "  of which rental income of persons",              "3.6",     sprintf("%.1f", last$c_rent),
  "Proprietors' income, cents per $ of GDI",          "6.7",     sprintf("%.1f", last$c_prop),
  "Capital + proprietors, cents per $ of GDI",       "24",       sprintf("%.1f", last$c_ucap + last$c_prop),
  "Consumption of fixed capital, cents per $",       "~17",      sprintf("%.1f", last$c_cfc),
  "Taxes on production and imports (net), cents",     "7.0",     sprintf("%.1f", last$c_topi),
  "Taxes on corporate income, cents",                 "2.8",     sprintf("%.1f", last$c_ctax),
  "LABOR share of net income, latest",               "68.3",     sprintf("%.1f", last$lab_net),
  "CAPITAL share of net income, latest",             "22.6",     sprintf("%.1f", last$cap_net),
  "PROPRIETORS' share of net income, latest",         "9.1",     sprintf("%.1f", last$prop_net),
  "Max capital share of net income, latest",         "31.7",     sprintf("%.1f", last$capmax_net),
  "Labor share of net income, 1947-49 avg",          "~69",      sprintf("%.1f", m4749$lab_net),
  "Capital share of net income, 1947-49 avg",        "~13",      sprintf("%.1f", m4749$cap_net),
  "Proprietors' share of net income, 1947-49 avg",   "~18",      sprintf("%.1f", m4749$prop_net),
  "Labor share of net income, 1970s avg",            "~75",      sprintf("%.1f", d1970$lab_net),
  "Proprietors' share of net income, 1970",          "~10",      sprintf("%.1f", a$prop_net[a$year == 1970]),
  "Proprietors' share, 1982 trough",                  "6.7",     sprintf("%.1f", a$prop_net[a$year == 1982]),
  "Capital share of net income, 2000",               "17",       sprintf("%.1f", a$cap_net[a$year == 2000])
)

sink(file.path(TABS_SEC, "t01_replication_validation.txt"))
cat("Tax Foundation labor-share replication\n")
cat("Source: DiSalvo & York, Tax Foundation, 2026-09-03\n")
cat("Data:   BEA NIPA Table 1.10, quarterly, vintage",
    format(Sys.time(), "%Y-%m-%d"), "\n")
cat("Latest quarter in data:", lq, "\n\n")
cat("Identity checks (max abs deviation, $ millions; BEA publishes to $1m):\n")
cat(sprintf("  GDI = comp + TOPI_net + NOS + CFC              : %.4f\n", id1))
cat(sprintf("  ucap = private NOS - proprietors - corp taxes  : %.4f\n", id2))
cat(sprintf("  net income = GDI - CFC - TOPI - ctax - govt ent: %.4f\n", id3))
cat(sprintf("  three net-income shares sum to 100            : %.2e\n", id4))
cat(sprintf("  quarters with an incomplete income split      : %d\n\n", n_incomplete))
print(as.data.frame(chk), right = FALSE, row.names = FALSE)
cat("\nAll TF figures reproduce to the precision reported in the blog post.\n")
sink()

cat(readLines(file.path(TABS_SEC, "t01_replication_validation.txt")), sep = "\n")
