// MathJax 2 configuration, loaded before MathJax.js from the CDN.
//
// It reproduces the settings of the config/default.js file that was
// customized in the former local copy of MathJax (site/lib/MathJax):
// TeX input rendered as SVG, with $...$ for inline math (the stock
// configuration only recognizes \(...\)). reticulo.js depends on the
// MathJax 2 API (MathJax.Hub.Queue), so this must stay on 2.x.
//
// AMSsymbols adds symbols used by the formulas in the database that
// base TeX lacks, such as \square.
window.MathJax = {
  jax: ["input/TeX", "output/SVG"],
  extensions: ["tex2jax.js"],
  TeX: {
    extensions: ["AMSsymbols.js"]
  },
  tex2jax: {
    inlineMath: [ ['$', '$'] ],
    displayMath: [ ['$$', '$$'], ['\\[', '\\]'] ],
    processEscapes: false
  }
};
