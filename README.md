# Boundless

Boundless F.C. — find games, run tournaments and track your team.

A Flutter app (Android · iOS · Web) backed by Supabase.

## Brand

The visual identity is taken from the club crest (`assets/images/newlogo.png`):
a deep navy field, the cream/ivory eagle, and antique-gold shading.

| Token | Hex | Role |
| --- | --- | --- |
| `AppColors.gold` | `#C9A961` | Primary accent — the crest gold |
| `AppColors.goldDeep` | `#8A6A2F` | Shadow end of every metal sweep |
| `AppColors.goldLight` | `#F0D89B` | Highlight end of every metal sweep |
| `AppColors.cream` | `#F5EBD2` | High-emphasis text, light fills |
| `AppColors.ice` | `#8FB9E8` | Cool accent — info / verified |
| `AppColors.navy` | `#131C2E` | Crest background |
| `AppColors.navyDeep` | `#0A0F1A` | App background |

Depth is expressed through three devices, all defined in
[`lib/core/theme/app_colors.dart`](lib/core/theme/app_colors.dart): **metal
gradients** (dark→light→dark sweeps), **bevels** (light top edge, dark bottom
edge) and **layered shadows** (tight contact shadow + wide ambient one, with an
optional gold glow on primary actions).

Use the tokens rather than raw hex values so a future palette change stays a
one-file edit.

## Getting started

```bash
flutter pub get
flutter run
```

Copy `.env.example` to `.env` and fill in the Supabase credentials first.

Regenerate the launcher icons after changing the crest:

```bash
dart run flutter_launcher_icons
```
