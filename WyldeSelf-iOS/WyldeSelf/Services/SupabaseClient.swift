import Foundation
import Supabase

// ════════════════════════════════════════════════════════════════════
//  Singleton Supabase client. Reads SUPABASE_URL + SUPABASE_ANON_KEY
//  from Info.plist. Add the Supabase Swift SDK via SPM:
//    https://github.com/supabase-community/supabase-swift
// ════════════════════════════════════════════════════════════════════

enum SupabaseService {
    static let shared: SupabaseClient = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !anonKey.isEmpty
        else {
            fatalError("Missing SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist.")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: .init(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }()
}
