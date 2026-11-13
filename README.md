# Team Attendance

A staff attendance app for small teams. Employees check in when they arrive and check out when they leave. The app shows a today register, per employee monthly summaries, attendance history by date, and a CSV export.

Built with Flutter and Material 3, dark theme with a #39FF88 accent. Part of a one app per day reference build series by Partho Sarothi Paik. All code is original, written for this project.

## Features

- Employee list: add employees with a name and role, remove them when they leave
- Daily check in and check out with timestamps, one record per employee per day
- Today register: who is present, who checked out, who is absent, with live counts
- Monthly summary per employee: days present, total hours, average hours per day, late arrivals (after 9:15 AM)
- Attendance history: pick any date and see that day's full register
- CSV export: full history as CSV text with a copy button, ready to paste into a spreadsheet
- Demo seed data: 6 employees with this week's attendance on first run, so the app is useful immediately
- Reset data: from the refresh button in the AppBar, clear all data to start with an empty team, or restore the 6 person demo team
- Local persistence with shared_preferences, data survives app restarts

## How it works

By default the app runs in local demo mode. All data is stored on the device as JSON in shared_preferences. There is no account, no server, and no data leaves the device.

A Supabase schema is included at `supabase/schema.sql` so the app can be wired to a real backend later. It defines `employees` and `attendance` tables, a monthly summary view, and starter row level security policies. The app does not connect to Supabase yet: that wiring is a deliberate next step, not a hidden feature. See "Wiring up Supabase" below.

## Wiring up Supabase

1. Create a project at supabase.com and run `supabase/schema.sql` in the SQL editor.
2. Add the `supabase_flutter` package and initialise it in `main.dart` with your project URL and anon key.
3. Replace the shared_preferences save and load in `lib/state/attendance_provider.dart` with Supabase queries against the `employees` and `attendance` tables. Keep the same method names (`checkIn`, `checkOut`, `monthlySummary`, `toCsv`) so the screens do not change.
4. Tighten the starter row level security policies to your own roles before going live. The included policies allow any signed in user to manage both tables, which is a starting point, not a production setup.

## Run it

```bash
flutter pub get
flutter run
```

For a web build:

```bash
flutter build web
```

## Tests

```bash
flutter test
```

Unit tests cover check in and check out rules, monthly day counts and hours, late arrival counting, the today register, CSV export, and data reset (clear all and restore demo).

## Tech

- Flutter, Material 3, dark theme
- State: provider
- Storage: shared_preferences (JSON)
- Dates: intl
- Dependencies only: provider, intl, shared_preferences, flutter_lints (dev)
