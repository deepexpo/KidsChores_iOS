<div align="center">

<img src="KidsChores/KidsChores/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="112" alt="KidsChores app icon" />

# KidsChores — iOS

**A family chore-and-rewards app for teenagers, built in SwiftUI.**
Offline-first · iPad-adaptive · SOLID-structured · one codebase, two experiences.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-black)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI-blue)
![Architecture](https://img.shields.io/badge/architecture-MVVM%20%2B%20protocols-green)

</div>

---

## Why this project

Most chore apps are built for young children — sticker charts and confetti — and a 15-year-old
deletes them within a week. The design thesis here is **perceived fairness, not gamification**:
every point has a visible reason, non-completion is handled gracefully (excuse → parent review),
and the UI reads as a modern productivity/banking app rather than a kids' toy.

It's a **single SwiftUI codebase that renders two entirely different experiences** — teen and
parent — branched off the authenticated role, and adapts from iPhone to a full iPad
`NavigationSplitView` management surface. This repo is the **client**; it talks to a FastAPI backend
over a documented REST contract.

> This is a portfolio piece. The emphasis below is on **architecture and engineering decisions**,
> not just the feature list.

---

## Highlights

- 🧩 **Offline-first, done properly** — an optimistic **write outbox** (SwiftData) with per-action
  idempotency keys and FIFO drain, plus a **read cache** so Today/Week render instantly on a cold
  launch with no network. Conflicts (illegal state transitions) revert non-destructively.
- 🔐 **Resilient session layer** — an `actor` token provider that decodes the JWT `exp`, refreshes
  **pre-emptively** (with single-flight coalescing so a rotating refresh token isn't burned by a
  thundering herd), and self-recovers to the sign-in screen when a refresh is permanently rejected.
- 📱 **Genuinely adaptive iPad** — not a stretched phone. Parent side is a sidebar
  `NavigationSplitView`; teen side is a 2-column list/detail. Collapses to a tab bar in compact
  width via a single size-class branch.
- 🧱 **SOLID by construction** — interface-segregated service protocols, dependency inversion at
  every seam (views depend on protocols, never `URLSession`), and a forward-compatible enum
  decoding strategy that absorbs new server enum cases without touching a single call site.
- 👨‍👩‍👧 **Shared-device mode** — profile picker + per-teen PIN (server-verified with an offline
  fallback), gated by a parent passcode so a kid can't switch into the parent controls.
- 📊 **Reports** — per-teen completion-rate trend, points-per-week, and excuse frequency
  (**Swift Charts**), with excuse data styled as *informational, not accusatory*.
- ✨ **Purposeful motion & a warm theme** — animated launch, spring transitions, rolling-digit
  balances, colorful deterministic avatars, and a gradient Wallet hero. Restrained, never
  cartoonish, Reduce-Motion aware, and haptics used sparingly (meaningful confirmations only).

---

## Architecture

A layered, testable MVVM. Every arrow crosses a **protocol** boundary, so any layer can be
swapped or mocked.

```
┌───────────────────────────────────────────────────────────────┐
│  Features/  (SwiftUI Views + @Observable ViewModels)           │
│    Teen: Today · Week · Wallet    Parent: Inbox · Family ·      │
│    Tasks · Series · Reports · Account · Household               │
│    SharedDevice · Auth                                          │
└───────────────┬───────────────────────────────────────────────┘
                │ depends on narrow capability protocols (ISP)
┌───────────────▼───────────────────────────────────────────────┐
│  Networking/   AuthService · TaskService · ApprovalService …   │
│                (protocols)  ──►  LiveAPIClient (one concrete)   │
│                HTTPClient transport seam (DIP) ──► URLSession   │
├────────────────────────────────────────────────────────────────┤
│  Persistence/  Outbox (offline writes) · TaskCache (SwiftData)  │
│  Services/     DefinitionCache (title join) · WeekdayMask       │
│  App/          AppContainer (composition root) · AppSession     │
│                TokenProvider (actor, JWT refresh)               │
├────────────────────────────────────────────────────────────────┤
│  Models/       Codable DTOs · ForwardCompatibleEnum            │
│  DesignSystem/ TaskRow · PointPill · StatusBadge · BrandMark …  │
└────────────────────────────────────────────────────────────────┘
```

**Design principles applied:**

| Principle | Where it shows up |
|---|---|
| **S**ingle responsibility | Presentation mapping (`StatusStyle`) split from views; transport split from endpoints. |
| **O**pen/closed | `ForwardCompatibleEnum` decodes unknown server enum values into an `unknown` case — new backend states never break an old client. |
| **L**iskov | Services are protocols; `LiveAPIClient` and test/preview fakes are substitutable. |
| **I**nterface segregation | The Today screen takes a `TaskService`, the Inbox an `ApprovalService` — not one god-client. |
| **D**ependency inversion | Views/VMs depend on protocols; `AppContainer` is the only place concrete types are wired. |

---

## Engineering deep-dives

A few decisions I'm happy with:

**Offline write path.** `complete`/`excuse` write an optimistic local status *and* enqueue a
durable `OutboxAction` (SwiftData) carrying an idempotency key generated **once**. The outbox
drains FIFO on connectivity; the same key is reused on every retry, so a flaky network can never
double-award points. A `422` (the parent cancelled the task while the teen was offline) reverts the
optimistic state with a quiet inline notice instead of a modal interrupt.

**Working around real API gaps.** The backend's task-instance responses don't populate `title`,
so an `actor DefinitionCache` joins titles client-side and drives its own refresh policy. Wire
enums are modelled with an `unknown` fallback for forward-compatibility. These aren't hacks —
they're deliberate seams documented at each site.

**Token refresh as an actor.** Concurrent requests coalesce onto a single in-flight refresh so a
single-use rotating refresh token isn't invalidated by simultaneous callers; the refresh call uses a
bare `URLSession` to avoid a client↔provider dependency cycle.

**Adaptive layout with zero duplication.** The parent tab bar and iPad sidebar are two renderings
of one `ParentSection` enum feeding one `parentSectionView(...)` builder. Teen screens use
`NavigationSplitView`, which is inherently adaptive — 2-column on iPad, push navigation on iPhone —
so there's no per-size-class code to maintain.

---

## Feature tour

**Teen** — Today (glance-and-tap, swipe-to-complete, overdue pinned), Week (7-day scroll-snap),
Wallet (rounded balance, savings goal, claim composer, paginated ledger), Task Detail.

**Parent** — Inbox (task approvals *and* reward claims in one place — approve with an undo window,
deny-with-comment, **bulk** resolve; empty = the success state), Tasks (definition CRUD with
schedule types & weekday mask, plus **Series** create/edit/delete), Family (per-teen cards, adjust
points, add/remove teen, set/change/remove PIN), **Reports** (Swift Charts), and a clear split
between the personal **Account** (change password / sign out / delete account) and shared
**Household** settings.

**Shared family device** — profile picker → PIN unlock → teen surface scoped to that member,
running under the parent's token; parent passcode required to exit.

---

## Tech stack

- **SwiftUI**, iOS 17+ · `@Observable` (Observation), `NavigationSplitView`, `ScrollViewReader`
- **Swift Charts** — reports (trend lines + bars)
- **SwiftData** — offline outbox + read cache
- **URLSession** + `async/await` · hand-written `Codable` against a documented REST contract
- **Keychain** (session tokens + shared-device PINs) · **UIFeedbackGenerator** (haptics)
- No third-party dependencies.

---

## Project structure

```
KidsChores/KidsChores/
├── App/            Composition root, session, root navigation, token provider
├── Models/         Codable DTOs + forward-compatible enums
├── Networking/     Transport seam, segregated service protocols, live client
├── Persistence/    SwiftData outbox + read cache
├── Services/       Definition cache, weekday-mask helper
├── DesignSystem/   Reusable components (rows, pills, badges, brand mark, haptics)
└── Features/
    ├── Auth/  Teen/{Today,Week,Wallet}  SharedDevice/
    └── Parent/{Inbox,Family,Tasks,Series,Settings}
```

---

## Getting started

Requires Xcode 15+ and the KidsChores FastAPI backend running locally.

```bash
# 1. Open the project
open KidsChores/KidsChores.xcodeproj

# 2. Point the app at your backend (Edit Scheme → Run → Environment Variables)
API_BASE_URL = http://<your-mac-lan-ip>:8000     # localhost works on the Simulator

# 3. For a local HTTP backend, add an ATS exception in the target's Info tab:
#    App Transport Security Settings → Allow Local Networking = YES
```

Run on the iOS Simulator or a device on the same network. The base URL is read from the
`API_BASE_URL` environment variable, falling back to `http://localhost:8000`.

---

## Status & roadmap

**Built:** full teen + parent feature set, offline read/write, email auth (login/register/refresh),
shared-device mode, iPad adaptivity, motion & haptics.

**Deferred (external blockers, not code):**
- *Sign in with Apple* — implemented behind the `AuthService` protocol; awaiting Apple Developer
  Program enrollment for the entitlement.
- *Push notifications (APNs)* — client contract ready; awaiting the entitlement and backend
  delivery.
- Several features are **built and wired against proposed REST endpoints** the backend hasn't
  shipped yet (change-password, delete-account, member-PIN update, series `PATCH`, per-teen reports,
  list-claims). Each is documented as a spec and degrades gracefully until the endpoint exists — a
  deliberate "build the client, hand the backend a contract" workflow.

---

<div align="center">
<sub>Built with SwiftUI. Client for a Python/FastAPI backend.</sub>
</div>
