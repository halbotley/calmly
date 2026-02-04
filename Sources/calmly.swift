#!/usr/bin/env swift

// calmly - A calm CLI for macOS Calendar
// Uses EventKit to manage iCloud/local calendars without UI dialogs or prompts.

import EventKit
import Foundation

let version = "1.2.0"
let store = EKEventStore()

// Request access synchronously
let semaphore = DispatchSemaphore(value: 0)
var accessGranted = false

if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents { granted, error in
        accessGranted = granted
        if let error = error {
            fputs("Error requesting access: \(error.localizedDescription)\n", stderr)
        }
        semaphore.signal()
    }
} else {
    store.requestAccess(to: .event) { granted, error in
        accessGranted = granted
        if let error = error {
            fputs("Error requesting access: \(error.localizedDescription)\n", stderr)
        }
        semaphore.signal()
    }
}
semaphore.wait()

guard accessGranted else {
    fputs("Calendar access not granted.\n", stderr)
    fputs("Grant access in: System Settings → Privacy & Security → Calendars\n", stderr)
    exit(1)
}

let args = CommandLine.arguments

func printUsage() {
    print("""
    calmly v\(version) - A calm CLI for macOS Calendar
    
    Usage: calmly <command> [options]
    
    Commands:
      list                              List all calendars
      events <calendar> [days]          Show events (default: 30 days ahead)
      add <calendar> <title> <date> [end_date]
                                        Add an all-day event (dates: YYYY-MM-DD)
      addtimed <calendar> <title> <date> <start_time> <end_time>
                                        Add a timed event (date: YYYY-MM-DD, times: HH:MM)
      delete <calendar> <title> <date>  Delete an event by title and date
      version                           Show version
    
    Examples:
      calmly list
      calmly events Work 14
      calmly add Family "Vacation" 2025-07-01 2025-07-14
      calmly add Work "Day Off" 2025-03-15
      calmly addtimed Conrad "Swim Practice" 2025-02-03 07:00 08:30
    
    Dates are in YYYY-MM-DD format. Times are in 24-hour HH:MM format.
    Multi-day events span from start to end (inclusive).
    """)
}

guard args.count >= 2 else {
    printUsage()
    exit(1)
}

let command = args[1]

switch command {
case "list":
    let calendars = store.calendars(for: .event).sorted { $0.title < $1.title }
    for cal in calendars {
        let typeStr: String
        switch cal.type {
        case .local: typeStr = "Local"
        case .calDAV: typeStr = "iCloud/CalDAV"
        case .exchange: typeStr = "Exchange"
        case .subscription: typeStr = "Subscription"
        case .birthday: typeStr = "Birthdays"
        @unknown default: typeStr = "Unknown"
        }
        print("\(cal.title) (\(typeStr))")
    }
    
case "events":
    guard args.count >= 3 else {
        fputs("Usage: calmly events <calendar> [days]\n", stderr)
        exit(1)
    }
    let calName = args[2]
    let days = args.count >= 4 ? Int(args[3]) ?? 30 : 30
    
    guard let calendar = store.calendars(for: .event).first(where: { $0.title.lowercased() == calName.lowercased() }) else {
        fputs("Calendar '\(calName)' not found. Run 'calmly list' to see available calendars.\n", stderr)
        exit(1)
    }
    
    let start = Calendar.current.startOfDay(for: Date())
    let end = Calendar.current.date(byAdding: .day, value: days, to: start)!
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
    let events = store.events(matching: predicate)
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    
    if events.isEmpty {
        print("No events in '\(calName)' for the next \(days) days.")
    } else {
        for event in events.sorted(by: { $0.startDate < $1.startDate }) {
            let startStr = formatter.string(from: event.startDate)
            if event.isAllDay {
                if let endDate = event.endDate, 
                   Calendar.current.dateComponents([.day], from: event.startDate, to: endDate).day ?? 0 > 1 {
                    let endStr = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: endDate)!)
                    print("\(startStr) → \(endStr): \(event.title ?? "Untitled") (all day)")
                } else {
                    print("\(startStr): \(event.title ?? "Untitled") (all day)")
                }
            } else {
                let startTime = timeFormatter.string(from: event.startDate)
                let endTime = timeFormatter.string(from: event.endDate)
                print("\(startStr): \(event.title ?? "Untitled") (\(startTime)-\(endTime))")
            }
        }
    }
    
case "add":
    guard args.count >= 5 else {
        fputs("Usage: calmly add <calendar> <title> <start_date> [end_date]\n", stderr)
        fputs("Dates should be YYYY-MM-DD format.\n", stderr)
        exit(1)
    }
    let calName = args[2]
    let title = args[3]
    let startDateStr = args[4]
    let endDateStr = args.count >= 6 ? args[5] : startDateStr
    
    guard let calendar = store.calendars(for: .event).first(where: { $0.title.lowercased() == calName.lowercased() }) else {
        fputs("Calendar '\(calName)' not found. Run 'calmly list' to see available calendars.\n", stderr)
        exit(1)
    }
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    
    guard let startDate = formatter.date(from: startDateStr) else {
        fputs("Invalid start date: \(startDateStr). Use YYYY-MM-DD format.\n", stderr)
        exit(1)
    }
    
    guard var endDate = formatter.date(from: endDateStr) else {
        fputs("Invalid end date: \(endDateStr). Use YYYY-MM-DD format.\n", stderr)
        exit(1)
    }
    
    // For all-day events, end date should be the day after the last day
    endDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
    
    let event = EKEvent(eventStore: store)
    event.title = title
    event.startDate = startDate
    event.endDate = endDate
    event.isAllDay = true
    event.calendar = calendar
    
    do {
        try store.save(event, span: .thisEvent)
        if startDateStr == endDateStr || args.count < 6 {
            print("✓ Created '\(title)' on \(startDateStr) in \(calendar.title)")
        } else {
            print("✓ Created '\(title)' from \(startDateStr) to \(endDateStr) in \(calendar.title)")
        }
    } catch {
        fputs("Failed to create event: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "addtimed":
    guard args.count >= 7 else {
        fputs("Usage: calmly addtimed <calendar> <title> <date> <start_time> <end_time>\n", stderr)
        fputs("Date: YYYY-MM-DD, Times: HH:MM (24-hour format)\n", stderr)
        exit(1)
    }
    let calName = args[2]
    let title = args[3]
    let dateStr = args[4]
    let startTimeStr = args[5]
    let endTimeStr = args[6]
    
    guard let calendar = store.calendars(for: .event).first(where: { $0.title.lowercased() == calName.lowercased() }) else {
        fputs("Calendar '\(calName)' not found. Run 'calmly list' to see available calendars.\n", stderr)
        exit(1)
    }
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    formatter.timeZone = TimeZone.current
    
    guard let startDate = formatter.date(from: "\(dateStr) \(startTimeStr)") else {
        fputs("Invalid start datetime: \(dateStr) \(startTimeStr). Use YYYY-MM-DD and HH:MM formats.\n", stderr)
        exit(1)
    }
    
    guard let endDate = formatter.date(from: "\(dateStr) \(endTimeStr)") else {
        fputs("Invalid end datetime: \(dateStr) \(endTimeStr). Use YYYY-MM-DD and HH:MM formats.\n", stderr)
        exit(1)
    }
    
    let event = EKEvent(eventStore: store)
    event.title = title
    event.startDate = startDate
    event.endDate = endDate
    event.isAllDay = false
    event.calendar = calendar
    
    do {
        try store.save(event, span: .thisEvent)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        print("✓ Created '\(title)' on \(dateStr) \(timeFormatter.string(from: startDate))-\(timeFormatter.string(from: endDate)) in \(calendar.title)")
    } catch {
        fputs("Failed to create event: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "delete":
    guard args.count >= 5 else {
        fputs("Usage: calmly delete <calendar> <title> <date>\n", stderr)
        fputs("Date should be YYYY-MM-DD format.\n", stderr)
        exit(1)
    }
    let calName = args[2]
    let title = args[3]
    let dateStr = args[4]
    
    guard let calendar = store.calendars(for: .event).first(where: { $0.title.lowercased() == calName.lowercased() }) else {
        fputs("Calendar '\(calName)' not found. Run 'calmly list' to see available calendars.\n", stderr)
        exit(1)
    }
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    
    guard let targetDate = formatter.date(from: dateStr) else {
        fputs("Invalid date: \(dateStr). Use YYYY-MM-DD format.\n", stderr)
        exit(1)
    }
    
    // Search events on that day
    let startOfDay = Calendar.current.startOfDay(for: targetDate)
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: [calendar])
    let events = store.events(matching: predicate)
    
    // Find matching event by title (case-insensitive)
    let matching = events.filter { ($0.title ?? "").lowercased() == title.lowercased() }
    
    if matching.isEmpty {
        fputs("No event '\(title)' found on \(dateStr) in \(calendar.title).\n", stderr)
        exit(1)
    }
    
    // Delete all matching events (usually just one)
    var deleted = 0
    for event in matching {
        do {
            try store.remove(event, span: .thisEvent)
            deleted += 1
        } catch {
            fputs("Failed to delete event: \(error.localizedDescription)\n", stderr)
        }
    }
    
    if deleted > 0 {
        print("✓ Deleted '\(title)' on \(dateStr) from \(calendar.title)")
    } else {
        fputs("Failed to delete any events.\n", stderr)
        exit(1)
    }

case "version", "--version", "-v":
    print("calmly v\(version)")
    
case "help", "--help", "-h":
    printUsage()
    
default:
    fputs("Unknown command: \(command)\n", stderr)
    printUsage()
    exit(1)
}
