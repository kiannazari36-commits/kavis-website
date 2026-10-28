// iPhone photos are HEIC / HEIF, which only Safari can read. Here they are turned into JPEG in the browser before
// anything else touches them; every other format is returned as it is. The converter is loaded only when a HEIC
// file really comes (it is large).

const isHeic = (f: File) => /^image\/hei[cf]$/i.test(f.type) || /\.(heic|heif)$/i.test(f.name);

export async function normalizeImage(file: File): Promise<File> {
  if (!isHeic(file)) return file;
  const { heicTo } = await import('heic-to');
  const jpeg = await heicTo({ blob: file, type: 'image/jpeg', quality: 0.9 });
  return new File([jpeg], file.name.replace(/\.(heic|heif)$/i, '') + '.jpg', { type: 'image/jpeg' });
}
