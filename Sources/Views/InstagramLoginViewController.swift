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

    private var authURL: URL?
    private var success: SuccessHandler?
    private var failure: FailureHandler?

    // MARK: - Initializers
    
    static var instanceFromView: UIViewController? {
        let bundle = Bundle(for: self)
        let storyboard = UIStoryboard(name: "Instagram", bundle: bundle)
        return storyboard.instantiateInitialViewController()
    }
    
    func configure(authURL: URL, success: SuccessHandler?, failure: FailureHandler?) {
        self.authURL = authURL
        self.success = success
        self.failure = failure
    }
    
    @IBOutlet private weak var webView: UIWebView!
    
    fileprivate var stopButton: UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .stop,
                        target: self,
                        action: #selector(stopAction(_:)))
    }
    
    fileprivate var refreshButton: UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .refresh,
                        target: self,
                        action: #selector(refreshAction(_:)))
    }
    
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        }
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                                      target: self,
                                                                      action: #selector(doneClicked(_:)))

        // Starts authorization
        if let url = authURL {
            webView.loadRequest(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
        }
    }
    
    @objc private func doneClicked(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
        self.failure?(InstagramError(kind: .canceled, message: "Canceled"), self)
    }
    
    private func clearCookies() {
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                if cookie.domain.range(of: "instagram") != nil {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
            }
        }
    }
    
    @objc private func refreshAction(_ sender: Any) {
        webView.reload()
    }
    
    @objc private func stopAction(_ sender: Any) {
        webView.stopLoading()
        webViewDidFinishLoad(webView)
    }

}

// MARK: - WKNavigationDelegate

extension InstagramLoginViewController: UIWebViewDelegate {
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        let title = webView.stringByEvaluatingJavaScript(from: "document.title")
        navigationItem.title = title
        
        self.navigationItem.setRightBarButton(refreshButton, animated: true)
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        self.navigationItem.setRightBarButton(stopButton, animated: true)
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        guard let urlString = request.url?.absoluteString,
            let range = urlString.range(of: "#access_token=")  else { return true }
        
        DispatchQueue.main.async {
            self.clearCookies()
            self.success?(String(urlString[range.upperBound...]), self)
        }
        
        return true
    }

}
