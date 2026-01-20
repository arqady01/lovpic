//
//  AuthManager.swift
//  lovpic
//

import Foundation
import Supabase
import Observation

@Observable
final class AuthManager {
    static let shared = AuthManager()
    
    private(set) var currentUser: User?
    private(set) var userProfile: UserProfile?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    
    var isLoggedIn: Bool { currentUser != nil }
    
    private init() {
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Session Management
    
    @MainActor
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let session = try await SupabaseConfig.client.auth.session
            currentUser = session.user
            if currentUser != nil {
                await fetchProfile()
            }
        } catch {
            currentUser = nil
            userProfile = nil
        }
    }
    
    // MARK: - Sign Up
    
    @MainActor
    func signUp(email: String, password: String, nickname: String? = nil) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await SupabaseConfig.client.auth.signUp(
                email: email,
                password: password,
                data: nickname != nil ? ["nickname": .string(nickname!)] : nil
            )
            currentUser = response.user
            await fetchProfile()
        } catch {
            errorMessage = mapError(error)
            throw error
        }
    }
    
    // MARK: - Sign In
    
    @MainActor
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let session = try await SupabaseConfig.client.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            await fetchProfile()
        } catch {
            errorMessage = mapError(error)
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    @MainActor
    func signOut() async {
        do {
            try await SupabaseConfig.client.auth.signOut()
            currentUser = nil
            userProfile = nil
        } catch {
            errorMessage = mapError(error)
        }
    }
    
    // MARK: - Profile
    
    @MainActor
    func fetchProfile() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let profile: UserProfile = try await SupabaseConfig.client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            userProfile = profile
        } catch {
            print("Failed to fetch profile: \(error)")
        }
    }
    
    @MainActor
    func updateProfile(nickname: String?, avatarUrl: String? = nil) async throws {
        guard let userId = currentUser?.id else { return }
        
        var updates: [String: String] = [:]
        if let nickname = nickname { updates["nickname"] = nickname }
        if let avatarUrl = avatarUrl { updates["avatar_url"] = avatarUrl }
        
        try await SupabaseConfig.client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
        
        await fetchProfile()
    }
    
    // MARK: - Error Mapping
    
    private func mapError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid login") || message.contains("invalid credentials") {
            return "邮箱或密码错误"
        } else if message.contains("email") && message.contains("already") {
            return "该邮箱已被注册"
        } else if message.contains("password") && message.contains("weak") {
            return "密码强度不够，请使用至少6位字符"
        } else if message.contains("network") {
            return "网络连接失败，请检查网络"
        }
        return "操作失败，请稍后重试"
    }
}
