# These are imported by name because R CMD check does not see `pkg::fun()`
# calls inside a ggproto object, and would report the packages as unused.
#' @keywords internal
#' @importFrom grDevices col2rgb rgb
#' @importFrom grid gList gpar polylineGrob
#' @importFrom stats ave
"_PACKAGE"
