# VCourse Bachelor's Thesis — Knowledge Base

A working directory of atomic `.md` notes that back the thesis text. Every factual claim in any chapter of the thesis should first be checked here. The thesis itself is in Russian; this index is in English purely to make navigation easier — individual notes remain in Russian (their language matches the audience of the final document).

## How to use

- One topic per file. Facts are not duplicated between files — cross-links are used instead.
- When a fact changes (e.g. the user count grows), update it **in one place only**.
- `clients/*.md` files are the result of in-depth reviews of the iOS / Android / Web repositories and are kept in sync with the code. If a client behavior changes, update the corresponding file before relying on it in the thesis.
- `pending-questions-backend.md` is the list of open questions for Maxim (the backend co-author). Once answered, facts move into `backend-contract.md` and the questions file shrinks.

## Index

### Project context

| File | Topic |
|------|-------|
| [00-project-overview.md](00-project-overview.md) | Project essence, ecosystem composition, scope of this thesis |
| [01-problem-and-audience.md](01-problem-and-audience.md) | Problem statement, target audiences, user pains |
| [02-competitors.md](02-competitors.md) | Direct and indirect competitors |
| [03-history-and-milestones.md](03-history-and-milestones.md) | Project timeline, September 2024 – May 2026 |
| [04-product-features.md](04-product-features.md) | Flagship product features |
| [05-design-system.md](05-design-system.md) | Design approach, native-first principle, Figma setup |
| [06-architecture-overview.md](06-architecture-overview.md) | High-level architecture of the ecosystem and client–backend contract |

### Clients (in-depth, from repo reviews)

| File | Topic |
|------|-------|
| [clients/ios.md](clients/ios.md) | iOS app: SwiftUI + SwiftData + WidgetKit, Liquid Glass adaptation, ~18.5k LoC |
| [clients/android.md](clients/android.md) | Android app: Kotlin + Jetpack Compose + Material 3 Expressive + Room, ~23.5k LoC |
| [clients/web-public.md](clients/web-public.md) | Public Web: landing + schedule viewer on Next.js 16 + React 19, with the Next.js BFF pattern |
| [clients/web-admin.md](clients/web-admin.md) | Admin Web service: workspace, schedule editor with atomic lesson model and undo/redo; written in hybrid mode (current state + target state for the defense) |

### Backend & infrastructure

| File | Topic |
|------|-------|
| [backend-contract.md](backend-contract.md) | Backend stack + the client–server contract observed from the clients (headers, endpoints, payloads) |
| [pending-questions-backend.md](pending-questions-backend.md) | Open questions for Maxim — to be merged into `backend-contract.md` once answered |
| [infra-and-ci.md](infra-and-ci.md) | Build, signing, distribution and CI/CD status for each client |

### Traction & approbation

| File | Topic |
|------|-------|
| [metrics-and-traction.md](metrics-and-traction.md) | Usage metrics, platform split, request load by university |
| [pilots-and-partners.md](pilots-and-partners.md) | Connected universities (parsing model) and ongoing pilot negotiations (SaaS model) |
| [apparobation-and-promo.md](apparobation-and-promo.md) | Store releases, Telegram channel, investment fund and grant activity |

### Authorship & glossary

| File | Topic |
|------|-------|
| [personal-contribution.md](personal-contribution.md) | Author's personal contribution and delineation from the co-author's thesis (backend) |
| [thesis-glossary.md](thesis-glossary.md) | Glossary of terms used in the thesis |

## Conventions

- **Language inside notes:** Russian (matches the thesis language).
- **Filenames:** kebab-case.
- **Cross-links:** use relative Markdown links — `[label](file.md)` or `[label](clients/file.md)`.
- **Hidden-from-thesis blocks:** if a note contains material that must stay in the knowledge base but **not** appear in the thesis text (e.g. the "current factual state" and "TODO before defense" sections of `clients/web-admin.md`, or the explicit "do not mention in the thesis" rules in `clients/android.md`), this is called out at the top of that file. Always re-read those constraints before lifting content into a chapter draft.
