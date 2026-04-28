import Foundation
import Security

func debugLog(_ message: String) {
    #if os(iOS)
    AppLogger.shared.log(message)
    #else
    #if DEBUG
    NSLog(message)
    #endif
    #endif
}

/// Simple keychain wrapper for securely storing credentials with iCloud sync
class KeychainHelper {
    
    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case unexpectedData
        case unhandledError(status: OSStatus)
    }
    
    /// Save a string value to keychain with iCloud sync enabled
    static func save(key: String, value: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "systems.lupine.sheaf",
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: true  // Enable iCloud sync
        ]
        
        // Try to add the item
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        
        if addStatus == errSecDuplicateItem {
            // Item exists, update it instead
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "systems.lupine.sheaf",
                kSecAttrSynchronizable as String: true
            ]
            
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: updateStatus)
            }
        } else if addStatus != errSecSuccess {
            throw KeychainError.unhandledError(status: addStatus)
        }
        
        debugLog("Keychain: Saved '\(key)' (length: \(value.count))")
    }
    
    /// Retrieve a string value from keychain
    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "systems.lupine.sheaf",
            kSecAttrSynchronizable as String: true,  // Look for synced items
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                debugLog("Keychain: Failed to read '\(key)' (status: \(status))")
            }
            return nil
        }
        
        debugLog("Keychain: Read '\(key)' (length: \(value.count))")
        return value
    }
    
    /// Delete a value from keychain
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "systems.lupine.sheaf",
            kSecAttrSynchronizable as String: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            debugLog("Keychain: Deleted '\(key)'")
        }
    }
    
    /// Delete all credentials
    static func deleteAll() {
        delete(key: "sheaf_base_url")
        delete(key: "sheaf_access_token")
        delete(key: "sheaf_refresh_token")
    }
}
