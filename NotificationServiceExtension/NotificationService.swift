import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = content.userInfo

        if let title = userInfo["title"] as? String {
            content.title = title
        }
        if let body = userInfo["body"] as? String {
            content.body = body
        }
        if let subtitle = userInfo["subtitle"] as? String {
            content.subtitle = subtitle
        }
        if let category = userInfo["category"] as? String {
            content.categoryIdentifier = category
        }
        if let threadId = userInfo["thread_id"] as? String {
            content.threadIdentifier = threadId
        }

        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        if let handler = contentHandler, let content = bestAttemptContent {
            handler(content)
        }
    }
}
