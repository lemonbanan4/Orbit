// Uploads tool/wisdom_library_drafts.json into the wisdom_library
// collection. Dry-run by default; pass --apply to write.
//
//   node tool/upload_wisdom_library.mjs           # preview only
//   node tool/upload_wisdom_library.mjs --apply   # write to Firestore
//
// Run from the repo root. Reuses functions/node_modules' firebase-admin
// and your local gcloud Application Default Credentials.

import {readFileSync} from "node:fs";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const admin = require("./../functions/node_modules/firebase-admin");

const apply = process.argv.includes("--apply");
const drafts = JSON.parse(
  readFileSync(new URL("./wisdom_library_drafts.json", import.meta.url)),
);
delete drafts._readme;

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "orbit-mvp-54642",
});
const db = admin.firestore();

for (const [docId, scrolls] of Object.entries(drafts)) {
  const ref = db.collection("wisdom_library").doc(docId);
  const existing = await ref.get();
  const status = existing.exists ? "EXISTS (skipping)" : "new";
  console.log(`${docId}: ${scrolls.length} scrolls, ${status}`);
  if (existing.exists) continue; // never clobber curated content
  if (apply) {
    await ref.set({scrolls});
    console.log(`  -> written`);
  }
}
console.log(apply ? "Done." : "Dry run only — pass --apply to write.");
process.exit(0);
