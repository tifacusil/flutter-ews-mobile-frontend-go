# EWS Landslide Monitor — Flutter Frontend

Mobile app for the Early Warning System described in Bai et al. 2020.
Monitors two sites (**Shangtan** and **Lingzhan**) via five sensor types: GNSS, rainfall, strain, soil pressure, and deep displacement.

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter | ≥ 3.22 (tested on 3.44) |
| Dart | ≥ 3.12 |
| Android SDK | API 21+ |
| Java | 17 (required by Gradle) |

---

## First-time setup

```bash
# 1. Copy the environment template and fill in your API host and Firebase values
cp .env.example.json .env.json
#    Place the Firebase config at android/app/google-services.json (gitignored)

# 2. Install dependencies
flutter pub get

# 3. Generate Freezed models, JSON serializers, and Riverpod providers
dart run build_runner build --delete-conflicting-outputs

# 4. Connect a device or start an emulator, then run
flutter run --dart-define-from-file=.env.json

# Release APK
flutter build apk --release --dart-define-from-file=.env.json
```

> **Re-run steps 2–3** whenever you add a `@freezed` model, a new `@riverpod` provider, or change `pubspec.yaml`.

---

## Environment configuration

Runtime values are injected at build time via `--dart-define-from-file`. Copy `.env.example.json` to `.env.json` (gitignored) and set your values:

| Key | Default | Description |
|---|---|---|
| `API_BASE_URL` | `http://localhost/api/v1` | Nginx / API Gateway base URL |
| `API_CONNECT_TIMEOUT_MS` | `10000` | Dio connect timeout (ms) |
| `API_RECEIVE_TIMEOUT_MS` | `15000` | Dio receive timeout (ms) |
| `DEFAULT_POLLING_INTERVAL_S` | `3600` | Sensor polling interval (seconds) |
| `FIREBASE_API_KEY` | — | Firebase Android API key |
| `FIREBASE_APP_ID` | — | Firebase Android app ID |
| `FIREBASE_MESSAGING_SENDER_ID` | — | FCM sender ID |
| `FIREBASE_PROJECT_ID` | — | Firebase project ID |
| `FIREBASE_STORAGE_BUCKET` | — | Firebase storage bucket |

`android/app/google-services.json` is also required for Android builds. It is gitignored; download it from the Firebase console.

All constants are centralised in `lib/core/constants.dart`.

---

## Folder structure

```
lib/
├── core/
│   ├── constants.dart               # All app-wide constants; env values via fromEnvironment
│   ├── models/                      # Freezed + json_serializable data classes
│   │   ├── sensor_envelope.dart     # Wrapper for every sensor message
│   │   ├── gnss_payload.dart
│   │   ├── rainfall_payload.dart
│   │   ├── strain_payload.dart
│   │   ├── soil_pressure_payload.dart
│   │   ├── deep_displacement_payload.dart
│   │   ├── alert.dart
│   │   ├── alert_level.dart         # enum: blue / orange / red + mm/day thresholds
│   │   └── date_range.dart
│   ├── repositories/                # Abstract interfaces only — no HTTP code here
│   │   ├── sensor_repository.dart
│   │   ├── alert_repository.dart
│   │   └── auth_repository.dart
│   ├── services/
│   │   ├── api_service.dart         # Dio client with auth interceptor stub
│   │   ├── auth_service.dart        # JWT read/write via SharedPreferences
│   │   └── polling_service.dart     # Generic periodic poller → Stream<T>
│   ├── theme/
│   │   ├── app_theme.dart           # ShadThemeData (slate colour scheme)
│   │   ├── app_colors.dart          # Alert-level colours: blue / orange / red
│   │   └── text_styles.dart
│   └── utils/
│       ├── date_formatter.dart
│       ├── alert_level_helper.dart  # mm/day → AlertLevel enum
│       └── router_utils.dart        # AppRoutes constants + goTo/pushTo/popRoute extension
├── features/
│   ├── auth/
│   │   ├── viewmodels/
│   │   │   └── login_view_model.dart   # LoginState (isLoading, isSuccess, error) + mock login
│   │   └── views/
│   │       ├── login_screen.dart       # ref.listen → navigates on isSuccess
│   │       └── widgets/
│   │           ├── login_header.dart   # Logo icon + app title + subtitle
│   │           ├── login_form.dart     # ShadCard + ShadForm, holds form key
│   │           ├── username_field.dart # ShadInputFormField
│   │           ├── password_field.dart # ShadInputFormField + obscure toggle (@riverpod)
│   │           └── login_button.dart   # ShadButton with loading spinner
│   ├── projects/
│   │   ├── viewmodels/project_list_view_model.dart
│   │   └── views/
│   │       ├── project_list_screen.dart
│   │       └── project_detail_screen.dart
│   ├── sensors/
│   │   ├── viewmodels/sensor_dashboard_view_model.dart
│   │   └── views/
│   │       ├── sensor_dashboard_screen.dart
│   │       ├── gnss_chart_widget.dart        # cumulative_displacement_mm vs time (Fig 8a)
│   │       ├── rainfall_chart_widget.dart    # daily + cumulative rainfall (Fig 8b)
│   │       ├── deep_displacement_chart.dart  # tilt vs depth (borehole profile)
│   │       ├── strain_widget.dart
│   │       └── soil_pressure_widget.dart
│   └── alerts/
│       ├── viewmodels/alert_view_model.dart
│       └── views/
│           ├── alert_banner_widget.dart      # colour-coded by AlertLevel
│           └── alert_history_screen.dart
├── main.dart     # ProviderScope + ShadApp.router
└── router.dart   # GoRouter: /login  /projects  /projects/:id  /sensors/:id  /alerts
```

---

## Architecture

**Clean Architecture + Repository Pattern + MVVM with Riverpod 3**

```
View (Widget)
  └── watches/listens → ViewModel (@riverpod Notifier)
                           └── calls → Repository interface
                                          └── implemented by → HTTP data source (PollingService + ApiService)
```

- **No `setState`** anywhere — all state lives in Riverpod providers.
- **ViewModels** use `@riverpod` codegen (`Notifier<State>`). The `build()` method returns the initial state; `ref.onDispose` handles stream cleanup.
- **Repository interfaces** in `core/repositories/` are pure Dart; HTTP implementations will live in a `data/` layer (not yet created).
- **UI components** follow a composition pattern: screens own no logic, widgets are small and single-purpose.

---

## UI library

The app uses [shadcn_ui](https://pub.dev/packages/shadcn_ui) — a Flutter port of shadcn/ui. Components used so far: `ShadApp`, `ShadCard`, `ShadForm`, `ShadInputFormField`, `ShadButton`, `ShadIconButton`. The theme uses the **slate** colour scheme so alert colours (blue / orange / red) stand out clearly against the neutral base.

---

## Real-time data strategy (polling over HTTP)

The backend exposes REST endpoints through Nginx/API Gateway. There is no WebSocket layer.

`PollingService<T>` wraps any `Future<T> Function()` fetcher and emits values on a `Stream<T>` via `Stream.periodic`. The interval is driven by `sampling_interval_seconds` from the last received `SensorEnvelope` (default: **3600 s**). Errors are forwarded to a separate `errors` stream without cancelling the polling loop.

Repository interfaces return `Stream<T>` — callers never know whether the transport is HTTP polling, SSE, or WebSocket. A future transport upgrade is a data-layer concern only.

---

## Code generation

This project uses three generators, all run together via `build_runner`:

| Generator | Annotation | Output |
|---|---|---|
| `freezed` | `@freezed` on model classes | `*.freezed.dart` — `==`, `hashCode`, `copyWith`, `toString` |
| `json_serializable` | `@JsonSerializable` (via freezed) | `*.g.dart` — `fromJson` / `toJson` |
| `riverpod_generator` | `@riverpod` on Notifier classes | `*.g.dart` — typed provider variables |

Generated files (`*.freezed.dart`, `*.g.dart`) are committed so CI does not need to run `build_runner`.

---

## Navigation

Routes are defined in `router.dart` and referenced via `AppRoutes` constants in `core/utils/router_utils.dart`:

| Constant | Path | Screen |
|---|---|---|
| `AppRoutes.login` | `/login` | `LoginScreen` |
| `AppRoutes.projects` | `/projects` | `ProjectListScreen` |
| `AppRoutes.projectDetail(id)` | `/projects/:id` | `ProjectDetailScreen` |
| `AppRoutes.sensorDashboard(id)` | `/sensors/:id` | `SensorDashboardScreen` |
| `AppRoutes.alerts` | `/alerts` | `AlertHistoryScreen` |

Navigate using the `BuildContext` extension from `router_utils.dart`:

```dart
context.goTo(AppRoutes.projects);          // replace stack
context.pushTo(AppRoutes.sensorDashboard('LZ-01'));  // push onto stack
context.popRoute();
```

---

## Alert thresholds (Bai et al. 2020)

| Level | mm/day |
|---|---|
| Blue | ≥ 10 |
| Orange | ≥ 15 |
| Red | ≥ 20 |

---

## Sites and sensors

| Site | Sensor IDs |
|---|---|
| Shangtan | GXZM-DB01 … GXZM-DB08, GXZM-RG01 |
| Lingzhan | LZ-01, LZ-02, LZ-03 |
