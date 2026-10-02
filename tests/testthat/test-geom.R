test_that("the layer asks for room above and below the data", {
  y_range <- function(plot) ggplot2::ggplot_build(plot)$layout$panel_params[[1]]$y.range
  spread <- 15 - 8
  expansion <- function(limits) limits + c(-1, 1) * 0.05 * diff(limits)

  expect_equal(y_range(base_plot(draw_from = 2023)), expansion(c(8, 15) + c(-1, 1) * 0.3 * spread))
  expect_equal(y_range(base_plot(draw_from = 2023, headroom = 0)), expansion(c(8, 15)))
})

test_that("limits set by the user win over the headroom", {
  plot <- base_plot(draw_from = 2023) + ggplot2::scale_y_continuous(limits = c(0, 20))
  expect_equal(ggplot2::ggplot_build(plot)$layout$panel_params[[1]]$y.range, c(-1, 21))
  expect_no_warning(svg_of(plot))
})

test_that("the SVG tags what the browser needs", {
  svg <- svg_of(base_plot(draw_from = 2023))

  expect_length(tagged(svg, "zone"), 1)
  expect_length(tagged(svg, "truth"), 1)
  expect_equal(tagged(svg, "known", "ydi_x"), c("2020", "2021", "2022"))
  expect_equal(tagged(svg, "anchor", "ydi_x"), "2023")
  expect_equal(tagged(svg, "anchor", "ydi_y"), "8.5")
  expect_equal(tagged(svg, "hidden", "ydi_x"), c("2024", "2025", "2026"))
  expect_equal(tagged(svg, "hidden", "ydi_y"), c("10", "12", "15"))
})

test_that("draw_from is the last visible point, also between two x values", {
  expect_equal(tagged(svg_of(base_plot(draw_from = 2024.5)), "hidden", "ydi_x"), c("2025", "2026"))
  expect_length(tagged(svg_of(base_plot(draw_from = 2020)), "known"), 0)
})

test_that("the zone carries the value at each height of the panel", {
  linear <- lut_of(base_plot(draw_from = 2023) + ggplot2::scale_y_continuous(limits = c(0, 20)))
  expect_length(linear, 101)
  expect_equal(linear[c(1, 51, 101)], c(-1, 10, 21))
})

test_that("the table is in data units on a log axis and flips on a reversed axis", {
  growth <- data.frame(x = 1:6, y = c(10, 30, 100, 300, 1000, 3000))
  log_plot <- ggplot2::ggplot(growth, ggplot2::aes(x, y)) +
    geom_you_draw_line(draw_from = 5) +
    ggplot2::scale_y_log10()
  steps <- diff(log10(lut_of(log_plot)))
  expect_true(all(steps > 0))
  expect_equal(steps, rep(steps[1], 100), tolerance = 1e-6)
  expect_equal(tagged(svg_of(log_plot), "hidden", "ydi_y"), "3000")

  reversed <- lut_of(base_plot(draw_from = 2023) + ggplot2::scale_y_reverse())
  expect_gt(reversed[1], reversed[101])
})

test_that("each facet panel gets its own zone and points", {
  both <- rbind(cbind(takeaway, group = "a"), cbind(takeaway, group = "b"))
  plot <- ggplot2::ggplot(both, ggplot2::aes(year, share)) +
    geom_you_draw_line(draw_from = 2023) +
    ggplot2::facet_wrap(~group)
  svg <- svg_of(plot)

  expect_equal(tagged(svg, "zone", "ydi_panel"), c("1", "2"))
  expect_equal(tagged(svg, "hidden", "ydi_panel"), rep(c("1", "2"), each = 3))
})

test_that("a discrete x axis works with the name of a category", {
  quarters <- data.frame(
    quarter = factor(c("Q1", "Q2", "Q3", "Q4")),
    revenue = c(120, 135, 128, 160)
  )
  plot <- ggplot2::ggplot(quarters, ggplot2::aes(quarter, revenue)) +
    geom_you_draw_line(draw_from = "Q2")
  svg <- svg_of(plot)

  expect_equal(tagged(svg, "anchor", "ydi_x"), "Q2")
  expect_equal(tagged(svg, "hidden", "ydi_x"), c("Q3", "Q4"))
})

test_that("a date axis works with a date and uses the labels of the scale", {
  months <- data.frame(
    month = seq(as.Date("2025-01-01"), by = "month", length.out = 6),
    value = c(3, 4, 4, 5, 7, 6)
  )
  plot <- ggplot2::ggplot(months, ggplot2::aes(month, value)) +
    geom_you_draw_line(draw_from = as.Date("2025-04-15")) +
    ggplot2::scale_x_date(date_labels = "%Y-%m")

  expect_equal(tagged(svg_of(plot), "hidden", "ydi_x"), c("2025-05", "2025-06"))
})

test_that("the reader's colour is passed as hex", {
  svg <- svg_of(base_plot(draw_from = 2023, guess_colour = "darkorchid4", zone = FALSE))
  expect_equal(tagged(svg, "zone", "ydi_colour"), "#68228B")
})

test_that("missing values are dropped with a warning", {
  gap <- takeaway
  gap$share[6] <- NA
  plot <- ggplot2::ggplot(gap, ggplot2::aes(year, share)) + geom_you_draw_line(draw_from = 2023)

  expect_warning(svg <- svg_of(plot), "missing values")
  expect_equal(tagged(svg, "hidden", "ydi_x"), c("2024", "2026"))
  expect_no_warning(svg_of(
    ggplot2::ggplot(gap, ggplot2::aes(year, share)) +
      geom_you_draw_line(draw_from = 2023, na.rm = TRUE)
  ))
})

test_that("an ordinary device shows the complete line", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  expect_no_error(print(base_plot(draw_from = 2023)))
})

test_that("misuse fails with a clear message", {
  expect_error(geom_you_draw_line(), "draw_from")
  expect_error(svg_of(base_plot(draw_from = 2030)), "between the first and the last")
  expect_error(svg_of(base_plot(draw_from = "2023-01-01")), "between the first and the last")
  expect_error(svg_of(base_plot(draw_from = 2023) + ggplot2::coord_flip()), "Cartesian")

  two_lines <- ggplot2::ggplot(rbind(takeaway, takeaway), ggplot2::aes(year, share)) +
    geom_you_draw_line(draw_from = 2023)
  expect_error(svg_of(two_lines), "single line per panel")
})

test_that("the zone and the known part take their own fill", {
  rects <- function(svg) regmatches(svg, gregexpr("<rect[^>]*>", svg))[[1]]
  zone_fill <- function(svg) sub(".* fill='([^']*)'.*", "\\1",tagged(svg, "zone"))

  plain <- svg_of(base_plot(draw_from = 2023))
  filled <- svg_of(base_plot(draw_from = 2023, zone_fill = "#00ff00", known_fill = "#0000ff",
                             fill_alpha = 0.2))
  expect_equal(toupper(zone_fill(filled)), "#00FF00")
  expect_length(rects(filled), length(rects(plain)) + 1)
  expect_true(any(grepl("fill='#0000FF'", rects(filled), ignore.case = TRUE)))
  expect_true(any(grepl("fill-opacity='0.2", rects(filled), fixed = TRUE)))

  none <- svg_of(base_plot(draw_from = 2023, zone_fill = NA))
  expect_length(tagged(none, "zone"), 1)
  expect_false(grepl("#D95926", zone_fill(none), ignore.case = TRUE))
})

test_that("bad fills fail with a clear message", {
  expect_error(geom_you_draw_line(draw_from = 2023, zone_fill = c("red", "blue")), "zone_fill")
  expect_error(geom_you_draw_line(draw_from = 2023, known_fill = 3), "known_fill")
  expect_error(geom_you_draw_line(draw_from = 2023, fill_alpha = 2), "fill_alpha")
})
