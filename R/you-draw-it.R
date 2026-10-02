#' Turn a plot into a 'you draw it' widget
#'
#' Renders a plot that has a [geom_you_draw_line()] layer with
#' [ggiraph::girafe()] and adds the interaction: the part after `draw_from` is
#' hidden, the reader drags to draw their own line, and a button reveals the
#' real one.
#'
#' With `auto_reveal = TRUE` there is no button: the real line appears as soon
#' as the reader lifts the mouse or finger with the line complete. A button
#' that is too easy to miss is then no longer a problem.
#'
#' The result is an htmlwidget. It shows in the RStudio viewer, can be included
#' in R Markdown and Quarto documents with HTML output, and can be saved with
#' [htmlwidgets::saveWidget()].
#'
#' @section Shiny:
#' Use [ggiraph::girafeOutput()] and [ggiraph::renderGirafe()]. What the reader
#' draws comes back as `input$<outputId>_guess`, a data frame with one row per
#' point to draw:
#'
#' * `panel`: the panel the point is in, as numbered by ggplot2.
#' * `x`: the point's label on the x axis.
#' * `guess`: the value the reader drew, `NA` as long as they have not.
#' * `truth`: the real value.
#' * `revealed`: has the reader revealed the real line?
#'
#' The input updates after every stroke, on reveal and on reset.
#'
#' @section Texts:
#' The texts around the chart exist in English (`"en"`) and Dutch (`"nl"`). Set
#' `options(ggyoudraw.lang = "nl")` to change the default for a session.
#' `labels` replaces individual texts:
#'
#' * `reveal`: the button that shows the real line. Not used with
#'   `auto_reveal = TRUE`.
#' * `reset`: the button to start over.
#' * `hint`: the invitation inside the drawing zone.
#' * `todo`: the note next to the button while the line is incomplete.
#' * `adjust`: the note once the line is complete.
#' * `result`: the sentence under the chart after the reveal. `{x}`, `{guess}`
#'   and `{truth}` are filled in for the last point. It is left out when the
#'   plot has several panels.
#'
#' @param ggobj A ggplot with a [geom_you_draw_line()] layer.
#' @param ... Arguments passed on to [ggiraph::girafe()], such as `width_svg`
#'   and `height_svg` (in inches).
#' @param unit Text put after every value, for example `"%"`.
#' @param digits Number of decimals. `NULL`, the default, picks a number that
#'   suits the range of the y axis.
#' @param decimal_mark The decimal mark.
#' @param lang Language of the texts around the chart: `"en"` or `"nl"`.
#' @param auto_reveal Show the real line as soon as the reader has drawn the
#'   whole line, instead of waiting for a click on the button?
#' @param controls Where the buttons and texts go: `"bottom"`, under the chart,
#'   or `"top"`, above it.
#' @param labels A named list of texts that replace the defaults. See the
#'   section on texts.
#' @param options A list of options for [ggiraph::girafe()], for example
#'   `list(ggiraph::opts_sizing(rescale = FALSE))`. The ggiraph toolbar is
#'   hidden, because it overlaps the drawing zone, unless you turn it back on
#'   here.
#'
#' @return A `girafe` htmlwidget.
#' @seealso [geom_you_draw_line()]
#' @export
#' @examples
#' takeaway <- data.frame(
#'   year  = 2020:2026,
#'   share = c(8, 9, 10, 8.5, 10, 12, 15)
#' )
#'
#' p <- ggplot2::ggplot(takeaway, ggplot2::aes(year, share)) +
#'   geom_you_draw_line(draw_from = 2023, colour = "#2a78d6") +
#'   ggplot2::scale_y_continuous(limits = c(0, 20))
#'
#' widget <- you_draw_it(p, unit = "%", width_svg = 7, height_svg = 4)
#' if (interactive()) widget
#'
#' # Dutch texts and a decimal comma
#' widget <- you_draw_it(p, unit = "%", lang = "nl", decimal_mark = ",")
#'
#' # No button: the real line appears once the reader's line is complete
#' widget <- you_draw_it(p, unit = "%", auto_reveal = TRUE)
#'
#' # The button above the chart
#' widget <- you_draw_it(p, unit = "%", controls = "top")
#'
#' # In a Shiny app the guesses come back as input$chart_guess
#' if (interactive() && requireNamespace("shiny", quietly = TRUE)) {
#'   ui <- shiny::fluidPage(
#'     ggiraph::girafeOutput("chart"),
#'     shiny::tableOutput("guess")
#'   )
#'   server <- function(input, output) {
#'     output$chart <- ggiraph::renderGirafe(you_draw_it(p, unit = "%"))
#'     output$guess <- shiny::renderTable(input$chart_guess)
#'   }
#'   shiny::shinyApp(ui, server)
#' }
you_draw_it <- function(ggobj, ..., unit = "", digits = NULL,
                        decimal_mark = getOption("OutDec"),
                        lang = getOption("ggyoudraw.lang", "en"),
                        auto_reveal = FALSE, controls = c("bottom", "top"),
                        labels = list(), options = list()) {
  if (!inherits(ggobj, "ggplot")) {
    stop("`ggobj` must be a ggplot.", call. = FALSE)
  }
  has_layer <- any(vapply(
    ggobj$layers, function(layer) inherits(layer$geom, "GeomYouDrawLine"), logical(1)
  ))
  if (!has_layer) {
    stop("The plot has no geom_you_draw_line() layer.", call. = FALSE)
  }
  if (!(isTRUE(auto_reveal) || isFALSE(auto_reveal))) {
    stop("`auto_reveal` must be TRUE or FALSE.", call. = FALSE)
  }
  if (!is.character(controls) || !all(controls %in% c("bottom", "top"))) {
    stop('`controls` must be "bottom" or "top".', call. = FALSE)
  }
  controls <- controls[1]
  settings <- list(
    unit = unit, digits = digits, decimal_mark = decimal_mark,
    auto_reveal = auto_reveal, controls = controls,
    labels = resolve_texts(lang, labels)
  )

  toolbar <- ggiraph::opts_toolbar(
    saveaspng = FALSE, hidden = c("selection", "zoom", "misc")
  )
  widget <- ggiraph::girafe(ggobj = ggobj, ..., options = c(list(toolbar), options))
  widget$dependencies <- c(widget$dependencies, list(browser_assets()))

  # After girafe has put the SVG on the page, hand it to the script in
  # inst/assets/ggyoudraw.js.
  htmlwidgets::onRender(
    widget, "function(el, x, settings) { window.ggyoudraw(el, settings); }",
    data = settings
  )
}

# The script and stylesheet that run in the browser.
browser_assets <- function() {
  htmltools::htmlDependency(
    name = "ggyoudraw",
    version = as.character(utils::packageVersion("ggyoudraw")),
    src = "assets", package = "ggyoudraw",
    script = "ggyoudraw.js", stylesheet = "ggyoudraw.css"
  )
}
