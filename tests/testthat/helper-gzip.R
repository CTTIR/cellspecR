# Gzip members and BGZF blocks built in base R.

gzip_member <- function(bytes) {
  path <- tempfile(fileext = ".gz")
  on.exit(unlink(path), add = TRUE)
  con <- gzfile(path, open = "wb")
  writeBin(bytes, con)
  close(con)
  readBin(path, "raw", file.size(path))
}

# A BGZF block is a gzip member whose FEXTRA field holds the "BC" subfield
# with the block size minus one.
bgzf_block <- function(bytes) {
  member <- gzip_member(bytes)
  bsize <- length(member) + 8L - 1L
  c(
    member[1:3], as.raw(bitwOr(as.integer(member[[4L]]), 4L)), member[5:10],
    as.raw(c(6L, 0L, 0x42, 0x43, 2L, 0L, bsize %% 256L, bsize %/% 256L)),
    member[-(1:10)]
  )
}

bgzf_eof <- function() {
  as.raw(c(
    0x1f, 0x8b, 0x08, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0x06, 0x00,
    0x42, 0x43, 0x02, 0x00, 0x1b, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00
  ))
}

# Tab-separated text of a small generic table, split into two parts.
gzip_table_parts <- function(n = 60L) {
  lines <- c(
    "id\tx\ty\tvalue",
    sprintf("c%03d\t%d\t%d\t%.1f", seq_len(n), seq_len(n), 2L * seq_len(n),
            seq_len(n) / 2)
  )
  half <- n %/% 2L + 1L
  list(
    first = charToRaw(paste0(paste(lines[seq_len(half)], collapse = "\n"), "\n")),
    second = charToRaw(paste0(paste(lines[-seq_len(half)], collapse = "\n"), "\n"))
  )
}
