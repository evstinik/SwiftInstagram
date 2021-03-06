//
//  Instagram.swift
//  SwiftInstagram
//
//  Created by Ander Goig on 15/9/17.
//  Copyright © 2017 Ander Goig. All rights reserved.
//

import UIKit

/// A set of helper functions to make the Instagram API easier to use.

public class Instagram {

    // MARK: - Types

    public typealias EmptySuccessHandler = () -> Void
    public typealias SuccessHandler<T> = (_ data: T) -> Void
    public typealias FailureHandler = (_ error: InstagramError) -> Void

    typealias Parameters = [String: Any]

    private enum API {
        static let authURL = "https://api.instagram.com/oauth/authorize"
        static let baseURL = "https://api.instagram.com/v1"
    }

    private enum Keychain {
        static let accessTokenKey = "AccessToken"
    }

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case delete = "DELETE"
    }

    // MARK: - Properties

    private let urlSession = URLSession(configuration: .default)
    private let keychain = KeychainSwift(keyPrefix: "SwiftInstagram_")

    private var client: (id: String?, redirectURI: String?)?

    // MARK: - Initializers

    /// Returns a shared instance of Instagram.
    public static let shared = Instagram()

    private init() {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            let clientId = dict["InstagramClientId"] as? String
            let redirectURI = dict["InstagramRedirectURI"] as? String
            client = (clientId, redirectURI)
        }
    }

    // MARK: - Authentication

    /// Starts an authentication process.
    ///
    /// Shows a custom `UIViewController` with Intagram's login page.
    ///
    /// - parameter controller: The `UINavigationController` from which the `InstagramLoginViewController` will be showed.
    /// - parameter scopes: The scope of the access you are requesting from the user. Basic access by default.
    /// - parameter success: The callback called after a correct login.
    /// - parameter failure: The callback called after an incorrect login.

    public func login(from controller: UIViewController,
                      withScopes scopes: [InstagramScope] = [.basic],
                      success: EmptySuccessHandler?,
                      failure: FailureHandler?) {
        guard let authURL = buildAuthURL(scopes: scopes) else {
            failure?(InstagramError(kind: .missingClient, message: "Error while reading your Info.plist file settings."))
            return
        }
        
        if let navController = InstagramLoginViewController.instanceFromView {
            
            for child in navController.childViewControllers {
                if let vc = child as? InstagramLoginViewController {
                    vc.configure(authURL: authURL,
                                 success: { accessToken, sender in
                                    guard self.storeAccessToken(accessToken) else {
                                        sender.dismiss(animated: true, completion: nil)
                                        failure?(InstagramError(kind: .keychainError(code: self.keychain.lastResultCode), message: "Error storing access token into keychain."))
                                        return
                                    }
                                    sender.dismiss(animated: true, completion: nil)
                                    success?()
                    }, failure: { error, sender in
                        sender.dismiss(animated: true, completion: nil)
                        failure?(error)
                    })
                }
            }
            
            controller.present(navController, animated: true, completion: nil)
        }
    }

    private func buildAuthURL(scopes: [InstagramScope]) -> URL? {
        guard let client = client else {
            return nil
        }

        var components = URLComponents(string: API.authURL)!

        components.queryItems = [
            URLQueryItem(name: "client_id", value: client.id),
            URLQueryItem(name: "redirect_uri", value: client.redirectURI),
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: "+"))
        ]

        return components.url
    }

    /// Ends the current session.
    ///
    /// - returns: True if the user was successfully logged out, false otherwise.

    @discardableResult
    public func logout() -> Bool {
        return deleteAccessToken()
    }

    /// Returns whether a user is currently authenticated or not.

    public var isAuthenticated: Bool {
        return retrieveAccessToken() != nil
    }
    
    /// Returns current access token.
    
    public var accessToken: String? {
        return retrieveAccessToken()
    }

    // MARK: - Access Token

    private func storeAccessToken(_ accessToken: String) -> Bool {
        return keychain.set(accessToken, forKey: Keychain.accessTokenKey)
    }

    private func retrieveAccessToken() -> String? {
        return keychain.get(Keychain.accessTokenKey)
    }

    private func deleteAccessToken() -> Bool {
        return keychain.delete(Keychain.accessTokenKey)
    }

    // MARK: -

    func request<T: Decodable>(_ endpoint: String,
                               method: HTTPMethod = .get,
                               parameters: Parameters? = nil,
                               success: SuccessHandler<T>?,
                               failure: FailureHandler?) {
        var urlRequest = URLRequest(url: buildURL(for: endpoint, withParameters: parameters))
        urlRequest.httpMethod = method.rawValue

        urlSession.dataTask(with: urlRequest) { (data, _, error) in
            if let data = data {
                DispatchQueue.global(qos: .utility).async {
                    do {
                        let object = try JSONDecoder().decode(InstagramResponse<T>.self, from: data)
                        if let errorMessage = object.meta.errorMessage {
                            DispatchQueue.main.async {
                                failure?(InstagramError(kind: .invalidRequest, message: errorMessage))
                            }
                        } else {
                            DispatchQueue.main.async {
                                success?(object.data!)
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            failure?(InstagramError(kind: .jsonParseError, message: error.localizedDescription))
                        }
                    }
                }
            }
        }.resume()
    }

    private func buildURL(for endpoint: String, withParameters parameters: Parameters? = nil) -> URL {
        var urlComps = URLComponents(string: API.baseURL + endpoint)

        var items = [URLQueryItem]()

        // Every request needs the access token
        items.append(URLQueryItem(name: "access_token", value: retrieveAccessToken() ?? ""))

        parameters?.forEach({ parameter in
            items.append(URLQueryItem(name: parameter.key, value: "\(parameter.value)"))
        })

        urlComps!.queryItems = items

        return urlComps!.url!
    }

}
