# Labor share: replicating the Tax Foundation's net-income measure

Replication of Richard DiSalvo and Erica York, "Capital Is Not Taking Half of America's
Income, and Other Myths About the 'Labor Share'" (Tax Foundation, September 3, 2026), built
directly from BEA NIPA register files, plus sensitivity analysis placing their measure
against the labor-share literature.

**Main write-up:** [`docs/replication_and_literature.md`](docs/replication_and_literature.md)

## Result in one line

Their arithmetic replicates exactly. Their conclusion depends on treating all proprietors'
income as capital, which they themselves say is wrong; fix that and the labor share is down
7 to 10 points from its postwar peak to near an 80-year low.

## Pipeline

```bash
Rscript R/01_download_nipa.R      # BEA NIPA quarterly + annual register files -> data/raw
Rscript R/02_replicate_tf.R       # exact replication + validation table
Rscript R/03_variants.R           # nine alternative conventions
Rscript R/04_decomposition.R      # sector shift-share of the net labor share
Rscript R/05_figures.R            # figures
Rscript R/06_universe.R           # what is inside their income universe
```

Requires R with `tidyverse` and [`tidyusmacro`](https://github.com/mtkonczal/tidyusmacro)
(>= 0.3.0). No API key needed; NIPA register files are public flat files.

## Outputs

| File | Contents |
|---|---|
| `output/tables/t01_replication_validation.txt` | Every Tax Foundation figure, claimed vs replicated, plus accounting-identity checks |
| `output/tables/t02_variants_summary.txt` | Labor share under nine conventions, by era, with 79-year ranks |
| `output/tables/t03_sector_decomposition.txt` | Within- vs between-sector shift-share |
| `output/tables/t04_universe.txt` | Composition of their income universe vs corporate and nonfinancial corporate |
| `output/figures/f01_tf_replication.png` | The three-way split of net income, 1947-2026 |
| `output/figures/f02_net_vs_gross.png` | Net vs gross labor share |
| `output/figures/f03_proprietor_bounds.png` | Labor share under three allocations of proprietors' income |
| `output/figures/f03b_proprietor_bounds_1960.png` | Same, 1960 onward, compensation only vs 50/50 split |
| `output/figures/f04_corporate_sector.png` | Corporate-sector labor share, three conventions |
| `output/figures/f05_shift_share.png` | Decomposition of the 1947-49 to 2026 change |
| `output/figures/f06_capital_ex_housing.png` | Capital share with and without rental income of persons |

Derived CSVs land in `data/derived/`, each with a `.vintage.txt` stamp recording the pull
timestamp. NIPA data are revised; re-running `01_download_nipa.R` changes the numbers.

## Data notes

- All series come from NIPA Tables 1.10, 1.13, 1.14 and 7.4.5, quarterly, SAAR, current
  dollars, 1947Q1 through the latest published quarter.
- `tidyusmacro::getNIPAFiles(type = "A")` fails on the annual file's bare-year `Period`
  string as of 0.3.0, so `01_download_nipa.R` carries a local annual loader.
- Net operating surplus and the current surplus of government enterprises are not published
  quarterly before 1959; the two identity checks that use them are evaluated where they
  exist. The three income categories themselves are complete from 1947Q1.
- The final annual observation is a partial year. Ranks are reported for the last full
  calendar year.
