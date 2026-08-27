import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const pluginDir = resolve(scriptDir, "..");
const repositoryDir = resolve(pluginDir, "../..");
const templatePath = resolve(pluginDir, "src/client.template.js");
const outputPath = resolve(pluginDir, "lib/client.js");
const assetsPath = resolve(pluginDir, "lib/assets.json");
const sources = {
  deepwhale: resolve(repositoryDir, "artifacts/pets/deepwhale-run/package/spritesheet.webp"),
  marina: resolve(repositoryDir, "artifacts/pets/marina-run/package/spritesheet.webp")
};

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

async function encodeAsset(name, path) {
  const bytes = await readFile(path);
  if (bytes.length < 12 || bytes.subarray(0, 4).toString("ascii") !== "RIFF" || bytes.subarray(8, 12).toString("ascii") !== "WEBP") {
    throw new Error(`${name}: expected a WebP spritesheet at ${path}`);
  }
  return {
    dataUrl: `data:image/webp;base64,${bytes.toString("base64")}`,
    metadata: {
      source: `artifacts/pets/${name}-run/package/spritesheet.webp`,
      bytes: bytes.length,
      sha256: sha256(bytes)
    }
  };
}

const [template, deepwhale, marina] = await Promise.all([
  readFile(templatePath, "utf8"),
  encodeAsset("deepwhale", sources.deepwhale),
  encodeAsset("marina", sources.marina)
]);

const output = template
  .replace("__DEEPWHALE_DATA_URL__", JSON.stringify(deepwhale.dataUrl))
  .replace("__MARINA_DATA_URL__", JSON.stringify(marina.dataUrl));

if (output.includes("__DEEPWHALE_DATA_URL__") || output.includes("__MARINA_DATA_URL__")) {
  throw new Error("client template still contains an unresolved asset placeholder");
}

await mkdir(resolve(pluginDir, "lib"), { recursive: true });
await Promise.all([
  writeFile(outputPath, output),
  writeFile(assetsPath, `${JSON.stringify({ deepwhale: deepwhale.metadata, marina: marina.metadata }, null, 2)}\n`)
]);

console.log(`built ${outputPath}`);
