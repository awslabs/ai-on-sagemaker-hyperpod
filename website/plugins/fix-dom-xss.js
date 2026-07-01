/**
 * Docusaurus plugin to mitigate DOM-based Cross-Site Scripting (XSS).
 *
 * ACAT Finding: DOM-based XSS in generated HTML output
 * Reference: https://www.aristotle.a2z.com/implementations/324
 *
 * The Docusaurus build produces inline scripts that use dangerous DOM sinks
 * (innerHTML) with user-controllable input (window.location.pathname and
 * URL search parameters). This plugin runs after each build to replace
 * unsafe patterns with safe alternatives.
 *
 * Fixes applied:
 * 1. insertBanner(): replaces innerHTML assignment of pathname-derived
 *    variable with textContent (safe text rendering).
 * 2. Theme/data-attribute script: sanitizes URL parameter values before
 *    they are set as attributes on the document element.
 *
 * When to remove: This plugin can be removed once Docusaurus upstream
 * addresses the innerHTML usage in their base URL banner script.
 * Track: https://github.com/facebook/docusaurus/issues/10515
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

/**
 * Sanitize a string for safe use as an HTML attribute value.
 * Encodes characters that could break out of attribute context.
 */
function escapeAttrJs() {
  // Returns a JS snippet that performs runtime attribute sanitization
  return `function __sanitizeAttr(s){return String(s).replace(/[&<>"'\`]/g,function(c){return'&#'+c.charCodeAt(0)+';'})}`;
}

module.exports = function pluginFixDomXss() {
  return {
    name: 'fix-dom-xss',
    async postBuild({ outDir }) {
      const htmlFiles = findHtmlFiles(outDir);
      let patchedCount = 0;
      let bannerPatched = false;
      let themePatched = false;

      for (const filePath of htmlFiles) {
        let content = fs.readFileSync(filePath, 'utf-8');
        let modified = false;

        // === Fix 1: insertBanner() innerHTML XSS ===
        //
        // The Docusaurus insertBanner() function computes a value from
        // window.location.pathname and assigns it to an element's innerHTML.
        // We match the semantic pattern: the banner container ID + innerHTML
        // assignment, regardless of the minified variable name.
        //
        // Robust pattern: match innerHTML assignment that follows the
        // banner suggestion container getElementById, within the same
        // script block context.
        //
        // Strategy: Find the insertBanner function by its stable marker
        // (__docusaurus-base-url-issue-banner-suggestion-container) and
        // replace any .innerHTML= with .textContent= within that function.
        const bannerMarker = '__docusaurus-base-url-issue-banner-suggestion-container';
        if (content.includes(bannerMarker)) {
          // Match: .innerHTML=<variable>} at end of the insertBanner function
          // The variable name changes with minification (could be o, a, n, etc.)
          const bannerPattern = /(["']__docusaurus-base-url-issue-banner-suggestion-container["'][^}]*?)\.innerHTML\s*=\s*(\w+)\s*}/g;
          if (bannerPattern.test(content)) {
            bannerPattern.lastIndex = 0; // reset after test
            content = content.replace(bannerPattern, '$1.textContent=$2}');
            modified = true;
            bannerPatched = true;
          }
        }

        // === Fix 2: Theme/data-attribute script ===
        //
        // The theme initialization script reads URL search parameters
        // (docusaurus-data-*) and sets them as attributes on <html>.
        // While data-* attributes can't directly execute JS, they could
        // be used in CSS injection or DOM clobbering attacks.
        //
        // Fix: Validate that attribute values only contain safe characters
        // (alphanumeric, hyphens, underscores, dots).
        const dataAttrPattern = /if\((\w+)\.startsWith\(["']docusaurus-data-["']\)\)\{var\s+(\w+)=\1\.replace\(["']docusaurus-data-["'],["']data-["']\);document\.documentElement\.setAttribute\(\2,(\w+)\)/g;
        if (dataAttrPattern.test(content)) {
          dataAttrPattern.lastIndex = 0;
          content = content.replace(
            dataAttrPattern,
            'if($1.startsWith("docusaurus-data-")){var $2=$1.replace("docusaurus-data-","data-");if(/^[\\w.\\-]+$/.test($2)&&/^[\\w.\\-\\s]+$/.test($3))document.documentElement.setAttribute($2,$3)'
          );
          modified = true;
          themePatched = true;
        }

        if (modified) {
          fs.writeFileSync(filePath, content, 'utf-8');
          patchedCount++;
        }
      }

      // === Fail-safe: warn if expected patterns were not found ===
      if (!bannerPatched) {
        console.warn(
          '[fix-dom-xss] WARNING: The insertBanner innerHTML pattern was NOT found in any HTML file. ' +
          'The vulnerable pattern may have changed (e.g., after a Docusaurus upgrade). ' +
          'Please verify manually that window.location.pathname is not used with innerHTML.'
        );
        // Exit with non-zero to fail the build — forces manual review
        process.exitCode = 1;
      } else {
        console.log(
          `[fix-dom-xss] Patched ${patchedCount} HTML file(s) — banner innerHTML → textContent.`
        );
      }

      if (themePatched) {
        console.log('[fix-dom-xss] Patched theme/data-attribute script with input validation.');
      }
    },
  };
};
