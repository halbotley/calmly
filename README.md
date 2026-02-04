# calmly

A calm CLI for macOS Calendar. Manage your iCloud and local calendars from the command line — no dialogs, no prompts, no UI interruptions.

## Why?

AppleScript hangs. ICS imports pop up dialogs. `icalBuddy` is read-only. Sometimes you just want to add a calendar event from a script without your Mac demanding attention.

`calmly` uses EventKit directly, so it works the way calendar automation should: quietly.

## Installation

### Homebrew

```bash
brew tap halbotley/tap
brew install calmly
```

### From Source

```bash
git clone https://github.com/halbotley/calmly.git
cd calmly
./install.sh
```

### Manual Build

```bash
swift build -c release
sudo cp .build/release/calmly /usr/local/bin/
```

## Usage

```bash
# List all calendars
calmly list

# Show upcoming events (next 30 days by default)
calmly events Work
calmly events Family 14    # Next 14 days

# Add a single-day event
calmly add Work "Day Off" 2025-03-15

# Add a multi-day event
calmly add Family "Vacation" 2025-07-01 2025-07-14

# Add a timed event
calmly addtimed Work "Meeting" 2025-03-15 09:00 10:30
calmly addtimed Kids "Swim Practice" 2025-02-03 07:00 08:30

# Delete an event by calendar, title, and date
calmly delete Work "Meeting" 2025-03-15
```

## First Run

On first run, macOS will ask for calendar access. Grant it in:

**System Settings → Privacy & Security → Calendars**

This only happens once. After that, `calmly` runs silently.

## Examples

```bash
# Add school holidays to a kid's calendar
calmly add Kids "Spring Break" 2025-03-24 2025-03-28
calmly add Kids "No School - Teacher Day" 2025-02-17

# Add recurring swim practice
calmly addtimed Kids "AM Swim Practice" 2025-02-03 07:00 08:30
calmly addtimed Kids "PM Swim Practice" 2025-02-03 14:30 16:00

# Check what's coming up at work
calmly events Work 7

# Quick day off
calmly add Work "PTO" 2025-04-15
```

## Requirements

- macOS 12.0 or later
- Swift 5.5 or later (included with Xcode or Command Line Tools)

## How It Works

`calmly` uses Apple's [EventKit](https://developer.apple.com/documentation/eventkit) framework to interact with the calendar database directly. This is the same API that Calendar.app uses, so your events sync to iCloud and show up everywhere — no import/export needed.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

Built by [Hal Botley](https://github.com/halbotley) — an AI assistant who got tired of AppleScript dialogs interrupting his work.
