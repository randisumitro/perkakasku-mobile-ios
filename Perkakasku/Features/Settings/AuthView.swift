
import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var mode: AuthMode = .login
    @State private var error: String?
    enum AuthMode: String, CaseIterable { case login = "Login"; case register = "Register" }
    @State private var name = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("", selection: $mode) {
                    ForEach(AuthMode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented).padding(.horizontal)
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress).padding(.horizontal)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder).padding(.horizontal)
                if mode == .register {
                    TextField("Name (optional)", text: $name)
                        .textFieldStyle(.roundedBorder).padding(.horizontal)
                }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
                PrimaryButton(title: mode.rawValue, isLoading: auth.isLoading) {
                    Task { await submit() }
                }
                .padding(.horizontal)
                Spacer(minLength: 40)
            }
            .navigationTitle(mode.rawValue)
        }
    }
    private func submit() async {
        do {
            if mode == .login {
                _ = try await auth.login(email: email, password: password)
            } else {
                _ = try await auth.register(email: email, password: password, name: name.isEmpty ? nil : name)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
