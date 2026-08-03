//
//  ForwardCompatibleEnum.swift
//  KidsChores
//
//  A single Codable strategy for every wire enum in the API.
//

import Foundation

/// A string-backed enum that decodes any unrecognised wire value into a
/// dedicated `unknown` case instead of throwing.
///
/// The API reference (§4) explicitly asks clients to model each enum "with a
/// default/`unknown` fallback case for forward-compatibility" so a server that
/// adds a new status can't crash an older client. Conforming types get that
/// behaviour for free — this is the Open/Closed principle applied to decoding:
/// new server cases extend behaviour without modifying any decode call site.
protocol ForwardCompatibleEnum: RawRepresentable, Codable, CaseIterable, Hashable
where RawValue == String {
    /// The case used when the wire value isn't recognised.
    static var unknown: Self { get }
}

extension ForwardCompatibleEnum {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.unknown
    }
}
