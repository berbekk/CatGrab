import Foundation
import ServiceManagement

enum LaunchAtLoginService {
    static var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needsUserApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setOpenAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginItemsSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
