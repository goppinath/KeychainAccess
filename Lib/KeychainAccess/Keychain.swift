//
//  Keychain.swift
//  KeychainAccess
//
//  Created by kishikawa katsumi on 2014/12/24.
//  Copyright (c) 2014 kishikawa katsumi. All rights reserved.
//

import Foundation
import Security

public enum ItemClass {
    case GenericPassword
    case InternetPassword
}

public enum ProtocolType {
    case FTP
    case FTPAccount
    case HTTP
    case IRC
    case NNTP
    case POP3
    case SMTP
    case SOCKS
    case IMAP
    case LDAP
    case AppleTalk
    case AFP
    case Telnet
    case SSH
    case FTPS
    case HTTPS
    case HTTPProxy
    case HTTPSProxy
    case FTPProxy
    case SMB
    case RTSP
    case RTSPProxy
    case DAAP
    case EPPC
    case IPP
    case NNTPS
    case LDAPS
    case TelnetS
    case IMAPS
    case IRCS
    case POP3S
}

public enum AuthenticationType {
    case NTLM
    case MSN
    case DPA
    case RPA
    case HTTPBasic
    case HTTPDigest
    case HTMLForm
    case Default
}

public enum Accessibility {
    case WhenUnlocked
    case AfterFirstUnlock
    case Always
    case WhenPasscodeSetThisDeviceOnly
    case WhenUnlockedThisDeviceOnly
    case AfterFirstUnlockThisDeviceOnly
    case AlwaysThisDeviceOnly
}

public enum FailableOf<T> {
    case Success(Value<T?>)
    case Failure(NSError)
    
    init(_ value: T?) {
        self = .Success(Value(value))
    }
    
    init(_ error: NSError) {
        self = .Failure(error)
    }
    
    public var failed: Bool {
        switch self {
        case .Failure(let error):
            return true
        default:
            return false
        }
    }
    
    public var error: NSError? {
        switch self {
        case .Failure(let error):
            return error
        default:
            return nil
        }
    }
    
    public var value: T? {
        switch self {
        case .Success(let v):
            return v.value
        default:
            return nil
        }
    }
}

public class Value<T> {
    let value: T
    init(_ value: T) { self.value = value }
}

public class Keychain {
    public var service: String {
        return options.service
    }
    
    public var accessGroup: String? {
        return options.accessGroup
    }
    
    public var server: NSURL {
        return options.server
    }
    
    public var protocolType: ProtocolType {
        return options.protocolType
    }
    
    public var authenticationType: AuthenticationType {
        return options.authenticationType
    }
    
    public var accessibility: Accessibility {
        return options.accessibility
    }
    
    public var synchronizable: Bool {
        return options.synchronizable
    }
    
    public var label: String? {
        return options.label
    }
    
    public var comment: String? {
        return options.comment
    }
    
    public var itemClass: ItemClass {
        return options.itemClass
    }
    
    private class var errorDomain: String {
        return "KeychainAccess"
    }
    
    private let options: Options
    
    // MARK:
    
    public convenience init() {
        var options = Options()
        if let bundleIdentifier = NSBundle.mainBundle().bundleIdentifier {
            options.service = bundleIdentifier
        }
        self.init(options)
    }
    
    public convenience init(service: String) {
        var options = Options()
        options.service = service
        self.init(options)
    }
    
    public convenience init(accessGroup: String) {
        var options = Options()
        if let bundleIdentifier = NSBundle.mainBundle().bundleIdentifier {
            options.service = bundleIdentifier
        }
        options.accessGroup = accessGroup
        self.init(options)
    }
    
    public convenience init(service: String, accessGroup: String) {
        var options = Options()
        options.service = service
        options.accessGroup = accessGroup
        self.init(options)
    }
    
    public convenience init(server: NSURL, protocolType: ProtocolType) {
        self.init(server: server, protocolType: protocolType, authenticationType: .Default)
    }
    
    public convenience init(server: NSURL, protocolType: ProtocolType, authenticationType: AuthenticationType) {
        var options = Options()
        options.itemClass = .InternetPassword
        options.server = server
        options.protocolType = protocolType
        options.authenticationType = authenticationType
        self.init(options)
    }
    
    private init(_ opts: Options) {
        options = opts
    }
    
    // MARK:
    
    public func accessibility(accessibility: Accessibility) -> Keychain {
        var options = self.options
        options.accessibility = accessibility
        return Keychain(options)
    }
    
    public func synchronizable(synchronizable: Bool) -> Keychain {
        var options = self.options
        options.synchronizable = synchronizable
        return Keychain(options)
    }
    
    public func label(label: String) -> Keychain {
        var options = self.options
        options.label = label
        return Keychain(options)
    }
    
    public func comment(comment: String) -> Keychain {
        var options = self.options
        options.comment = comment
        return Keychain(options)
    }
    
    // MARK:
    
    public func get(key: String) -> String? {
        return getString(key)
    }
    
    public func getString(key: String) -> String? {
        let failable = getStringOrError(key)
        return failable.value
    }
    
    public func getData(key: String) -> NSData? {
        let failable = getDataOrError(key)
        return failable.value
    }
    
    public func getStringOrError(key: String) -> FailableOf<String> {
        let failable = getDataOrError(key)
        switch failable {
        case .Success:
            if let data = failable.value {
                if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
                    return FailableOf(string)
                }
                return FailableOf(conversionError(message: "failed to convert data to string"))
            } else {
                return FailableOf(nil)
            }
        case .Failure(let error):
            return FailableOf(error)
        }
    }
    
    public func getDataOrError(key: String) -> FailableOf<NSData> {
        var query = options.query()
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = kCFBooleanTrue
        
        query[kSecAttrAccount] = key
        
        var result: AnyObject?
        var status = withUnsafeMutablePointer(&result) { SecItemCopyMatching(query, UnsafeMutablePointer($0)) }
        
        switch status {
        case errSecSuccess:
            if let data = result as NSData? {
                return FailableOf(data)
            }
            return FailableOf(securityError(status: Status.UnknownError.rawValue))
        case errSecItemNotFound:
            return FailableOf(nil)
        default: ()
        }
        
        return FailableOf(securityError(status: status))
    }
    
    // MARK:
    
    public func set(value: String, key: String) -> NSError? {
        if let data = value.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
            return set(data, key: key)
        }
        return conversionError(message: "failed to convert string to data")
    }
    
    public func set(value: NSData, key: String) -> NSError? {
        var query = options.query()
        query[kSecAttrAccount] = key
        
        var status = SecItemCopyMatching(query, nil)
        switch status {
        case errSecSuccess:
            var attributes = options.attributes(value: value)
            
            status = SecItemUpdate(query, attributes)
            if status != errSecSuccess {
                return securityError(status: status)
            }
        case errSecItemNotFound:
            var attributes = options.attributes(key: key, value: value)
            
            status = SecItemAdd(attributes, nil)
            if status != errSecSuccess {
                return securityError(status: status)
            }
        default:
            return securityError(status: status)
        }
        return nil
    }
    
    // MARK:
    
    public func remove(key: String) -> NSError? {
        var query = options.query()
        query[kSecAttrAccount] = key
        
        let status = SecItemDelete(query)
        if status != errSecSuccess && status != errSecItemNotFound {
            return securityError(status: status)
        }
        return nil
    }
    
    public func removeAll() -> NSError? {
        var query = options.query()
        #if !os(iOS)
        query[kSecMatchLimit] = kSecMatchLimitAll
        #endif
        
        let status = SecItemDelete(query)
        if status != errSecSuccess && status != errSecItemNotFound {
            return securityError(status: status)
        }
        return nil
    }
    
    // MARK:
    
    public func contains(key: String) -> Bool? {
        var query = options.query()
        query[kSecAttrAccount] = key
        
        var status = SecItemCopyMatching(query, nil)
        
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            securityError(status: status)
            return false
        }
    }
    
    // MARK:
    
    public subscript(key: String) -> String? {
        get {
            return get(key)
        }
        
        set {
            if let value = newValue {
                set(value, key: key)
            } else {
                remove(key)
            }
        }
    }
    
    // MARK:
    
    public class func allKeys(itemClass: ItemClass) -> [(String, String)] {
        var query = [String: AnyObject]()
        query[kSecClass] = itemClass.rawValue
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = kCFBooleanTrue
        
        var result: AnyObject?
        var status = withUnsafeMutablePointer(&result) { SecItemCopyMatching(query, UnsafeMutablePointer($0)) }
        
        switch status {
        case errSecSuccess:
            if let items = result as [[String: AnyObject]]? {
                return prettify(itemClass: itemClass, items: items).map {
                    switch itemClass {
                    case .GenericPassword:
                        return (($0["service"] ?? "") as String, ($0["key"] ?? "") as String)
                    case .InternetPassword:
                        return (($0["server"] ?? "") as String, ($0["key"] ?? "") as String)
                    }
                }
            }
        case errSecItemNotFound:
            return []
        default: ()
        }
        
        securityError(status: status)
        return []
    }
    
    public func allKeys() -> [String] {
        return self.dynamicType.prettify(itemClass: itemClass, items: items()).map { $0["key"] as String }
    }
    
    public class func allItems(itemClass: ItemClass) -> [[String: AnyObject]] {
        var query = [String: AnyObject]()
        query[kSecClass] = itemClass.rawValue
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = kCFBooleanTrue
        #if os(iOS)
        query[kSecReturnData] = kCFBooleanTrue
        #endif
        
        var result: AnyObject?
        var status = withUnsafeMutablePointer(&result) { SecItemCopyMatching(query, UnsafeMutablePointer($0)) }
        
        switch status {
        case errSecSuccess:
            if let items = result as? [[String: AnyObject]] {
                return prettify(itemClass: itemClass, items: items)
            }
        case errSecItemNotFound:
            return []
        default: ()
        }
        
        securityError(status: status)
        return []
    }
    
    public func allItems() -> [[String: AnyObject]] {
        return self.dynamicType.prettify(itemClass: itemClass, items: items())
    }
    
    // MARK:
    
    private func items() -> [[String: AnyObject]] {
        var query = options.query()
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = kCFBooleanTrue
        #if os(iOS)
        query[kSecReturnData] = kCFBooleanTrue
        #endif
        
        var result: AnyObject?
        var status = withUnsafeMutablePointer(&result) { SecItemCopyMatching(query, UnsafeMutablePointer($0)) }
        
        switch status {
        case errSecSuccess:
            if let items = result as? [[String: AnyObject]] {
                return items
            }
        case errSecItemNotFound:
            return []
        default: ()
        }
        
        securityError(status: status)
        return []
    }
    
    private class func prettify(#itemClass: ItemClass, items: [[String: AnyObject]]) -> [[String: AnyObject]] {
        let items = items.map { attributes -> [String: AnyObject] in
            var item = [String: AnyObject]()
            
            item["class"] = itemClass.description
            
            switch itemClass {
            case .GenericPassword:
                if let service = attributes[kSecAttrService] as? String {
                    item["service"] = service
                }
                if let accessGroup = attributes[kSecAttrAccessGroup] as? String {
                    item["accessGroup"] = accessGroup
                }
            case .InternetPassword:
                if let server = attributes[kSecAttrServer] as? String {
                    item["server"] = server
                }
                if let proto = attributes[kSecAttrProtocol] as? String {
                    if let protocolType = ProtocolType(rawValue: proto) {
                        item["protocol"] = protocolType.description
                    }
                }
                if let auth = attributes[kSecAttrAuthenticationType] as? String {
                    if let authenticationType = AuthenticationType(rawValue: auth) {
                        item["authenticationType"] = authenticationType.description
                    }
                }
            }
            
            if let key = attributes[kSecAttrAccount] as? String {
                item["key"] = key
            }
            if let data = attributes[kSecValueData] as? NSData {
                if let text = NSString(data: data, encoding: NSUTF8StringEncoding) {
                    item["value"] = text
                } else  {
                    item["value"] = data
                }
            }
            
            if let accessible = attributes[kSecAttrAccessible] as? String {
                if let accessibility = Accessibility(rawValue: accessible) {
                    item["accessibility"] = accessibility.description
                }
            }
            if let synchronizable = attributes[kSecAttrSynchronizable] as? Bool {
                item["synchronizable"] = synchronizable ? "true" : "false"
            }

            return item
        }
        return items
    }
    
    // MARK:
    
    private class func conversionError(#message: String) -> NSError {
        let error = NSError(domain: errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        log(error)
        
        return error
    }
    
    private func conversionError(#message: String) -> NSError {
        return self.dynamicType.conversionError(message: message)
    }
    
    private class func securityError(#status: OSStatus) -> NSError {
        let message = Status(rawValue: status).description
        
        let error = NSError(domain: errorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
        log(error)
        
        return error
    }
    
    private func securityError(#status: OSStatus) -> NSError {
        return self.dynamicType.securityError(status: status)
    }
    
    private class func log(error: NSError) {
        println("OSStatus error:[\(error.code)] \(error.localizedDescription)")
    }
    
    private func log(error: NSError) {
        self.dynamicType.log(error)
    }
}

struct Options {
    var itemClass: ItemClass = .GenericPassword
    
    var service: String = ""
    var accessGroup: String? = nil
    
    var server: NSURL!
    var protocolType: ProtocolType!
    var authenticationType: AuthenticationType = .Default
    
    var accessibility: Accessibility = .AfterFirstUnlock
    var synchronizable: Bool = false
    
    var label: String?
    var comment: String?
    
    init() {}
}

extension Keychain : Printable, DebugPrintable {
    public var description: String {
        let items = allItems()
        if items.isEmpty {
            return "[]"
        }
        var description = "[\n"
        for item in items {
            description += "  "
            description += "\(item)\n"
        }
        description += "]"
        return description
    }
    
    public var debugDescription: String {
        return "\(items())"
    }
}

extension Options {
    
    func query() -> [String: AnyObject] {
        var query = [String: AnyObject]()
        query[kSecClass] = itemClass.rawValue
        query[kSecAttrSynchronizable] = kSecAttrSynchronizableAny
        
        switch itemClass {
        case .GenericPassword:
            query[kSecAttrService] = service
            #if (!arch(i386) && !arch(x86_64)) || !os(iOS)
            if let accessGroup = self.accessGroup {
                query[kSecAttrAccessGroup] = accessGroup
            }
            #endif
        case .InternetPassword:
            query[kSecAttrServer] = server.host
            query[kSecAttrPort] = server.port
            query[kSecAttrProtocol] = protocolType.rawValue
            query[kSecAttrAuthenticationType] = authenticationType.rawValue
        }
        
        return query
    }
    
    func attributes(#key: String, value: NSData) -> [String: AnyObject] {
        var attributes = query()
        
        attributes[kSecAttrAccount] = key
        attributes[kSecValueData] = value
        
        attributes[kSecAttrAccessible] = accessibility.rawValue
        attributes[kSecAttrSynchronizable] = synchronizable
        
        if label != nil {
            attributes[kSecAttrLabel] = label
        }
        if comment != nil {
            attributes[kSecAttrComment] = comment
        }
        
        return attributes
    }
    
    func attributes(#value: NSData) -> [String: AnyObject] {
        var attributes = [String: AnyObject]()
        
        attributes[kSecValueData] = value
        
        attributes[kSecAttrAccessible] = accessibility.rawValue
        attributes[kSecAttrSynchronizable] = synchronizable
        
        return attributes
    }
}

// MARK:

extension ItemClass : RawRepresentable, Printable {
    public static let allValues: [ItemClass] = [GenericPassword, InternetPassword]
    
    public init?(rawValue: String) {
        if rawValue == kSecClassGenericPassword {
            self = GenericPassword
        } else if rawValue == kSecClassInternetPassword {
            self = InternetPassword
        } else {
            return nil
        }
    }
    
    public var rawValue: String {
        switch self {
        case GenericPassword:
            return kSecClassGenericPassword
        case InternetPassword:
            return kSecClassInternetPassword
        }
    }
    
    public var description : String {
        switch self {
        case GenericPassword:
            return "GenericPassword"
        case InternetPassword:
            return "InternetPassword"
        }
    }
}

extension Accessibility : RawRepresentable, Printable {
    public static let allValues: [Accessibility] = [
        WhenUnlocked,
        AfterFirstUnlock,
        Always,
        WhenPasscodeSetThisDeviceOnly,
        WhenUnlockedThisDeviceOnly,
        AfterFirstUnlockThisDeviceOnly,
        AlwaysThisDeviceOnly,
    ]
    
    public init?(rawValue: String) {
        if rawValue == kSecAttrAccessibleWhenUnlocked {
            self = WhenUnlocked
        } else if rawValue == kSecAttrAccessibleAfterFirstUnlock {
            self = AfterFirstUnlock
        } else if rawValue == kSecAttrAccessibleAlways {
            self = Always
        } else if rawValue == kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly {
            self = WhenPasscodeSetThisDeviceOnly
        } else if rawValue == kSecAttrAccessibleWhenUnlockedThisDeviceOnly {
            self = WhenUnlockedThisDeviceOnly
        }  else if rawValue == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly {
            self = AfterFirstUnlockThisDeviceOnly
        } else if rawValue == kSecAttrAccessibleAlwaysThisDeviceOnly {
            self = AlwaysThisDeviceOnly
        } else {
            return nil
        }
    }
    
    public var rawValue: String {
        switch self {
        case WhenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case AfterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        case Always:
            return kSecAttrAccessibleAlways
        case WhenPasscodeSetThisDeviceOnly:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        case WhenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case AfterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case AlwaysThisDeviceOnly:
            return kSecAttrAccessibleAlwaysThisDeviceOnly
        }
    }
    
    public var description : String {
        switch self {
        case WhenUnlocked:
            return "WhenUnlocked"
        case AfterFirstUnlock:
            return "AfterFirstUnlock"
        case Always:
            return "Always"
        case WhenPasscodeSetThisDeviceOnly:
            return "WhenPasscodeSetThisDeviceOnly"
        case WhenUnlockedThisDeviceOnly:
            return "WhenUnlockedThisDeviceOnly"
        case AfterFirstUnlockThisDeviceOnly:
            return "AfterFirstUnlockThisDeviceOnly"
        case AlwaysThisDeviceOnly:
            return "AlwaysThisDeviceOnly"
        }
    }
}

extension ProtocolType : RawRepresentable, Printable {
    public static let allValues: [ProtocolType] = [
        FTP,
        FTPAccount,
        HTTP,
        IRC,
        NNTP,
        POP3,
        SMTP,
        SOCKS,
        IMAP,
        LDAP,
        AppleTalk,
        AFP,
        Telnet,
        SSH,
        FTPS,
        HTTPS,
        HTTPProxy,
        HTTPSProxy,
        FTPProxy,
        SMB,
        RTSP,
        RTSPProxy,
        DAAP,
        EPPC,
        IPP,
        NNTPS,
        LDAPS,
        TelnetS,
        IMAPS,
        IRCS,
        POP3S,
    ]
    
    public init?(rawValue: String) {
        if rawValue == kSecAttrProtocolFTP {
            self = FTP
        } else if rawValue == kSecAttrProtocolFTPAccount {
            self = FTPAccount
        } else if rawValue == kSecAttrProtocolHTTP {
            self = HTTP
        } else if rawValue == kSecAttrProtocolIRC {
            self = IRC
        }  else if rawValue == kSecAttrProtocolNNTP {
            self = NNTP
        } else if rawValue == kSecAttrProtocolPOP3 {
            self = POP3
        } else if rawValue == kSecAttrProtocolSMTP {
            self = SMTP
        } else if rawValue == kSecAttrProtocolPOP3 {
            self = POP3
        } else if rawValue == kSecAttrProtocolSOCKS {
            self = SOCKS
        } else if rawValue == kSecAttrProtocolIMAP {
            self = IMAP
        } else if rawValue == kSecAttrProtocolLDAP {
            self = LDAP
        } else if rawValue == kSecAttrProtocolAppleTalk {
            self = AppleTalk
        } else if rawValue == kSecAttrProtocolAFP {
            self = AFP
        } else if rawValue == kSecAttrProtocolTelnet {
            self = Telnet
        } else if rawValue == kSecAttrProtocolSSH {
            self = SSH
        } else if rawValue == kSecAttrProtocolFTPS {
            self = FTPS
        } else if rawValue == kSecAttrProtocolHTTPS {
            self = HTTPS
        } else if rawValue == kSecAttrProtocolHTTPProxy {
            self = HTTPProxy
        } else if rawValue == kSecAttrProtocolHTTPSProxy {
            self = HTTPSProxy
        } else if rawValue == kSecAttrProtocolFTPProxy {
            self = FTPProxy
        } else if rawValue == kSecAttrProtocolSMB {
            self = SMB
        } else if rawValue == kSecAttrProtocolRTSP {
            self = RTSP
        } else if rawValue == kSecAttrProtocolRTSPProxy {
            self = RTSPProxy
        } else if rawValue == kSecAttrProtocolDAAP {
            self = DAAP
        } else if rawValue == kSecAttrProtocolEPPC {
            self = EPPC
        } else if rawValue == kSecAttrProtocolIPP {
            self = IPP
        } else if rawValue == kSecAttrProtocolNNTPS {
            self = NNTPS
        } else if rawValue == kSecAttrProtocolLDAPS {
            self = LDAPS
        } else if rawValue == kSecAttrProtocolTelnetS {
            self = TelnetS
        } else if rawValue == kSecAttrProtocolIMAPS {
            self = IMAPS
        } else if rawValue == kSecAttrProtocolIRCS {
            self = IRCS
        } else if rawValue == kSecAttrProtocolPOP3S {
            self = POP3S
        } else {
            return nil
        }
    }
    
    public var rawValue: String {
        switch self {
        case FTP:
            return kSecAttrProtocolFTP
        case FTPAccount:
            return kSecAttrProtocolFTPAccount
        case HTTP:
            return kSecAttrProtocolHTTP
        case IRC:
            return kSecAttrProtocolIRC
        case NNTP:
            return kSecAttrProtocolNNTP
        case POP3:
            return kSecAttrProtocolPOP3
        case SMTP:
            return kSecAttrProtocolSMTP
        case SOCKS:
            return kSecAttrProtocolSOCKS
        case IMAP:
            return kSecAttrProtocolIMAP
        case LDAP:
            return kSecAttrProtocolLDAP
        case AppleTalk:
            return kSecAttrProtocolAppleTalk
        case AFP:
            return kSecAttrProtocolAFP
        case Telnet:
            return kSecAttrProtocolTelnet
        case SSH:
            return kSecAttrProtocolSSH
        case FTPS:
            return kSecAttrProtocolFTPS
        case HTTPS:
            return kSecAttrProtocolHTTPS
        case HTTPProxy:
            return kSecAttrProtocolHTTPProxy
        case HTTPSProxy:
            return kSecAttrProtocolHTTPSProxy
        case FTPProxy:
            return kSecAttrProtocolFTPProxy
        case SMB:
            return kSecAttrProtocolSMB
        case RTSP:
            return kSecAttrProtocolRTSP
        case RTSPProxy:
            return kSecAttrProtocolRTSPProxy
        case DAAP:
            return kSecAttrProtocolDAAP
        case EPPC:
            return kSecAttrProtocolEPPC
        case IPP:
            return kSecAttrProtocolIPP
        case NNTPS:
            return kSecAttrProtocolNNTPS
        case LDAPS:
            return kSecAttrProtocolLDAPS
        case TelnetS:
            return kSecAttrProtocolTelnetS
        case IMAPS:
            return kSecAttrProtocolIMAPS
        case IRCS:
            return kSecAttrProtocolIRCS
        case POP3S:
            return kSecAttrProtocolPOP3S
        }
    }
    
    public var description : String {
        switch self {
        case FTP:
            return "FTP"
        case FTPAccount:
            return "FTPAccount"
        case HTTP:
            return "HTTP"
        case IRC:
            return "IRC"
        case NNTP:
            return "NNTP"
        case POP3:
            return "POP3"
        case SMTP:
            return "SMTP"
        case SOCKS:
            return "SOCKS"
        case IMAP:
            return "IMAP"
        case LDAP:
            return "LDAP"
        case AppleTalk:
            return "AppleTalk"
        case AFP:
            return "AFP"
        case Telnet:
            return "Telnet"
        case SSH:
            return "SSH"
        case FTPS:
            return "FTPS"
        case HTTPS:
            return "HTTPS"
        case HTTPProxy:
            return "HTTPProxy"
        case HTTPSProxy:
            return "HTTPSProxy"
        case FTPProxy:
            return "FTPProxy"
        case SMB:
            return "SMB"
        case RTSP:
            return "RTSP"
        case RTSPProxy:
            return "RTSPProxy"
        case DAAP:
            return "DAAP"
        case EPPC:
            return "EPPC"
        case IPP:
            return "IPP"
        case NNTPS:
            return "NNTPS"
        case LDAPS:
            return "LDAPS"
        case TelnetS:
            return "TelnetS"
        case IMAPS:
            return "IMAPS"
        case IRCS:
            return "IRCS"
        case POP3S:
            return "POP3S"
        }
    }
}

extension AuthenticationType : RawRepresentable, Printable {
    public static let allValues: [AuthenticationType] = [
        NTLM,
        MSN,
        DPA,
        RPA,
        HTTPBasic,
        HTTPDigest,
        HTMLForm,
        Default,
    ]
    
    public init?(rawValue: String) {
        if rawValue == kSecAttrAuthenticationTypeNTLM {
            self = NTLM
        } else if rawValue == kSecAttrAuthenticationTypeMSN {
            self = MSN
        } else if rawValue == kSecAttrAuthenticationTypeDPA {
            self = DPA
        } else if rawValue == kSecAttrAuthenticationTypeRPA {
            self = RPA
        } else if rawValue == kSecAttrAuthenticationTypeHTTPBasic {
            self = HTTPBasic
        }  else if rawValue == kSecAttrAuthenticationTypeHTTPDigest {
            self = HTTPDigest
        } else if rawValue == kSecAttrAuthenticationTypeHTMLForm {
            self = HTMLForm
        } else if rawValue == kSecAttrAuthenticationTypeDefault {
            self = Default
        } else {
            return nil
        }
    }
    
    public var rawValue: String {
        switch self {
        case NTLM:
            return kSecAttrAuthenticationTypeNTLM
        case MSN:
            return kSecAttrAuthenticationTypeMSN
        case DPA:
            return kSecAttrAuthenticationTypeDPA
        case RPA:
            return kSecAttrAuthenticationTypeRPA
        case HTTPBasic:
            return kSecAttrAuthenticationTypeHTTPBasic
        case HTTPDigest:
            return kSecAttrAuthenticationTypeHTTPDigest
        case HTMLForm:
            return kSecAttrAuthenticationTypeHTMLForm
        case Default:
            return kSecAttrAuthenticationTypeDefault
        }
    }
    
    public var description : String {
        switch self {
        case NTLM:
            return "NTLM"
        case MSN:
            return "MSN"
        case DPA:
            return "DPA"
        case RPA:
            return "RPA"
        case HTTPBasic:
            return "HTTPBasic"
        case HTTPDigest:
            return "HTTPDigest"
        case HTMLForm:
            return "HTMLForm"
        case Default:
            return "Default"
        }
    }
}

public enum Status {
    case Success
    case Unimplemented
    case Param
    case Allocate
    case NotAvailable
    case ReadOnly
    case AuthFailed
    case NoSuchKeychain
    case InvalidKeychain
    case DuplicateKeychain
    case DuplicateCallback
    case InvalidCallback
    case DuplicateItem
    case ItemNotFound
    case BufferTooSmall
    case DataTooLarge
    case NoSuchAttr
    case InvalidItemRef
    case InvalidSearchRef
    case NoSuchClass
    case NoDefaultKeychain
    case InteractionNotAllowed
    case ReadOnlyAttr
    case WrongSecVersion
    case KeySizeNotAllowed
    case NoStorageModule
    case NoCertificateModule
    case NoPolicyModule
    case InteractionRequired
    case DataNotAvailable
    case DataNotModifiable
    case CreateChainFailed
    case InvalidPrefsDomain
    case ACLNotSimple
    case PolicyNotFound
    case InvalidTrustSetting
    case NoAccessForItem
    case InvalidOwnerEdit
    case TrustNotAvailable
    case UnsupportedFormat
    case UnknownFormat
    case KeyIsSensitive
    case MultiplePrivKeys
    case PassphraseRequired
    case InvalidPasswordRef
    case InvalidTrustSettings
    case NoTrustSettings
    case Pkcs12VerifyFailure
    case InvalidCertificate
    case NotSigner
    case PolicyDenied
    case InvalidKey
    case Decode
    case Internal
    case UnsupportedAlgorithm
    case UnsupportedOperation
    case UnsupportedPadding
    case ItemInvalidKey
    case ItemInvalidKeyType
    case ItemInvalidValue
    case ItemClassMissing
    case ItemMatchUnsupported
    case UseItemListUnsupported
    case UseKeychainUnsupported
    case UseKeychainListUnsupported
    case ReturnDataUnsupported
    case ReturnAttributesUnsupported
    case ReturnRefUnsupported
    case ReturnPersitentRefUnsupported
    case ValueRefUnsupported
    case ValuePersistentRefUnsupported
    case ReturnMissingPointer
    case MatchLimitUnsupported
    case ItemIllegalQuery
    case WaitForCallback
    case MissingEntitlement
    case UpgradePending
    case MPSignatureInvalid
    case OTRTooOld
    case OTRIDTooNew
    case ServiceNotAvailable
    case InsufficientClientID
    case DeviceReset
    case DeviceFailed
    case AppleAddAppACLSubject
    case ApplePublicKeyIncomplete
    case AppleSignatureMismatch
    case AppleInvalidKeyStartDate
    case AppleInvalidKeyEndDate
    case ConversionError
    case AppleSSLv2Rollback
    case DiskFull
    case QuotaExceeded
    case FileTooBig
    case InvalidDatabaseBlob
    case InvalidKeyBlob
    case IncompatibleDatabaseBlob
    case IncompatibleKeyBlob
    case HostNameMismatch
    case UnknownCriticalExtensionFlag
    case NoBasicConstraints
    case NoBasicConstraintsCA
    case InvalidAuthorityKeyID
    case InvalidSubjectKeyID
    case InvalidKeyUsageForPolicy
    case InvalidExtendedKeyUsage
    case InvalidIDLinkage
    case PathLengthConstraintExceeded
    case InvalidRoot
    case CRLExpired
    case CRLNotValidYet
    case CRLNotFound
    case CRLServerDown
    case CRLBadURI
    case UnknownCertExtension
    case UnknownCRLExtension
    case CRLNotTrusted
    case CRLPolicyFailed
    case IDPFailure
    case SMIMEEmailAddressesNotFound
    case SMIMEBadExtendedKeyUsage
    case SMIMEBadKeyUsage
    case SMIMEKeyUsageNotCritical
    case SMIMENoEmailAddress
    case SMIMESubjAltNameNotCritical
    case SSLBadExtendedKeyUsage
    case OCSPBadResponse
    case OCSPBadRequest
    case OCSPUnavailable
    case OCSPStatusUnrecognized
    case EndOfData
    case IncompleteCertRevocationCheck
    case NetworkFailure
    case OCSPNotTrustedToAnchor
    case RecordModified
    case OCSPSignatureError
    case OCSPNoSigner
    case OCSPResponderMalformedReq
    case OCSPResponderInternalError
    case OCSPResponderTryLater
    case OCSPResponderSignatureRequired
    case OCSPResponderUnauthorized
    case OCSPResponseNonceMismatch
    case CodeSigningBadCertChainLength
    case CodeSigningNoBasicConstraints
    case CodeSigningBadPathLengthConstraint
    case CodeSigningNoExtendedKeyUsage
    case CodeSigningDevelopment
    case ResourceSignBadCertChainLength
    case ResourceSignBadExtKeyUsage
    case TrustSettingDeny
    case InvalidSubjectName
    case UnknownQualifiedCertStatement
    case MobileMeRequestQueued
    case MobileMeRequestRedirected
    case MobileMeServerError
    case MobileMeServerNotAvailable
    case MobileMeServerAlreadyExists
    case MobileMeServerServiceErr
    case MobileMeRequestAlreadyPending
    case MobileMeNoRequestPending
    case MobileMeCSRVerifyFailure
    case MobileMeFailedConsistencyCheck
    case NotInitialized
    case InvalidHandleUsage
    case PVCReferentNotFound
    case FunctionIntegrityFail
    case InternalError
    case MemoryError
    case InvalidData
    case MDSError
    case InvalidPointer
    case SelfCheckFailed
    case FunctionFailed
    case ModuleManifestVerifyFailed
    case InvalidGUID
    case InvalidHandle
    case InvalidDBList
    case InvalidPassthroughID
    case InvalidNetworkAddress
    case CRLAlreadySigned
    case InvalidNumberOfFields
    case VerificationFailure
    case UnknownTag
    case InvalidSignature
    case InvalidName
    case InvalidCertificateRef
    case InvalidCertificateGroup
    case TagNotFound
    case InvalidQuery
    case InvalidValue
    case CallbackFailed
    case ACLDeleteFailed
    case ACLReplaceFailed
    case ACLAddFailed
    case ACLChangeFailed
    case InvalidAccessCredentials
    case InvalidRecord
    case InvalidACL
    case InvalidSampleValue
    case IncompatibleVersion
    case PrivilegeNotGranted
    case InvalidScope
    case PVCAlreadyConfigured
    case InvalidPVC
    case EMMLoadFailed
    case EMMUnloadFailed
    case AddinLoadFailed
    case InvalidKeyRef
    case InvalidKeyHierarchy
    case AddinUnloadFailed
    case LibraryReferenceNotFound
    case InvalidAddinFunctionTable
    case InvalidServiceMask
    case ModuleNotLoaded
    case InvalidSubServiceID
    case AttributeNotInContext
    case ModuleManagerInitializeFailed
    case ModuleManagerNotFound
    case EventNotificationCallbackNotFound
    case InputLengthError
    case OutputLengthError
    case PrivilegeNotSupported
    case DeviceError
    case AttachHandleBusy
    case NotLoggedIn
    case AlgorithmMismatch
    case KeyUsageIncorrect
    case KeyBlobTypeIncorrect
    case KeyHeaderInconsistent
    case UnsupportedKeyFormat
    case UnsupportedKeySize
    case InvalidKeyUsageMask
    case UnsupportedKeyUsageMask
    case InvalidKeyAttributeMask
    case UnsupportedKeyAttributeMask
    case InvalidKeyLabel
    case UnsupportedKeyLabel
    case InvalidKeyFormat
    case UnsupportedVectorOfBuffers
    case InvalidInputVector
    case InvalidOutputVector
    case InvalidContext
    case InvalidAlgorithm
    case InvalidAttributeKey
    case MissingAttributeKey
    case InvalidAttributeInitVector
    case MissingAttributeInitVector
    case InvalidAttributeSalt
    case MissingAttributeSalt
    case InvalidAttributePadding
    case MissingAttributePadding
    case InvalidAttributeRandom
    case MissingAttributeRandom
    case InvalidAttributeSeed
    case MissingAttributeSeed
    case InvalidAttributePassphrase
    case MissingAttributePassphrase
    case InvalidAttributeKeyLength
    case MissingAttributeKeyLength
    case InvalidAttributeBlockSize
    case MissingAttributeBlockSize
    case InvalidAttributeOutputSize
    case MissingAttributeOutputSize
    case InvalidAttributeRounds
    case MissingAttributeRounds
    case InvalidAlgorithmParms
    case MissingAlgorithmParms
    case InvalidAttributeLabel
    case MissingAttributeLabel
    case InvalidAttributeKeyType
    case MissingAttributeKeyType
    case InvalidAttributeMode
    case MissingAttributeMode
    case InvalidAttributeEffectiveBits
    case MissingAttributeEffectiveBits
    case InvalidAttributeStartDate
    case MissingAttributeStartDate
    case InvalidAttributeEndDate
    case MissingAttributeEndDate
    case InvalidAttributeVersion
    case MissingAttributeVersion
    case InvalidAttributePrime
    case MissingAttributePrime
    case InvalidAttributeBase
    case MissingAttributeBase
    case InvalidAttributeSubprime
    case MissingAttributeSubprime
    case InvalidAttributeIterationCount
    case MissingAttributeIterationCount
    case InvalidAttributeDLDBHandle
    case MissingAttributeDLDBHandle
    case InvalidAttributeAccessCredentials
    case MissingAttributeAccessCredentials
    case InvalidAttributePublicKeyFormat
    case MissingAttributePublicKeyFormat
    case InvalidAttributePrivateKeyFormat
    case MissingAttributePrivateKeyFormat
    case InvalidAttributeSymmetricKeyFormat
    case MissingAttributeSymmetricKeyFormat
    case InvalidAttributeWrappedKeyFormat
    case MissingAttributeWrappedKeyFormat
    case StagedOperationInProgress
    case StagedOperationNotStarted
    case VerifyFailed
    case QuerySizeUnknown
    case BlockSizeMismatch
    case PublicKeyInconsistent
    case DeviceVerifyFailed
    case InvalidLoginName
    case AlreadyLoggedIn
    case InvalidDigestAlgorithm
    case InvalidCRLGroup
    case CertificateCannotOperate
    case CertificateExpired
    case CertificateNotValidYet
    case CertificateRevoked
    case CertificateSuspended
    case InsufficientCredentials
    case InvalidAction
    case InvalidAuthority
    case VerifyActionFailed
    case InvalidCertAuthority
    case InvaldCRLAuthority
    case InvalidCRLEncoding
    case InvalidCRLType
    case InvalidCRL
    case InvalidFormType
    case InvalidID
    case InvalidIdentifier
    case InvalidIndex
    case InvalidPolicyIdentifiers
    case InvalidTimeString
    case InvalidReason
    case InvalidRequestInputs
    case InvalidResponseVector
    case InvalidStopOnPolicy
    case InvalidTuple
    case MultipleValuesUnsupported
    case NotTrusted
    case NoDefaultAuthority
    case RejectedForm
    case RequestLost
    case RequestRejected
    case UnsupportedAddressType
    case UnsupportedService
    case InvalidTupleGroup
    case InvalidBaseACLs
    case InvalidTupleCredendtials
    case InvalidEncoding
    case InvalidValidityPeriod
    case InvalidRequestor
    case RequestDescriptor
    case InvalidBundleInfo
    case InvalidCRLIndex
    case NoFieldValues
    case UnsupportedFieldFormat
    case UnsupportedIndexInfo
    case UnsupportedLocality
    case UnsupportedNumAttributes
    case UnsupportedNumIndexes
    case UnsupportedNumRecordTypes
    case FieldSpecifiedMultiple
    case IncompatibleFieldFormat
    case InvalidParsingModule
    case DatabaseLocked
    case DatastoreIsOpen
    case MissingValue
    case UnsupportedQueryLimits
    case UnsupportedNumSelectionPreds
    case UnsupportedOperator
    case InvalidDBLocation
    case InvalidAccessRequest
    case InvalidIndexInfo
    case InvalidNewOwner
    case InvalidModifyMode
    case UnknownError
}

extension Status : RawRepresentable, Printable {
    public static let allValues: [Status] = [
        Success,
        Unimplemented,
        Param,
        Allocate,
        NotAvailable,
        ReadOnly,
        AuthFailed,
        NoSuchKeychain,
        InvalidKeychain,
        DuplicateKeychain,
        DuplicateCallback,
        InvalidCallback,
        DuplicateItem,
        ItemNotFound,
        BufferTooSmall,
        DataTooLarge,
        NoSuchAttr,
        InvalidItemRef,
        InvalidSearchRef,
        NoSuchClass,
        NoDefaultKeychain,
        InteractionNotAllowed,
        ReadOnlyAttr,
        WrongSecVersion,
        KeySizeNotAllowed,
        NoStorageModule,
        NoCertificateModule,
        NoPolicyModule,
        InteractionRequired,
        DataNotAvailable,
        DataNotModifiable,
        CreateChainFailed,
        InvalidPrefsDomain,
        ACLNotSimple,
        PolicyNotFound,
        InvalidTrustSetting,
        NoAccessForItem,
        InvalidOwnerEdit,
        TrustNotAvailable,
        UnsupportedFormat,
        UnknownFormat,
        KeyIsSensitive,
        MultiplePrivKeys,
        PassphraseRequired,
        InvalidPasswordRef,
        InvalidTrustSettings,
        NoTrustSettings,
        Pkcs12VerifyFailure,
        InvalidCertificate,
        NotSigner,
        PolicyDenied,
        InvalidKey,
        Decode,
        Internal,
        UnsupportedAlgorithm,
        UnsupportedOperation,
        UnsupportedPadding,
        ItemInvalidKey,
        ItemInvalidKeyType,
        ItemInvalidValue,
        ItemClassMissing,
        ItemMatchUnsupported,
        UseItemListUnsupported,
        UseKeychainUnsupported,
        UseKeychainListUnsupported,
        ReturnDataUnsupported,
        ReturnAttributesUnsupported,
        ReturnRefUnsupported,
        ReturnPersitentRefUnsupported,
        ValueRefUnsupported,
        ValuePersistentRefUnsupported,
        ReturnMissingPointer,
        MatchLimitUnsupported,
        ItemIllegalQuery,
        WaitForCallback,
        MissingEntitlement,
        UpgradePending,
        MPSignatureInvalid,
        OTRTooOld,
        OTRIDTooNew,
        ServiceNotAvailable,
        InsufficientClientID,
        DeviceReset,
        DeviceFailed,
        AppleAddAppACLSubject,
        ApplePublicKeyIncomplete,
        AppleSignatureMismatch,
        AppleInvalidKeyStartDate,
        AppleInvalidKeyEndDate,
        ConversionError,
        AppleSSLv2Rollback,
        DiskFull,
        QuotaExceeded,
        FileTooBig,
        InvalidDatabaseBlob,
        InvalidKeyBlob,
        IncompatibleDatabaseBlob,
        IncompatibleKeyBlob,
        HostNameMismatch,
        UnknownCriticalExtensionFlag,
        NoBasicConstraints,
        NoBasicConstraintsCA,
        InvalidAuthorityKeyID,
        InvalidSubjectKeyID,
        InvalidKeyUsageForPolicy,
        InvalidExtendedKeyUsage,
        InvalidIDLinkage,
        PathLengthConstraintExceeded,
        InvalidRoot,
        CRLExpired,
        CRLNotValidYet,
        CRLNotFound,
        CRLServerDown,
        CRLBadURI,
        UnknownCertExtension,
        UnknownCRLExtension,
        CRLNotTrusted,
        CRLPolicyFailed,
        IDPFailure,
        SMIMEEmailAddressesNotFound,
        SMIMEBadExtendedKeyUsage,
        SMIMEBadKeyUsage,
        SMIMEKeyUsageNotCritical,
        SMIMENoEmailAddress,
        SMIMESubjAltNameNotCritical,
        SSLBadExtendedKeyUsage,
        OCSPBadResponse,
        OCSPBadRequest,
        OCSPUnavailable,
        OCSPStatusUnrecognized,
        EndOfData,
        IncompleteCertRevocationCheck,
        NetworkFailure,
        OCSPNotTrustedToAnchor,
        RecordModified,
        OCSPSignatureError,
        OCSPNoSigner,
        OCSPResponderMalformedReq,
        OCSPResponderInternalError,
        OCSPResponderTryLater,
        OCSPResponderSignatureRequired,
        OCSPResponderUnauthorized,
        OCSPResponseNonceMismatch,
        CodeSigningBadCertChainLength,
        CodeSigningNoBasicConstraints,
        CodeSigningBadPathLengthConstraint,
        CodeSigningNoExtendedKeyUsage,
        CodeSigningDevelopment,
        ResourceSignBadCertChainLength,
        ResourceSignBadExtKeyUsage,
        TrustSettingDeny,
        InvalidSubjectName,
        UnknownQualifiedCertStatement,
        MobileMeRequestQueued,
        MobileMeRequestRedirected,
        MobileMeServerError,
        MobileMeServerNotAvailable,
        MobileMeServerAlreadyExists,
        MobileMeServerServiceErr,
        MobileMeRequestAlreadyPending,
        MobileMeNoRequestPending,
        MobileMeCSRVerifyFailure,
        MobileMeFailedConsistencyCheck,
        NotInitialized,
        InvalidHandleUsage,
        PVCReferentNotFound,
        FunctionIntegrityFail,
        InternalError,
        MemoryError,
        InvalidData,
        MDSError,
        InvalidPointer,
        SelfCheckFailed,
        FunctionFailed,
        ModuleManifestVerifyFailed,
        InvalidGUID,
        InvalidHandle,
        InvalidDBList,
        InvalidPassthroughID,
        InvalidNetworkAddress,
        CRLAlreadySigned,
        InvalidNumberOfFields,
        VerificationFailure,
        UnknownTag,
        InvalidSignature,
        InvalidName,
        InvalidCertificateRef,
        InvalidCertificateGroup,
        TagNotFound,
        InvalidQuery,
        InvalidValue,
        CallbackFailed,
        ACLDeleteFailed,
        ACLReplaceFailed,
        ACLAddFailed,
        ACLChangeFailed,
        InvalidAccessCredentials,
        InvalidRecord,
        InvalidACL,
        InvalidSampleValue,
        IncompatibleVersion,
        PrivilegeNotGranted,
        InvalidScope,
        PVCAlreadyConfigured,
        InvalidPVC,
        EMMLoadFailed,
        EMMUnloadFailed,
        AddinLoadFailed,
        InvalidKeyRef,
        InvalidKeyHierarchy,
        AddinUnloadFailed,
        LibraryReferenceNotFound,
        InvalidAddinFunctionTable,
        InvalidServiceMask,
        ModuleNotLoaded,
        InvalidSubServiceID,
        AttributeNotInContext,
        ModuleManagerInitializeFailed,
        ModuleManagerNotFound,
        EventNotificationCallbackNotFound,
        InputLengthError,
        OutputLengthError,
        PrivilegeNotSupported,
        DeviceError,
        AttachHandleBusy,
        NotLoggedIn,
        AlgorithmMismatch,
        KeyUsageIncorrect,
        KeyBlobTypeIncorrect,
        KeyHeaderInconsistent,
        UnsupportedKeyFormat,
        UnsupportedKeySize,
        InvalidKeyUsageMask,
        UnsupportedKeyUsageMask,
        InvalidKeyAttributeMask,
        UnsupportedKeyAttributeMask,
        InvalidKeyLabel,
        UnsupportedKeyLabel,
        InvalidKeyFormat,
        UnsupportedVectorOfBuffers,
        InvalidInputVector,
        InvalidOutputVector,
        InvalidContext,
        InvalidAlgorithm,
        InvalidAttributeKey,
        MissingAttributeKey,
        InvalidAttributeInitVector,
        MissingAttributeInitVector,
        InvalidAttributeSalt,
        MissingAttributeSalt,
        InvalidAttributePadding,
        MissingAttributePadding,
        InvalidAttributeRandom,
        MissingAttributeRandom,
        InvalidAttributeSeed,
        MissingAttributeSeed,
        InvalidAttributePassphrase,
        MissingAttributePassphrase,
        InvalidAttributeKeyLength,
        MissingAttributeKeyLength,
        InvalidAttributeBlockSize,
        MissingAttributeBlockSize,
        InvalidAttributeOutputSize,
        MissingAttributeOutputSize,
        InvalidAttributeRounds,
        MissingAttributeRounds,
        InvalidAlgorithmParms,
        MissingAlgorithmParms,
        InvalidAttributeLabel,
        MissingAttributeLabel,
        InvalidAttributeKeyType,
        MissingAttributeKeyType,
        InvalidAttributeMode,
        MissingAttributeMode,
        InvalidAttributeEffectiveBits,
        MissingAttributeEffectiveBits,
        InvalidAttributeStartDate,
        MissingAttributeStartDate,
        InvalidAttributeEndDate,
        MissingAttributeEndDate,
        InvalidAttributeVersion,
        MissingAttributeVersion,
        InvalidAttributePrime,
        MissingAttributePrime,
        InvalidAttributeBase,
        MissingAttributeBase,
        InvalidAttributeSubprime,
        MissingAttributeSubprime,
        InvalidAttributeIterationCount,
        MissingAttributeIterationCount,
        InvalidAttributeDLDBHandle,
        MissingAttributeDLDBHandle,
        InvalidAttributeAccessCredentials,
        MissingAttributeAccessCredentials,
        InvalidAttributePublicKeyFormat,
        MissingAttributePublicKeyFormat,
        InvalidAttributePrivateKeyFormat,
        MissingAttributePrivateKeyFormat,
        InvalidAttributeSymmetricKeyFormat,
        MissingAttributeSymmetricKeyFormat,
        InvalidAttributeWrappedKeyFormat,
        MissingAttributeWrappedKeyFormat,
        StagedOperationInProgress,
        StagedOperationNotStarted,
        VerifyFailed,
        QuerySizeUnknown,
        BlockSizeMismatch,
        PublicKeyInconsistent,
        DeviceVerifyFailed,
        InvalidLoginName,
        AlreadyLoggedIn,
        InvalidDigestAlgorithm,
        InvalidCRLGroup,
        CertificateCannotOperate,
        CertificateExpired,
        CertificateNotValidYet,
        CertificateRevoked,
        CertificateSuspended,
        InsufficientCredentials,
        InvalidAction,
        InvalidAuthority,
        VerifyActionFailed,
        InvalidCertAuthority,
        InvaldCRLAuthority,
        InvalidCRLEncoding,
        InvalidCRLType,
        InvalidCRL,
        InvalidFormType,
        InvalidID,
        InvalidIdentifier,
        InvalidIndex,
        InvalidPolicyIdentifiers,
        InvalidTimeString,
        InvalidReason,
        InvalidRequestInputs,
        InvalidResponseVector,
        InvalidStopOnPolicy,
        InvalidTuple,
        MultipleValuesUnsupported,
        NotTrusted,
        NoDefaultAuthority,
        RejectedForm,
        RequestLost,
        RequestRejected,
        UnsupportedAddressType,
        UnsupportedService,
        InvalidTupleGroup,
        InvalidBaseACLs,
        InvalidTupleCredendtials,
        InvalidEncoding,
        InvalidValidityPeriod,
        InvalidRequestor,
        RequestDescriptor,
        InvalidBundleInfo,
        InvalidCRLIndex,
        NoFieldValues,
        UnsupportedFieldFormat,
        UnsupportedIndexInfo,
        UnsupportedLocality,
        UnsupportedNumAttributes,
        UnsupportedNumIndexes,
        UnsupportedNumRecordTypes,
        FieldSpecifiedMultiple,
        IncompatibleFieldFormat,
        InvalidParsingModule,
        DatabaseLocked,
        DatastoreIsOpen,
        MissingValue,
        UnsupportedQueryLimits,
        UnsupportedNumSelectionPreds,
        UnsupportedOperator,
        InvalidDBLocation,
        InvalidAccessRequest,
        InvalidIndexInfo,
        InvalidNewOwner,
        InvalidModifyMode,
        UnknownError,
    ]
    
    public init(rawValue: Int32) {
        if rawValue == 0 {
            self = Success
        } else if rawValue == -4 {
            self = Unimplemented
        } else if rawValue == -50 {
            self = Param
        } else if rawValue == -108 {
            self = Allocate
        } else if rawValue == -25291 {
            self = NotAvailable
        } else if rawValue == -25292 {
            self = ReadOnly
        } else if rawValue == -25293 {
            self = AuthFailed
        } else if rawValue == -25294 {
            self = NoSuchKeychain
        } else if rawValue == -25295 {
            self = InvalidKeychain
        } else if rawValue == -25296 {
            self = DuplicateKeychain
        } else if rawValue == -25297 {
            self = DuplicateCallback
        } else if rawValue == -25298 {
            self = InvalidCallback
        } else if rawValue == -25299 {
            self = DuplicateItem
        } else if rawValue == -25300 {
            self = ItemNotFound
        } else if rawValue == -25301 {
            self = BufferTooSmall
        } else if rawValue == -25302 {
            self = DataTooLarge
        } else if rawValue == -25303 {
            self = NoSuchAttr
        } else if rawValue == -25304 {
            self = InvalidItemRef
        } else if rawValue == -25305 {
            self = InvalidSearchRef
        } else if rawValue == -25306 {
            self = NoSuchClass
        } else if rawValue == -25307 {
            self = NoDefaultKeychain
        } else if rawValue == -25308 {
            self = InteractionNotAllowed
        } else if rawValue == -25309 {
            self = ReadOnlyAttr
        } else if rawValue == -25310 {
            self = WrongSecVersion
        } else if rawValue == -25311 {
            self = KeySizeNotAllowed
        } else if rawValue == -25312 {
            self = NoStorageModule
        } else if rawValue == -25313 {
            self = NoCertificateModule
        } else if rawValue == -25314 {
            self = NoPolicyModule
        } else if rawValue == -25315 {
            self = InteractionRequired
        } else if rawValue == -25316 {
            self = DataNotAvailable
        } else if rawValue == -25317 {
            self = DataNotModifiable
        } else if rawValue == -25318 {
            self = CreateChainFailed
        } else if rawValue == -25319 {
            self = InvalidPrefsDomain
        } else if rawValue == -25240 {
            self = ACLNotSimple
        } else if rawValue == -25241 {
            self = PolicyNotFound
        } else if rawValue == -25242 {
            self = InvalidTrustSetting
        } else if rawValue == -25243 {
            self = NoAccessForItem
        } else if rawValue == -25244 {
            self = InvalidOwnerEdit
        } else if rawValue == -25245 {
            self = TrustNotAvailable
        } else if rawValue == -25256 {
            self = UnsupportedFormat
        } else if rawValue == -25257 {
            self = UnknownFormat
        } else if rawValue == -25258 {
            self = KeyIsSensitive
        } else if rawValue == -25259 {
            self = MultiplePrivKeys
        } else if rawValue == -25260 {
            self = PassphraseRequired
        } else if rawValue == -25261 {
            self = InvalidPasswordRef
        } else if rawValue == -25262 {
            self = InvalidTrustSettings
        } else if rawValue == -25263 {
            self = NoTrustSettings
        } else if rawValue == -25264 {
            self = Pkcs12VerifyFailure
        } else if rawValue == -26265 {
            self = InvalidCertificate
        } else if rawValue == -26267 {
            self = NotSigner
        } else if rawValue == -26270 {
            self = PolicyDenied
        } else if rawValue == -26274 {
            self = InvalidKey
        } else if rawValue == -26275 {
            self = Decode
        } else if rawValue == -26276 {
            self = Internal
        } else if rawValue == -26268 {
            self = UnsupportedAlgorithm
        } else if rawValue == -26271 {
            self = UnsupportedOperation
        } else if rawValue == -26273 {
            self = UnsupportedPadding
        } else if rawValue == -34000 {
            self = ItemInvalidKey
        } else if rawValue == -34001 {
            self = ItemInvalidKeyType
        } else if rawValue == -34002 {
            self = ItemInvalidValue
        } else if rawValue == -34003 {
            self = ItemClassMissing
        } else if rawValue == -34004 {
            self = ItemMatchUnsupported
        } else if rawValue == -34005 {
            self = UseItemListUnsupported
        } else if rawValue == -34006 {
            self = UseKeychainUnsupported
        } else if rawValue == -34007 {
            self = UseKeychainListUnsupported
        } else if rawValue == -34008 {
            self = ReturnDataUnsupported
        } else if rawValue == -34009 {
            self = ReturnAttributesUnsupported
        } else if rawValue == -34010 {
            self = ReturnRefUnsupported
        } else if rawValue == -34010 {
            self = ReturnPersitentRefUnsupported
        } else if rawValue == -34012 {
            self = ValueRefUnsupported
        } else if rawValue == -34013 {
            self = ValuePersistentRefUnsupported
        } else if rawValue == -34014 {
            self = ReturnMissingPointer
        } else if rawValue == -34015 {
            self = MatchLimitUnsupported
        } else if rawValue == -34016 {
            self = ItemIllegalQuery
        } else if rawValue == -34017 {
            self = WaitForCallback
        } else if rawValue == -34018 {
            self = MissingEntitlement
        } else if rawValue == -34019 {
            self = UpgradePending
        } else if rawValue == -25327 {
            self = MPSignatureInvalid
        } else if rawValue == -25328 {
            self = OTRTooOld
        } else if rawValue == -25329 {
            self = OTRIDTooNew
        } else if rawValue == -67585 {
            self = ServiceNotAvailable
        } else if rawValue == -67586 {
            self = InsufficientClientID
        } else if rawValue == -67587 {
            self = DeviceReset
        } else if rawValue == -67588 {
            self = DeviceFailed
        } else if rawValue == -67589 {
            self = AppleAddAppACLSubject
        } else if rawValue == -67590 {
            self = ApplePublicKeyIncomplete
        } else if rawValue == -67591 {
            self = AppleSignatureMismatch
        } else if rawValue == -67592 {
            self = AppleInvalidKeyStartDate
        } else if rawValue == -67593 {
            self = AppleInvalidKeyEndDate
        } else if rawValue == -67594 {
            self = ConversionError
        } else if rawValue == -67595 {
            self = AppleSSLv2Rollback
        } else if rawValue == -34 {
            self = DiskFull
        } else if rawValue == -67596 {
            self = QuotaExceeded
        } else if rawValue == -67597 {
            self = FileTooBig
        } else if rawValue == -67598 {
            self = InvalidDatabaseBlob
        } else if rawValue == -67599 {
            self = InvalidKeyBlob
        } else if rawValue == -67600 {
            self = IncompatibleDatabaseBlob
        } else if rawValue == -67601 {
            self = IncompatibleKeyBlob
        } else if rawValue == -67602 {
            self = HostNameMismatch
        } else if rawValue == -67603 {
            self = UnknownCriticalExtensionFlag
        } else if rawValue == -67604 {
            self = NoBasicConstraints
        } else if rawValue == -67605 {
            self = NoBasicConstraintsCA
        } else if rawValue == -67606 {
            self = InvalidAuthorityKeyID
        } else if rawValue == -67607 {
            self = InvalidSubjectKeyID
        } else if rawValue == -67608 {
            self = InvalidKeyUsageForPolicy
        } else if rawValue == -67609 {
            self = InvalidExtendedKeyUsage
        } else if rawValue == -67610 {
            self = InvalidIDLinkage
        } else if rawValue == -67611 {
            self = PathLengthConstraintExceeded
        } else if rawValue == -67612 {
            self = InvalidRoot
        } else if rawValue == -67613 {
            self = CRLExpired
        } else if rawValue == -67614 {
            self = CRLNotValidYet
        } else if rawValue == -67615 {
            self = CRLNotFound
        } else if rawValue == -67616 {
            self = CRLServerDown
        } else if rawValue == -67617 {
            self = CRLBadURI
        } else if rawValue == -67618 {
            self = UnknownCertExtension
        } else if rawValue == -67619 {
            self = UnknownCRLExtension
        } else if rawValue == -67620 {
            self = CRLNotTrusted
        } else if rawValue == -67621 {
            self = CRLPolicyFailed
        } else if rawValue == -67622 {
            self = IDPFailure
        } else if rawValue == -67623 {
            self = SMIMEEmailAddressesNotFound
        } else if rawValue == -67624 {
            self = SMIMEBadExtendedKeyUsage
        } else if rawValue == -67625 {
            self = SMIMEBadKeyUsage
        } else if rawValue == -67626 {
            self = SMIMEKeyUsageNotCritical
        } else if rawValue == -67627 {
            self = SMIMENoEmailAddress
        } else if rawValue == -67628 {
            self = SMIMESubjAltNameNotCritical
        } else if rawValue == -67629 {
            self = SSLBadExtendedKeyUsage
        } else if rawValue == -67630 {
            self = OCSPBadResponse
        } else if rawValue == -67631 {
            self = OCSPBadRequest
        } else if rawValue == -67632 {
            self = OCSPUnavailable
        } else if rawValue == -67633 {
            self = OCSPStatusUnrecognized
        } else if rawValue == -67634 {
            self = EndOfData
        } else if rawValue == -67635 {
            self = IncompleteCertRevocationCheck
        } else if rawValue == -67636 {
            self = NetworkFailure
        } else if rawValue == -67637 {
            self = OCSPNotTrustedToAnchor
        } else if rawValue == -67638 {
            self = RecordModified
        } else if rawValue == -67639 {
            self = OCSPSignatureError
        } else if rawValue == -67640 {
            self = OCSPNoSigner
        } else if rawValue == -67641 {
            self = OCSPResponderMalformedReq
        } else if rawValue == -67642 {
            self = OCSPResponderInternalError
        } else if rawValue == -67643 {
            self = OCSPResponderTryLater
        } else if rawValue == -67644 {
            self = OCSPResponderSignatureRequired
        } else if rawValue == -67645 {
            self = OCSPResponderUnauthorized
        } else if rawValue == -67646 {
            self = OCSPResponseNonceMismatch
        } else if rawValue == -67647 {
            self = CodeSigningBadCertChainLength
        } else if rawValue == -67648 {
            self = CodeSigningNoBasicConstraints
        } else if rawValue == -67649 {
            self = CodeSigningBadPathLengthConstraint
        } else if rawValue == -67650 {
            self = CodeSigningNoExtendedKeyUsage
        } else if rawValue == -67651 {
            self = CodeSigningDevelopment
        } else if rawValue == -67652 {
            self = ResourceSignBadCertChainLength
        } else if rawValue == -67653 {
            self = ResourceSignBadExtKeyUsage
        } else if rawValue == -67654 {
            self = TrustSettingDeny
        } else if rawValue == -67655 {
            self = InvalidSubjectName
        } else if rawValue == -67656 {
            self = UnknownQualifiedCertStatement
        } else if rawValue == -67657 {
            self = MobileMeRequestQueued
        } else if rawValue == -67658 {
            self = MobileMeRequestRedirected
        } else if rawValue == -67659 {
            self = MobileMeServerError
        } else if rawValue == -67660 {
            self = MobileMeServerNotAvailable
        } else if rawValue == -67661 {
            self = MobileMeServerAlreadyExists
        } else if rawValue == -67662 {
            self = MobileMeServerServiceErr
        } else if rawValue == -67663 {
            self = MobileMeRequestAlreadyPending
        } else if rawValue == -67664 {
            self = MobileMeNoRequestPending
        } else if rawValue == -67665 {
            self = MobileMeCSRVerifyFailure
        } else if rawValue == -67666 {
            self = MobileMeFailedConsistencyCheck
        } else if rawValue == -67667 {
            self = NotInitialized
        } else if rawValue == -67668 {
            self = InvalidHandleUsage
        } else if rawValue == -67669 {
            self = PVCReferentNotFound
        } else if rawValue == -67670 {
            self = FunctionIntegrityFail
        } else if rawValue == -67671 {
            self = InternalError
        } else if rawValue == -67672 {
            self = MemoryError
        } else if rawValue == -67673 {
            self = InvalidData
        } else if rawValue == -67674 {
            self = MDSError
        } else if rawValue == -67675 {
            self = InvalidPointer
        } else if rawValue == -67676 {
            self = SelfCheckFailed
        } else if rawValue == -67677 {
            self = FunctionFailed
        } else if rawValue == -67678 {
            self = ModuleManifestVerifyFailed
        } else if rawValue == -67679 {
            self = InvalidGUID
        } else if rawValue == -67680 {
            self = InvalidHandle
        } else if rawValue == -67681 {
            self = InvalidDBList
        } else if rawValue == -67682 {
            self = InvalidPassthroughID
        } else if rawValue == -67683 {
            self = InvalidNetworkAddress
        } else if rawValue == -67684 {
            self = CRLAlreadySigned
        } else if rawValue == -67685 {
            self = InvalidNumberOfFields
        } else if rawValue == -67686 {
            self = VerificationFailure
        } else if rawValue == -67687 {
            self = UnknownTag
        } else if rawValue == -67688 {
            self = InvalidSignature
        } else if rawValue == -67689 {
            self = InvalidName
        } else if rawValue == -67690 {
            self = InvalidCertificateRef
        } else if rawValue == -67691 {
            self = InvalidCertificateGroup
        } else if rawValue == -67692 {
            self = TagNotFound
        } else if rawValue == -67693 {
            self = InvalidQuery
        } else if rawValue == -67694 {
            self = InvalidValue
        } else if rawValue == -67695 {
            self = CallbackFailed
        } else if rawValue == -67696 {
            self = ACLDeleteFailed
        } else if rawValue == -67697 {
            self = ACLReplaceFailed
        } else if rawValue == -67698 {
            self = ACLAddFailed
        } else if rawValue == -67699 {
            self = ACLChangeFailed
        } else if rawValue == -67700 {
            self = InvalidAccessCredentials
        } else if rawValue == -67701 {
            self = InvalidRecord
        } else if rawValue == -67702 {
            self = InvalidACL
        } else if rawValue == -67703 {
            self = InvalidSampleValue
        } else if rawValue == -67704 {
            self = IncompatibleVersion
        } else if rawValue == -67705 {
            self = PrivilegeNotGranted
        } else if rawValue == -67706 {
            self = InvalidScope
        } else if rawValue == -67707 {
            self = PVCAlreadyConfigured
        } else if rawValue == -67708 {
            self = InvalidPVC
        } else if rawValue == -67709 {
            self = EMMLoadFailed
        } else if rawValue == -67710 {
            self = EMMUnloadFailed
        } else if rawValue == -67711 {
            self = AddinLoadFailed
        } else if rawValue == -67712 {
            self = InvalidKeyRef
        } else if rawValue == -67713 {
            self = InvalidKeyHierarchy
        } else if rawValue == -67714 {
            self = AddinUnloadFailed
        } else if rawValue == -67715 {
            self = LibraryReferenceNotFound
        } else if rawValue == -67716 {
            self = InvalidAddinFunctionTable
        } else if rawValue == -67717 {
            self = InvalidServiceMask
        } else if rawValue == -67718 {
            self = ModuleNotLoaded
        } else if rawValue == -67719 {
            self = InvalidSubServiceID
        } else if rawValue == -67720 {
            self = AttributeNotInContext
        } else if rawValue == -67721 {
            self = ModuleManagerInitializeFailed
        } else if rawValue == -67722 {
            self = ModuleManagerNotFound
        } else if rawValue == -67723 {
            self = EventNotificationCallbackNotFound
        } else if rawValue == -67724 {
            self = InputLengthError
        } else if rawValue == -67725 {
            self = OutputLengthError
        } else if rawValue == -67726 {
            self = PrivilegeNotSupported
        } else if rawValue == -67727 {
            self = DeviceError
        } else if rawValue == -67728 {
            self = AttachHandleBusy
        } else if rawValue == -67729 {
            self = NotLoggedIn
        } else if rawValue == -67730 {
            self = AlgorithmMismatch
        } else if rawValue == -67731 {
            self = KeyUsageIncorrect
        } else if rawValue == -67732 {
            self = KeyBlobTypeIncorrect
        } else if rawValue == -67733 {
            self = KeyHeaderInconsistent
        } else if rawValue == -67734 {
            self = UnsupportedKeyFormat
        } else if rawValue == -67735 {
            self = UnsupportedKeySize
        } else if rawValue == -67736 {
            self = InvalidKeyUsageMask
        } else if rawValue == -67737 {
            self = UnsupportedKeyUsageMask
        } else if rawValue == -67738 {
            self = InvalidKeyAttributeMask
        } else if rawValue == -67739 {
            self = UnsupportedKeyAttributeMask
        } else if rawValue == -67740 {
            self = InvalidKeyLabel
        } else if rawValue == -67741 {
            self = UnsupportedKeyLabel
        } else if rawValue == -67742 {
            self = InvalidKeyFormat
        } else if rawValue == -67743 {
            self = UnsupportedVectorOfBuffers
        } else if rawValue == -67744 {
            self = InvalidInputVector
        } else if rawValue == -67745 {
            self = InvalidOutputVector
        } else if rawValue == -67746 {
            self = InvalidContext
        } else if rawValue == -67747 {
            self = InvalidAlgorithm
        } else if rawValue == -67748 {
            self = InvalidAttributeKey
        } else if rawValue == -67749 {
            self = MissingAttributeKey
        } else if rawValue == -67750 {
            self = InvalidAttributeInitVector
        } else if rawValue == -67751 {
            self = MissingAttributeInitVector
        } else if rawValue == -67752 {
            self = InvalidAttributeSalt
        } else if rawValue == -67753 {
            self = MissingAttributeSalt
        } else if rawValue == -67754 {
            self = InvalidAttributePadding
        } else if rawValue == -67755 {
            self = MissingAttributePadding
        } else if rawValue == -67756 {
            self = InvalidAttributeRandom
        } else if rawValue == -67757 {
            self = MissingAttributeRandom
        } else if rawValue == -67758 {
            self = InvalidAttributeSeed
        } else if rawValue == -67759 {
            self = MissingAttributeSeed
        } else if rawValue == -67760 {
            self = InvalidAttributePassphrase
        } else if rawValue == -67761 {
            self = MissingAttributePassphrase
        } else if rawValue == -67762 {
            self = InvalidAttributeKeyLength
        } else if rawValue == -67763 {
            self = MissingAttributeKeyLength
        } else if rawValue == -67764 {
            self = InvalidAttributeBlockSize
        } else if rawValue == -67765 {
            self = MissingAttributeBlockSize
        } else if rawValue == -67766 {
            self = InvalidAttributeOutputSize
        } else if rawValue == -67767 {
            self = MissingAttributeOutputSize
        } else if rawValue == -67768 {
            self = InvalidAttributeRounds
        } else if rawValue == -67769 {
            self = MissingAttributeRounds
        } else if rawValue == -67770 {
            self = InvalidAlgorithmParms
        } else if rawValue == -67771 {
            self = MissingAlgorithmParms
        } else if rawValue == -67772 {
            self = InvalidAttributeLabel
        } else if rawValue == -67773 {
            self = MissingAttributeLabel
        } else if rawValue == -67774 {
            self = InvalidAttributeKeyType
        } else if rawValue == -67775 {
            self = MissingAttributeKeyType
        } else if rawValue == -67776 {
            self = InvalidAttributeMode
        } else if rawValue == -67777 {
            self = MissingAttributeMode
        } else if rawValue == -67778 {
            self = InvalidAttributeEffectiveBits
        } else if rawValue == -67779 {
            self = MissingAttributeEffectiveBits
        } else if rawValue == -67780 {
            self = InvalidAttributeStartDate
        } else if rawValue == -67781 {
            self = MissingAttributeStartDate
        } else if rawValue == -67782 {
            self = InvalidAttributeEndDate
        } else if rawValue == -67783 {
            self = MissingAttributeEndDate
        } else if rawValue == -67784 {
            self = InvalidAttributeVersion
        } else if rawValue == -67785 {
            self = MissingAttributeVersion
        } else if rawValue == -67786 {
            self = InvalidAttributePrime
        } else if rawValue == -67787 {
            self = MissingAttributePrime
        } else if rawValue == -67788 {
            self = InvalidAttributeBase
        } else if rawValue == -67789 {
            self = MissingAttributeBase
        } else if rawValue == -67790 {
            self = InvalidAttributeSubprime
        } else if rawValue == -67791 {
            self = MissingAttributeSubprime
        } else if rawValue == -67792 {
            self = InvalidAttributeIterationCount
        } else if rawValue == -67793 {
            self = MissingAttributeIterationCount
        } else if rawValue == -67794 {
            self = InvalidAttributeDLDBHandle
        } else if rawValue == -67795 {
            self = MissingAttributeDLDBHandle
        } else if rawValue == -67796 {
            self = InvalidAttributeAccessCredentials
        } else if rawValue == -67797 {
            self = MissingAttributeAccessCredentials
        } else if rawValue == -67798 {
            self = InvalidAttributePublicKeyFormat
        } else if rawValue == -67799 {
            self = MissingAttributePublicKeyFormat
        } else if rawValue == -67800 {
            self = InvalidAttributePrivateKeyFormat
        } else if rawValue == -67801 {
            self = MissingAttributePrivateKeyFormat
        } else if rawValue == -67802 {
            self = InvalidAttributeSymmetricKeyFormat
        } else if rawValue == -67803 {
            self = MissingAttributeSymmetricKeyFormat
        } else if rawValue == -67804 {
            self = InvalidAttributeWrappedKeyFormat
        } else if rawValue == -67805 {
            self = MissingAttributeWrappedKeyFormat
        } else if rawValue == -67806 {
            self = StagedOperationInProgress
        } else if rawValue == -67807 {
            self = StagedOperationNotStarted
        } else if rawValue == -67808 {
            self = VerifyFailed
        } else if rawValue == -67809 {
            self = QuerySizeUnknown
        } else if rawValue == -67810 {
            self = BlockSizeMismatch
        } else if rawValue == -67811 {
            self = PublicKeyInconsistent
        } else if rawValue == -67812 {
            self = DeviceVerifyFailed
        } else if rawValue == -67813 {
            self = InvalidLoginName
        } else if rawValue == -67814 {
            self = AlreadyLoggedIn
        } else if rawValue == -67815 {
            self = InvalidDigestAlgorithm
        } else if rawValue == -67816 {
            self = InvalidCRLGroup
        } else if rawValue == -67817 {
            self = CertificateCannotOperate
        } else if rawValue == -67818 {
            self = CertificateExpired
        } else if rawValue == -67819 {
            self = CertificateNotValidYet
        } else if rawValue == -67820 {
            self = CertificateRevoked
        } else if rawValue == -67821 {
            self = CertificateSuspended
        } else if rawValue == -67822 {
            self = InsufficientCredentials
        } else if rawValue == -67823 {
            self = InvalidAction
        } else if rawValue == -67824 {
            self = InvalidAuthority
        } else if rawValue == -67825 {
            self = VerifyActionFailed
        } else if rawValue == -67826 {
            self = InvalidCertAuthority
        } else if rawValue == -67827 {
            self = InvaldCRLAuthority
        } else if rawValue == -67828 {
            self = InvalidCRLEncoding
        } else if rawValue == -67829 {
            self = InvalidCRLType
        } else if rawValue == -67830 {
            self = InvalidCRL
        } else if rawValue == -67831 {
            self = InvalidFormType
        } else if rawValue == -67832 {
            self = InvalidID
        } else if rawValue == -67833 {
            self = InvalidIdentifier
        } else if rawValue == -67834 {
            self = InvalidIndex
        } else if rawValue == -67835 {
            self = InvalidPolicyIdentifiers
        } else if rawValue == -67836 {
            self = InvalidTimeString
        } else if rawValue == -67837 {
            self = InvalidReason
        } else if rawValue == -67838 {
            self = InvalidRequestInputs
        } else if rawValue == -67839 {
            self = InvalidResponseVector
        } else if rawValue == -67840 {
            self = InvalidStopOnPolicy
        } else if rawValue == -67841 {
            self = InvalidTuple
        } else if rawValue == -67842 {
            self = MultipleValuesUnsupported
        } else if rawValue == -67843 {
            self = NotTrusted
        } else if rawValue == -67844 {
            self = NoDefaultAuthority
        } else if rawValue == -67845 {
            self = RejectedForm
        } else if rawValue == -67846 {
            self = RequestLost
        } else if rawValue == -67847 {
            self = RequestRejected
        } else if rawValue == -67848 {
            self = UnsupportedAddressType
        } else if rawValue == -67849 {
            self = UnsupportedService
        } else if rawValue == -67850 {
            self = InvalidTupleGroup
        } else if rawValue == -67851 {
            self = InvalidBaseACLs
        } else if rawValue == -67852 {
            self = InvalidTupleCredendtials
        } else if rawValue == -67853 {
            self = InvalidEncoding
        } else if rawValue == -67854 {
            self = InvalidValidityPeriod
        } else if rawValue == -67855 {
            self = InvalidRequestor
        } else if rawValue == -67856 {
            self = RequestDescriptor
        } else if rawValue == -67857 {
            self = InvalidBundleInfo
        } else if rawValue == -67858 {
            self = InvalidCRLIndex
        } else if rawValue == -67859 {
            self = NoFieldValues
        } else if rawValue == -67860 {
            self = UnsupportedFieldFormat
        } else if rawValue == -67861 {
            self = UnsupportedIndexInfo
        } else if rawValue == -67862 {
            self = UnsupportedLocality
        } else if rawValue == -67863 {
            self = UnsupportedNumAttributes
        } else if rawValue == -67864 {
            self = UnsupportedNumIndexes
        } else if rawValue == -67865 {
            self = UnsupportedNumRecordTypes
        } else if rawValue == -67866 {
            self = FieldSpecifiedMultiple
        } else if rawValue == -67867 {
            self = IncompatibleFieldFormat
        } else if rawValue == -67868 {
            self = InvalidParsingModule
        } else if rawValue == -67869 {
            self = DatabaseLocked
        } else if rawValue == -67870 {
            self = DatastoreIsOpen
        } else if rawValue == -67871 {
            self = MissingValue
        } else if rawValue == -67872 {
            self = UnsupportedQueryLimits
        } else if rawValue == -67873 {
            self = UnsupportedNumSelectionPreds
        } else if rawValue == -67874 {
            self = UnsupportedOperator
        } else if rawValue == -67875 {
            self = InvalidDBLocation
        } else if rawValue == -67876 {
            self = InvalidAccessRequest
        } else if rawValue == -67877 {
            self = InvalidIndexInfo
        } else if rawValue == -67878 {
            self = InvalidNewOwner
        } else if rawValue == -67879 {
            self = InvalidModifyMode
        } else {
            self = UnknownError
        }
    }
    
    public var rawValue: Int32 {
        switch self {
        case Success:
            return 0
        case Unimplemented:
            return -4
        case Param:
            return -50
        case Allocate:
            return -108
        case NotAvailable:
            return -25291
        case ReadOnly:
            return -25292
        case AuthFailed:
            return -25293
        case NoSuchKeychain:
            return -25294
        case InvalidKeychain:
            return -25295
        case DuplicateKeychain:
            return -25296
        case DuplicateCallback:
            return -25297
        case InvalidCallback:
            return -25298
        case DuplicateItem:
            return -25299
        case ItemNotFound:
            return -25300
        case BufferTooSmall:
            return -25301
        case DataTooLarge:
            return -25302
        case NoSuchAttr:
            return -25303
        case InvalidItemRef:
            return -25304
        case InvalidSearchRef:
            return -25305
        case NoSuchClass:
            return -25306
        case NoDefaultKeychain:
            return -25307
        case InteractionNotAllowed:
            return -25308
        case ReadOnlyAttr:
            return -25309
        case WrongSecVersion:
            return -25310
        case KeySizeNotAllowed:
            return -25311
        case NoStorageModule:
            return -25312
        case NoCertificateModule:
            return -25313
        case NoPolicyModule:
            return -25314
        case InteractionRequired:
            return -25315
        case DataNotAvailable:
            return -25316
        case DataNotModifiable:
            return -25317
        case CreateChainFailed:
            return -25318
        case InvalidPrefsDomain:
            return -25319
        case ACLNotSimple:
            return -25240
        case PolicyNotFound:
            return -25241
        case InvalidTrustSetting:
            return -25242
        case NoAccessForItem:
            return -25243
        case InvalidOwnerEdit:
            return -25244
        case TrustNotAvailable:
            return -25245
        case UnsupportedFormat:
            return -25256
        case UnknownFormat:
            return -25257
        case KeyIsSensitive:
            return -25258
        case MultiplePrivKeys:
            return -25259
        case PassphraseRequired:
            return -25260
        case InvalidPasswordRef:
            return -25261
        case InvalidTrustSettings:
            return -25262
        case NoTrustSettings:
            return -25263
        case Pkcs12VerifyFailure:
            return -25264
        case InvalidCertificate:
            return -26265
        case NotSigner:
            return -26267
        case PolicyDenied:
            return -26270
        case InvalidKey:
            return -26274
        case Decode:
            return -26275
        case Internal:
            return -26276
        case UnsupportedAlgorithm:
            return -26268
        case UnsupportedOperation:
            return -26271
        case UnsupportedPadding:
            return -26273
        case ItemInvalidKey:
            return -34000
        case ItemInvalidKeyType:
            return -34001
        case ItemInvalidValue:
            return -34002
        case ItemClassMissing:
            return -34003
        case ItemMatchUnsupported:
            return -34004
        case UseItemListUnsupported:
            return -34005
        case UseKeychainUnsupported:
            return -34006
        case UseKeychainListUnsupported:
            return -34007
        case ReturnDataUnsupported:
            return -34008
        case ReturnAttributesUnsupported:
            return -34009
        case ReturnRefUnsupported:
            return -34010
        case ReturnPersitentRefUnsupported:
            return -34010
        case ValueRefUnsupported:
            return -34012
        case ValuePersistentRefUnsupported:
            return -34013
        case ReturnMissingPointer:
            return -34014
        case MatchLimitUnsupported:
            return -34015
        case ItemIllegalQuery:
            return -34016
        case WaitForCallback:
            return -34017
        case MissingEntitlement:
            return -34018
        case UpgradePending:
            return -34019
        case MPSignatureInvalid:
            return -25327
        case OTRTooOld:
            return -25328
        case OTRIDTooNew:
            return -25329
        case ServiceNotAvailable:
            return -67585
        case InsufficientClientID:
            return -67586
        case DeviceReset:
            return -67587
        case DeviceFailed:
            return -67588
        case AppleAddAppACLSubject:
            return -67589
        case ApplePublicKeyIncomplete:
            return -67590
        case AppleSignatureMismatch:
            return -67591
        case AppleInvalidKeyStartDate:
            return -67592
        case AppleInvalidKeyEndDate:
            return -67593
        case ConversionError:
            return -67594
        case AppleSSLv2Rollback:
            return -67595
        case DiskFull:
            return -34
        case QuotaExceeded:
            return -67596
        case FileTooBig:
            return -67597
        case InvalidDatabaseBlob:
            return -67598
        case InvalidKeyBlob:
            return -67599
        case IncompatibleDatabaseBlob:
            return -67600
        case IncompatibleKeyBlob:
            return -67601
        case HostNameMismatch:
            return -67602
        case UnknownCriticalExtensionFlag:
            return -67603
        case NoBasicConstraints:
            return -67604
        case NoBasicConstraintsCA:
            return -67605
        case InvalidAuthorityKeyID:
            return -67606
        case InvalidSubjectKeyID:
            return -67607
        case InvalidKeyUsageForPolicy:
            return -67608
        case InvalidExtendedKeyUsage:
            return -67609
        case InvalidIDLinkage:
            return -67610
        case PathLengthConstraintExceeded:
            return -67611
        case InvalidRoot:
            return -67612
        case CRLExpired:
            return -67613
        case CRLNotValidYet:
            return -67614
        case CRLNotFound:
            return -67615
        case CRLServerDown:
            return -67616
        case CRLBadURI:
            return -67617
        case UnknownCertExtension:
            return -67618
        case UnknownCRLExtension:
            return -67619
        case CRLNotTrusted:
            return -67620
        case CRLPolicyFailed:
            return -67621
        case IDPFailure:
            return -67622
        case SMIMEEmailAddressesNotFound:
            return -67623
        case SMIMEBadExtendedKeyUsage:
            return -67624
        case SMIMEBadKeyUsage:
            return -67625
        case SMIMEKeyUsageNotCritical:
            return -67626
        case SMIMENoEmailAddress:
            return -67627
        case SMIMESubjAltNameNotCritical:
            return -67628
        case SSLBadExtendedKeyUsage:
            return -67629
        case OCSPBadResponse:
            return -67630
        case OCSPBadRequest:
            return -67631
        case OCSPUnavailable:
            return -67632
        case OCSPStatusUnrecognized:
            return -67633
        case EndOfData:
            return -67634
        case IncompleteCertRevocationCheck:
            return -67635
        case NetworkFailure:
            return -67636
        case OCSPNotTrustedToAnchor:
            return -67637
        case RecordModified:
            return -67638
        case OCSPSignatureError:
            return -67639
        case OCSPNoSigner:
            return -67640
        case OCSPResponderMalformedReq:
            return -67641
        case OCSPResponderInternalError:
            return -67642
        case OCSPResponderTryLater:
            return -67643
        case OCSPResponderSignatureRequired:
            return -67644
        case OCSPResponderUnauthorized:
            return -67645
        case OCSPResponseNonceMismatch:
            return -67646
        case CodeSigningBadCertChainLength:
            return -67647
        case CodeSigningNoBasicConstraints:
            return -67648
        case CodeSigningBadPathLengthConstraint:
            return -67649
        case CodeSigningNoExtendedKeyUsage:
            return -67650
        case CodeSigningDevelopment:
            return -67651
        case ResourceSignBadCertChainLength:
            return -67652
        case ResourceSignBadExtKeyUsage:
            return -67653
        case TrustSettingDeny:
            return -67654
        case InvalidSubjectName:
            return -67655
        case UnknownQualifiedCertStatement:
            return -67656
        case MobileMeRequestQueued:
            return -67657
        case MobileMeRequestRedirected:
            return -67658
        case MobileMeServerError:
            return -67659
        case MobileMeServerNotAvailable:
            return -67660
        case MobileMeServerAlreadyExists:
            return -67661
        case MobileMeServerServiceErr:
            return -67662
        case MobileMeRequestAlreadyPending:
            return -67663
        case MobileMeNoRequestPending:
            return -67664
        case MobileMeCSRVerifyFailure:
            return -67665
        case MobileMeFailedConsistencyCheck:
            return -67666
        case NotInitialized:
            return -67667
        case InvalidHandleUsage:
            return -67668
        case PVCReferentNotFound:
            return -67669
        case FunctionIntegrityFail:
            return -67670
        case InternalError:
            return -67671
        case MemoryError:
            return -67672
        case InvalidData:
            return -67673
        case MDSError:
            return -67674
        case InvalidPointer:
            return -67675
        case SelfCheckFailed:
            return -67676
        case FunctionFailed:
            return -67677
        case ModuleManifestVerifyFailed:
            return -67678
        case InvalidGUID:
            return -67679
        case InvalidHandle:
            return -67680
        case InvalidDBList:
            return -67681
        case InvalidPassthroughID:
            return -67682
        case InvalidNetworkAddress:
            return -67683
        case CRLAlreadySigned:
            return -67684
        case InvalidNumberOfFields:
            return -67685
        case VerificationFailure:
            return -67686
        case UnknownTag:
            return -67687
        case InvalidSignature:
            return -67688
        case InvalidName:
            return -67689
        case InvalidCertificateRef:
            return -67690
        case InvalidCertificateGroup:
            return -67691
        case TagNotFound:
            return -67692
        case InvalidQuery:
            return -67693
        case InvalidValue:
            return -67694
        case CallbackFailed:
            return -67695
        case ACLDeleteFailed:
            return -67696
        case ACLReplaceFailed:
            return -67697
        case ACLAddFailed:
            return -67698
        case ACLChangeFailed:
            return -67699
        case InvalidAccessCredentials:
            return -67700
        case InvalidRecord:
            return -67701
        case InvalidACL:
            return -67702
        case InvalidSampleValue:
            return -67703
        case IncompatibleVersion:
            return -67704
        case PrivilegeNotGranted:
            return -67705
        case InvalidScope:
            return -67706
        case PVCAlreadyConfigured:
            return -67707
        case InvalidPVC:
            return -67708
        case EMMLoadFailed:
            return -67709
        case EMMUnloadFailed:
            return -67710
        case AddinLoadFailed:
            return -67711
        case InvalidKeyRef:
            return -67712
        case InvalidKeyHierarchy:
            return -67713
        case AddinUnloadFailed:
            return -67714
        case LibraryReferenceNotFound:
            return -67715
        case InvalidAddinFunctionTable:
            return -67716
        case InvalidServiceMask:
            return -67717
        case ModuleNotLoaded:
            return -67718
        case InvalidSubServiceID:
            return -67719
        case AttributeNotInContext:
            return -67720
        case ModuleManagerInitializeFailed:
            return -67721
        case ModuleManagerNotFound:
            return -67722
        case EventNotificationCallbackNotFound:
            return -67723
        case InputLengthError:
            return -67724
        case OutputLengthError:
            return -67725
        case PrivilegeNotSupported:
            return -67726
        case DeviceError:
            return -67727
        case AttachHandleBusy:
            return -67728
        case NotLoggedIn:
            return -67729
        case AlgorithmMismatch:
            return -67730
        case KeyUsageIncorrect:
            return -67731
        case KeyBlobTypeIncorrect:
            return -67732
        case KeyHeaderInconsistent:
            return -67733
        case UnsupportedKeyFormat:
            return -67734
        case UnsupportedKeySize:
            return -67735
        case InvalidKeyUsageMask:
            return -67736
        case UnsupportedKeyUsageMask:
            return -67737
        case InvalidKeyAttributeMask:
            return -67738
        case UnsupportedKeyAttributeMask:
            return -67739
        case InvalidKeyLabel:
            return -67740
        case UnsupportedKeyLabel:
            return -67741
        case InvalidKeyFormat:
            return -67742
        case UnsupportedVectorOfBuffers:
            return -67743
        case InvalidInputVector:
            return -67744
        case InvalidOutputVector:
            return -67745
        case InvalidContext:
            return -67746
        case InvalidAlgorithm:
            return -67747
        case InvalidAttributeKey:
            return -67748
        case MissingAttributeKey:
            return -67749
        case InvalidAttributeInitVector:
            return -67750
        case MissingAttributeInitVector:
            return -67751
        case InvalidAttributeSalt:
            return -67752
        case MissingAttributeSalt:
            return -67753
        case InvalidAttributePadding:
            return -67754
        case MissingAttributePadding:
            return -67755
        case InvalidAttributeRandom:
            return -67756
        case MissingAttributeRandom:
            return -67757
        case InvalidAttributeSeed:
            return -67758
        case MissingAttributeSeed:
            return -67759
        case InvalidAttributePassphrase:
            return -67760
        case MissingAttributePassphrase:
            return -67761
        case InvalidAttributeKeyLength:
            return -67762
        case MissingAttributeKeyLength:
            return -67763
        case InvalidAttributeBlockSize:
            return -67764
        case MissingAttributeBlockSize:
            return -67765
        case InvalidAttributeOutputSize:
            return -67766
        case MissingAttributeOutputSize:
            return -67767
        case InvalidAttributeRounds:
            return -67768
        case MissingAttributeRounds:
            return -67769
        case InvalidAlgorithmParms:
            return -67770
        case MissingAlgorithmParms:
            return -67771
        case InvalidAttributeLabel:
            return -67772
        case MissingAttributeLabel:
            return -67773
        case InvalidAttributeKeyType:
            return -67774
        case MissingAttributeKeyType:
            return -67775
        case InvalidAttributeMode:
            return -67776
        case MissingAttributeMode:
            return -67777
        case InvalidAttributeEffectiveBits:
            return -67778
        case MissingAttributeEffectiveBits:
            return -67779
        case InvalidAttributeStartDate:
            return -67780
        case MissingAttributeStartDate:
            return -67781
        case InvalidAttributeEndDate:
            return -67782
        case MissingAttributeEndDate:
            return -67783
        case InvalidAttributeVersion:
            return -67784
        case MissingAttributeVersion:
            return -67785
        case InvalidAttributePrime:
            return -67786
        case MissingAttributePrime:
            return -67787
        case InvalidAttributeBase:
            return -67788
        case MissingAttributeBase:
            return -67789
        case InvalidAttributeSubprime:
            return -67790
        case MissingAttributeSubprime:
            return -67791
        case InvalidAttributeIterationCount:
            return -67792
        case MissingAttributeIterationCount:
            return -67793
        case InvalidAttributeDLDBHandle:
            return -67794
        case MissingAttributeDLDBHandle:
            return -67795
        case InvalidAttributeAccessCredentials:
            return -67796
        case MissingAttributeAccessCredentials:
            return -67797
        case InvalidAttributePublicKeyFormat:
            return -67798
        case MissingAttributePublicKeyFormat:
            return -67799
        case InvalidAttributePrivateKeyFormat:
            return -67800
        case MissingAttributePrivateKeyFormat:
            return -67801
        case InvalidAttributeSymmetricKeyFormat:
            return -67802
        case MissingAttributeSymmetricKeyFormat:
            return -67803
        case InvalidAttributeWrappedKeyFormat:
            return -67804
        case MissingAttributeWrappedKeyFormat:
            return -67805
        case StagedOperationInProgress:
            return -67806
        case StagedOperationNotStarted:
            return -67807
        case VerifyFailed:
            return -67808
        case QuerySizeUnknown:
            return -67809
        case BlockSizeMismatch:
            return -67810
        case PublicKeyInconsistent:
            return -67811
        case DeviceVerifyFailed:
            return -67812
        case InvalidLoginName:
            return -67813
        case AlreadyLoggedIn:
            return -67814
        case InvalidDigestAlgorithm:
            return -67815
        case InvalidCRLGroup:
            return -67816
        case CertificateCannotOperate:
            return -67817
        case CertificateExpired:
            return -67818
        case CertificateNotValidYet:
            return -67819
        case CertificateRevoked:
            return -67820
        case CertificateSuspended:
            return -67821
        case InsufficientCredentials:
            return -67822
        case InvalidAction:
            return -67823
        case InvalidAuthority:
            return -67824
        case VerifyActionFailed:
            return -67825
        case InvalidCertAuthority:
            return -67826
        case InvaldCRLAuthority:
            return -67827
        case InvalidCRLEncoding:
            return -67828
        case InvalidCRLType:
            return -67829
        case InvalidCRL:
            return -67830
        case InvalidFormType:
            return -67831
        case InvalidID:
            return -67832
        case InvalidIdentifier:
            return -67833
        case InvalidIndex:
            return -67834
        case InvalidPolicyIdentifiers:
            return -67835
        case InvalidTimeString:
            return -67836
        case InvalidReason:
            return -67837
        case InvalidRequestInputs:
            return -67838
        case InvalidResponseVector:
            return -67839
        case InvalidStopOnPolicy:
            return -67840
        case InvalidTuple:
            return -67841
        case MultipleValuesUnsupported:
            return -67842
        case NotTrusted:
            return -67843
        case NoDefaultAuthority:
            return -67844
        case RejectedForm:
            return -67845
        case RequestLost:
            return -67846
        case RequestRejected:
            return -67847
        case UnsupportedAddressType:
            return -67848
        case UnsupportedService:
            return -67849
        case InvalidTupleGroup:
            return -67850
        case InvalidBaseACLs:
            return -67851
        case InvalidTupleCredendtials:
            return -67852
        case InvalidEncoding:
            return -67853
        case InvalidValidityPeriod:
            return -67854
        case InvalidRequestor:
            return -67855
        case RequestDescriptor:
            return -67856
        case InvalidBundleInfo:
            return -67857
        case InvalidCRLIndex:
            return -67858
        case NoFieldValues:
            return -67859
        case UnsupportedFieldFormat:
            return -67860
        case UnsupportedIndexInfo:
            return -67861
        case UnsupportedLocality:
            return -67862
        case UnsupportedNumAttributes:
            return -67863
        case UnsupportedNumIndexes:
            return -67864
        case UnsupportedNumRecordTypes:
            return -67865
        case FieldSpecifiedMultiple:
            return -67866
        case IncompatibleFieldFormat:
            return -67867
        case InvalidParsingModule:
            return -67868
        case DatabaseLocked:
            return -67869
        case DatastoreIsOpen:
            return -67870
        case MissingValue:
            return -67871
        case UnsupportedQueryLimits:
            return -67872
        case UnsupportedNumSelectionPreds:
            return -67873
        case UnsupportedOperator:
            return -67874
        case InvalidDBLocation:
            return -67875
        case InvalidAccessRequest:
            return -67876
        case InvalidIndexInfo:
            return -67877
        case InvalidNewOwner:
            return -67878
        case InvalidModifyMode:
            return -67879
        case UnknownError:
            return -99999
        }
    }
    
    public var description : String {
        switch self {
        case Success:
            return "No error."
        case Unimplemented:
            return "Function or operation not implemented."
        case Param:
            return "One or more parameters passed to a function were not valid."
        case Allocate:
            return "Failed to allocate memory."
        case NotAvailable:
            return "No keychain is available. You may need to restart your computer."
        case ReadOnly:
            return "This keychain cannot be modified."
        case AuthFailed:
            return "The user name or passphrase you entered is not correct."
        case NoSuchKeychain:
            return "The specified keychain could not be found."
        case InvalidKeychain:
            return "The specified keychain is not a valid keychain file."
        case DuplicateKeychain:
            return "A keychain with the same name already exists."
        case DuplicateCallback:
            return "The specified callback function is already installed."
        case InvalidCallback:
            return "The specified callback function is not valid."
        case DuplicateItem:
            return "The specified item already exists in the keychain."
        case ItemNotFound:
            return "The specified item could not be found in the keychain."
        case BufferTooSmall:
            return "There is not enough memory available to use the specified item."
        case DataTooLarge:
            return "This item contains information which is too large or in a format that cannot be displayed."
        case NoSuchAttr:
            return "The specified attribute does not exist."
        case InvalidItemRef:
            return "The specified item is no longer valid. It may have been deleted from the keychain."
        case InvalidSearchRef:
            return "Unable to search the current keychain."
        case NoSuchClass:
            return "The specified item does not appear to be a valid keychain item."
        case NoDefaultKeychain:
            return "A default keychain could not be found."
        case InteractionNotAllowed:
            return "User interaction is not allowed."
        case ReadOnlyAttr:
            return "The specified attribute could not be modified."
        case WrongSecVersion:
            return "This keychain was created by a different version of the system software and cannot be opened."
        case KeySizeNotAllowed:
            return "This item specifies a key size which is too large."
        case NoStorageModule:
            return "A required component (data storage module) could not be loaded. You may need to restart your computer."
        case NoCertificateModule:
            return "A required component (certificate module) could not be loaded. You may need to restart your computer."
        case NoPolicyModule:
            return "A required component (policy module) could not be loaded. You may need to restart your computer."
        case InteractionRequired:
            return "User interaction is required, but is currently not allowed."
        case DataNotAvailable:
            return "The contents of this item cannot be retrieved."
        case DataNotModifiable:
            return "The contents of this item cannot be modified."
        case CreateChainFailed:
            return "One or more certificates required to validate this certificate cannot be found."
        case InvalidPrefsDomain:
            return "The specified preferences domain is not valid."
        case ACLNotSimple:
            return "The specified access control list is not in standard (simple) form."
        case PolicyNotFound:
            return "The specified policy cannot be found."
        case InvalidTrustSetting:
            return "The specified trust setting is invalid."
        case NoAccessForItem:
            return "The specified item has no access control."
        case InvalidOwnerEdit:
            return "Invalid attempt to change the owner of this item."
        case TrustNotAvailable:
            return "No trust results are available."
        case UnsupportedFormat:
            return "Import/Export format unsupported."
        case UnknownFormat:
            return "Unknown format in import."
        case KeyIsSensitive:
            return "Key material must be wrapped for export."
        case MultiplePrivKeys:
            return "An attempt was made to import multiple private keys."
        case PassphraseRequired:
            return "Passphrase is required for import/export."
        case InvalidPasswordRef:
            return "The password reference was invalid."
        case InvalidTrustSettings:
            return "The Trust Settings Record was corrupted."
        case NoTrustSettings:
            return "No Trust Settings were found."
        case Pkcs12VerifyFailure:
            return "MAC verification failed during PKCS12 import (wrong password?)"
        case InvalidCertificate:
            return "This certificate could not be decoded."
        case NotSigner:
            return "A certificate was not signed by its proposed parent."
        case PolicyDenied:
            return "The certificate chain was not trusted due to a policy not accepting it."
        case InvalidKey:
            return "The provided key material was not valid."
        case Decode:
            return "Unable to decode the provided data."
        case Internal:
            return "An internal error occured in the Security framework."
        case UnsupportedAlgorithm:
            return "An unsupported algorithm was encountered."
        case UnsupportedOperation:
            return "The operation you requested is not supported by this key."
        case UnsupportedPadding:
            return "The padding you requested is not supported."
        case ItemInvalidKey:
            return "A string key in dictionary is not one of the supported keys."
        case ItemInvalidKeyType:
            return "A key in a dictionary is neither a CFStringRef nor a CFNumberRef."
        case ItemInvalidValue:
            return "A value in a dictionary is an invalid (or unsupported) CF type."
        case ItemClassMissing:
            return "No kSecItemClass key was specified in a dictionary."
        case ItemMatchUnsupported:
            return "The caller passed one or more kSecMatch keys to a function which does not support matches."
        case UseItemListUnsupported:
            return "The caller passed in a kSecUseItemList key to a function which does not support it."
        case UseKeychainUnsupported:
            return "The caller passed in a kSecUseKeychain key to a function which does not support it."
        case UseKeychainListUnsupported:
            return "The caller passed in a kSecUseKeychainList key to a function which does not support it."
        case ReturnDataUnsupported:
            return "The caller passed in a kSecReturnData key to a function which does not support it."
        case ReturnAttributesUnsupported:
            return "The caller passed in a kSecReturnAttributes key to a function which does not support it."
        case ReturnRefUnsupported:
            return "The caller passed in a kSecReturnRef key to a function which does not support it."
        case ReturnPersitentRefUnsupported:
            return "The caller passed in a kSecReturnPersistentRef key to a function which does not support it."
        case ValueRefUnsupported:
            return "The caller passed in a kSecValueRef key to a function which does not support it."
        case ValuePersistentRefUnsupported:
            return "The caller passed in a kSecValuePersistentRef key to a function which does not support it."
        case ReturnMissingPointer:
            return "The caller passed asked for something to be returned but did not pass in a result pointer."
        case MatchLimitUnsupported:
            return "The caller passed in a kSecMatchLimit key to a call which does not support limits."
        case ItemIllegalQuery:
            return "The caller passed in a query which contained too many keys."
        case WaitForCallback:
            return "This operation is incomplete, until the callback is invoked (not an error)."
        case MissingEntitlement:
            return "Internal error when a required entitlement isn't present, client has neither application-identifier nor keychain-access-groups entitlements."
        case UpgradePending:
            return "Error returned if keychain database needs a schema migration but the device is locked, clients should wait for a device unlock notification and retry the command."
        case MPSignatureInvalid:
            return "Signature invalid on MP message"
        case OTRTooOld:
            return "Message is too old to use"
        case OTRIDTooNew:
            return "Key ID is too new to use! Message from the future?"
        case ServiceNotAvailable:
            return "The required service is not available."
        case InsufficientClientID:
            return "The client ID is not correct."
        case DeviceReset:
            return "A device reset has occurred."
        case DeviceFailed:
            return "A device failure has occurred."
        case AppleAddAppACLSubject:
            return "Adding an application ACL subject failed."
        case ApplePublicKeyIncomplete:
            return "The public key is incomplete."
        case AppleSignatureMismatch:
            return "A signature mismatch has occurred."
        case AppleInvalidKeyStartDate:
            return "The specified key has an invalid start date."
        case AppleInvalidKeyEndDate:
            return "The specified key has an invalid end date."
        case ConversionError:
            return "A conversion error has occurred."
        case AppleSSLv2Rollback:
            return "A SSLv2 rollback error has occurred."
        case DiskFull:
            return "The disk is full."
        case QuotaExceeded:
            return "The quota was exceeded."
        case FileTooBig:
            return "The file is too big."
        case InvalidDatabaseBlob:
            return "The specified database has an invalid blob."
        case InvalidKeyBlob:
            return "The specified database has an invalid key blob."
        case IncompatibleDatabaseBlob:
            return "The specified database has an incompatible blob."
        case IncompatibleKeyBlob:
            return "The specified database has an incompatible key blob."
        case HostNameMismatch:
            return "A host name mismatch has occurred."
        case UnknownCriticalExtensionFlag:
            return "There is an unknown critical extension flag."
        case NoBasicConstraints:
            return "No basic constraints were found."
        case NoBasicConstraintsCA:
            return "No basic CA constraints were found."
        case InvalidAuthorityKeyID:
            return "The authority key ID is not valid."
        case InvalidSubjectKeyID:
            return "The subject key ID is not valid."
        case InvalidKeyUsageForPolicy:
            return "The key usage is not valid for the specified policy."
        case InvalidExtendedKeyUsage:
            return "The extended key usage is not valid."
        case InvalidIDLinkage:
            return "The ID linkage is not valid."
        case PathLengthConstraintExceeded:
            return "The path length constraint was exceeded."
        case InvalidRoot:
            return "The root or anchor certificate is not valid."
        case CRLExpired:
            return "The CRL has expired."
        case CRLNotValidYet:
            return "The CRL is not yet valid."
        case CRLNotFound:
            return "The CRL was not found."
        case CRLServerDown:
            return "The CRL server is down."
        case CRLBadURI:
            return "The CRL has a bad Uniform Resource Identifier."
        case UnknownCertExtension:
            return "An unknown certificate extension was encountered."
        case UnknownCRLExtension:
            return "An unknown CRL extension was encountered."
        case CRLNotTrusted:
            return "The CRL is not trusted."
        case CRLPolicyFailed:
            return "The CRL policy failed."
        case IDPFailure:
            return "The issuing distribution point was not valid."
        case SMIMEEmailAddressesNotFound:
            return "An email address mismatch was encountered."
        case SMIMEBadExtendedKeyUsage:
            return "The appropriate extended key usage for SMIME was not found."
        case SMIMEBadKeyUsage:
            return "The key usage is not compatible with SMIME."
        case SMIMEKeyUsageNotCritical:
            return "The key usage extension is not marked as critical."
        case SMIMENoEmailAddress:
            return "No email address was found in the certificate."
        case SMIMESubjAltNameNotCritical:
            return "The subject alternative name extension is not marked as critical."
        case SSLBadExtendedKeyUsage:
            return "The appropriate extended key usage for SSL was not found."
        case OCSPBadResponse:
            return "The OCSP response was incorrect or could not be parsed."
        case OCSPBadRequest:
            return "The OCSP request was incorrect or could not be parsed."
        case OCSPUnavailable:
            return "OCSP service is unavailable."
        case OCSPStatusUnrecognized:
            return "The OCSP server did not recognize this certificate."
        case EndOfData:
            return "An end-of-data was detected."
        case IncompleteCertRevocationCheck:
            return "An incomplete certificate revocation check occurred."
        case NetworkFailure:
            return "A network failure occurred."
        case OCSPNotTrustedToAnchor:
            return "The OCSP response was not trusted to a root or anchor certificate."
        case RecordModified:
            return "The record was modified."
        case OCSPSignatureError:
            return "The OCSP response had an invalid signature."
        case OCSPNoSigner:
            return "The OCSP response had no signer."
        case OCSPResponderMalformedReq:
            return "The OCSP responder was given a malformed request."
        case OCSPResponderInternalError:
            return "The OCSP responder encountered an internal error."
        case OCSPResponderTryLater:
            return "The OCSP responder is busy, try again later."
        case OCSPResponderSignatureRequired:
            return "The OCSP responder requires a signature."
        case OCSPResponderUnauthorized:
            return "The OCSP responder rejected this request as unauthorized."
        case OCSPResponseNonceMismatch:
            return "The OCSP response nonce did not match the request."
        case CodeSigningBadCertChainLength:
            return "Code signing encountered an incorrect certificate chain length."
        case CodeSigningNoBasicConstraints:
            return "Code signing found no basic constraints."
        case CodeSigningBadPathLengthConstraint:
            return "Code signing encountered an incorrect path length constraint."
        case CodeSigningNoExtendedKeyUsage:
            return "Code signing found no extended key usage."
        case CodeSigningDevelopment:
            return "Code signing indicated use of a development-only certificate."
        case ResourceSignBadCertChainLength:
            return "Resource signing has encountered an incorrect certificate chain length."
        case ResourceSignBadExtKeyUsage:
            return "Resource signing has encountered an error in the extended key usage."
        case TrustSettingDeny:
            return "The trust setting for this policy was set to Deny."
        case InvalidSubjectName:
            return "An invalid certificate subject name was encountered."
        case UnknownQualifiedCertStatement:
            return "An unknown qualified certificate statement was encountered."
        case MobileMeRequestQueued:
            return "The MobileMe request will be sent during the next connection."
        case MobileMeRequestRedirected:
            return "The MobileMe request was redirected."
        case MobileMeServerError:
            return "A MobileMe server error occurred."
        case MobileMeServerNotAvailable:
            return "The MobileMe server is not available."
        case MobileMeServerAlreadyExists:
            return "The MobileMe server reported that the item already exists."
        case MobileMeServerServiceErr:
            return "A MobileMe service error has occurred."
        case MobileMeRequestAlreadyPending:
            return "A MobileMe request is already pending."
        case MobileMeNoRequestPending:
            return "MobileMe has no request pending."
        case MobileMeCSRVerifyFailure:
            return "A MobileMe CSR verification failure has occurred."
        case MobileMeFailedConsistencyCheck:
            return "MobileMe has found a failed consistency check."
        case NotInitialized:
            return "A function was called without initializing CSSM."
        case InvalidHandleUsage:
            return "The CSSM handle does not match with the service type."
        case PVCReferentNotFound:
            return "A reference to the calling module was not found in the list of authorized callers."
        case FunctionIntegrityFail:
            return "A function address was not within the verified module."
        case InternalError:
            return "An internal error has occurred."
        case MemoryError:
            return "A memory error has occurred."
        case InvalidData:
            return "Invalid data was encountered."
        case MDSError:
            return "A Module Directory Service error has occurred."
        case InvalidPointer:
            return "An invalid pointer was encountered."
        case SelfCheckFailed:
            return "Self-check has failed."
        case FunctionFailed:
            return "A function has failed."
        case ModuleManifestVerifyFailed:
            return "A module manifest verification failure has occurred."
        case InvalidGUID:
            return "An invalid GUID was encountered."
        case InvalidHandle:
            return "An invalid handle was encountered."
        case InvalidDBList:
            return "An invalid DB list was encountered."
        case InvalidPassthroughID:
            return "An invalid passthrough ID was encountered."
        case InvalidNetworkAddress:
            return "An invalid network address was encountered."
        case CRLAlreadySigned:
            return "The certificate revocation list is already signed."
        case InvalidNumberOfFields:
            return "An invalid number of fields were encountered."
        case VerificationFailure:
            return "A verification failure occurred."
        case UnknownTag:
            return "An unknown tag was encountered."
        case InvalidSignature:
            return "An invalid signature was encountered."
        case InvalidName:
            return "An invalid name was encountered."
        case InvalidCertificateRef:
            return "An invalid certificate reference was encountered."
        case InvalidCertificateGroup:
            return "An invalid certificate group was encountered."
        case TagNotFound:
            return "The specified tag was not found."
        case InvalidQuery:
            return "The specified query was not valid."
        case InvalidValue:
            return "An invalid value was detected."
        case CallbackFailed:
            return "A callback has failed."
        case ACLDeleteFailed:
            return "An ACL delete operation has failed."
        case ACLReplaceFailed:
            return "An ACL replace operation has failed."
        case ACLAddFailed:
            return "An ACL add operation has failed."
        case ACLChangeFailed:
            return "An ACL change operation has failed."
        case InvalidAccessCredentials:
            return "Invalid access credentials were encountered."
        case InvalidRecord:
            return "An invalid record was encountered."
        case InvalidACL:
            return "An invalid ACL was encountered."
        case InvalidSampleValue:
            return "An invalid sample value was encountered."
        case IncompatibleVersion:
            return "An incompatible version was encountered."
        case PrivilegeNotGranted:
            return "The privilege was not granted."
        case InvalidScope:
            return "An invalid scope was encountered."
        case PVCAlreadyConfigured:
            return "The PVC is already configured."
        case InvalidPVC:
            return "An invalid PVC was encountered."
        case EMMLoadFailed:
            return "The EMM load has failed."
        case EMMUnloadFailed:
            return "The EMM unload has failed."
        case AddinLoadFailed:
            return "The add-in load operation has failed."
        case InvalidKeyRef:
            return "An invalid key was encountered."
        case InvalidKeyHierarchy:
            return "An invalid key hierarchy was encountered."
        case AddinUnloadFailed:
            return "The add-in unload operation has failed."
        case LibraryReferenceNotFound:
            return "A library reference was not found."
        case InvalidAddinFunctionTable:
            return "An invalid add-in function table was encountered."
        case InvalidServiceMask:
            return "An invalid service mask was encountered."
        case ModuleNotLoaded:
            return "A module was not loaded."
        case InvalidSubServiceID:
            return "An invalid subservice ID was encountered."
        case AttributeNotInContext:
            return "An attribute was not in the context."
        case ModuleManagerInitializeFailed:
            return "A module failed to initialize."
        case ModuleManagerNotFound:
            return "A module was not found."
        case EventNotificationCallbackNotFound:
            return "An event notification callback was not found."
        case InputLengthError:
            return "An input length error was encountered."
        case OutputLengthError:
            return "An output length error was encountered."
        case PrivilegeNotSupported:
            return "The privilege is not supported."
        case DeviceError:
            return "A device error was encountered."
        case AttachHandleBusy:
            return "The CSP handle was busy."
        case NotLoggedIn:
            return "You are not logged in."
        case AlgorithmMismatch:
            return "An algorithm mismatch was encountered."
        case KeyUsageIncorrect:
            return "The key usage is incorrect."
        case KeyBlobTypeIncorrect:
            return "The key blob type is incorrect."
        case KeyHeaderInconsistent:
            return "The key header is inconsistent."
        case UnsupportedKeyFormat:
            return "The key header format is not supported."
        case UnsupportedKeySize:
            return "The key size is not supported."
        case InvalidKeyUsageMask:
            return "The key usage mask is not valid."
        case UnsupportedKeyUsageMask:
            return "The key usage mask is not supported."
        case InvalidKeyAttributeMask:
            return "The key attribute mask is not valid."
        case UnsupportedKeyAttributeMask:
            return "The key attribute mask is not supported."
        case InvalidKeyLabel:
            return "The key label is not valid."
        case UnsupportedKeyLabel:
            return "The key label is not supported."
        case InvalidKeyFormat:
            return "The key format is not valid."
        case UnsupportedVectorOfBuffers:
            return "The vector of buffers is not supported."
        case InvalidInputVector:
            return "The input vector is not valid."
        case InvalidOutputVector:
            return "The output vector is not valid."
        case InvalidContext:
            return "An invalid context was encountered."
        case InvalidAlgorithm:
            return "An invalid algorithm was encountered."
        case InvalidAttributeKey:
            return "A key attribute was not valid."
        case MissingAttributeKey:
            return "A key attribute was missing."
        case InvalidAttributeInitVector:
            return "An init vector attribute was not valid."
        case MissingAttributeInitVector:
            return "An init vector attribute was missing."
        case InvalidAttributeSalt:
            return "A salt attribute was not valid."
        case MissingAttributeSalt:
            return "A salt attribute was missing."
        case InvalidAttributePadding:
            return "A padding attribute was not valid."
        case MissingAttributePadding:
            return "A padding attribute was missing."
        case InvalidAttributeRandom:
            return "A random number attribute was not valid."
        case MissingAttributeRandom:
            return "A random number attribute was missing."
        case InvalidAttributeSeed:
            return "A seed attribute was not valid."
        case MissingAttributeSeed:
            return "A seed attribute was missing."
        case InvalidAttributePassphrase:
            return "A passphrase attribute was not valid."
        case MissingAttributePassphrase:
            return "A passphrase attribute was missing."
        case InvalidAttributeKeyLength:
            return "A key length attribute was not valid."
        case MissingAttributeKeyLength:
            return "A key length attribute was missing."
        case InvalidAttributeBlockSize:
            return "A block size attribute was not valid."
        case MissingAttributeBlockSize:
            return "A block size attribute was missing."
        case InvalidAttributeOutputSize:
            return "An output size attribute was not valid."
        case MissingAttributeOutputSize:
            return "An output size attribute was missing."
        case InvalidAttributeRounds:
            return "The number of rounds attribute was not valid."
        case MissingAttributeRounds:
            return "The number of rounds attribute was missing."
        case InvalidAlgorithmParms:
            return "An algorithm parameters attribute was not valid."
        case MissingAlgorithmParms:
            return "An algorithm parameters attribute was missing."
        case InvalidAttributeLabel:
            return "A label attribute was not valid."
        case MissingAttributeLabel:
            return "A label attribute was missing."
        case InvalidAttributeKeyType:
            return "A key type attribute was not valid."
        case MissingAttributeKeyType:
            return "A key type attribute was missing."
        case InvalidAttributeMode:
            return "A mode attribute was not valid."
        case MissingAttributeMode:
            return "A mode attribute was missing."
        case InvalidAttributeEffectiveBits:
            return "An effective bits attribute was not valid."
        case MissingAttributeEffectiveBits:
            return "An effective bits attribute was missing."
        case InvalidAttributeStartDate:
            return "A start date attribute was not valid."
        case MissingAttributeStartDate:
            return "A start date attribute was missing."
        case InvalidAttributeEndDate:
            return "An end date attribute was not valid."
        case MissingAttributeEndDate:
            return "An end date attribute was missing."
        case InvalidAttributeVersion:
            return "A version attribute was not valid."
        case MissingAttributeVersion:
            return "A version attribute was missing."
        case InvalidAttributePrime:
            return "A prime attribute was not valid."
        case MissingAttributePrime:
            return "A prime attribute was missing."
        case InvalidAttributeBase:
            return "A base attribute was not valid."
        case MissingAttributeBase:
            return "A base attribute was missing."
        case InvalidAttributeSubprime:
            return "A subprime attribute was not valid."
        case MissingAttributeSubprime:
            return "A subprime attribute was missing."
        case InvalidAttributeIterationCount:
            return "An iteration count attribute was not valid."
        case MissingAttributeIterationCount:
            return "An iteration count attribute was missing."
        case InvalidAttributeDLDBHandle:
            return "A database handle attribute was not valid."
        case MissingAttributeDLDBHandle:
            return "A database handle attribute was missing."
        case InvalidAttributeAccessCredentials:
            return "An access credentials attribute was not valid."
        case MissingAttributeAccessCredentials:
            return "An access credentials attribute was missing."
        case InvalidAttributePublicKeyFormat:
            return "A public key format attribute was not valid."
        case MissingAttributePublicKeyFormat:
            return "A public key format attribute was missing."
        case InvalidAttributePrivateKeyFormat:
            return "A private key format attribute was not valid."
        case MissingAttributePrivateKeyFormat:
            return "A private key format attribute was missing."
        case InvalidAttributeSymmetricKeyFormat:
            return "A symmetric key format attribute was not valid."
        case MissingAttributeSymmetricKeyFormat:
            return "A symmetric key format attribute was missing."
        case InvalidAttributeWrappedKeyFormat:
            return "A wrapped key format attribute was not valid."
        case MissingAttributeWrappedKeyFormat:
            return "A wrapped key format attribute was missing."
        case StagedOperationInProgress:
            return "A staged operation is in progress."
        case StagedOperationNotStarted:
            return "A staged operation was not started."
        case VerifyFailed:
            return "A cryptographic verification failure has occurred."
        case QuerySizeUnknown:
            return "The query size is unknown."
        case BlockSizeMismatch:
            return "A block size mismatch occurred."
        case PublicKeyInconsistent:
            return "The public key was inconsistent."
        case DeviceVerifyFailed:
            return "A device verification failure has occurred."
        case InvalidLoginName:
            return "An invalid login name was detected."
        case AlreadyLoggedIn:
            return "The user is already logged in."
        case InvalidDigestAlgorithm:
            return "An invalid digest algorithm was detected."
        case InvalidCRLGroup:
            return "An invalid CRL group was detected."
        case CertificateCannotOperate:
            return "The certificate cannot operate."
        case CertificateExpired:
            return "An expired certificate was detected."
        case CertificateNotValidYet:
            return "The certificate is not yet valid."
        case CertificateRevoked:
            return "The certificate was revoked."
        case CertificateSuspended:
            return "The certificate was suspended."
        case InsufficientCredentials:
            return "Insufficient credentials were detected."
        case InvalidAction:
            return "The action was not valid."
        case InvalidAuthority:
            return "The authority was not valid."
        case VerifyActionFailed:
            return "A verify action has failed."
        case InvalidCertAuthority:
            return "The certificate authority was not valid."
        case InvaldCRLAuthority:
            return "The CRL authority was not valid."
        case InvalidCRLEncoding:
            return "The CRL encoding was not valid."
        case InvalidCRLType:
            return "The CRL type was not valid."
        case InvalidCRL:
            return "The CRL was not valid."
        case InvalidFormType:
            return "The form type was not valid."
        case InvalidID:
            return "The ID was not valid."
        case InvalidIdentifier:
            return "The identifier was not valid."
        case InvalidIndex:
            return "The index was not valid."
        case InvalidPolicyIdentifiers:
            return "The policy identifiers are not valid."
        case InvalidTimeString:
            return "The time specified was not valid."
        case InvalidReason:
            return "The trust policy reason was not valid."
        case InvalidRequestInputs:
            return "The request inputs are not valid."
        case InvalidResponseVector:
            return "The response vector was not valid."
        case InvalidStopOnPolicy:
            return "The stop-on policy was not valid."
        case InvalidTuple:
            return "The tuple was not valid."
        case MultipleValuesUnsupported:
            return "Multiple values are not supported."
        case NotTrusted:
            return "The trust policy was not trusted."
        case NoDefaultAuthority:
            return "No default authority was detected."
        case RejectedForm:
            return "The trust policy had a rejected form."
        case RequestLost:
            return "The request was lost."
        case RequestRejected:
            return "The request was rejected."
        case UnsupportedAddressType:
            return "The address type is not supported."
        case UnsupportedService:
            return "The service is not supported."
        case InvalidTupleGroup:
            return "The tuple group was not valid."
        case InvalidBaseACLs:
            return "The base ACLs are not valid."
        case InvalidTupleCredendtials:
            return "The tuple credentials are not valid."
        case InvalidEncoding:
            return "The encoding was not valid."
        case InvalidValidityPeriod:
            return "The validity period was not valid."
        case InvalidRequestor:
            return "The requestor was not valid."
        case RequestDescriptor:
            return "The request descriptor was not valid."
        case InvalidBundleInfo:
            return "The bundle information was not valid."
        case InvalidCRLIndex:
            return "The CRL index was not valid."
        case NoFieldValues:
            return "No field values were detected."
        case UnsupportedFieldFormat:
            return "The field format is not supported."
        case UnsupportedIndexInfo:
            return "The index information is not supported."
        case UnsupportedLocality:
            return "The locality is not supported."
        case UnsupportedNumAttributes:
            return "The number of attributes is not supported."
        case UnsupportedNumIndexes:
            return "The number of indexes is not supported."
        case UnsupportedNumRecordTypes:
            return "The number of record types is not supported."
        case FieldSpecifiedMultiple:
            return "Too many fields were specified."
        case IncompatibleFieldFormat:
            return "The field format was incompatible."
        case InvalidParsingModule:
            return "The parsing module was not valid."
        case DatabaseLocked:
            return "The database is locked."
        case DatastoreIsOpen:
            return "The data store is open."
        case MissingValue:
            return "A missing value was detected."
        case UnsupportedQueryLimits:
            return "The query limits are not supported."
        case UnsupportedNumSelectionPreds:
            return "The number of selection predicates is not supported."
        case UnsupportedOperator:
            return "The operator is not supported."
        case InvalidDBLocation:
            return "The database location is not valid."
        case InvalidAccessRequest:
            return "The access request is not valid."
        case InvalidIndexInfo:
            return "The index information is not valid."
        case InvalidNewOwner:
            return "The new owner is not valid."
        case InvalidModifyMode:
            return "The modify mode is not valid. }"
        case UnknownError:
            return "Unknown error has occurred."
        }
    }
}