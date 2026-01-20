//
//  AuthView.swift
//  lovpic
//

import SwiftUI

struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var showError = false
    
    private var authManager: AuthManager { AuthManager.shared }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.98, blue: 0.99)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Logo
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0, green: 0.7, blue: 0.4),
                                                Color(red: 1.0, green: 0.5, blue: 0.5)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Lovpic")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 40)
                        
                        // Tab Switcher
                        HStack(spacing: 0) {
                            tabButton(title: "登录", isSelected: isLogin) {
                                withAnimation { isLogin = true }
                            }
                            tabButton(title: "注册", isSelected: !isLogin) {
                                withAnimation { isLogin = false }
                            }
                        }
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                        
                        // Form
                        VStack(spacing: 16) {
                            if !isLogin {
                                inputField(
                                    icon: "person",
                                    placeholder: "昵称（选填）",
                                    text: $nickname
                                )
                            }
                            
                            inputField(
                                icon: "envelope",
                                placeholder: "邮箱",
                                text: $email,
                                keyboardType: .emailAddress
                            )
                            
                            inputField(
                                icon: "lock",
                                placeholder: "密码",
                                text: $password,
                                isSecure: true
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Submit Button
                        Button(action: submit) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isLogin ? "登录" : "注册")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.7, blue: 0.4),
                                        Color(red: 1.0, green: 0.5, blue: 0.5)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(authManager.isLoading || !isFormValid)
                        .opacity(isFormValid ? 1 : 0.6)
                        .padding(.horizontal, 24)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("提示", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(authManager.errorMessage ?? "操作失败")
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6
    }
    
    private func submit() {
        Task {
            do {
                if isLogin {
                    try await authManager.signIn(email: email, password: password)
                } else {
                    try await authManager.signUp(
                        email: email,
                        password: password,
                        nickname: nickname.isEmpty ? nil : nickname
                    )
                }
                dismiss()
            } catch {
                showError = true
            }
        }
    }
    
    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    isSelected ?
                    AnyShapeStyle(LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.7, blue: 0.4),
                            Color(red: 1.0, green: 0.5, blue: 0.5)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )) : AnyShapeStyle(Color.clear)
                )
                .cornerRadius(10)
        }
        .padding(2)
    }
    
    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    AuthView()
}
