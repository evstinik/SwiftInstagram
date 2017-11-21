//
//  InstagramLoginViewController.swift
//  SwiftInstagram
//
//  Created by Ander Goig on 8/9/17.
//  Copyright © 2017 Ander Goig. All rights reserved.
//

import UIKit
import WebKit

class InstagramLoginViewController: UIViewController {

    // MARK: - Types

    typealias SuccessHandler = (_ accesToken: String, _ sender: UIViewController) -> Void
    typealias FailureHandler = (_ error: InstagramError, _ sender: UIViewController) -> Void

    // MARK: - Properties

    private var authURL: URL
    private var success: SuccessHandler?
    private var failure: FailureHandler?

    // MARK: - Initializers

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(authURL: URL, success: SuccessHandler?, failure: FailureHandler?) {
        self.authURL = authURL
        self.success = success
        self.failure = failure

        super.init(nibName: nil, bundle: nil)
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        }

        // Initializes web view
        let webView = setupWebView()

        // Starts authorization
        webView.load(URLRequest(url: authURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
    }

    // MARK: -

    private func setupWebView() -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: view.frame, configuration: webConfiguration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self

        view.addSubview(webView)

        return webView
    }

}

// MARK: - WKNavigationDelegate

extension InstagramLoginViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationItem.title = webView.title
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let urlString = navigationAction.request.url!.absoluteString

        guard let range = urlString.range(of: "#access_token=") else {
            decisionHandler(.allow)
            return
        }

        decisionHandler(.cancel)

        DispatchQueue.main.async {
            self.success?(String(urlString[range.upperBound...]), self)
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let httpResponse = navigationResponse.response as? HTTPURLResponse else {
            decisionHandler(.allow)
            return
        }

        switch httpResponse.statusCode {
        case 400:
            decisionHandler(.cancel)
            DispatchQueue.main.async {
                self.failure?(InstagramError(kind: .invalidRequest, message: "Invalid request"), self)
            }
        default:
            decisionHandler(.allow)
        }
    }

}
