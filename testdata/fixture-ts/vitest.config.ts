import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// VULNERABLE=1 resolves every import of authz/authz.js to the vulnerable
// version, the way `-tags vulnerable` swaps the Go fixture's build. The tests
// and the property run unchanged against either version.
const vulnerable = process.env.VULNERABLE === "1";

export default defineConfig({
  resolve: {
    alias: vulnerable
      ? [
          {
            find: /^\.\/authz\.js$/,
            replacement: fileURLToPath(
              new URL("./src/authz/authz.vulnerable.ts", import.meta.url),
            ),
          },
        ]
      : [],
  },
});
