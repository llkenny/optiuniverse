//
//  ProfileView.swift
//  OptiUniverse
//
//  Created by max on 04.05.2026.
//

import SwiftUI
import BaseModule
import AuthenticationServices

struct ProfileView: View {

    @Environment(AppEnvironment.self) private var appEnvironment
    private var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel = .init()) {
        self.viewModel = viewModel
    }

    var body: some View {
        @Bindable var appEnvironment = appEnvironment

        VStack {
            Form {
                Section(header: Text("Account")) {
                    LabeledContent("Name") {
                        TextField("Username", text: $appEnvironment.username)
                    }
                }

                if let appleAuthData = viewModel.appleAuthData {
                    Section(header: Text("Apple Auth data")) {
                        LabeledContent("userId") {
                            Text(appleAuthData.userId)
                        }
                        LabeledContent("email") {
                            Text(appleAuthData.email ?? "")
                        }
                        LabeledContent("firstName") {
                            Text(appleAuthData.firstName ?? "")
                        }
                        LabeledContent("secondName") {
                            Text(appleAuthData.secondName ?? "")
                        }
                        LabeledContent("authorizationCodeString") {
                            Text(appleAuthData.authorizationCodeString ?? "")
                        }
                        LabeledContent("tokenString") {
                            Text(appleAuthData.tokenString ?? "")
                        }
                        Button(viewModel.isAuthenticating
                               ? "Authorizing..."
                               : "Authorize") {
                            viewModel.authenticate()
                        }
                        .disabled(viewModel.isAuthenticating)
                    }
                }

                if let authenticationResponseBody = viewModel.authenticationResponseBody {
                    Section(header: Text("Backend Auth response")) {
                        Text(authenticationResponseBody)
                    }
                }

                if let appleAuthError = viewModel.appleAuthError {
                    Section(header: Text("Apple Auth error")) {
                        Text(appleAuthError.localizedDescription)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .padding()
            .padding(.top, 16)

            Spacer()

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    viewModel.handle(result)
                }
            )
            .frame(height: 50)
            .padding()
        }
    }
}

#Preview("Empty") {
    ProfileView()
        .environment(AppEnvironment())
}

#Preview("Apple Auth data") {

    let appleAuthData = ProfileViewModel.AppleAuthData(
        userId: "userId",
        email: "email",
        firstName: "firstName",
        secondName: "secondName",
        authorizationCodeString: "authorizationCodeString ajdshkjsahdkjashdkjashdkjsahdkjashdkjahsdkjhsad",
        tokenString: "tokenString aldjaklsjdklasjdlkasjdlkasjdlkasjdlkajsdlkasdjlkasjdlkasjdlkasjd"
    )
    let viewModel = ProfileViewModel(appleAuthData: appleAuthData)

    ProfileView(viewModel: viewModel)
        .environment(AppEnvironment())
}

#Preview("Apple Auth error") {

    let appleAuthError = NSError(
        domain: ASAuthorizationError.errorDomain,
        code: ASAuthorizationError.canceled.rawValue
    )
    let viewModel = ProfileViewModel(appleAuthError: appleAuthError)

    ProfileView(viewModel: viewModel)
        .environment(AppEnvironment())
}
