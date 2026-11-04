// Finding a hard word in a text, Turkish endings included ("kaptoprilin", "anjiyoödemi", "ilacı").
// The same rule is in supabase/functions/process-material/lib.ts (termHits); keep both alike.

/** Lower case with Turkish rules, one character for one character (so places stay the same); ı counts as i. */
export function fold(text: string): string {
  let out = '';
  for (const ch of text) {
    const l = ch.toLocaleLowerCase('tr');
    out += (l.length === ch.length ? l : ch).replace('ı', 'i');
  }
  return out;
}

const esc = (x: string) => x.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const SOFT: Record<string, string> = { p: 'b', ç: 'c', t: 'd', k: 'ğ', g: 'ğ' };

/**
 * Regex for one hard word on folded text: whole word at the start, then (for words of 4+ letters) a Turkish ending
 * of up to 8 letters, or an ending after an apostrophe ("ACE'nin"). A last p/ç/t/k may soften before a vowel
 * ("kalbi", "ilacı"). The match covers the whole written word.
 */
export function termRegex(surface: string): RegExp | null {
  const s = fold(surface.trim()).replace(/\s+/g, ' ');
  if (s.length < 2) return null;
  const parts = [esc(s).replace(/ /g, '\\s+')];
  const last = s[s.length - 1];
  if (s.length >= 4 && SOFT[last]) parts.push(`${esc(s.slice(0, -1)).replace(/ /g, '\\s+')}${SOFT[last]}(?=[aeioöuü])`);
  const ending = s.length >= 4 ? `(?:['’]\\p{L}{1,10}|\\p{L}{0,8})` : `(?:['’]\\p{L}{1,10})?`;
  return new RegExp(`(?<![\\p{L}\\p{N}])(?:${parts.join('|')})${ending}(?![\\p{L}\\p{N}])`, 'gu');
}

/** Every place the hard word stands in the text, as [start, end) of the original text. */
export function termHits(text: string, surface: string): [number, number][] {
  const re = termRegex(surface);
  if (!re) return [];
  return [...fold(text).matchAll(re)].map((m) => [m.index!, m.index! + m[0].length]);
}
