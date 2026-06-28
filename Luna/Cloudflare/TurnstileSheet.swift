//
//  TurnstileSheet.swift
//  Luna
//
//  Created by Francesco on 28/06/26.
//

#if os(iOS)
import UIKit
import WebKit

enum TurnstileOutcome {
    case solved
    case aborted
    case timedOut
}

final class TurnstileSheet: UIViewController {
    private let browser: WKWebView
    let targetHost: String
    private let deadline: TimeInterval
    private var detectionTask: Task<Void, Never>?
    private var resolved = false
    
    var onOutcome: ((TurnstileOutcome) -> Void)?
    
    init(browser: WKWebView, host: String, deadline: TimeInterval = 30) {
        self.browser = browser
        self.targetHost = host
        self.deadline = deadline
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    
    private lazy var bannerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.95, green: 0.45, blue: 0.0, alpha: 1)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alpha = 0
        return v
    }()
    
    private lazy var activityRing: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .medium)
        a.color = .white
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()
    
    private lazy var bannerLabel: UILabel = {
        let l = UILabel()
        l.text = "Complete the security check below"
        l.textColor = .white
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private lazy var dismissButton: UIButton = {
        var cfg = UIButton.Configuration.plain()
        cfg.title = "Dismiss"
        cfg.baseForegroundColor = .white
        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(userDismissed), for: .touchUpInside)
        return b
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        embedBrowser()
        embedBanner()
        loadTarget()
        beginDetection()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        detectionTask?.cancel()
    }
    
    private func embedBrowser() {
        browser.navigationDelegate = self
        browser.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browser)
        NSLayoutConstraint.activate([
            browser.topAnchor.constraint(equalTo: view.topAnchor),
            browser.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            browser.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            browser.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func embedBanner() {
        view.addSubview(bannerView)
        bannerView.addSubview(activityRing)
        bannerView.addSubview(bannerLabel)
        bannerView.addSubview(dismissButton)
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.heightAnchor.constraint(equalToConstant: 48),
            
            activityRing.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 16),
            activityRing.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor),
            
            bannerLabel.leadingAnchor.constraint(equalTo: activityRing.trailingAnchor, constant: 10),
            bannerLabel.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor),
            
            dismissButton.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -16),
            dismissButton.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor)
        ])
    }
    
    private func loadTarget() {
        guard let url = URL(string: "https://\(targetHost)/") else { return }
        browser.load(URLRequest(url: url))
    }
    
    private func beginDetection() {
        detectionTask = Task { [weak self] in
            guard let self else { return }
            
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled, !self.resolved else { return }
            
            await MainActor.run {
                UIView.animate(withDuration: 0.25) { self.bannerView.alpha = 1 }
                self.activityRing.startAnimating()
            }
            
            let expires = Date().addingTimeInterval(self.deadline)
            
            while Date() < expires {
                guard !Task.isCancelled, !self.resolved else { return }
                
                let found = await self.scanForClearanceCookie()
                if found {
                    await self.conclude(.solved)
                    return
                }
                
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            
            await self.conclude(.timedOut)
        }
    }
    
    private func scanForClearanceCookie() async -> Bool {
        await withCheckedContinuation { cont in
            browser.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let found = cookies.contains { $0.name == "cf_clearance" && $0.belongsTo(self.targetHost) }
                cont.resume(returning: found)
            }
        }
    }
    
    @MainActor
    private func conclude(_ outcome: TurnstileOutcome) async {
        guard !resolved else { return }
        resolved = true
        detectionTask?.cancel()
        activityRing.stopAnimating()
        
        if outcome == .timedOut {
            bannerLabel.text = "Timed out. Please try again."
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        
        dismiss(animated: true) { [weak self] in
            self?.onOutcome?(outcome)
        }
    }
    
    @objc private func userDismissed() {
        Task { await conclude(.aborted) }
    }
}

extension TurnstileSheet: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            let found = await scanForClearanceCookie()
            if found { await conclude(.solved) }
        }
    }
}

extension HTTPCookie {
    func belongsTo(_ host: String) -> Bool {
        let stripped = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain
        return host == stripped || host.hasSuffix("." + stripped)
    }
}
#endif
