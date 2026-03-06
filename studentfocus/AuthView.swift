import SwiftUI
import AuthenticationServices

// MARK: - AUTH ROUTER
// Place this as the entry point in your App file:
// @main struct YourApp: App {
//     var body: some Scene {
//         WindowGroup { AuthRouterView() }
//     }
// }

struct AuthRouterView: View {
    @StateObject private var authState = AuthState()

    var body: some View {
        Group {
            if authState.isAuthenticated {
                // ✅ Goes to your main ContentView after login/signup
                ContentView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                WelcomeView()
                    .environmentObject(authState)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.45), value: authState.isAuthenticated)
    }
}

// MARK: - AUTH STATE
class AuthState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AppUser? = nil

    private let userKey = "saved_user"

    init() {
        // Auto-login if user already exists
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(AppUser.self, from: data) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }

    func signUp(name: String, email: String) {
        let user = AppUser(name: name, email: email, provider: .email)
        save(user)
    }

    func login(email: String) {
        // In a real app: validate against backend
        let user = AppUser(name: email.components(separatedBy: "@").first?.capitalized ?? "User",
                           email: email, provider: .email)
        save(user)
    }

    func signInWithGoogle() {
        // Placeholder — wire up GoogleSignIn SDK here
        let user = AppUser(name: "Google User", email: "user@gmail.com", provider: .google)
        save(user)
    }

    func signInWithApple(name: String, email: String) {
        let user = AppUser(name: name, email: email, provider: .apple)
        save(user)
    }

    func signOut() {
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    private func save(_ user: AppUser) {
        currentUser = user
        isAuthenticated = true
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
}

// MARK: - USER MODEL
struct AppUser: Codable {
    let name: String
    let email: String
    let provider: AuthProvider

    enum AuthProvider: String, Codable {
        case email, google, apple
    }
}

// MARK: - WELCOME / LANDING
struct WelcomeView: View {
    @EnvironmentObject var authState: AuthState
    @State private var showLogin  = false
    @State private var showSignUp = false
    @State private var glowPulse  = false

    var body: some View {
        ZStack {
            // Background
            backgroundLayer

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 130, height: 130)
                            .scaleEffect(glowPulse ? 1.12 : 1.0)
                            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowPulse)

                        Circle()
                            .fill(Color.orange.opacity(0.06))
                            .frame(width: 160, height: 160)
                            .scaleEffect(glowPulse ? 1.08 : 0.95)
                            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: glowPulse)

                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .yellow],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }

                    VStack(spacing: 8) {
                        Text("Student Focus")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Build focus. Build habits.\nBuild your future.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                Spacer()

                // Buttons
                VStack(spacing: 14) {
                    // Sign Up
                    Button {
                        showSignUp = true
                    } label: {
                        Text("Create Account")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.orange, Color(red: 1, green: 0.6, blue: 0.1)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.black)
                            .cornerRadius(16)
                    }

                    // Log In
                    Button {
                        showLogin = true
                    } label: {
                        Text("Log In")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }

                    // Divider
                    HStack {
                        Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                        Text("or").font(.caption).foregroundColor(.white.opacity(0.35))
                        Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                    }

                    // Google Sign In
                    Button {
                        authState.signInWithGoogle()
                    } label: {
                        HStack(spacing: 10) {
                            GoogleLogoView()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }

                    // Apple Sign In
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .onAppear { glowPulse = true }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView().environmentObject(authState)
        }
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView().environmentObject(authState)
        }
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                let name  = [cred.fullName?.givenName, cred.fullName?.familyName]
                    .compactMap { $0 }.joined(separator: " ")
                let email = cred.email ?? "apple@privaterelay.com"
                authState.signInWithApple(name: name.isEmpty ? "Apple User" : name, email: email)
            }
        case .failure:
            break
        }
    }

    var backgroundLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Subtle radial glow top
            RadialGradient(
                colors: [Color.orange.opacity(0.18), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()
            // Bottom glow
            RadialGradient(
                colors: [Color.orange.opacity(0.08), Color.clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - LOGIN VIEW
struct LoginView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) var dismiss

    @State private var email    = ""
    @State private var password = ""
    @State private var showPassword  = false
    @State private var isLoading     = false
    @State private var showError     = false
    @State private var errorMessage  = ""
    @State private var animateIn     = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Color.orange.opacity(0.14), Color.clear],
                           center: .top, startRadius: 0, endRadius: 380)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {

                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome\nback 👋")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineSpacing(2)
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateIn)

                            Text("Log in to continue your streak")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 16)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.18), value: animateIn)
                        }
                        .padding(.top, 32)

                        // Form
                        VStack(spacing: 16) {
                            // Email
                            AuthField(
                                icon: "envelope.fill",
                                placeholder: "Email address",
                                text: $email,
                                keyboardType: .emailAddress,
                                isSecure: false
                            )
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }

                            // Password
                            AuthField(
                                icon: "lock.fill",
                                placeholder: "Password",
                                text: $password,
                                keyboardType: .default,
                                isSecure: !showPassword,
                                trailingButton: AnyView(
                                    Button { showPassword.toggle() } label: {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.white.opacity(0.4))
                                            .font(.system(size: 15))
                                    }
                                )
                            )
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { attemptLogin() }

                            // Error
                            if showError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            // Forgot password
                            HStack {
                                Spacer()
                                Button("Forgot password?") { }
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                        }
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 24)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: animateIn)

                        // Log In button
                        Button(action: attemptLogin) {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Log In")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                LinearGradient(colors: [.orange, Color(red: 1, green: 0.6, blue: 0.1)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                        }
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.32), value: animateIn)

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                            Text("or").font(.caption).foregroundColor(.white.opacity(0.35))
                            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                        }
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeIn.delay(0.38), value: animateIn)

                        // Social buttons
                        VStack(spacing: 12) {
                            // Google
                            Button { authState.signInWithGoogle() } label: {
                                HStack(spacing: 10) {
                                    GoogleLogoView().frame(width: 20, height: 20)
                                    Text("Continue with Google")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }

                            // Apple
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                if case .success(let auth) = result,
                                   let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                                    let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                                        .compactMap { $0 }.joined(separator: " ")
                                    authState.signInWithApple(
                                        name: name.isEmpty ? "Apple User" : name,
                                        email: cred.email ?? "apple@privaterelay.com"
                                    )
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 52)
                            .cornerRadius(16)
                        }
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateIn)

                        // Sign up link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.white.opacity(0.45))
                            Button {
                                dismiss()
                                // Parent will show SignUp via WelcomeView
                            } label: {
                                Text("Sign up")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.system(size: 15, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 32)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeIn.delay(0.45), value: animateIn)
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
        .onAppear { animateIn = true }
    }

    func attemptLogin() {
        let trimEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimEmail.isEmpty, trimEmail.contains("@") else {
            showError(message: "Please enter a valid email address")
            return
        }
        guard !password.isEmpty else {
            showError(message: "Please enter your password")
            return
        }
        isLoading = true
        // Simulate network call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isLoading = false
            authState.login(email: trimEmail)
        }
    }

    func showError(message: String) {
        errorMessage = message
        withAnimation { showError = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showError = false }
        }
    }
}

// MARK: - SIGN UP VIEW
struct SignUpView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) var dismiss

    @State private var fullName   = ""
    @State private var email      = ""
    @State private var password   = ""
    @State private var confirmPwd = ""
    @State private var showPassword    = false
    @State private var showConfirmPwd  = false
    @State private var isLoading       = false
    @State private var showError       = false
    @State private var errorMessage    = ""
    @State private var agreedToTerms   = false
    @State private var animateIn       = false
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, confirm }

    // Password strength
    var passwordStrength: Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*".contains($0) }) { score += 1 }
        return score
    }

    var strengthLabel: String {
        switch passwordStrength {
        case 0, 1: return "Weak"
        case 2:    return "Fair"
        case 3:    return "Good"
        default:   return "Strong"
        }
    }

    var strengthColor: Color {
        switch passwordStrength {
        case 0, 1: return .red
        case 2:    return .orange
        case 3:    return .yellow
        default:   return .green
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Color.orange.opacity(0.14), Color.clear],
                           center: .top, startRadius: 0, endRadius: 380)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Step 1 of 1")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {

                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Create your\naccount ✨")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineSpacing(2)
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateIn)

                            Text("Join thousands of focused students")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .opacity(animateIn ? 1 : 0)
                                .animation(.spring(response: 0.6).delay(0.18), value: animateIn)
                        }
                        .padding(.top, 32)

                        // Form fields
                        VStack(spacing: 14) {
                            // Full name
                            AuthField(icon: "person.fill", placeholder: "Full name",
                                      text: $fullName, keyboardType: .default, isSecure: false)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .email }

                            // Email
                            AuthField(icon: "envelope.fill", placeholder: "Email address",
                                      text: $email, keyboardType: .emailAddress, isSecure: false)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }

                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                AuthField(
                                    icon: "lock.fill",
                                    placeholder: "Password",
                                    text: $password,
                                    keyboardType: .default,
                                    isSecure: !showPassword,
                                    trailingButton: AnyView(
                                        Button { showPassword.toggle() } label: {
                                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                                .foregroundColor(.white.opacity(0.4))
                                                .font(.system(size: 15))
                                        }
                                    )
                                )
                                .focused($focusedField, equals: .password)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .confirm }

                                // Password strength indicator
                                if !password.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            ForEach(0..<4) { i in
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(i < passwordStrength ? strengthColor : Color.white.opacity(0.1))
                                                    .frame(height: 3)
                                                    .animation(.easeInOut(duration: 0.3), value: passwordStrength)
                                            }
                                        }
                                        Text(strengthLabel)
                                            .font(.caption2)
                                            .foregroundColor(strengthColor)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }

                            // Confirm password
                            AuthField(
                                icon: "lock.rotation",
                                placeholder: "Confirm password",
                                text: $confirmPwd,
                                keyboardType: .default,
                                isSecure: !showConfirmPwd,
                                trailingButton: AnyView(
                                    Button { showConfirmPwd.toggle() } label: {
                                        Image(systemName: showConfirmPwd ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.white.opacity(0.4))
                                            .font(.system(size: 15))
                                    }
                                )
                            )
                            .focused($focusedField, equals: .confirm)
                            .submitLabel(.done)
                            .onSubmit { attemptSignUp() }

                            // Match indicator
                            if !confirmPwd.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: password == confirmPwd ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(password == confirmPwd ? .green : .red)
                                        .font(.caption)
                                    Text(password == confirmPwd ? "Passwords match" : "Passwords don't match")
                                        .font(.caption)
                                        .foregroundColor(password == confirmPwd ? .green : .red)
                                }
                                .transition(.opacity)
                            }

                            // Error
                            if showError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red).font(.caption)
                                    Text(errorMessage).font(.caption).foregroundColor(.red)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            // Terms
                            Button {
                                agreedToTerms.toggle()
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(agreedToTerms ? .orange : .white.opacity(0.4))
                                        .font(.system(size: 18))
                                    Text("I agree to the **Terms of Service** and **Privacy Policy**")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 24)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: animateIn)

                        // Create account button
                        Button(action: attemptSignUp) {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Create Account")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                agreedToTerms
                                ? LinearGradient(colors: [.orange, Color(red: 1, green: 0.6, blue: 0.1)],
                                                 startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                                 startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                        }
                        .disabled(!agreedToTerms || isLoading)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.spring(response: 0.6).delay(0.32), value: animateIn)

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                            Text("or").font(.caption).foregroundColor(.white.opacity(0.35))
                            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                        }

                        // Social buttons
                        VStack(spacing: 12) {
                            Button { authState.signInWithGoogle() } label: {
                                HStack(spacing: 10) {
                                    GoogleLogoView().frame(width: 20, height: 20)
                                    Text("Sign up with Google")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }

                            SignInWithAppleButton(.signUp) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                if case .success(let auth) = result,
                                   let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                                    let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                                        .compactMap { $0 }.joined(separator: " ")
                                    authState.signInWithApple(
                                        name: name.isEmpty ? "Apple User" : name,
                                        email: cred.email ?? "apple@privaterelay.com"
                                    )
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 52)
                            .cornerRadius(16)
                        }
                        .opacity(animateIn ? 1 : 0)
                        .animation(.spring(response: 0.6).delay(0.38), value: animateIn)

                        // Already have account
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(.white.opacity(0.45))
                            Button { dismiss() } label: {
                                Text("Log in")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.system(size: 15, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 40)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeIn.delay(0.44), value: animateIn)
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
        .onAppear { animateIn = true }
    }

    func attemptSignUp() {
        let trimName  = fullName.trimmingCharacters(in: .whitespaces)
        let trimEmail = email.trimmingCharacters(in: .whitespaces)

        guard !trimName.isEmpty else {
            showErrorMsg("Please enter your full name"); return
        }
        guard !trimEmail.isEmpty, trimEmail.contains("@") else {
            showErrorMsg("Please enter a valid email address"); return
        }
        guard password.count >= 6 else {
            showErrorMsg("Password must be at least 6 characters"); return
        }
        guard password == confirmPwd else {
            showErrorMsg("Passwords don't match"); return
        }
        guard agreedToTerms else {
            showErrorMsg("Please agree to the Terms of Service"); return
        }

        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            isLoading = false
            authState.signUp(name: trimName, email: trimEmail)
        }
    }

    func showErrorMsg(_ msg: String) {
        errorMessage = msg
        withAnimation { showError = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showError = false }
        }
    }
}

// MARK: - REUSABLE AUTH FIELD
struct AuthField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    var trailingButton: AnyView? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange.opacity(0.8))
                .font(.system(size: 15))
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
            }

            if let trailing = trailingButton {
                trailing
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - GOOGLE LOGO (drawn, no image asset needed)
struct GoogleLogoView: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2

            // Draw G shape using colored arcs
            // Blue arc (right side)
            var path = Path()
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(-15), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: center)
            path.closeSubpath()
            context.fill(path, with: .color(.blue))

            // Red arc (top)
            var path2 = Path()
            path2.addArc(center: center, radius: radius,
                         startAngle: .degrees(90), endAngle: .degrees(200), clockwise: false)
            path2.addLine(to: center)
            path2.closeSubpath()
            context.fill(path2, with: .color(.red))

            // Yellow arc (bottom-left)
            var path3 = Path()
            path3.addArc(center: center, radius: radius,
                         startAngle: .degrees(200), endAngle: .degrees(345), clockwise: false)
            path3.addLine(to: center)
            path3.closeSubpath()
            context.fill(path3, with: .color(.yellow))

            // White inner circle
            var inner = Path()
            inner.addEllipse(in: CGRect(x: size.width * 0.25, y: size.height * 0.25,
                                        width: size.width * 0.5, height: size.height * 0.5))
            context.fill(inner, with: .color(.white))

            // Blue horizontal bar (the G crossbar)
            var bar = Path()
            bar.addRect(CGRect(x: size.width * 0.5, y: size.height * 0.38,
                               width: size.width * 0.45, height: size.height * 0.22))
            context.fill(bar, with: .color(.blue))

            // White center dot (clean up G center)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: size.width * 0.3, y: size.height * 0.3,
                                      width: size.width * 0.4, height: size.height * 0.4))
            context.fill(dot, with: .color(.white))
        }
    }
}
#Preview{
   AuthRouterView()
}
