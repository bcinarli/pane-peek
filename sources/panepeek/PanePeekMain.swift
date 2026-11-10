import Foundation

@main enum PanePeekMain {
    @MainActor static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == Launcher.modeArgument {
            Launcher.run(Array(arguments.dropFirst()))
        }
        PanePeekApp.main()
    }
}
