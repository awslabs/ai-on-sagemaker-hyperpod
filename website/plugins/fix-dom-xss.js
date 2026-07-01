/**
 * Docusaurus plugin to mitigate DOM-based Cross-Site Scripting (XSS).
 *
 * ACAT Finding: DOM-based XSS in generated HTML output
 * Reference: https://www.aristotle.a2z.com/implementations/324
 *
 * The Docusaurus build produces an inline script (insertBanner function)
 * that uses a dangerous DOM sink (innerHTML) with user-controllable input
 * (window.location.pathname). This plugin runs after each build to replace
 * the unsafe pattern with a safe alternative.
 *
 * Specifically, it replaces:
 *   e.innerHTML = o  (where o derives from window.location.pathname)
 * with:
 *   e.textContent = o
 *
 * Using textContent instead of innerHTML ensures that any characters in the
 * URL path are rendered as plain text rather than being parsed as HTML,
 * preventing DOM-based XSS attacks.
 */

const fs = require('fs');
const path = require('path');

function findHtmlFiles(dir) {
  const results = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findHtmlFiles(fullPath));
    } else if (entry.name.endsWith('.html')) {
      results.push(fullPath);
    }
  }
  return results;
}

module.exports = function pluginFixDomXss() {
  return {
    name: 'fix-dom-xss',
    async postBuild({ outDir }) {
      const htmlFiles = findHtmlFiles(outDir);
      let patchedCount = 0;

      for (const filePath of htmlFiles) {
        let content = fs.readFileSync(filePath, 'utf-8');
        let modified = false;

        // Fix: Replace innerHTML assignment of pathname in the base URL banner.
        //
        // The Docusaurus insertBanner() function assigns window.location.pathname
        // to an element via innerHTML. Since this is displaying a URL path as text,
        // textContent is the correct and safe alternative.
        //
        // Minified pattern from Docusaurus core:
        //   var s=window.location.pathname,o="/"===s.substr(-1)?s:s+"/";e.innerHTML=o
        //
        // We target the specific pattern where innerHTML is assigned the variable 'o'
        // which is derived from the pathname, immediately before the closing brace.
        if (content.includes('.innerHTML=o}')) {
          content = content.replace(/\.innerHTML=o}/g, '.textContent=o}');
          modified = true;
        }

        // Handle potential variations with whitespace
        if (content.includes('.innerHTML = o}')) {
          content = content.replace(/\.innerHTML\s*=\s*o}/g, '.textContent=o}');
          modified = true;
        }

        if (modified) {
          fs.writeFileSync(filePath, content, 'utf-8');
          patchedCount++;
        }
      }

      if (patchedCount > 0) {
        console.log(
          `[fix-dom-xss] Patched ${patchedCount} HTML file(s) to mitigate DOM-based XSS.`
        );
      }
    },
  };
};
