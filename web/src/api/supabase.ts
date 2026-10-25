import { createClient } from '@supabase/supabase-js';

// URL and publishable key come from web/.env.local (and the Vercel project settings). Both are public by design;
// Row Level Security protects the data. Never put the service role key or any other secret in the web app.
const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;
if (!url || !key) throw new Error('Missing VITE_SUPABASE_URL / VITE_SUPABASE_PUBLISHABLE_KEY (see web/.env.local)');

export const supabase = createClient(url, key);

/** For calls the client library cannot make itself (the assistant's answer arrives as a stream). */
export const functionsUrl = `${url}/functions/v1`;
export const publishableKey = key;
