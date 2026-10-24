// Pure rule of add-card: a flash card made from a hard word of the reader (no database, no AI).

export type Expl = { name?: string; kind?: string; text?: string };
type Lang = 'tr' | 'en' | 'fa' | 'ar';

const ASK: Record<Lang, (x: string) => string> = {
  tr: (x) => `${x} nedir?`,
  en: (x) => `What is ${x}?`,
  fa: (x) => `${x} چیست؟`,
  ar: (x) => `ما هو ${x}؟`,
};

/**
 * The card is written in the lesson's content language (CLAUDE.md), using the word's ready explanation:
 * question = "<word> nedir?", answer = the explanation, note = its kind. Another language is used only when the
 * content language has no explanation. null = the word has no explanation at all.
 */
export function termCard(explanation: Partial<Record<string, Expl>>, contentLang: string, surface: string) {
  const order = [contentLang, 'tr', 'en', 'fa', 'ar'].filter((l): l is Lang => l in ASK);
  const lang = order.find((l) => explanation[l]?.text?.trim());
  if (!lang) return null;
  const ex = explanation[lang]!;
  const name = ex.name?.trim() || surface;
  return { lang, question: ASK[lang](name), answer: ex.text!.trim(), note: ex.kind?.trim() || null };
}
