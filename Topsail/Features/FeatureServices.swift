import Foundation

/// The services behind the switched-off-by-default features (Settings › Features). Each one
/// idles until its feature is turned on.
@MainActor
final class FeatureServices {
    let keepAwake = KeepAwake()
    let shelf = ShelfStore()
    let reminders = RemindersService()
    let teleprompter = TeleprompterController()
    let recorder = Recorder()
    let agents = AgentHub()
    let notifications = NotificationMirror()
    let apps = AppModules()
    let updater = Updater()
}
