//
//  Route.swift
//  Nurikabe
//
//  One navigation vocabulary; ContentView owns the single destination switch.
//

import Foundation

nonisolated enum Route: Hashable {
    case play(PlaySource)
    case learn
    case rule(RuleStep)
    case lesson(Technique)
    case stats
    case settings
}
