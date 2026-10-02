# Renders the widgets that dev/browser-test.js drives in a real browser.
# The unit tests cover what R produces; this covers what happens after that.
#
#   Rscript dev/browser-test.R          # writes dev/out/*.html
#   Rscript dev/browser-test.R shiny    # then serves a Shiny app on port 4750
#
# Run from the package root. Uses the source tree when pkgload is installed,
# otherwise the installed package.

suppressPackageStartupMessages(library(ggplot2))
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  library(ggyoudraw)
}

out <- file.path("dev", "out")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
save <- function(widget, name) {
  file <- file.path(normalizePath(out), paste0(name, ".html"))
  htmlwidgets::saveWidget(widget, file, selfcontained = FALSE, libdir = "lib", title = name)
}

takeaway <- data.frame(year = 2020:2026, share = c(8, 9, 10, 8.5, 10, 12, 15))
basic <- ggplot(takeaway, aes(year, share)) +
  geom_you_draw_line(draw_from = 2023, colour = "#2a78d6") +
  scale_y_continuous(limits = c(0, 20))
save(you_draw_it(basic, unit = "%", decimal_mark = ",", width_svg = 7, height_svg = 4), "basic")

# No button, controls above the chart, both parts of the panel tinted
filled <- ggplot(takeaway, aes(year, share)) +
  geom_you_draw_line(draw_from = 2023, colour = "#2a78d6", known_fill = "grey50", fill_alpha = 0.12) +
  scale_y_continuous(limits = c(0, 20))
save(you_draw_it(filled, unit = "%", auto_reveal = TRUE, controls = "top", width_svg = 7, height_svg = 4), "auto")

both <- rbind(cbind(takeaway, group = "a"), cbind(takeaway, group = "b"))
facets <- ggplot(both, aes(year, share)) +
  geom_you_draw_line(draw_from = 2023) +
  facet_wrap(~group)
save(you_draw_it(facets, width_svg = 8, height_svg = 3.5), "facets")

growth <- data.frame(x = 1:6, y = c(10, 30, 100, 300, 1000, 3000))
log_axis <- ggplot(growth, aes(x, y)) + geom_you_draw_line(draw_from = 5) + scale_y_log10()
save(you_draw_it(log_axis), "log")

reversed <- ggplot(takeaway, aes(year, share)) +
  geom_you_draw_line(draw_from = 2024, zone = FALSE, guess_colour = "darkorchid4") +
  scale_y_reverse()
labels <- list(result = "{x}: you {guess}, real {truth}")
save(you_draw_it(reversed, digits = 0, labels = labels), "reversed")

quarters <- data.frame(quarter = factor(c("Q1", "Q2", "Q3", "Q4")), revenue = c(120, 135, 128, 160))
discrete <- ggplot(quarters, aes(quarter, revenue)) + geom_you_draw_line(draw_from = "Q2")
save(you_draw_it(discrete, lang = "nl"), "discrete")

if (identical(commandArgs(trailingOnly = TRUE), "shiny")) {
  library(shiny)
  ui <- fluidPage(ggiraph::girafeOutput("chart"), tableOutput("guess"), actionButton("again", "Render again"))
  server <- function(input, output) {
    output$chart <- ggiraph::renderGirafe({
      input$again
      you_draw_it(basic, unit = "%", width_svg = 7, height_svg = 4)
    })
    output$guess <- renderTable(input$chart_guess)
  }
  runApp(shinyApp(ui, server), port = 4750, host = "127.0.0.1", launch.browser = FALSE)
}
