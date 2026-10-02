settings_of <- function(widget) widget$jsHooks$render[[1]]$data

test_that("you_draw_it() returns a girafe widget with the script attached", {
  widget <- you_draw_it(base_plot(draw_from = 2023), unit = "%", decimal_mark = ",")

  expect_s3_class(widget, c("girafe", "htmlwidget"))
  expect_true("ggyoudraw" %in% vapply(widget$dependencies, function(d) d$name, character(1)))
  expect_match(widget$jsHooks$render[[1]]$code, "window.ggyoudraw", fixed = TRUE)
  expect_equal(settings_of(widget)$unit, "%")
  expect_equal(settings_of(widget)$decimal_mark, ",")
  expect_null(settings_of(widget)$digits)
})

test_that("the script and stylesheet ship with the package", {
  expect_true(nzchar(system.file("assets", "ggyoudraw.js", package = "ggyoudraw")))
  expect_true(nzchar(system.file("assets", "ggyoudraw.css", package = "ggyoudraw")))
})

test_that("arguments for girafe() are passed on", {
  widget <- you_draw_it(base_plot(draw_from = 2023), width_svg = 8, height_svg = 4)
  expect_equal(widget$x$ratio, 2)
})

test_that("texts follow lang, the option and labels", {
  texts <- function(...) settings_of(you_draw_it(base_plot(draw_from = 2023), ...))$labels

  expect_equal(texts()$reveal, "Show the real numbers")
  expect_equal(texts(lang = "nl")$reveal, "Toon de echte cijfers")

  old <- options(ggyoudraw.lang = "nl")
  on.exit(options(old))
  expect_equal(texts()$reset, "Opnieuw tekenen")

  custom <- texts(labels = list(reveal = "Toon"))
  expect_equal(custom$reveal, "Toon")
  expect_equal(custom$reset, "Opnieuw tekenen")
})

test_that("auto_reveal and controls reach the browser", {
  settings <- settings_of(you_draw_it(base_plot(draw_from = 2023)))
  expect_false(settings$auto_reveal)
  expect_equal(settings$controls, "bottom")

  settings <- settings_of(you_draw_it(base_plot(draw_from = 2023), auto_reveal = TRUE, controls = "top"))
  expect_true(settings$auto_reveal)
  expect_equal(settings$controls, "top")
})

test_that("misuse fails with a clear message", {
  plain <- ggplot2::ggplot(takeaway, ggplot2::aes(year, share)) + ggplot2::geom_line()

  expect_error(you_draw_it(plain), "no geom_you_draw_line")
  expect_error(you_draw_it("not a plot"), "must be a ggplot")
  expect_error(you_draw_it(base_plot(draw_from = 2023), lang = "xx"), "`lang` must be one of")
  expect_error(
    you_draw_it(base_plot(draw_from = 2023), labels = list(revael = "typo")),
    "Known names"
  )
  expect_error(you_draw_it(base_plot(draw_from = 2023), auto_reveal = "yes"), "auto_reveal")
  expect_error(you_draw_it(base_plot(draw_from = 2023), controls = "left"), "controls")
})
