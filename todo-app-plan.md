# Todo App — Plan & Requirements

## Overview

A focused, personal task management app for iOS. Designed to replace the iOS Reminders app for day-to-day admin tasks with a simpler, more opinionated experience. No collaboration, no projects, no overhead — just a clean ordered list with dates and Siri support. Order is set by drag-to-reorder; no fixed priority levels.

---

## Goals

- Capture and manage personal admin tasks quickly
- Surface what matters most via manual ordering
- Support due dates with overdue/upcoming awareness
- Allow hands-free task entry and removal via Siri
- Feel native, fast, and uncluttered on iPhone

---

## Non-Goals

- Team collaboration or task sharing
- Project or folder hierarchy
- Time tracking or recurring tasks (v1)
- Android or web support
- Third-party integrations

---

## Stack

| Layer | Choice | Rationale |
|---|---|---|
| Language | Swift | Native performance, best iOS tooling |
| UI | SwiftUI | Modern, declarative, pairs well with SwiftData |
| Persistence | SwiftData | Simple schema ownership, iCloud sync built-in |
| Cloud sync | CloudKit (via SwiftData) | Free, automatic, no backend to maintain |
| Siri / Shortcuts | App Intents | Full control over data model, Shortcuts support free |
| Min. deployment | iOS 17 | Required for SwiftData |

---

## Data Model

```swift
@Model
class Task {
    var id: UUID
    var title: String
    var sortOrder: Int            // manual position; lower = higher up the list
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
}
```

---

## Features

### Core (v1)

- **Add task** — title and optional due date; new tasks append to bottom of list
- **Complete task** — tap to mark done; completed tasks move to a separate Done section
- **Delete task** — swipe to delete
- **Edit task** — tap to edit title or date inline
- **Drag to reorder** — long press and drag to set position; order is the only priority signal
- **Due date labels** — contextual display: "Today", "Tomorrow", "3d", "2d ago" (overdue highlighted in red)
- **Filter tabs** — Active / Done with live counts
- **iCloud sync** — automatic via CloudKit, no setup required

### Siri / Shortcuts (v1)

Two App Intents:

**AddTaskIntent**
- Parameters: `title` (required), `dueDate` (optional)
- Phrase: *"Add [title] to [App Name]"*
- Phrase: *"Remind me to [title] in [App Name]"*
- Returns: confirmation with task summary; task appends to bottom of list

**DeleteTaskIntent**
- Parameters: `title` (fuzzy matched against existing tasks)
- Phrase: *"Remove [title] from [App Name]*"
- Requires: confirmation before deletion

Both intents should be donated to the system so they surface as Siri suggestions after use.

### Widgets (v1)

- Small: top 2 tasks by sort order
- Medium: top 4 tasks by sort order
- Both deep-link into the app on tap

---

## UI Screens

### Main List
- Navigation title: app name
- Filter tabs: Active / Done
- Task rows: drag handle, title, date badge
- Drag handle (or long press anywhere on row) to reorder
- Swipe actions: complete (left), delete (right)
- Floating + button to add task
- Empty state per filter

### Add / Edit Sheet
- Text field for title (auto-focused)
- Optional date picker (collapsed by default)
- Save / Cancel

### Settings (minimal)
- iCloud sync status
- Clear completed tasks
- App version

---

## Design Principles

- **Speed first** — adding a task should take under 5 seconds
- **No friction** — date is always optional; new tasks just go to the bottom
- **Order is everything** — position in the list is the only priority signal
- **iOS-native** — uses system fonts, standard gestures, native sheets and pickers
- **No accounts** — iCloud sync only, zero sign-up

---

## Phased Roadmap

### v1 — Core + Siri
- SwiftData model with iCloud sync
- Full CRUD with drag-to-reorder and date
- Active / Done filter tabs
- AddTaskIntent + DeleteTaskIntent
- Basic widgets

### v2 — Polish
- Recurring tasks (daily, weekly, monthly)
- Haptic feedback on reorder
- Lock screen widget
- Overdue task auto-bump to top (opt-in)

### v3 — Consider
- Natural language input ("dentist friday")
- Shortcut to capture from share sheet
- Mac Catalyst port

---

## Open Questions

- **App name** — TBD
- **Pricing** — Free with tip jar, or one-time purchase (~$2.99)?
- **Overdue behaviour** — Auto-bump overdue tasks to top of list, or just highlight?
- **Completed task retention** — Auto-clear after X days, or manual?
