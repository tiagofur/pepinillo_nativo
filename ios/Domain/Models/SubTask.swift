// SubTask.swift
// Pepinillo — Deep Work Companion for Apple

import Foundation
import SwiftData

@Model
public final class SubTask {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var sortOrder: Int
    public var createdAt: Date

    public var parent: TaskItem?

    public init(title: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.sortOrder = sortOrder
        self.createdAt = Date.now
    }
}
