// Storage paths that come from the database (material_files, question_samples, support_messages, profiles.avatar_path)
// are written by the student's app. The Edge Functions read them with the service role, so a path must be turned into a
// clean "<user id>/…" path first: no "..", no leading slash, no backslash, and it must start with the owner's own folder.
// Returns the cleaned path, or null when the path is not inside the owner's folder.
export function safeStoragePath(uid: string, path: string | null | undefined): string | null {
  if (!path || typeof path !== 'string' || path.includes('\\') || path.includes('\0')) return null;
  const parts: string[] = [];
  for (const seg of path.split('/')) {
    if (seg === '' || seg === '.') continue;
    if (seg === '..') return null; // never walk up: reject instead of resolving
    parts.push(seg);
  }
  if (parts.length < 2 || parts[0] !== uid) return null;
  return parts.join('/');
}
