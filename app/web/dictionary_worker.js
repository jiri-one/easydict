// SQLite for the dictionary copy (lib/data/worker_sql_reader.dart).
//
// The whole database lives in memory: GitHub Pages cannot send the headers that the OPFS storage
// of SQLite needs, and its variant without them allows only one tab.
import sqlite3InitModule from "./sqlite/index.mjs";

let database;

async function download(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);
  const total = Number(response.headers.get("content-length"));
  const reader = response.body.getReader();
  const chunks = [];
  let received = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) return new Blob(chunks);
    chunks.push(value);
    received += value.length;
    if (total) postMessage({ progress: Math.min(received / total, 1) });
  }
}

async function store(cache, url, blob) {
  try {
    for (const key of await cache.keys()) await cache.delete(key);
    await cache.put(url, new Response(blob));
  } catch (error) {
    console.warn("The dictionary copy was not stored:", error);
  }
}

async function open(url) {
  // Without the Cache API (some private windows) every outage downloads the copy again.
  const cache = await globalThis.caches?.open("easydict-dictionary").catch(() => undefined);
  const cached = await cache?.match(url);
  const blob = cached ? await cached.blob() : await download(url);
  const unpacked = blob.stream().pipeThrough(new DecompressionStream("gzip"));
  const bytes = new Uint8Array(await new Response(unpacked).arrayBuffer());
  const sqlite3 = await sqlite3InitModule();
  const { capi, wasm } = sqlite3;
  database = new sqlite3.oo1.DB();
  database.checkRc(
    capi.sqlite3_deserialize(
      database.pointer,
      "main",
      wasm.allocFromTypedArray(bytes),
      bytes.length,
      bytes.length,
      capi.SQLITE_DESERIALIZE_FREEONCLOSE | capi.SQLITE_DESERIALIZE_READONLY,
    ),
  );
  // Every page is in memory already, and the default cache would hold them twice.
  database.exec("PRAGMA cache_size = 16");
  // Only now: a broken file would stay in the cache until the next dictionary.
  if (cache && !cached) await store(cache, url, blob);
}

onmessage = async ({ data }) => {
  try {
    if (data.open) await open(data.open);
    const rows = data.sql ? database.selectObjects(data.sql, data.arguments) : [];
    postMessage({ id: data.id, rows });
  } catch (error) {
    postMessage({ id: data.id, error: `${error}` });
  }
};
