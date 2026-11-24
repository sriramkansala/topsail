import SwiftUI

/// Another app's notification, below the camera: its icon, who it's from and what it says.
/// Clicking opens the app; it stays while the pointer is on it.
struct NotificationNotice: View {
    let notification: MirroredNotification
    /// Off: says who it's from, not what it says.
    let showsText: Bool
    let notchSize: CGSize

    var body: some View {
        Button(action: notification.open) {
            VStack(spacing: 0) {
                Color.clear.frame(height: notchSize.height)
                HStack(spacing: 11) {
                    Group {
                        if let icon = notification.icon {
                            Image(nsImage: icon).resizable()
                        } else {
                            Image(systemName: "bell.fill").foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(width: IslandLayout.notificationIconSize, height: IslandLayout.notificationIconSize)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(notification.title.isEmpty ? notification.appName : notification.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(notification.appName)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.45))
                                .fixedSize()
                        }
                        Text(showsText ? notification.body : String(localized: "New notification"))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(height: IslandLayout.notificationHeight)
                .padding(.horizontal, IslandLayout.reminderInset)
                .padding(.top, IslandLayout.noticeTopGap)
                .padding(.bottom, IslandLayout.noticeInset)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(.subtle, hoverWash: false))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(notification.appName): \(notification.title). \(showsText ? notification.body : "")")
        .accessibilityHint("Opens \(notification.appName)")
    }
}
