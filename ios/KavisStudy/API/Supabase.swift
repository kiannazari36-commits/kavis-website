import Foundation
import Supabase

/// The one Supabase client of the app: the same backend as the web (auth, tables with Row Level Security,
/// storage, Edge Functions). The session is kept in the Keychain by the client and refreshed by itself.
let supabase = SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseKey)
