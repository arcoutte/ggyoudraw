# Register the Shiny input handler without loading shiny for those who do not
# use it: now if shiny is already loaded, otherwise as soon as it is.
.onLoad <- function(libname, pkgname) {
  if (isNamespaceLoaded("shiny")) {
    register_guess_input_handler()
  } else {
    setHook(packageEvent("shiny", "onLoad"), register_guess_input_handler)
  }
}
