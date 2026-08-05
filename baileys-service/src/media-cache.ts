// Decrypted media, held for Rails to fetch. Baileys media must be downloaded
// while the socket event is fresh — a lazy URL handed to Rails hours later
// would fail — so instances download on receipt and park the buffer here.
interface CachedMedia {
  buffer: Buffer;
  mimetype: string;
  filename?: string;
  storedAt: number;
}

const TTL_MS = 30 * 60 * 1000;
const store = new Map<string, CachedMedia>();

export function putMedia(
  id: string,
  buffer: Buffer,
  mimetype: string,
  filename?: string
) {
  store.set(id, { buffer, mimetype, filename, storedAt: Date.now() });
}

export function getMedia(id: string): CachedMedia | undefined {
  const item = store.get(id);
  if (!item) return undefined;
  if (Date.now() - item.storedAt > TTL_MS) {
    store.delete(id);
    return undefined;
  }
  return item;
}

setInterval(() => {
  const cutoff = Date.now() - TTL_MS;
  for (const [id, item] of store) {
    if (item.storedAt < cutoff) store.delete(id);
  }
}, 60 * 1000).unref();
