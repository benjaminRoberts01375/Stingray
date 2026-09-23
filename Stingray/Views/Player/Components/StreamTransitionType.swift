//
//  StreamTransitionType.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

/// Dictates how the player should transition a particular stream
public enum StreamTransitionType {
    /// Do not transition to a new stream
    case keep
    /// Update the current stream to a new ID. Nil for no stream.
    case newID(String?)
}
