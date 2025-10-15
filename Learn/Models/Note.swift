//
//  Note.swift
//  Learn
//
//  Created by Omakala on 12.10.2025.
//

import Foundation

struct Note: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var content: String
    var date: Date = Date()
    var isCollaborative: Bool = false
    var collaborativeId: String? = nil
}
