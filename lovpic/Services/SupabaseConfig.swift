//
//  SupabaseConfig.swift
//  lovpic
//

import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://qtczfctupwpbqlxbiatu.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0Y3pmY3R1cHdwYnFseGJpYXR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4MTk0MzcsImV4cCI6MjA4NDM5NTQzN30.Mc43NC9xryiOcy2nAcenghHhiQ2BMXg2e-eFXSwnDWs"
    
    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey
    )
}
