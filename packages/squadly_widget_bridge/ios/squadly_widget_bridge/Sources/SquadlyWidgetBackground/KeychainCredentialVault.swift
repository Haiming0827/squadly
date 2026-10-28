import Foundation
import Security
import SquadlyWidgetCore

/// No access-group override: this is the main app's private, device-only item.
public final class KeychainCredentialVault: BackgroundCredentialVault {
  private let service: String
  public init(applicationID: String) { service = applicationID + ".photo-background-v1" }
  private var query: [String: Any] {
    var value: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service, kSecAttrAccount as String: "current",
      kSecAttrSynchronizable as String: false]
    #if os(macOS)
    value[kSecUseDataProtectionKeychain as String] = true
    #endif
    return value
  }
  public func load() throws -> Data? {
    var request = query
    request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(request as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else { throw WidgetStoreError.unavailable }
    return data
  }
  public func save(_ data: Data) throws {
    try clear()
    var request = query
    request[kSecValueData as String] = data
    request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else { throw WidgetStoreError.unavailable }
  }
  public func clear() throws {
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw WidgetStoreError.unavailable }
  }
}
