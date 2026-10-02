takeaway <- data.frame(
  year  = 2020:2026,
  share = c(8, 9, 10, 8.5, 10, 12, 15)
)

base_plot <- function(...) {
  ggplot2::ggplot(takeaway, ggplot2::aes(year, share)) + geom_you_draw_line(...)
}

# The SVG that ggiraph makes of a plot
svg_of <- function(plot) {
  ggiraph::girafe(ggobj = plot)$x$html
}

# The SVG elements with a given role, or the values of one of their attributes
tagged <- function(svg, role, attr = NULL) {
  elements <- regmatches(svg, gregexpr(sprintf("<[^>]*ydi='%s'[^>]*>", role), svg))[[1]]
  if (is.null(attr)) {
    return(elements)
  }
  sub(sprintf(".*\\b%s='([^']*)'.*", attr), "\\1", elements)
}

# The table that maps a height in the panel to a value
lut_of <- function(plot) {
  as.numeric(strsplit(tagged(svg_of(plot), "zone", "ydi_lut"), " ")[[1]])
}
