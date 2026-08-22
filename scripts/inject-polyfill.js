// Inject a crypto.randomUUID() polyfill into the DSH frontend index.html.
//
// Browsers only expose crypto.randomUUID() in secure contexts (HTTPS /
// localhost). On plain HTTP LAN access (e.g. http://192.168.x.x:3080) it is
// undefined and breaks the DSH Web UI. This script patches the served
// index.html with a tiny polyfill built on crypto.getRandomValues (the one
// WebCrypto API that IS available in insecure contexts).
//
// Usage: node inject-polyfill.js

const fs = require("fs");
const { execSync } = require("child_process");

const candidates = [
  // npm global install layout (@deepseek-ai/dsh nests its deps)
  "/usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-web-frontend/dist/index.html",
  // hoisted layout
  "/usr/local/lib/node_modules/@deepseek-ai/dsh-web-frontend/dist/index.html",
];

let indexFile = candidates.find((p) => fs.existsSync(p));
if (!indexFile) {
  try {
    indexFile = execSync(
      'find /usr/local/lib/node_modules -path "*dsh-web-frontend/dist/index.html" | head -1',
    )
      .toString()
      .trim();
  } catch {
    indexFile = "";
  }
}

if (!indexFile) {
  console.error("WARNING: frontend index.html not found, skipping polyfill");
  process.exit(0);
}

let html = fs.readFileSync(indexFile, "utf8");

if (html.includes("randomUUID polyfill")) {
  console.log("Polyfill already present in " + indexFile);
  process.exit(0);
}

const POLYFILL = `<script>
/* crypto.randomUUID polyfill for non-secure contexts (LAN HTTP) */
(function(){if(typeof crypto.randomUUID!=="function"){crypto.randomUUID=function(){var b=crypto.getRandomValues(new Uint8Array(16));b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;var h=Array.from(b,function(x){return x.toString(16).padStart(2,"0")});return h.join("").replace(/(.{8})(.{4})(.{4})(.{4})(.{12})/,"$1-$2-$3-$4-$5")};}})();
</script>
`;

html = html.replace("</head>", POLYFILL + "</head>");
fs.writeFileSync(indexFile, html);
console.log("Polyfill injected into " + indexFile);