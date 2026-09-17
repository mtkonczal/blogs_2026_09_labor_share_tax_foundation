# 00_setup.R -----------------------------------------------------------------
# Shared setup for the labor-share replication.
# Replicates Tax Foundation, "Capital Is Not Taking Half of America's Income,
# and Other Myths About the 'Labor Share'" (DiSalvo & York, Sept 3 2026),
# then places their measure against the labor-share literature.

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringi)
  library(ggplot2); library(scales); library(tidyusmacro)
})

options(dplyr.summarise.inform = FALSE)

PROJ    <- normalizePath(".")
RAW     <- file.path(PROJ, "data", "raw")
DERIVED <- file.path(PROJ, "data", "derived")
FIGS    <- file.path(PROJ, "output", "figures")
TABS    <- file.path(PROJ, "output", "tables")

# Figures/tables split by which write-up consumes them: labor_share_pushback.md
# ("blogpost") vs. docs/replication_and_literature.md, factcheck.qmd, and
# measures_survey.qmd (all "secondary"). data/derived/ stays flat -- almost
# every CSV there is a shared input across several scripts, so splitting it
# would mean duplicating files rather than separating concerns.
FIGS_BLOG <- file.path(FIGS, "blogpost")
FIGS_SEC  <- file.path(FIGS, "secondary")
TABS_BLOG <- file.path(TABS, "blogpost")
TABS_SEC  <- file.path(TABS, "secondary")

for (d in c(RAW, DERIVED, FIGS_BLOG, FIGS_SEC, TABS_BLOG, TABS_SEC)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# Release-mode discipline: every derived file gets a vintage stamp.
write_derived <- function(x, name) {
  readr::write_csv(x, file.path(DERIVED, paste0(name, ".csv")))
  writeLines(
    c(paste("vintage:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
      paste("rows:", nrow(x)),
      paste("nipa_source:", "https://apps.bea.gov/national/Release/TXT/")),
    file.path(DERIVED, paste0(name, ".vintage.txt")))
  invisible(x)
}

theme_ls <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(linewidth = 0.25, colour = "grey85"),
          plot.title    = element_text(face = "bold", size = rel(1.15)),
          plot.subtitle = element_text(colour = "grey30"),
          plot.caption  = element_text(colour = "grey45", hjust = 0),
          legend.position = "none")
}
