#!/usr/bin/env Rscript

default_input <- file.path("data", "mosaic_events_autosomal.txt")
default_prefix <- "mosaic_events_autosomal_circos"
script_version <- "1.1.1"

load_required_packages <- function() {
  suppressPackageStartupMessages({
    if (!requireNamespace("circlize", quietly = TRUE)) {
      stop("The R package 'circlize' is required. Install it with install.packages('circlize').", call. = FALSE)
    }
    library(circlize)
  })
}

parse_args <- function(args) {
  opts <- list(
    input = default_input,
    output_prefix = default_prefix,
    types = c("Gain", "CN-LOH", "Loss"),
    type_column = "type_FINAL",
    sample_column = "sample_id",
    sep = "auto",
    genome = "hg38",
    start_column = NULL,
    end_column = NULL,
    width = 3600,
    height = 3600,
    dpi = 300,
    make_png = TRUE,
    make_pdf = TRUE,
    legend = TRUE,
    title = NULL
  )

  for (arg in args) {
    if (grepl("^--input=", arg)) {
      opts$input <- sub("^--input=", "", arg)
    } else if (grepl("^--output-prefix=", arg)) {
      opts$output_prefix <- sub("^--output-prefix=", "", arg)
    } else if (grepl("^--types=", arg)) {
      opts$types <- strsplit(sub("^--types=", "", arg), ",", fixed = TRUE)[[1]]
      opts$types <- trimws(opts$types)
    } else if (grepl("^--type-column=", arg)) {
      opts$type_column <- sub("^--type-column=", "", arg)
    } else if (grepl("^--sample-column=", arg)) {
      opts$sample_column <- sub("^--sample-column=", "", arg)
    } else if (grepl("^--sep=", arg)) {
      opts$sep <- tolower(sub("^--sep=", "", arg))
    } else if (grepl("^--genome=", arg)) {
      opts$genome <- tolower(sub("^--genome=", "", arg))
    } else if (grepl("^--start-column=", arg)) {
      opts$start_column <- sub("^--start-column=", "", arg)
    } else if (grepl("^--end-column=", arg)) {
      opts$end_column <- sub("^--end-column=", "", arg)
    } else if (grepl("^--width=", arg)) {
      opts$width <- as.integer(sub("^--width=", "", arg))
    } else if (grepl("^--height=", arg)) {
      opts$height <- as.integer(sub("^--height=", "", arg))
    } else if (grepl("^--dpi=", arg)) {
      opts$dpi <- as.integer(sub("^--dpi=", "", arg))
    } else if (arg == "--no-png") {
      opts$make_png <- FALSE
    } else if (arg == "--no-pdf") {
      opts$make_pdf <- FALSE
    } else if (arg == "--no-legend") {
      opts$legend <- FALSE
    } else if (grepl("^--title=", arg)) {
      opts$title <- sub("^--title=", "", arg)
    } else if (arg == "--version") {
      cat("plot_mosaic_circos.R version ", script_version, "\n", sep = "")
      quit(status = 0)
    } else if (arg %in% c("--help", "-h")) {
      cat(
        "plot_mosaic_circos.R version ", script_version, "\n\n",
        "Usage:\n",
        "  Rscript plot_mosaic_circos.R [options]\n\n",
        "Options:\n",
        "  --input=FILE             Input tab- or whitespace-delimited mosaic events file.\n",
        "  --output-prefix=PREFIX   Output prefix for PNG/PDF/summary files.\n",
        "  --types=A,B,C            Comma-separated event type values to plot.\n",
        "  --type-column=NAME       Event type column. Default: type_FINAL; falls back to type.\n",
        "  --sample-column=NAME     Sample ID column. Default: sample_id; if absent, row IDs are used.\n",
        "  --sep=auto|tab|space|whitespace\n",
        "                           Input delimiter. Default: auto.\n",
        "  --genome=hg38|hg19       Genome build. Default: hg38.\n",
        "                           hg38 uses beg_GRCh38/end_GRCh38 by default.\n",
        "                           hg19 uses beg_GRCh37/end_GRCh37 by default.\n",
        "  --start-column=NAME      Override start coordinate column.\n",
        "  --end-column=NAME        Override end coordinate column.\n",
        "  --width=PIXELS           PNG width. Default: 3600.\n",
        "  --height=PIXELS          PNG height. Default: 3600.\n",
        "  --dpi=DPI                PNG resolution. Default: 300.\n",
        "  --title=TEXT             Optional plot title.\n",
        "  --no-png                 Do not write PNG.\n",
        "  --no-pdf                 Do not write PDF.\n",
        "  --no-legend              Do not draw the center legend.\n",
        "  --version                Print script version and exit.\n",
        sep = ""
      )
      quit(status = 0)
    } else {
      stop("Unknown argument: ", arg)
    }
  }

  if (!opts$make_png && !opts$make_pdf) {
    stop("Nothing to do: both --no-png and --no-pdf were supplied.")
  }
  if (!opts$genome %in% c("hg19", "hg38")) {
    stop("--genome must be either hg19 or hg38.")
  }
  if (!opts$sep %in% c("auto", "tab", "space", "whitespace")) {
    stop("--sep must be one of: auto, tab, space, whitespace.")
  }

  default_coord_cols <- switch(
    opts$genome,
    hg19 = c(start = "beg_GRCh37", end = "end_GRCh37"),
    hg38 = c(start = "beg_GRCh38", end = "end_GRCh38")
  )
  if (is.null(opts$start_column)) {
    opts$start_column <- default_coord_cols[["start"]]
  }
  if (is.null(opts$end_column)) {
    opts$end_column <- default_coord_cols[["end"]]
  }

  opts
}

resolve_input_path <- function(path) {
  if (file.exists(path)) {
    return(normalizePath(path, winslash = "/", mustWork = TRUE))
  }

  # The project is often described with a Linux /DCEG path but mounted as T:/DCEG
  # in this Windows workspace.
  if (.Platform$OS.type == "windows" && grepl("^/DCEG/", path)) {
    candidate <- paste0("T:", path)
    if (file.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  stop("Input file does not exist: ", path)
}

normalize_output_prefix <- function(prefix) {
  prefix <- gsub("\\\\", "/", prefix)
  dirname_part <- dirname(prefix)
  if (!dir.exists(dirname_part) && dirname_part != ".") {
    dir.create(dirname_part, recursive = TRUE, showWarnings = FALSE)
  }
  normalizePath(dirname_part, winslash = "/", mustWork = TRUE) |>
    file.path(basename(prefix))
}

fallback_chr_lengths <- list(
  hg19 = c(
    chr1 = 249250621, chr2 = 243199373, chr3 = 198022430, chr4 = 191154276,
    chr5 = 180915260, chr6 = 171115067, chr7 = 159138663, chr8 = 146364022,
    chr9 = 141213431, chr10 = 135534747, chr11 = 135006516, chr12 = 133851895,
    chr13 = 115169878, chr14 = 107349540, chr15 = 102531392, chr16 = 90354753,
    chr17 = 81195210, chr18 = 78077248, chr19 = 59128983, chr20 = 63025520,
    chr21 = 48129895, chr22 = 51304566
  ),
  hg38 = c(
    chr1 = 248956422, chr2 = 242193529, chr3 = 198295559, chr4 = 190214555,
    chr5 = 181538259, chr6 = 170805979, chr7 = 159345973, chr8 = 145138636,
    chr9 = 138394717, chr10 = 133797422, chr11 = 135086622, chr12 = 133275309,
    chr13 = 114364328, chr14 = 107043718, chr15 = 101991189, chr16 = 90338345,
    chr17 = 83257441, chr18 = 80373285, chr19 = 58617616, chr20 = 64444167,
    chr21 = 46709983, chr22 = 50818468
  )
)

load_cytoband <- function(genome, chromosomes) {
  out <- tryCatch(read.cytoband(species = genome), error = function(e) NULL)
  if (is.null(out)) {
    message("Could not load ", genome, " cytobands with circlize; drawing chromosomes from built-in lengths.")
    return(list(cytoband = NULL, chr_lengths = fallback_chr_lengths[[genome]][chromosomes]))
  }

  cytoband <- out$df[out$df[[1]] %in% chromosomes, , drop = FALSE]
  chr_lengths <- out$chr.len[chromosomes]
  if (any(!is.finite(chr_lengths))) {
    message("Could not read all ", genome, " chromosome lengths from cytobands; using built-in lengths.")
    chr_lengths <- fallback_chr_lengths[[genome]][chromosomes]
  }
  list(cytoband = cytoband, chr_lengths = chr_lengths)
}

assign_lanes_one_chrom <- function(events) {
  if (nrow(events) == 0) {
    return(events)
  }

  events <- events[order(events$start, events$end, events$sample_id), , drop = FALSE]
  lane_ends <- numeric(0)
  events$lane <- NA_integer_

  for (i in seq_len(nrow(events))) {
    available <- which(lane_ends <= events$start[i])
    lane <- if (length(available) > 0) available[1] else length(lane_ends) + 1
    events$lane[i] <- lane
    lane_ends[lane] <- events$end[i]
  }

  events
}

assign_lanes <- function(events, chromosomes) {
  split_events <- split(events, interaction(events$type, events$chrom, drop = TRUE), drop = TRUE)
  lane_events <- do.call(rbind, lapply(split_events, assign_lanes_one_chrom))
  rownames(lane_events) <- NULL

  lane_summary <- expand.grid(
    type = unique(events$type),
    chrom = chromosomes,
    stringsAsFactors = FALSE
  )
  lane_summary$n_events <- 0L
  lane_summary$n_lanes <- 0L

  for (i in seq_len(nrow(lane_summary))) {
    idx <- lane_events$type == lane_summary$type[i] & lane_events$chrom == lane_summary$chrom[i]
    lane_summary$n_events[i] <- sum(idx)
    lane_summary$n_lanes[i] <- if (any(idx)) max(lane_events$lane[idx]) else 0L
  }

  list(events = lane_events, lane_summary = lane_summary)
}

allocate_track_heights <- function(max_lanes, total_height = 0.70) {
  max_lanes <- pmax(max_lanes, 1)
  common_lane_height <- total_height / sum(max_lanes)
  max_lanes * common_lane_height
}

read_event_table <- function(input, sep = "auto") {
  sep <- tolower(sep)
  if (!sep %in% c("auto", "tab", "space", "whitespace")) {
    stop("--sep must be one of: auto, tab, space, whitespace.")
  }

  if (identical(sep, "auto")) {
    preview <- readLines(input, n = 25, warn = FALSE)
    preview <- preview[nzchar(trimws(preview)) & !grepl("^\\s*#", preview)]
    if (length(preview) == 0) {
      stop("Input file is empty or contains only blank/comment lines: ", input)
    }
    sep <- if (grepl("\t", preview[1], fixed = TRUE)) "tab" else "whitespace"
    message("Auto-detected input delimiter: ", sep)
  }

  read_sep <- if (identical(sep, "tab")) "\t" else ""
  read.table(
    input,
    header = TRUE,
    sep = read_sep,
    quote = "",
    comment.char = "",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    strip.white = TRUE,
    blank.lines.skip = TRUE
  )
}

prepare_events <- function(input, types, chr_lengths, type_column = "type_FINAL",
                           sample_column = "sample_id",
                           sep = "auto",
                           start_column = "beg_GRCh38", end_column = "end_GRCh38") {
  required_cols <- c("chrom", start_column, end_column)
  raw <- read_event_table(input, sep)

  missing_cols <- setdiff(required_cols, names(raw))
  if (length(missing_cols) > 0) {
    stop("Missing required column(s): ", paste(missing_cols, collapse = ", "))
  }

  if (!type_column %in% names(raw)) {
    if (identical(type_column, "type_FINAL") && "type" %in% names(raw)) {
      message("Column 'type_FINAL' not found; using column 'type' for event categories.")
      type_column <- "type"
    } else {
      stop("Missing event type column: ", type_column)
    }
  }

  row_id_width <- max(1, nchar(nrow(raw)))
  make_row_ids <- function(i) {
    sprintf(paste0("row_%0", row_id_width, "d"), i)
  }

  if (sample_column %in% names(raw)) {
    sample_id <- as.character(raw[[sample_column]])
  } else if (identical(sample_column, "sample_id")) {
    message("Column 'sample_id' not found; using row numbers for stable event sorting.")
    sample_id <- make_row_ids(seq_len(nrow(raw)))
  } else {
    stop("Missing sample ID column: ", sample_column)
  }
  missing_sample_id <- is.na(sample_id) | sample_id == ""
  if (any(missing_sample_id)) {
    sample_id[missing_sample_id] <- make_row_ids(which(missing_sample_id))
  }

  events <- data.frame(
    sample_id = sample_id,
    chrom = raw$chrom,
    start = suppressWarnings(as.numeric(raw[[start_column]])),
    end = suppressWarnings(as.numeric(raw[[end_column]])),
    type = raw[[type_column]],
    stringsAsFactors = FALSE
  )

  events$chrom <- ifelse(grepl("^chr", events$chrom), events$chrom, paste0("chr", events$chrom))
  events <- events[events$type %in% types, , drop = FALSE]
  events <- events[events$chrom %in% names(chr_lengths), , drop = FALSE]
  events <- events[is.finite(events$start) & is.finite(events$end), , drop = FALSE]
  events <- events[events$end > events$start, , drop = FALSE]

  if (nrow(events) == 0) {
    stop("No events remain after filtering to: ", paste(types, collapse = ", "))
  }

  events$start <- pmax(0, events$start)
  events$end <- pmin(events$end, chr_lengths[events$chrom])
  events <- events[events$end > events$start, , drop = FALSE]
  events$type <- factor(events$type, levels = types)
  events[order(events$type, events$chrom, events$start, events$end), , drop = FALSE]
}

draw_mosaic_circos <- function(events, lane_summary, chr_meta, types, track_heights, opts) {
  colors <- c(
    Gain = "#39b54a",
    `CN-LOH` = "#3c98cf",
    Loss = "#ff4b36",
    Undetermined = "#8a8a8a"
  )
  borders <- c(
    Gain = "#2f9340",
    `CN-LOH` = "#2a7fb2",
    Loss = "#dd3426",
    Undetermined = "#666666"
  )
  # Light alpha backgrounds keep track identity visible without competing with event tiles.
  bg_base <- c(
    Gain = "#39b54a",
    `CN-LOH` = "#3c98cf",
    Loss = "#ff4b36",
    Undetermined = "#8a8a8a"
  )
  backgrounds <- grDevices::adjustcolor(bg_base, alpha.f = 0.18)
  bg_borders <- grDevices::adjustcolor(bg_base, alpha.f = 0.35)
  names(backgrounds) <- names(bg_base)
  names(bg_borders) <- names(bg_base)

  colors <- colors[types]
  borders <- borders[types]
  backgrounds <- backgrounds[types]
  bg_borders <- bg_borders[types]
  names(colors) <- types
  names(borders) <- types
  names(backgrounds) <- types
  names(bg_borders) <- types
  missing_colors <- is.na(colors)
  if (any(missing_colors)) {
    missing_types <- names(colors)[missing_colors]
    palette <- grDevices::hcl.colors(sum(missing_colors), palette = "Dark 3")
    names(palette) <- missing_types
    colors[missing_types] <- palette
    borders[missing_types] <- palette
    backgrounds[missing_types] <- grDevices::adjustcolor(palette, alpha.f = 0.18)
    bg_borders[missing_types] <- grDevices::adjustcolor(palette, alpha.f = 0.35)
  }

  chromosomes <- names(chr_meta$chr_lengths)
  max_lanes <- tapply(lane_summary$n_lanes, lane_summary$type, max)
  max_lanes <- pmax(max_lanes[types], 1)
  event_counts <- table(factor(events$type, levels = types))

  circos.clear()
  circos.par(
    start.degree = 90,
    gap.after = c(rep(2.4, length(chromosomes) - 1), 7),
    track.margin = c(0.004, 0.004),
    cell.padding = c(0, 0, 0, 0)
  )

  if (!is.null(chr_meta$cytoband)) {
    ideogram_args <- list(
      cytoband = chr_meta$cytoband,
      chromosome.index = chromosomes,
      sort.chr = FALSE,
      major.by = 5e7,
      plotType = c("ideogram", "axis", "labels"),
      ideogram.height = convert_height(2.5, "mm"),
      axis.labels.cex = 0.22,
      labels.cex = 1.15
    )
    if ("draw.chr.prefix" %in% names(formals(circos.initializeWithIdeogram))) {
      ideogram_args$draw.chr.prefix <- FALSE
    }
    do.call(circos.initializeWithIdeogram, ideogram_args)
  } else {
    chrom_data <- data.frame(
      chrom = chromosomes,
      start = 0,
      end = as.numeric(chr_meta$chr_lengths),
      stringsAsFactors = FALSE
    )
    circos.genomicInitialize(
      chrom_data,
      sector.names = chromosomes,
      major.by = 5e7,
      plotType = c("axis", "labels"),
      tickLabelsStartFromZero = TRUE,
      axis.labels.cex = 0.22,
      labels.cex = 1.15
    )
  }

  sector_ids <- get.all.sector.index()
  if (length(sector_ids) != length(chromosomes)) {
    stop("Unexpected chromosome sector count after circos initialization.")
  }
  sector_to_chrom <- stats::setNames(chromosomes, sector_ids)

  for (type in types) {
    type_events <- events[events$type == type, , drop = FALSE]
    type_max_lanes <- max_lanes[type]
    tile_padding <- 0.035

    circos.trackPlotRegion(
      factors = sector_ids,
      ylim = c(0, type_max_lanes),
      track.height = track_heights[type],
      bg.border = NA,
      panel.fun = function(x, y) {
        chrom <- sector_to_chrom[[CELL_META$sector.index]]
        xlim <- CELL_META$xlim
        circos.rect(
          xleft = xlim[1],
          ybottom = CELL_META$ylim[1],
          xright = xlim[2],
          ytop = CELL_META$ylim[2],
          col = backgrounds[type],
          border = bg_borders[type],
          lwd = 0.28
        )

        idx <- type_events$chrom == chrom
        if (any(idx)) {
          ev <- type_events[idx, , drop = FALSE]
          circos.rect(
            xleft = ev$start,
            ybottom = ev$lane - 1 + tile_padding,
            xright = ev$end,
            ytop = ev$lane - tile_padding,
            col = colors[type],
            border = borders[type],
            lwd = 0.35
          )
        }
      }
    )
  }

  if (!is.null(opts$title) && nzchar(opts$title)) {
    title(opts$title, cex.main = 1)
  }

  if (isTRUE(opts$legend)) {
    legend_labels <- sprintf(
      "%s  n=%s",
      types,
      as.integer(event_counts[types])
    )
    legend(
      "center",
      legend = legend_labels,
      fill = colors[types],
      border = borders[types],
      bty = "n",
      cex = 1.05,
      x.intersp = 0.7,
      y.intersp = 1.1
    )
  }

  circos.clear()
}

write_summary <- function(prefix, events, lane_summary, types, track_heights) {
  max_lanes <- tapply(lane_summary$n_lanes, lane_summary$type, max)
  event_counts <- table(factor(events$type, levels = types))
  track_summary <- data.frame(
    type = types,
    n_events = as.integer(event_counts[types]),
    max_lanes = as.integer(max_lanes[types]),
    track_height_fraction = round(as.numeric(track_heights[types]), 4),
    lane_height_fraction = round(as.numeric(track_heights[types]) / pmax(max_lanes[types], 1), 5),
    stringsAsFactors = FALSE
  )

  write.table(
    track_summary,
    paste0(prefix, "_track_summary.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )
  write.table(
    lane_summary[order(lane_summary$type, lane_summary$chrom), ],
    paste0(prefix, "_lane_summary_by_chrom.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )
}

main <- function() {
  opts <- parse_args(commandArgs(trailingOnly = TRUE))
  message("plot_mosaic_circos.R version ", script_version)
  load_required_packages()
  input <- resolve_input_path(opts$input)
  prefix <- normalize_output_prefix(opts$output_prefix)
  chromosomes <- paste0("chr", 1:22)

  chr_meta <- load_cytoband(opts$genome, chromosomes)
  events <- prepare_events(
    input,
    opts$types,
    chr_meta$chr_lengths,
    opts$type_column,
    opts$sample_column,
    opts$sep,
    opts$start_column,
    opts$end_column
  )
  lane_info <- assign_lanes(events, chromosomes)
  events <- lane_info$events
  lane_summary <- lane_info$lane_summary
  max_lanes <- tapply(lane_summary$n_lanes, lane_summary$type, max)
  max_lanes <- pmax(max_lanes[opts$types], 1)
  track_heights <- allocate_track_heights(max_lanes)
  names(track_heights) <- opts$types

  write_summary(prefix, events, lane_summary, opts$types, track_heights)

  if (opts$make_png) {
    png_file <- paste0(prefix, ".png")
    png(png_file, width = opts$width, height = opts$height, res = opts$dpi, type = "cairo-png")
    draw_mosaic_circos(events, lane_summary, chr_meta, opts$types, track_heights, opts)
    dev.off()
    message("Wrote ", png_file)
  }

  if (opts$make_pdf) {
    pdf_file <- paste0(prefix, ".pdf")
    pdf(pdf_file, width = opts$width / opts$dpi, height = opts$height / opts$dpi, useDingbats = FALSE)
    draw_mosaic_circos(events, lane_summary, chr_meta, opts$types, track_heights, opts)
    dev.off()
    message("Wrote ", pdf_file)
  }

  message("Wrote ", paste0(prefix, "_track_summary.tsv"))
  message("Wrote ", paste0(prefix, "_lane_summary_by_chrom.tsv"))
}

main()
