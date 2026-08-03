//
//  SignInView.swift
//  KidsChores
//
//  Launch-with-no-session screen (ios-prd §5). For this phase we use an
//  email/password flow; Sign in with Apple is deferred to a later phase (it
//  needs the paid-account entitlement and a backend Apple-token verifier).
//

import SwiftUI

struct SignInView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: AuthViewModel?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            header
            Spacer(minLength: 24)
            if let model {
                form(model)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
            }
            Spacer(minLength: 24)
        }
        .padding(24)
        // Keep the form a readable, centered column on iPad instead of letting
        // the fields stretch edge-to-edge (portrait and landscape).
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            if model == nil {
                model = AuthViewModel(service: session.api) { tokens in
                    session.didSignIn(tokens)
                }
            }
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            BrandMark(size: 84)
                .padding(22)
                .background(Brand.backdrop, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)
            VStack(spacing: 6) {
                Text("KidsChores")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Get it done. Get paid.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
        }
    }

    @ViewBuilder
    private func form(_ model: AuthViewModel) -> some View {
        @Bindable var model = model
        VStack(spacing: 12) {
            Picker("Mode", selection: $model.mode) {
                ForEach(AuthViewModel.Mode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if model.mode == .register {
                TextField("Your name", text: $model.displayName)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Email", text: $model.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $model.password)
                .textContentType(model.mode == .login ? .password : .newPassword)
                .textFieldStyle(.roundedBorder)

            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await model.submit() }
            } label: {
                Group {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Text(model.mode.rawValue).frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canSubmit)
        }
    }
}
