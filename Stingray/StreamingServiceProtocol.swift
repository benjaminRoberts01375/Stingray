//
//  StreamingService.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

protocol StreamingService {
    var url: URL? { get }
    var usersName: String { get }
    var loggedIn: Bool { get }

    func login(httpProtocol: HttpProtocol, hostname: String, port: String, username: String, password: String) async throws
}
