// Keep the local uncensored bitllm provider inside ~/.free-pi/agent/models.json.
// The installer normalises paths (and may drop the "section" key), so this runs on every
// launch: merge provider "ollama" (section defense) into models.json without touching any
// other provider. Idempotent; prints nothing unless the file changed.
const fs = require("node:fs");
const path = require("node:path");

const agentDir = path.join(process.env.HOME, ".free-pi", "agent");
const target = path.join(agentDir, "models.json");
const overlayPath = path.join(process.env.HOME, ".free-pi", "state", "models-local.json");

function readJson(p) {
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch {
    return null;
  }
}

const overlay = readJson(overlayPath);
if (overlay && overlay.providers && overlay.providers.ollama) {
  const cur = readJson(target) || { $schema: "https://pi.dev/schemas/models.schema.json", providers: {} };
  if (!cur.providers) cur.providers = {};
  const want = overlay.providers.ollama;
  const have = cur.providers.ollama || {};
  const same =
    JSON.stringify(have) === JSON.stringify(want) && cur.$schema === overlay.$schema;
  if (!same) {
    cur.providers.ollama = want;
    if (!cur.$schema) cur.$schema = overlay.$schema;
    fs.mkdirSync(agentDir, { recursive: true });
    fs.writeFileSync(target, JSON.stringify(cur, null, 2) + "\n");
    console.log("models.json: provider ollama (section defense) merged");
  }
}
