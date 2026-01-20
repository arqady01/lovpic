//
//  UserProfile.swift
//  lovpic
//

import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var nickname: String?
    var avatarUrl: String?
    var phone: String?
    var membershipType: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case phone
        case membershipType = "membership_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var displayName: String {
        if let nickname = nickname, !nickname.isEmpty {
            return nickname
        }
        if let phone = phone, !phone.isEmpty {
            return maskPhone(phone)
        }
        return "用户"
    }
    
    var membershipDisplayName: String {
        switch membershipType {
        case "vip": return "VIP会员"
        case "premium": return "高级会员"
        default: return "普通会员"
        }
    }
    
    private func maskPhone(_ phone: String) -> String {
        guard phone.count >= 7 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }
}
