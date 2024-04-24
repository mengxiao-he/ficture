# Load necessary libraries
suppressPackageStartupMessages({
  library(readr, quietly = TRUE)
  library(dplyr, quietly = TRUE)
  library(tidyverse, quietly = TRUE)
  library(arrow, quietly = TRUE)
})

# Parse the command line arguments
args <- commandArgs(trailingOnly = TRUE)
bfile_path <- args[1]
mfile_path <- args[2]
ffile_path <- args[3]
brc_parq_path <- args[4]
output_path <- args[5]

# Read the files into data frames
ffile <- read_tsv(gzfile(ffile_path), col_names = c("gene_id", "gene", "type"), show_col_types = FALSE)
print("Finished reading feature.tsv.gz")
bfile <- read_tsv(gzfile(bfile_path), col_names = "barcode", show_col_types = FALSE)
print("Finished reading barcode.tsv.gz")
mfile <- read_delim(gzfile(mfile_path), delim = " ", skip = 3, col_names = c("gene_id_idx", "barcode_idx", "Count"), show_col_types = FALSE)
print("Finished reading matrix.mtx.gz")
brc_parq <- read_parquet(brc_parq_path)
print("Finished reading tissue_positions.parquet")

# Perform the necessary transformations and merges
bfile <- bfile %>% 
  mutate(barcode_idx = row_number())
ffile <- ffile %>% 
  mutate(gene_id_idx = row_number())
brc_parq <- brc_parq %>% 
  select(barcode, X = pxl_row_in_fullres, Y = pxl_col_in_fullres)
bfile <- inner_join(bfile, brc_parq, by = "barcode")
merged <- inner_join(mfile, bfile, by = "barcode_idx")
merged <- inner_join(merged, ffile, by = "gene_id_idx")
merged <- merged %>% 
  select(barcode_idx, X, Y, gene_id, gene, Count) %>% 
  arrange(X, Y)

# # Subset tp 10% of the data
# print("Subsetting to 10% of the data")
# merged <- head(merged, nrow(merged) %/% 10)
# print("Finished subsetting to 10% of the data")

min_max <- data.frame(
  minmax = c("xmin", "xmax", "ymin", "ymax"),
  value = c(min(merged$X), max(merged$X), min(merged$Y), max(merged$Y))
)

# Write the output file
write_tsv(merged, gzfile(file.path(output_path, "transcripts.tsv.gz")))
print("Finished writing transcripts.tsv.gz")
write.table(min_max, file.path(output_path, "coordinate_minmax.tsv"), sep = "\t", col.names = FALSE, row.names = FALSE, quote = FALSE)
print("Finished writing coordinate_minmax.tsv")

# Exit the script
print("Finished running ficture_preproc.R")