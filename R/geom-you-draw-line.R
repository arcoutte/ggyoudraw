#' A line the reader finishes
#'
#' `geom_you_draw_line()` draws a line with points, like [ggplot2::geom_line()]
#' plus [ggplot2::geom_point()]. Everything after `draw_from` is tagged, so that
#' [you_draw_it()] can hide it, let the reader draw their own guess and then
#' reveal the real line.
#'
#' Printed on an ordinary graphics device (a PNG or PDF file, the Plots pane),
#' the layer shows the complete line. The interaction only exists in the widget
#' made by [you_draw_it()].
#'
#' @section Vertical room:
#' A reader can only draw inside the panel, and an axis that stops just above
#' the highest value gives the answer away. The layer therefore asks for extra
#' room above and below its data: `headroom` times the spread of the y values.
#' Set the limits yourself, for example with `scale_y_continuous(limits = )` or
#' [ggplot2::expand_limits()], to take control.
#'
#' @section Limitations:
#' * One line per panel. Use facets to show several lines.
#' * Cartesian coordinates only: no `coord_flip()`, `coord_polar()` or
#'   `coord_sf()`.
#' * The y scale must be continuous. The x scale can be continuous, a date or
#'   discrete.
#'
#' @section Fills:
#' The layer can tint two parts of the panel: the part where the reader draws
#' (`zone_fill`) and the part with the known line (`known_fill`). Both are
#' drawn with the opacity in `fill_alpha`:
#'
#' ```
#' geom_you_draw_line(draw_from = 2023, zone_fill = "orange",
#'                    known_fill = "grey50", fill_alpha = 0.1)
#' ```
#'
#' @section Aesthetics:
#' `x` and `y` are required. `colour`, `linewidth`, `linetype` and `alpha` style
#' the line and its points. Because a panel holds a single line, they are taken
#' from the first row of each panel.
#'
#' @inheritParams ggplot2::layer
#' @param draw_from The last x value the reader gets to see, in the units of the
#'   x axis: a number, a date or the name of a category. The reader draws
#'   everything after it.
#' @param headroom Extra room above and below the data, as a fraction of the
#'   spread of the y values. See the section on vertical room.
#' @param zone Tint the part of the panel where the reader draws? `FALSE` is
#'   the same as `zone_fill = NA`.
#' @param zone_fill Fill of the part of the panel where the reader draws.
#'   `NULL`, the default, takes `guess_colour`. `NA` leaves it out.
#' @param known_fill Fill of the part of the panel with the known line, left of
#'   `draw_from`. `NA`, the default, leaves it out.
#' @param fill_alpha Opacity of `zone_fill` and `known_fill`, between 0 and 1.
#'   Keep it low, so the grid lines stay visible. `NA` keeps the opacity of the
#'   colours themselves, for example from [ggplot2::alpha()].
#' @param guess_colour Colour of the line the reader draws.
#' @param point_size Size of the points, like `size` in [ggplot2::geom_point()].
#' @param na.rm If `FALSE`, the default, missing values are removed with a
#'   warning. If `TRUE`, they are removed silently.
#' @param ... Other arguments passed on to [ggplot2::layer()], usually fixed
#'   aesthetics such as `colour = "steelblue"` or `linewidth = 1`.
#'
#' @return A ggplot2 layer.
#' @seealso [you_draw_it()] to make the plot interactive.
#' @export
#' @examples
#' takeaway <- data.frame(
#'   year  = 2020:2026,
#'   share = c(8, 9, 10, 8.5, 10, 12, 15)
#' )
#'
#' p <- ggplot2::ggplot(takeaway, ggplot2::aes(year, share)) +
#'   geom_you_draw_line(draw_from = 2023)
#'
#' # On an ordinary device the layer shows the complete line
#' p
#'
#' # In the widget the reader draws 2024 to 2026 before the real line appears
#' if (interactive()) {
#'   you_draw_it(p, unit = "%")
#' }
geom_you_draw_line <- function(mapping = NULL, data = NULL, ..., draw_from,
                               headroom = 0.3, zone = TRUE,
                               zone_fill = NULL, known_fill = NA,
                               fill_alpha = 0.08,
                               guess_colour = "#d95926", point_size = 1.5,
                               na.rm = FALSE, show.legend = NA,
                               inherit.aes = TRUE) {
  if (missing(draw_from)) {
    stop("`draw_from` is missing: give the last x value the reader gets to see.",
         call. = FALSE)
  }
  is_fill <- function(fill) length(fill) == 1 && (is.na(fill) || is.character(fill))
  if (!is.null(zone_fill) && !is_fill(zone_fill)) {
    stop("`zone_fill` must be a single colour, NA or NULL.", call. = FALSE)
  }
  if (!is_fill(known_fill)) {
    stop("`known_fill` must be a single colour or NA.", call. = FALSE)
  }
  if (!(length(fill_alpha) == 1 && (is.na(fill_alpha) ||
        (is.numeric(fill_alpha) && fill_alpha >= 0 && fill_alpha <= 1)))) {
    stop("`fill_alpha` must be a number between 0 and 1, or NA.", call. = FALSE)
  }
  ggplot2::layer(
    geom = GeomYouDrawLine, stat = "identity", position = "identity",
    data = data, mapping = mapping,
    show.legend = show.legend, inherit.aes = inherit.aes,
    params = list(
      draw_from = draw_from, headroom = headroom, zone = zone,
      zone_fill = zone_fill, known_fill = known_fill, fill_alpha = fill_alpha,
      guess_colour = guess_colour, point_size = point_size, na.rm = na.rm, ...
    )
  )
}

# The attributes this layer writes on its SVG elements. The script in the
# browser (inst/assets/ggyoudraw.js) finds the elements through them.
#   ydi        role of the element: "zone", "truth", "known", "anchor", "hidden"
#   ydi_panel  the panel the element belongs to
#   ydi_x      a point's label on the x axis
#   ydi_y      a point's value
#   ydi_lut    on the zone: the value at each height of the panel
#   ydi_colour on the zone: the colour of the reader's line
ydi_attrs <- c("ydi", "ydi_panel", "ydi_x", "ydi_y", "ydi_lut", "ydi_colour")

#' @rdname geom_you_draw_line
#' @format NULL
#' @usage NULL
#' @export
GeomYouDrawLine <- ggplot2::ggproto(
  "GeomYouDrawLine", ggplot2::GeomPath,
  required_aes = c("x", "y"),
  extra_params = c("na.rm", "headroom"),

  # A line cannot continue across a missing value, so drop incomplete rows
  # (GeomPath keeps them to break the line).
  handle_na = function(self, data, params) {
    ggplot2::remove_missing(data, params$na.rm, c("x", "y"), "geom_you_draw_line")
  },

  # Ask for room above and below the data. The y scale is trained on `ymin` and
  # `ymax` as well, so adding them here widens the axis.
  setup_data = function(data, params) {
    spread <- stats::ave(data$y, data$PANEL, FUN = function(v) {
      if (all(is.na(v))) 0 else diff(range(v, na.rm = TRUE))
    })
    data$ymin <- data$y - params$headroom * spread
    data$ymax <- data$y + params$headroom * spread
    data
  },

  draw_panel = function(data, panel_params, coord, draw_from, zone = TRUE,
                        zone_fill = NULL, known_fill = NA, fill_alpha = 0.08,
                        guess_colour = "#d95926", point_size = 1.5) {
    if (!inherits(coord, "CoordCartesian") || inherits(coord, "CoordFlip")) {
      stop("geom_you_draw_line() needs Cartesian coordinates. coord_flip(), ",
           "coord_polar() and other non-linear coords are not supported.",
           call. = FALSE)
    }
    if (panel_params$y$is_discrete()) {
      stop("geom_you_draw_line() needs a continuous y scale.", call. = FALSE)
    }

    data <- data[order(data$x), , drop = FALSE]
    if (anyDuplicated(data$x)) {
      stop("geom_you_draw_line() draws a single line per panel. ",
           "Use facets to show several lines.", call. = FALSE)
    }
    known <- data$x <= scale_position(draw_from, panel_params$x)
    if (anyNA(known) || !any(known) || all(known)) {
      stop("`draw_from` must be an x value between the first and the last one: ",
           "the last point the reader gets to see.", call. = FALSE)
    }
    n <- nrow(data)
    a <- sum(known)   # the last known point: the reader's line starts here

    npc <- coord$transform(data, panel_params)
    inverse <- panel_params$y$scale$get_transformation()$inverse

    # The value at each height of the panel, from bottom to top. The browser
    # interpolates in this table to turn a pixel into a value, which also
    # covers log and reversed axes.
    y_range <- panel_params$y.range
    ends <- coord$transform(data.frame(x = data$x[1], y = y_range), panel_params)$y
    heights <- seq(0, 1, length.out = 101)
    lut <- inverse(y_range[1] + (heights - ends[1]) / diff(ends) * diff(y_range))

    panel <- as.character(data$PANEL[1])
    colour <- ggplot2::alpha(data$colour[1], data$alpha[1])
    line_gp <- grid::gpar(
      col = colour, lwd = data$linewidth[1] * ggplot2::.pt,
      lty = data$linetype[1], lineend = "round", linejoin = "round"
    )
    point_gp <- grid::gpar(
      col = colour, fontsize = point_size * ggplot2::.pt + ggplot2::.stroke / 4
    )
    # As hex, because not every R colour name exists in a browser
    guess_hex <- grDevices::rgb(t(grDevices::col2rgb(guess_colour)), maxColorValue = 255)
    if (is.null(zone_fill)) zone_fill <- guess_colour
    if (!zone) zone_fill <- NA
    fill_of <- function(fill) {
      if (is.na(fill)) NA else ggplot2::alpha(fill, fill_alpha)
    }

    grid::gList(
      # The part with the known line: from the left edge of the panel to the
      # last known point. Not tagged, the browser leaves it alone.
      if (!is.na(known_fill)) {
        grid::rectGrob(
          x = 0, y = 0, width = npc$x[a], height = 1,
          just = c("left", "bottom"), default.units = "npc",
          gp = grid::gpar(col = NA, fill = fill_of(known_fill))
        )
      },
      # The drawing zone: from the last known point to the right edge of the
      # panel. It also carries the scale.
      ggiraph::interactive_rect_grob(
        x = npc$x[a], y = 0, width = 1 - npc$x[a], height = 1,
        just = c("left", "bottom"), default.units = "npc",
        gp = grid::gpar(col = NA, fill = if (is.na(zone_fill)) "transparent" else fill_of(zone_fill)),
        ydi = "zone", ydi_panel = panel, ydi_colour = guess_hex,
        ydi_lut = paste(signif(lut, 10), collapse = " "),
        extra_interactive_params = ydi_attrs
      ),
      # The known part of the line: always visible
      if (a > 1) {
        grid::polylineGrob(npc$x[known], npc$y[known], default.units = "npc", gp = line_gp)
      },
      # The part the reader draws: tagged, so the browser can hide and reveal it
      ggiraph::interactive_polyline_grob(
        npc$x[a:n], npc$y[a:n], default.units = "npc", gp = line_gp,
        ydi = "truth", ydi_panel = panel,
        extra_interactive_params = ydi_attrs
      ),
      # All points, each with its x label and value. The browser also reads
      # their pixel positions.
      ggiraph::interactive_points_grob(
        npc$x, npc$y, pch = 19, default.units = "npc", gp = point_gp,
        ydi = c(rep("known", a - 1), "anchor", rep("hidden", n - a)),
        ydi_panel = panel,
        ydi_x = scale_labels(data$x, panel_params$x),
        ydi_y = as.character(inverse(data$y)),
        extra_interactive_params = ydi_attrs
      )
    )
  }
)

# `draw_from` in the units ggplot2 uses internally for the x axis: a date
# becomes a number, a category becomes a position.
scale_position <- function(value, view_scale) {
  if (view_scale$is_discrete()) {
    return(match(as.character(value), view_scale$get_limits()))
  }
  transformation <- view_scale$scale$get_transformation()
  # A value the scale cannot handle ends as NA, which draw_panel() reports
  suppressWarnings(tryCatch(
    as.numeric(transformation$transform(value)),
    error = function(e) as.numeric(value)
  ))
}

# The x values as they appear on the axis, for the text under the chart and for
# Shiny.
scale_labels <- function(x, view_scale) {
  breaks <- if (view_scale$is_discrete()) view_scale$get_limits()[x] else x
  labels <- tryCatch(as.character(view_scale$get_labels(breaks)), error = function(e) NULL)
  if (length(labels) != length(x)) labels <- as.character(breaks)
  labels
}
