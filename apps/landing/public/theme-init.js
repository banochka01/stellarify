// Applies the saved/system theme before first paint (external file: CSP script-src 'self').
try {
  var theme = localStorage.getItem("resonance-theme") || (matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark");
  document.documentElement.dataset.theme = theme;
} catch (error) {
  /* storage unavailable */
}
