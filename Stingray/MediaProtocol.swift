//
//  MediaProtocol.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public protocol Media {
    var title: String { get }
    var description: String { get }
    var logoArtURL: String { get }
    var boxArtURL: String { get }
    var backgroundArtURL: String { get }
}
