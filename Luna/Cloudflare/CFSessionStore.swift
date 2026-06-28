//
//  CFSessionStore.swift
//  Luna
//
//  Created by Francesco on 28/06/26.
//

#if os(iOS)
import UIKit
import WebKit
import Security
import Foundation

enum CFSessionError: LocalizedError {
    case aborted
    case timedOut
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .aborted: return "User cancelled the security check."
        case .timedOut: return "Security check timed out."
        case .verificationFailed: return "Session verification failed after solving."
        }
    }
}

extension Notification.Name {
    static let cfSessionAcquired = Notification.Name("CFSessionAcquired")
}

struct CFPassport: Codable {
    let host: String
    let cookieBlob: String
    let browserAgent: String
    let acquiredAt: Date
    let expiresAt: Date
    
    var live: Bool { expiresAt > Date() }
    
    func stamp(_ req: inout URLRequest) {
        req.setValue(cookieBlob, forHTTPHeaderField: "Cookie")
        if !browserAgent.isEmpty { req.setValue(browserAgent, forHTTPHeaderField: "User-Agent") }
    }
}

@MainActor
final class CFSessionStore: NSObject {
    
    static let shared = CFSessionStore()
    private override init() {
        super.init()
        restoreFromVault()
    }
    
    private var passports: [String: CFPassport] = [:]
    private var lockedHosts: Set<String> = []
    private var queued: [String: [CheckedContinuation<Void, Error>]] = [:]
    
    func passport(for host: String) -> CFPassport? {
        guard let p = passports[host] else { return nil }
        if p.live { return p }
        drop(host)
        return nil
    }
    
    func preparedSession(for host: String) -> URLSession? {
        guard let p = passport(for: host) else { return nil }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpAdditionalHeaders = ["Cookie": p.cookieBlob, "User-Agent": p.browserAgent]
        return URLSession(configuration: cfg)
    }
    
    func stamp(_ req: inout URLRequest, host: String) {
        passport(for: host)?.stamp(&req)
    }
    
    func fetch(_ req: URLRequest, host: String, via transport: URLSession = .shared) async -> (Data, HTTPURLResponse)? {
        var stamped = req
        stamp(&stamped, host: host)
        guard let (data, raw) = try? await transport.data(for: stamped),
              let http = raw as? HTTPURLResponse else { return nil }
        if WallScanner.isBlocked(data: data, status: http.statusCode) {
            drop(host)
            return nil
        }
        return (data, http)
    }
    
    func acquire(for host: String, via presenter: UIViewController, deadline: TimeInterval = 30) async throws {
        if passport(for: host) != nil { return }
        
        if lockedHosts.contains(host) {
            try await holdUntilUnlocked(host)
            return
        }
        
        lockedHosts.insert(host)
        defer {
            lockedHosts.remove(host)
            releaseQueue(for: host)
        }
        
        let browser = isolatedBrowser()
        let outcome = try await spawnSheet(browser: browser, host: host, deadline: deadline, from: presenter)
        
        switch outcome {
        case .solved:
            try await buildAndStorePassport(from: browser, host: host)
        case .aborted:
            throw CFSessionError.aborted
        case .timedOut:
            throw CFSessionError.timedOut
        }
    }
    
    func expire(host: String) { drop(host) }
    
    private func spawnSheet(
        browser: WKWebView,
        host: String,
        deadline: TimeInterval,
        from presenter: UIViewController
    ) async throws -> TurnstileOutcome {
        await withCheckedContinuation { (cont: CheckedContinuation<TurnstileOutcome, Never>) in
            let sheet = TurnstileSheet(browser: browser, host: host, deadline: deadline)
            sheet.onOutcome = { outcome in cont.resume(returning: outcome) }
            sheet.modalPresentationStyle = .fullScreen
            presenter.present(sheet, animated: true)
        }
    }
    
    private func buildAndStorePassport(from browser: WKWebView, host: String) async throws {
        let jar = browser.configuration.websiteDataStore.httpCookieStore
        
        let allCookies: [HTTPCookie] = await withCheckedContinuation { c in
            jar.getAllCookies { c.resume(returning: $0) }
        }
        
        let relevant = allCookies.filter { $0.belongsTo(host) }
        guard !relevant.isEmpty else { throw CFSessionError.verificationFailed }
        
        let blob = relevant.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        let agent = (try? await browser.evaluateJavaScript("navigator.userAgent") as? String) ?? ""
        
        guard await probeSession(host: host, cookieBlob: blob, agent: agent) else {
            throw CFSessionError.verificationFailed
        }
        
        let now = Date()
        let passport = CFPassport(
            host: host,
            cookieBlob: blob,
            browserAgent: agent,
            acquiredAt: now,
            expiresAt: now.addingTimeInterval(3600)
        )
        passports[host] = passport
        writeToVault(passport)
        NotificationCenter.default.post(name: .cfSessionAcquired, object: host, userInfo: nil)
    }
    
    private func probeSession(host: String, cookieBlob: String, agent: String) async -> Bool {
        guard let url = URL(string: "https://\(host)/") else { return true }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.setValue(cookieBlob, forHTTPHeaderField: "Cookie")
        if !agent.isEmpty { req.setValue(agent, forHTTPHeaderField: "User-Agent") }
        let cfg = URLSessionConfiguration.ephemeral
        guard let (data, raw) = try? await URLSession(configuration: cfg).data(for: req),
              let http = raw as? HTTPURLResponse else { return true }
        return !WallScanner.isBlocked(data: data, status: http.statusCode)
    }
    
    private func holdUntilUnlocked(_ host: String) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            queued[host, default: []].append(c)
        }
    }
    
    private func releaseQueue(for host: String) {
        (queued.removeValue(forKey: host) ?? []).forEach { $0.resume() }
    }
    
    private func drop(_ host: String) {
        passports.removeValue(forKey: host)
        removeFromVault(host)
    }
    
    private func isolatedBrowser() -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: cfg)
    }
    
    private enum Vault {
        static let service = "me.cranci.cfsessionstore"
        static func key(_ host: String) -> String { "passport.\(host)" }
    }
    
    private func writeToVault(_ passport: CFPassport) {
        guard let data = try? JSONEncoder().encode(passport) else { return }
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Vault.service,
            kSecAttrAccount: Vault.key(passport.host)
        ]
        if SecItemUpdate(q as CFDictionary, [kSecValueData: data] as CFDictionary) == errSecItemNotFound {
            var add = q; add[kSecValueData] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }
    
    private func removeFromVault(_ host: String) {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Vault.service,
            kSecAttrAccount: Vault.key(host)
        ]
        SecItemDelete(q as CFDictionary)
    }
    
    private func restoreFromVault() {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Vault.service,
            kSecReturnData: true,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitAll
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let rows = out as? [[CFString: Any]] else { return }
        for row in rows {
            guard let data = row[kSecValueData] as? Data,
                  let p = try? JSONDecoder().decode(CFPassport.self, from: data),
                  p.live else { continue }
            passports[p.host] = p
        }
    }
}

enum WallScanner {
    private static let markers = [
        "cf-turnstile-response", "_cf_chl_opt",
        "jschl-answer", "cf_chl_prog", "Ray ID",
        "challenge-platform"
    ]
    
    static func isBlocked(data: Data, status: Int) -> Bool {
        guard [403, 429, 503].contains(status) else { return false }
        let body = String(data: data, encoding: .utf8) ?? ""
        return markers.contains(where: body.contains)
    }
}
#endif
