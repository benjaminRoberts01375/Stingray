//
//  CollectionProtocol.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

protocol Library {
    var title: String { get }
    var media: [Media] { get }
}
