import SwiftUI
import GoogleSignIn

struct GoogleSignInButtonView: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let button = GIDSignInButton()
        button.style = .standard
        button.colorScheme = .dark
        button.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.widthAnchor.constraint(equalTo: container.widthAnchor),
            button.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
