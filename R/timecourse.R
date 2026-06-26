# timecourse.R
# ---------------------------------------------------------------------------
# Longitudinal ("spaghetti plot") support for the visit-based domains.
#
# The visit-based datasets store their measurements in incompatible shapes:
#   - VS / EG / EX are WIDE   -- one row per visit, a column per parameter
#                                (SYSBP, DIABP, ...; EGHR, EGQTCB, ...; EXDOSE).
#   - the lab panels are LONG -- one row per (visit, test), a TEST-name column
#                                plus a result column (CHEM: CHMTST/CHMRSLT, ...).
# To browse any of them as a line-per-subject time course from ONE module, we
# stack them into a single tidy long table, TIMECOURSE, with uniform columns:
#   SubjectID | Dataset | Test | Visit | Date | Value | Unit
# build_timecourse() does that; tm_g_spaghetti() is the viewer (Dataset + Test
# dropdowns, one pane). Only numeric results are kept -- a spaghetti plot needs
# a numeric Y -- so qualitative panels (PREG, DRUG) and text findings drop out.
# The viewer renders via plotly (ggplotly) so each point shows a per-subject
# hover tooltip (Subject / Visit / value / date).
# ---------------------------------------------------------------------------

# Friendly axis labels for the WIDE measurement columns (fallback: the code).
.tc_labels <- c(
  SYSBP = "Systolic BP", DIABP = "Diastolic BP", PULSE = "Pulse rate",
  RESP = "Respiratory rate", TEMP = "Temperature",
  EGHR = "Heart rate", EGQD = "QRS duration", EGPI = "PR interval",
  EGRI = "RR interval", EGQTI = "QT interval", EGQTCI = "QTcI",
  EGQTCB = "QTcB",
  EXDOSE = "Dose", EXDOSOT = "Dose (other)"
)

# Per-dataset extraction spec. kind:
#   "wide"   -> `measures` columns each become a Test
#   "long"   -> `testcol` holds the Test name, `result` the value
#   "single" -> one fixed `testname`, `result` the value
# `date`/`unit` are column names (optional; missing -> NA).
.TIMECOURSE_SPEC <- list(
  VS  = list(kind = "wide", visit = "Visit", date = "VSDAT",
             measures = c("SYSBP", "DIABP", "PULSE", "RESP", "TEMP")),
  EG  = list(kind = "wide", visit = "Visit", date = "EGDAT",
             measures = c("EGHR", "EGQD", "EGPI", "EGRI", "EGQTI",
                          "EGQTCI", "EGQTCB")),
  EX  = list(kind = "wide", visit = "Visit", date = "EXDAT",
             measures = c("EXDOSE", "EXDOSOT")),
  CENTLAB = list(kind = "long", visit = "Visit", date = "DATEC",
                 testcol = "TEST", result = "LB1SCCL", unit = NA),
  FSH = list(kind = "single", visit = "Visit", date = "LB4DAT",
             testname = "FSH", result = "LB4ORRES", unit = NA),
  UR  = list(kind = "long", visit = "Visit", date = "URDT",
             testcol = "URTST", result = "URRSLT1", unit = "URUN"),
  CHEM = list(kind = "long", visit = "Visit", date = "CHMDT",
              testcol = "CHMTST", result = "CHMRSLT", unit = "CHMUN"),
  HEM = list(kind = "long", visit = "Visit", date = "LB7DAT",
             testcol = "LB7TEST", result = "LB7RES", unit = "LB7TUN"),
  VIR = list(kind = "long", visit = "Visit", date = "VIRDT",
             testcol = "VIRTEST", result = "VIRRSLT1", unit = "VIRUN")
)

# Coerce a column to numeric, preferring the split_mixed_columns() <col>_num
# helper when present (so "<5"/"POSITIVE"-style mixed columns still yield their
# numeric part). Non-numeric findings become NA and are dropped downstream.
.tc_numeric <- function(df, col) {
  num <- paste0(col, "_num")
  if (num %in% names(df)) return(suppressWarnings(as.numeric(df[[num]])))
  suppressWarnings(as.numeric(df[[col]]))
}

# Parse EDC date strings to Date. EDC dates arrive as "%d-%b-%Y" (e.g.
# "29-Aug-2025"); a few datasets may use other layouts and some values are
# partial/unknown. Try formats in turn, leaving anything unparseable as NA
# (passing an explicit `format` makes as.Date() return NA rather than error).
.tc_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  x <- as.character(x)
  out <- rep(as.Date(NA), length(x))
  fmts <- c("%d-%b-%Y", "%Y-%m-%d", "%d%b%Y", "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d")
  for (fmt in fmts) {
    todo <- is.na(out) & !is.na(x) & nzchar(x)
    if (!any(todo)) break
    out[todo] <- as.Date(x[todo], format = fmt)
  }
  out
}

.tc_label <- function(code) if (code %in% names(.tc_labels)) unname(.tc_labels[[code]]) else code

# Stack the visit-based domains into one tidy long table. Tolerant of missing
# datasets/columns (study variants differ) -- anything absent is simply skipped.
build_timecourse <- function(raw, id = "SubjectID") {
  parts <- list()
  add <- function(d) if (nrow(d)) parts[[length(parts) + 1L]] <<- d

  for (nm in intersect(names(.TIMECOURSE_SPEC), names(raw))) {
    df <- raw[[nm]]
    if (!id %in% names(df)) next
    s <- .TIMECOURSE_SPEC[[nm]]
    n <- nrow(df)

    visit <- if (s$visit %in% names(df)) as.character(df[[s$visit]]) else rep(NA_character_, n)
    date  <- if (!is.null(s$date) && s$date %in% names(df)) .tc_date(df[[s$date]]) else rep(as.Date(NA), n)

    if (identical(s$kind, "wide")) {
      for (m in intersect(s$measures, names(df))) {
        val  <- .tc_numeric(df, m)
        keep <- !is.na(val)
        if (!any(keep)) next
        add(data.frame(
          SubjectID = df[[id]][keep], Dataset = nm, Test = .tc_label(m),
          Visit = visit[keep], Date = date[keep], Value = val[keep],
          Unit = NA_character_, stringsAsFactors = FALSE))
      }
    } else {
      if (!s$result %in% names(df)) next
      test <- if (identical(s$kind, "single")) rep(s$testname, n)
              else if (s$testcol %in% names(df)) trimws(as.character(df[[s$testcol]]))
              else next
      val  <- .tc_numeric(df, s$result)
      unit <- if (!is.null(s$unit) && !is.na(s$unit) && s$unit %in% names(df))
                as.character(df[[s$unit]]) else rep(NA_character_, n)
      keep <- !is.na(val) & !is.na(test) & nzchar(test)
      if (!any(keep)) next
      add(data.frame(
        SubjectID = df[[id]][keep], Dataset = nm, Test = test[keep],
        Visit = visit[keep], Date = date[keep], Value = val[keep],
        Unit = unit[keep], stringsAsFactors = FALSE))
    }
  }

  if (!length(parts)) {
    return(data.frame(SubjectID = character(), Dataset = character(),
                      Test = character(), Visit = character(),
                      Date = as.Date(character()), Value = numeric(),
                      Unit = character(), stringsAsFactors = FALSE))
  }

  out <- do.call(rbind, parts)
  names(out)[1] <- id

  # Order visits chronologically by their median date so the X axis reads in
  # time order; visits whose dates are all missing trail at the end.
  med  <- tapply(as.numeric(out$Date), out$Visit, median, na.rm = TRUE)
  med  <- med[is.finite(med)]
  vlev <- c(names(sort(med)), setdiff(unique(out$Visit), names(med)))
  out$Visit <- factor(out$Visit, levels = vlev)
  out
}

# Custom teal module: spaghetti (line-per-subject) viewer over TIMECOURSE.
# Dataset + Test dropdowns drive a single pane (no faceting); X axis toggles
# between Visit (aligned, ordered by median date) and Date (true elapsed time).
tm_g_spaghetti <- function(label = "Time Course (Spaghetti)",
                           dataname = "TIMECOURSE") {
  teal::module(
    label = label,
    datanames = dataname,
    ui = function(id) {
      ns <- shiny::NS(id)
      teal.widgets::standard_layout(
        output = plotly::plotlyOutput(ns("plot"), height = "650px"),
        encoding = shiny::tags$div(
          shiny::selectInput(ns("dataset"), "Dataset:", choices = NULL),
          shiny::selectInput(ns("test"), "Test / parameter:", choices = NULL),
          shiny::radioButtons(ns("xaxis"), "X axis:",
                              choices = c("Date", "Visit"), inline = TRUE),
          shiny::checkboxInput(ns("overlay"), "Overlay trend (smooth on Date, mean per Visit)", TRUE),
          shiny::checkboxInput(ns("logy"), "Log-scale Y", FALSE)
        )
      )
    },
    server = function(id, data) {
      shiny::moduleServer(id, function(input, output, session) {
        tc <- shiny::reactive(as.data.frame(data()[[dataname]]))

        # Dataset choices follow the (filtered) data.
        shiny::observeEvent(tc(), {
          ds <- sort(unique(as.character(tc()$Dataset)))
          shiny::updateSelectInput(session, "dataset", choices = ds,
                                   selected = ds[1])
        })

        # Test choices follow the selected dataset.
        shiny::observeEvent(list(tc(), input$dataset), {
          shiny::req(input$dataset)
          d <- tc()
          tests <- sort(unique(d$Test[d$Dataset == input$dataset]))
          sel <- if (!is.null(input$test) && input$test %in% tests) input$test else tests[1]
          shiny::updateSelectInput(session, "test", choices = tests, selected = sel)
        })

        plot_r <- shiny::reactive({
          shiny::req(input$dataset, input$test)
          d <- tc()
          d <- d[d$Dataset == input$dataset & d$Test == input$test & !is.na(d$Value), ]
          xvar <- if (identical(input$xaxis, "Date")) "Date" else "Visit"
          d <- d[!is.na(d[[xvar]]), ]
          shiny::validate(shiny::need(
            nrow(d) > 0, "No numeric data for this Dataset / Test / X-axis selection."))

          unit <- unique(d$Unit[!is.na(d$Unit) & nzchar(d$Unit)])
          ylab <- if (length(unit)) paste0(input$test, " (", unit[1], ")") else input$test
           utxt <- if (length(unit)) paste0(" ", unit[1]) else ""

          # Per-point hover text (rendered by ggplotly via the `text` aesthetic).
          d$.tip <- paste0(
            "Subject: ", d$SubjectID,
            "<br>Visit: ", as.character(d$Visit),
            "<br>", input$test, ": ", signif(d$Value, 4), utxt,
            "<br>Date: ", format(d$Date))

          p <- ggplot2::ggplot(
                 d, ggplot2::aes(x = .data[[xvar]], y = .data$Value,
                                 group = .data$SubjectID)) +
            ggplot2::geom_line(alpha = 0.35, linewidth = 0.3, colour = "#377eb8") +
            ggplot2::geom_point(ggplot2::aes(text = .data$.tip),
              alpha = 0.55, size = 1, colour = "#377eb8") +
            ggplot2::labs(
              x = xvar, y = ylab,
              title = paste0(input$dataset, " — ", input$test, "  (",
                             length(unique(d$SubjectID)), " subjects, ",
                             nrow(d), " obs)")) +
            ggplot2::theme_bw() +
            ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))

          # Overlay a single trend line: a loess smooth on the continuous Date
          # axis, or the mean across subjects per visit on the categorical Visit
          # axis (where a smooth is undefined). The Visit mean is pre-aggregated
          # rather than via stat_summary so it translates cleanly to plotly.
          if (isTRUE(input$overlay)) {
            if (identical(xvar, "Date")) {
              p <- p + ggplot2::geom_smooth(
                ggplot2::aes(group = 1, text = NULL), method = "loess",
                formula = y ~ x, se = FALSE, colour = "#e41a1c", linewidth = 1.1)
            } else {
              mn <- aggregate(Value ~ Visit, data = d, FUN = mean)
              mn <- mn[order(match(mn$Visit, levels(d$Visit))), ]
              p <- p +
                ggplot2::geom_line(
                  data = mn, ggplot2::aes(x = .data$Visit, y = .data$Value, group = 1),
                  colour = "#e41a1c", linewidth = 1.1, inherit.aes = FALSE) +
                ggplot2::geom_point(
                  data = mn, ggplot2::aes(x = .data$Visit, y = .data$Value, group = 1),
                  colour = "#e41a1c", size = 2, inherit.aes = FALSE)
            }
          }
          if (isTRUE(input$logy)) p <- p + ggplot2::scale_y_log10()
          p
        })

        output$plot <- plotly::renderPlotly({
          plotly::ggplotly(plot_r(), tooltip = "text") |>
            plotly::layout(hovermode = "closest")
        })
      })
    }
  )
}
