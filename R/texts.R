# The texts around the chart, per language. `result` is a template: {x},
# {guess} and {truth} are filled in by the browser.
texts <- list(
  en = list(
    reveal = "Show the real numbers",
    reset  = "Draw again",
    hint   = "Draw the line yourself",
    todo   = "Draw the line all the way to the end first.",
    adjust = "You can still adjust your line.",
    result = "For {x} you drew {guess}. The real number is {truth}."
  ),
  nl = list(
    reveal = "Toon de echte cijfers",
    reset  = "Opnieuw tekenen",
    hint   = "Teken hier zelf de lijn",
    todo   = "Teken eerst de lijn tot het einde.",
    adjust = "Je kan je lijn nog bijsturen.",
    result = "Voor {x} tekende je {guess}. In werkelijkheid is dat {truth}."
  )
)

# The texts for one language, with the caller's replacements applied.
resolve_texts <- function(lang, labels) {
  if (!is.character(lang) || length(lang) != 1 || !lang %in% names(texts)) {
    stop("`lang` must be one of ", paste0('"', names(texts), '"', collapse = ", "), ".",
         call. = FALSE)
  }
  unknown <- setdiff(names(labels), names(texts[[lang]]))
  if (length(labels) && (is.null(names(labels)) || length(unknown))) {
    stop("`labels` must be a named list. Known names: ",
         paste(names(texts[[lang]]), collapse = ", "), ".", call. = FALSE)
  }
  utils::modifyList(texts[[lang]], as.list(labels))
}
