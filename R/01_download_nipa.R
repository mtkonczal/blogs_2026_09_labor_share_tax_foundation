# 01_download_nipa.R ---------------------------------------------------------
# Pull BEA NIPA register files. Quarterly comes from tidyusmacro::getNIPAFiles();
# the annual file uses a bare-year Period string that getNIPAFiles() cannot
# parse (as of tidyusmacro 0.3.0), so we replicate its logic here for type "A".

source("R/00_setup.R")

BEA_TXT <- "https://apps.bea.gov/national/Release/TXT/"

# --- Quarterly ---------------------------------------------------------------
nipa_q <- getNIPAFiles(type = "Q")
stopifnot(nrow(nipa_q) > 1e6, "TableId" %in% names(nipa_q))
saveRDS(nipa_q, file.path(RAW, "nipa_q.rds"))

# --- Annual (manual loader) --------------------------------------------------
get_nipa_annual <- function(base = BEA_TXT) {
  dat <- read_csv(paste0(base, "nipadataA.txt"),
                  col_types = cols(.default = col_character()), progress = FALSE) |>
    rename(SeriesCode = `%SeriesCode`) |>
    mutate(year  = as.integer(Period),
           Value = as.numeric(gsub(",", "", Value)))
  sr <- read_csv(paste0(base, "SeriesRegister.txt"),
                 col_types = cols(.default = col_character()), progress = FALSE) |>
    rename(SeriesCode = `%SeriesCode`, TL = `TableId:LineNo`) |>
    select(SeriesCode, SeriesLabel, TL) |>
    mutate(tl = stri_split_fixed(TL, "|")) |> select(-TL) |> unnest(tl) |>
    separate(tl, into = c("TableId", "LineNo"), sep = ":", convert = TRUE)
  dat |> inner_join(sr, by = "SeriesCode", relationship = "many-to-many")
}

nipa_a <- get_nipa_annual()
stopifnot(nrow(nipa_a) > 5e5)
saveRDS(nipa_a, file.path(RAW, "nipa_a.rds"))

writeLines(
  c(paste("downloaded:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste("source:", BEA_TXT),
    paste("quarterly rows:", nrow(nipa_q),
          "| last quarter:", format(max(nipa_q$date))),
    paste("annual rows:", nrow(nipa_a), "| last year:", max(nipa_a$year))),
  file.path(RAW, "nipa_vintage.txt"))

cat("NIPA download complete. Last quarter:", format(max(nipa_q$date)), "\n")
