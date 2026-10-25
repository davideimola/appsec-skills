import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// VULNERABLE=1 resolves every import of authz.js and archive.js to their
// vulnerable versions, the way `-tags vulnerable` swaps the Go fixture's
// build. The tests and the properties run unchanged against either version.
const vulnerable = process.env.VULNERABLE === "1";

export default defineConfig({
  resolve: {
    alias: vulnerable
      ? [
          {
            find: /^\.\/(authz|archive)\.js$/,
            replacement: fileURLToPath(
              new URL("./src/authz/$1.vulnerable.ts", import.meta.url),
            ),
          },
        ]
      : [],
  },
});
