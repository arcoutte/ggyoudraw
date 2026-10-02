# Shiny delivers what the browser sends as a nested list, with NULL for the
# points the reader has not drawn yet. This turns it into the data frame that
# input$<outputId>_guess holds.
guess_input_handler <- function(value, ...) {
  column <- function(items, as) {
    vapply(items, function(item) if (is.null(item)) as(NA) else as(item), as(NA))
  }
  data.frame(
    panel = column(value$panel, as.character),
    x = column(value$x, as.character),
    guess = column(value$guess, as.numeric),
    truth = column(value$truth, as.numeric),
    revealed = isTRUE(value$revealed)
  )
}

register_guess_input_handler <- function(...) {
  shiny::registerInputHandler("ggyoudraw.guess", guess_input_handler, force = TRUE)
}
