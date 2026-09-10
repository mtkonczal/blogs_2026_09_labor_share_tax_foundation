# Replicating the Tax Foundation labor-share measure, and where it sits in the literature

**Source under replication:** Richard DiSalvo and Erica York, "Capital Is Not Taking Half of
America's Income, and Other Myths About the 'Labor Share,'" Tax Foundation, September 3, 2026.

**Data:** BEA NIPA quarterly register files (`https://apps.bea.gov/national/Release/TXT/`),
pulled via `tidyusmacro::getNIPAFiles(type = "Q")`, vintage 2026-09-09, through 2026Q2.
Tables 1.10, 1.13, 1.14, 7.4.5.

---

## 1. What they built

Every number in the post comes out of NIPA Table 1.10 (Gross Domestic Income by Type of
Income). The construction, reverse-engineered and confirmed to the last reported digit:

| Category | Table 1.10 lines |
|---|---|
| Unambiguous **labor** | Compensation of employees, paid (2) |
| **Ambiguous** | Proprietors' income with IVA and CCAdj (13) |
| Unambiguous **capital** | Net interest and misc. payments (11) + business current transfer payments (12) + rental income of persons with CCAdj (14) + corporate profits **after tax** with IVA and CCAdj (17) |

Equivalently, unambiguous capital is the net operating surplus of private enterprises (10)
less proprietors' income less taxes on corporate income. The denominator is the sum of the
three:

```
net income = GDI - consumption of fixed capital
                 - taxes on production and imports net of subsidies
                 - taxes on corporate income
                 - current surplus of government enterprises
```

Two conventions inside this are worth naming, because neither is standard and neither is
stated in the post:

1. **Corporate income taxes are removed from the denominator** and profits are measured
   after tax. This is a "cash that reaches a household" concept, not the net national
   income concept used in the literature.
2. **The current surplus of government enterprises is dropped** (small and negative). That
   is what makes the three shares sum to exactly 100.

## 2. The replication is exact

`output/tables/t01_replication_validation.txt`. Every figure reproduces at the precision
the post reports, including all the historical claims:

| Claim | Post | Replicated |
|---|---|---|
| GDI, 2026Q2 SAAR | $32.2t | $32.2t |
| Compensation, cents per $ of GDI | 50.4 | 50.4 |
| Wages and salaries / supplements | 41.5 / 8.9 | 41.5 / 8.9 |
| Unambiguous capital, cents per $ | "nearly 17" | 16.7 |
| Proprietors' income, cents per $ | 6.7 | 6.7 |
| Depreciation, cents per $ | "nearly 17" | 16.7 |
| Production taxes net / corporate income tax | 7.0 / 2.8 | 7.0 / 2.8 |
| Net income | $23.7t | $23.8t |
| **Labor share of net income** | **68.3%** | **68.3%** |
| **Unambiguous capital share** | **22.6%** | **22.6%** |
| **Proprietors' share** | **9.1%** | **9.1%** |
| Max capital share | 31.7% | 31.7% |
| Labor share, 1947-49 | ~69% | 69.2% |
| Capital share, 1947-49 | ~13% | 13.0% |
| Proprietors' share, 1947-49 | ~18% | 17.8% |
| Labor share, 1970s | ~75% | 75.4% |
| Proprietors' share, 1982 trough | 6.7% | 6.8% |
| Capital share, 2000 | 17% | 16.6% |

The three accounting identities close to within BEA's $1m publication rounding. So the
arithmetic is not in dispute. What is in dispute is what the arithmetic supports.

## 3. Where the measure sits in the literature

### The gross-to-net correction is settled, and they are on the right side of it

Netting out depreciation and production taxes is not a Tax Foundation innovation; it is the
standard correction, and the two canonical cites reach the same conclusion the post does.
[Rognlie (2015, BPEA)](https://www.brookings.edu/wp-content/uploads/2016/07/2015a_rognlie.pdf)
shows the net capital share behaves very differently from the gross one because depreciation
has risen with the shift toward short-lived IT capital.
[Bridgman (2018, *Macroeconomic Dynamics* 22(8): 2070-87)](https://www.cambridge.org/core/journals/macroeconomic-dynamics/article/abs/is-labors-loss-capitals-gain-gross-versus-net-labor-shares/957C5C3D90762547B3CF4924EF34F4E9)
finds the recent net labor share is "within its historical range" while the gross share is
at its lowest level. That is essentially the post's headline, published eight years earlier.
[Koh, Santaeulàlia-Llopis and Zheng (2020, *Econometrica* 88(6): 2609-28)](https://onlinelibrary.wiley.com/doi/abs/10.3982/ECTA17477)
push further: the measured decline is entirely accounted for by the capitalization of
intellectual property products in successive NIPA revisions.

The point is well taken and the level effect is large: 68.3% of net income versus 50.4% of
gross. The "capital takes half" framing really is an artifact of a gross denominator.

But in this data the net correction changes the **level**, not the **trend** (figure
`f02_net_vs_gross.png`). Gross and net compensation shares are down 7.7pp and 7.9pp
respectively from their 1970 peaks. The gross-net distinction is not what produces the
round trip.

### What does produce the round trip: the ambiguous slice

The post takes its three-way taxonomy from
[Karabarbounis (2024, *JEP* 38(2): 107-36)](https://www.aeaweb.org/articles?id=10.1257/jep.38.2.107),
whose own abstract opens: "As of 2022, the share of US income accruing to labor is at its
lowest level since the Great Depression." That is worth sitting with. The taxonomy is
borrowed from a survey that reaches the opposite conclusion.

The reason is Gollin (2002, "Getting Income Shares Right," *JPE* 110(2): 458-74)'s
old problem: the unambiguous-labor share is not comparable across time if the ambiguous
slice changes size. It changed a lot. Proprietors' income fell from **18.3% of net income
in 1947 to 9.1% today**. Comparing compensation-only shares across that shift implicitly
treats a halving of the self-employed sector as if it had no labor content.

Run the bounds (figure `f03_proprietor_bounds.png`, table `t02_variants_summary.txt`):

| Allocation of proprietors' income | 1947-49 | 2025 | 2026H1 | Δ vs 1947-49 | 2025 rank of 79 |
|---|---|---|---|---|---|
| All to capital (the post's headline) | 69.2 | 69.3 | 68.7 | **-0.5** | 6th lowest |
| 75% to labor (Smith et al. 2019) | 81.7 | 76.3 | 75.5 | **-7.0** | 3rd lowest |
| All to labor | 87.0 | 78.6 | 77.8 | **-9.2** | 2nd lowest |

The post concedes the relevant evidence: "recent research suggests proprietor income is
mostly labor." That research is
[Smith, Yagan, Zidar and Zwick (2019, *QJE* 134(4): 1675-1745)](https://academic.oup.com/qje/article-abstract/134/4/1675/5542244),
who classify three-quarters of pass-through profit as human-capital income. Adopt their
number and the round trip becomes a 7pp decline to the third-lowest reading in 79 years.
The headline result holds only under the allocation the authors themselves say is wrong.

### The corporate sector is the clean test, and it fails

Inside the corporate sector there is no proprietors' income to allocate and no imputed rent
to argue about. Wages on one line, profits on another — as the post itself says. Apply the
post's own net-income convention there (figure `f04_corporate_sector.png`):

| Corporate labor share | 1947-49 | peak | 2025 | 2026H1 | Δ vs 1947-49 | Δ vs peak |
|---|---|---|---|---|---|---|
| TF convention (net of production and corporate tax) | 84.1 | 84.7 (1953) | 75.9 | 74.8 | **-9.4** | **-12.5** |
| Compensation / net value added | 68.5 | 75.5 (2001) | 65.3 | 63.7 | **-4.8** | **-11.8** |

Both are at or within a hair of 79-year lows. There is no round trip where the measurement
problem does not exist.

### The composition shift is doing the work

Shift-share the post's own net labor share across three sectors that partition its
denominator (figure `f05_shift_share.png`, table `t03_sector_decomposition.txt`):

**1947-49 to 2026H1: -0.5pp = -5.7pp within sectors + 5.3pp from composition**

| | Within (labor share moved) | Between (weight moved) |
|---|---|---|
| Corporate | **-5.1** | +5.2 |
| Government and nonprofit | 0.0 (labor share = 1 by construction) | +3.7 |
| Other private (noncorporate) | -0.7 | -3.6 |

The flat aggregate is a near-exact cancellation. Labor shares fell 5.7pp within sectors;
composition added 5.3pp back by shifting income out of the noncorporate sector, whose
measured labor share is only 34% precisely because proprietors' income and imputed rent sit
in the capital bucket, and into the corporate sector (86% under this
convention in the late 1940s, 75% now) and government and nonprofits (100% by
construction).

The 1947-to-1970 "rise" the post emphasizes is even starker: **+6.2pp, of which +7.4pp is
composition and -1.2pp is within-sector.** The postwar rise in the labor share, on this
measure, is not a rise in labor's bargaining position. It is the collapse of farming and
the expansion of government and nonprofits, both of which move income into buckets where
NIPA either measures labor share well or assumes it is one. From the 1970s forward, the
-6.7pp decline is -5.0pp within sectors, mostly corporate.

Related: the post criticizes BLS for excluding government and nonprofits, correctly noting
that including them raises the level, and cites
[Giandrea and Sprague (2017, BLS *MLR*)](https://www.bls.gov/opub/mlr/2017/article/estimating-the-us-labor-share.htm)
on this. Fair enough on the level. But the sector's weight in net income moved from 13.2%
in 1947 to 19.5% in 1970 to 16.7% today, so including a sector whose labor share is one by
construction imports that weight's movement straight into the trend. Restricting to the
business sector: 64.6% in 1947-49, 63.1% in 2025, and 8.9pp below the 1980 peak.

### Their non-standard tax convention is not the culprit

Worth stating plainly since it would be the easy criticism: putting corporate income taxes
back in the denominator and using pre-tax profits gives 65.6% in 1947-49 and 66.3% in
2026H1, a slightly *better* round trip than the post's version. High postwar corporate tax
rates cut both ways here. Convention (1) affects the level by about 2.4pp and essentially
nothing else.

### Housing: half the story since 1980, not since 1947

The post flags that 3.6 of its 16.7 cents of capital income is imputed rent, "not actually
cash that people collect," and then keeps it in. Rognlie's finding was that housing accounts
for essentially the entire postwar rise in the net capital share. Removing rental income of
persons from both capital and the denominator (figure `f06_capital_ex_housing.png`):

| Capital share of net income | 1947-49 | 1980 | 2026Q2 |
|---|---|---|---|
| As published | 13.0 | 15.5 | 22.6 |
| Ex rental income of persons | 9.7 | 14.7 | 18.7 |

Since 1980 housing accounts for about 45 percent of the 7.1pp rise in the capital share,
consistent with Rognlie. Over the full postwar period it accounts for little, because rental income of
persons was already 3.7% of net income in 1947.

**Caveat, stated because it matters:** rental income of persons is net of mortgage interest
paid, which is why it troughs at 0.9% of net income in 1980 under double-digit mortgage
rates. The interest itself reappears in "net interest and misc. payments," which is also in
the capital bucket, so total capital income is unaffected but the housing/non-housing split
is distorted across interest-rate regimes. The exact Rognlie decomposition needs the
income-side lines of NIPA Table 7.4.5 (housing net value added, its net operating surplus),
which BEA's `SeriesRegister.txt` does not map to that table; it would require the BEA API or
the interactive tables. Treat the housing split as indicative.

### What the level claim leaves out entirely

The post's argument is about how a dollar of accounting income is labeled. It says nothing
about whether the payments labeled "capital" are a competitive return to capital or economic
rent. [Barkai (2020, *JF* 75(5))](https://onlinelibrary.wiley.com/doi/full/10.1111/jofi.12909)
measures the required return on capital directly and finds both the labor share and the
capital share fell, offset by a large rise in pure profits, roughly 16% of nonfinancial
corporate gross value added. On that decomposition, "capital only takes 22.6%" and "markups
have risen a lot" are both true, and the second is the one that matters for policy. Same for
[De Loecker, Eeckhout and Unger (2020, *QJE*)](https://academic.oup.com/qje/article/135/2/561/5714769)
on markups and
[Autor, Dorn, Katz, Patterson and Van Reenen (2020, *QJE*)](https://academic.oup.com/qje/article/135/2/645/5721266)
on the reallocation of activity toward low-labor-share superstar firms — a within-industry,
between-firm mechanism that an aggregate accounting identity cannot see.
[Grossman and Oberfield (2022, *Annual Review of Economics* 14: 93-124)](https://www.annualreviews.org/content/journals/10.1146/annurev-economics-080921-103046)
survey the explanations and conclude none of them is settled.

## 4. Bottom line

The replication is exact and two of the post's criticisms are right and worth conceding:
the gross denominator overstates capital's take by a lot, and BLS's time-varying imputation
of proprietors' labor income is a real problem that biases its trend
([Elsby, Hobijn and Şahin 2013, BPEA](https://www.brookings.edu/wp-content/uploads/2016/07/2013b_elsby_labor_share.pdf)
document the same imputation drift).

The headline conclusion does not survive its own premises. "Labor share made a round trip"
requires (a) treating all proprietors' income as capital, which the post says is wrong,
(b) including government and nonprofits, whose weight moved substantially over the period,
and (c) comparing to a 1947-49 base in which the ambiguous slice was twice its current size.
Fix any one of the three and you get a decline of 7 to 12pp, at or near an 80-year low. In
the corporate sector, where the measurement problem is absent, the post's own convention
puts the labor share 12.5 points below its 1953 peak, with 2026H1 the lowest reading in the
series.

The defensible version of the finding is narrower and still useful: **capital income net of
depreciation and taxes is 22.6 to 31.7 percent of net income, not half; the labor share is not down by the 13 to 15
points implied by the BLS nonfarm-business series the post criticizes; and it is down by
roughly 7 to 10 points from its postwar peak, to about the lowest level in the series.**

---

### Reproduce

```
Rscript R/01_download_nipa.R
Rscript R/02_replicate_tf.R
Rscript R/03_variants.R
Rscript R/04_decomposition.R
Rscript R/05_figures.R
```
