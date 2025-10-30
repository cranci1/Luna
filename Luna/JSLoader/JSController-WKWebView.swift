//
//  JSController-WKWebView.swift
//  Luna
//
//  Created by Dominic on 30.10.25.
//

#if os(tvOS)

import Foundation
import UIKit

@inlinable
func sel(_ name: String) -> Selector { Selector(name) }

// MARK: - Cookie + DataStore

public struct WKCookie {
    let name: String
    let value: String
}

public class WKCookieStore {
    private let cookieStorage: AnyObject?

    init() {
        if let cookieClass = NSClassFromString("NSHTTPCookieStorage") as AnyObject?,
           let unmanaged = cookieClass.perform(sel("sharedHTTPCookieStorage")) {
            cookieStorage = (unmanaged.takeUnretainedValue() as AnyObject)
        } else {
            cookieStorage = nil
        }
    }

    func getAllCookies(_ callback: ([WKCookie]) -> Void) {
        guard let cookies = cookieStorage?.perform(Selector(("cookies")))?
            .takeUnretainedValue() as? [HTTPCookie] else {
            callback([])
            return
        }

        let wkCookies = cookies.map { WKCookie(name: $0.name, value: $0.value) }
        callback(wkCookies)
    }

    func setCookie(_ cookie: HTTPCookie) {
        _ = cookieStorage?.perform(sel("setCookie:"), with: cookie)
    }
}

public struct WKDataStore {
    let httpCookieStore = WKCookieStore()
}

// MARK: - User Scripts + Messaging

public enum WKUserScriptInjectionTime {
    case atDocumentStart
}

public struct WKUserScript {
    let source: String
    let injectionTime: WKUserScriptInjectionTime
    let forMainFrameOnly: Bool
}

public class WKUserContentController {
    private var scripts: [WKUserScript] = []
    private weak var attachedWebView: WKWebView?

    func attach(to webView: WKWebView) {
        self.attachedWebView = webView
    }

    func addUserScript(_ script: WKUserScript) {
        scripts.append(script)
        inject(script)
    }

    func removeScriptMessageHandler(forName: String) {
        // Not fully applicable for UIWebView (no native JS message bridge)
    }

    func add(_ scriptMessageHandler: any WKScriptMessageHandler, name: String) {
        // Simulated messaging bridge can be implemented via evaluateJavaScript polling
        print("add(scriptMessageHandler:\(name)) not natively supported on UIWebView")
    }

    private func inject(_ script: WKUserScript) {
        guard let webView = attachedWebView else { return }
        let js = script.source
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

// MARK: - Configuration

public class WKWebViewConfiguration {
    var userContentController = WKUserContentController()
    var allowsInlineMediaPlayback: Bool = true
    var mediaTypesRequiringUserActionForPlayback: [Any] = []
    var websiteDataStore = WKDataStore()
}

// MARK: - Navigation + Delegates

public class WKNavigation {}

public struct WKNavigationAction {
    let request: URLRequest
}

public enum WKNavigationActionPolicy {
    case allow
}

public protocol WKNavigationDelegate : NSObjectProtocol {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
}

// MARK: - Script Message Handler

public struct WKScriptMessage {
    let name: String
    let body: AnyObject
}

public protocol WKScriptMessageHandler : NSObjectProtocol {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage)
}

// MARK: - WKWebView (UIWebView-backed)

public class WKWebView: NSObject {

    private var internalWebView: AnyObject?
    private var internalDelegate: DynamicWebViewDelegate?

    var url: URL? = nil
    var configuration: WKWebViewConfiguration
    var navigationDelegate: WKNavigationDelegate? = nil
    var customUserAgent: String? = nil

    init(frame: CGRect, configuration: WKWebViewConfiguration) {
        self.configuration = configuration
        super.init()

        if let webViewClass = NSClassFromString("UIWebView") as? NSObject.Type {
            internalWebView = webViewClass.init()

            if internalWebView?.responds(to: Selector(("setFrame:"))) == true {
                _ = internalWebView?.perform(Selector(("setFrame:")), with: NSValue(cgRect: frame))
            }

            internalDelegate = DynamicWebViewDelegate(owner: self)
            _ = internalWebView?.perform(sel("setDelegate:"), with: internalDelegate)

            configuration.userContentController.attach(to: self)
        } else {
            print("⚠️ UIWebView not found at runtime (tvOS).")
        }
    }

    // MARK: - Web Methods

    func load(_ request: URLRequest) {
        url = request.url
        _ = internalWebView?.perform(sel("loadRequest:"), with: request)
    }

    func stopLoading() {
        _ = internalWebView?.perform(sel("stopLoading"))
    }

    func reload() {
        _ = internalWebView?.perform(sel("reload"))
    }

    func loadHTMLString(_ htmlContent: String, baseURL: String? = nil) {
        let base = baseURL.flatMap { URL(string: $0) }
        _ = internalWebView?.perform(sel("loadHTMLString:baseURL:"), with: htmlContent, with: base)
    }

    func evaluateJavaScript(_ script: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        let result = internalWebView?.perform(sel("stringByEvaluatingJavaScriptFromString:"), with: script)
        completionHandler?(result?.takeUnretainedValue(), nil)
    }

    func getInternalView() -> UIView? {
        return internalWebView as? UIView
    }
}

// MARK: - Delegate Bridge

fileprivate class DynamicWebViewDelegate: NSObject {
    weak var owner: WKWebView?

    init(owner: WKWebView) {
        self.owner = owner
    }

    @objc func webViewDidStartLoad(_ webView: Any) { }

    @objc func webViewDidFinishLoad(_ webView: Any) {
        guard let owner = owner else { return }
        owner.navigationDelegate?.webView(owner, didFinish: WKNavigation())
    }

    @objc func webView(_ webView: Any, didFailLoadWithError error: NSError) {
        guard let owner = owner else { return }
        owner.navigationDelegate?.webView(owner, didFail: WKNavigation(), withError: error)
    }

    @objc func webView(_ webView: Any, shouldStartLoadWith request: URLRequest, navigationType: Int) -> Bool {
        guard let owner = owner else { return true }

        var policy: WKNavigationActionPolicy = .allow
        owner.navigationDelegate?.webView(owner,
                                          decidePolicyFor: WKNavigationAction(request: request)) { p in
            policy = p
        }
        return policy == .allow
    }
}

#endif
