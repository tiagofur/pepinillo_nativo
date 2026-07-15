// SpacingTokens.swift
// Pepinillo — Deep Work Companion for Apple
//
// Canonical spacing scale (4pt base). Prefer these over ad-hoc paddings so
// margins/gaps feel like one system across screens.
//
//   • xs  (4)  — tight icon/label gaps, hairline insets
//   • sm  (8)  — compact vertical stacks, chip padding
//   • md  (16) — standard page horizontal inset, card internal padding
//   • lg  (20) — section padding, comfortable control insets
//   • xl  (24) — large section gaps, sheet content insets
//   • xxl (32) — bottom safe breathing room, empty-state padding

import CoreGraphics

enum SpacingTokens {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
