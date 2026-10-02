test_that("the Shiny input becomes a data frame, with NA for what is not drawn yet", {
  from_browser <- list(
    panel = list("1", "1", "1"),
    x = list("2024", "2025", "2026"),
    guess = list(9.5, 11L, NULL),
    truth = list(10L, 12L, 15L),
    revealed = FALSE
  )

  expect_equal(
    guess_input_handler(from_browser),
    data.frame(
      panel = "1",
      x = c("2024", "2025", "2026"),
      guess = c(9.5, 11, NA),
      truth = c(10, 12, 15),
      revealed = FALSE
    )
  )
})
