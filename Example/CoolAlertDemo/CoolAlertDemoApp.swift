import CoolAlert
import SwiftUI

@main
struct CoolAlertDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var showSaved = false

    var body: some View {
        NavigationStack {
            List {
                Section("SwiftUI modifier") {
                    Button("Show with .coolAlert(isPresented:)") { showSaved = true }
                }
                ForEach(Demos.sections) { section in
                    Section(section.id) {
                        ForEach(section.demos) { demo in
                            Button {
                                demo.run()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(demo.title).foregroundStyle(.primary)
                                    Text(demo.detail).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("CoolAlert")
        }
        .coolAlert(isPresented: $showSaved) {
            CoolAlert(.success, "Saved", "Presented from a SwiftUI binding.")
        }
        .task {
            if UserDefaults.standard.bool(forKey: "selftest") {
                try? await Task.sleep(for: .milliseconds(600))
                await SelfTest.run()
            }
            // `-demo <id>` opens a demo at launch, handy for screenshots.
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "landscape"),
               let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
            if let id = defaults.string(forKey: "demo"), let demo = Demos.demo(id: id) {
                try? await Task.sleep(for: .milliseconds(600))
                demo.run()
                // `-autotap <title>` taps a button once the alert is up.
                if let title = defaults.string(forKey: "autotap") {
                    try? await Task.sleep(for: .seconds(1))
                    SelfTest.tap(title)
                }
            }
        }
    }
}
