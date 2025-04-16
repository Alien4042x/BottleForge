//
//  Bottle.swift
//  BottleForge
//
//  Created by Radim Veselý on 28.03.2025.
//

import Foundation

struct Bottle: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let path: URL
}
