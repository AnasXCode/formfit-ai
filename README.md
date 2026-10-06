# FormFit AI

**FormFit AI** is an AI-powered fitness app built with Flutter. It uses on-device pose detection to watch you exercise in real time, corrects your form, and counts only the reps you do correctly.

Train. Compete. No dishonest reps.

---

## ✨ Features

- **Real-time pose detection** — Google ML Kit tracks your body through the camera, no internet required during the workout.
- **AI-powered rep counting** — push-ups are counted only when the form is actually correct: full depth reached, body kept straight, arms locked out at the top.
- **Live form coaching** — on-screen cues like *"Go lower"*, *"Lift your hips"* and *"Good form"* guide you while you train.
- **Side-view and front-view support** — works whether the phone is propped on the floor beside you or facing you.
- **Session summary** — reps, duration and a form-accuracy score (blended from rep quality and time spent in good form) after every workout.
- **History** — Daily / Weekly / Monthly views with a tappable bar chart, rest-day tracking and per-day breakdowns.
- **Daily goal ring** — set a personal rep target and track progress on the Home screen.
- **Leaderboard** — This Week and All Time boards, with an animated spotlight on the top 3 (gold / silver / bronze shine and glow).
- **Profile** — Google or Guest sign-in, editable display name, custom avatar colour, and a profile photo you can view full-screen or change from the gallery.
- **Appearance** — System / Light / Dark theme, saved on the device.
- **Resilient saving** — if you're offline, your workout is queued and uploaded automatically once you're back online; if a save genuinely fails, you get a clear retry prompt instead of silently losing your workout.
- **Workout session UX** — 3‑2‑1 countdown before counting starts, pause/resume mid-session, and the screen stays awake for the whole workout.

---

## 🛠 Tech stack

| Layer | Technology |
|---|---|
| App framework | [Flutter](https://flutter.dev) (Dart) |
| State management | [Riverpod](https://riverpod.dev) |
| Navigation | [go_router](https://pub.dev/packages/go_router) |
| Auth | Firebase Authentication (Google Sign‑In + Anonymous/Guest) |
| Database | Cloud Firestore |
| Pose detection | [google_mlkit_pose_detection](https://pub.dev/packages/google_mlkit_pose_detection) |
| Camera | [camera](https://pub.dev/packages/camera) |
| Local storage | shared_preferences |

---

## 📸 Screenshots

<table>
  <tr>
    <th align="center">Home</th>
    <th align="center">Exercise</th>
    <th align="center">History</th>
  </tr>
  <tr>
    <td align="center"><img src="https://github.com/user-attachments/assets/bdcc7356-985b-4ce4-84b7-cbf9072bca13" alt="Home" width="220" /></td>
    <td align="center"><img src="https://github.com/user-attachments/assets/21832522-5ba1-4be2-9bef-87b659c12d5e" alt="Exercise" width="220" /></td>
    <td align="center"><img src="https://github.com/user-attachments/assets/b0b4b04d-dba4-4d5a-8cba-9a505dd6aa49" alt="History" width="220" /></td>
  </tr>
</table>

<table>
  <tr>
    <th align="center">Leaderboard</th>
    <th align="center">Profile</th>
    <th align="center">More</th>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/leaderboard.png" alt="Leaderboard" width="220" /></td>
    <td align="center"><img src="screenshots/profile.png" alt="Profile" width="220" /></td>
    <td align="center"><img src="https://github.com/user-attachments/assets/687d53cb-d80e-40ea-8225-f7e532b56318" alt="More" width="220" /></td>
  </tr>
</table>

<p align="center">
  <img src="https://github.com/user-attachments/assets/a7f4b8ea-b25e-4ee5-9d74-c56aa8a681df" alt="App screen" width="220" />
</p>

---

## 🚀 Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- A physical Android or iOS device — pose detection needs a real camera and does not work well on an emulator
- A [Firebase](https://firebase.google.com/) project with **Authentication** (Google + Anonymous providers) and **Cloud Firestore** enabled

### Setup

```bash
# Clone the repo
git clone https://github.com/AnasXCode/formfit-ai.git
cd formfit-ai

# Install dependencies
flutter pub get

# Run on a connected device
flutter run
```

### Firebase configuration

This project uses [FlutterFire](https://firebase.flutter.dev/) for Firebase setup. `lib/firebase_options.dart` is already generated for this project's Firebase instance. To connect your own Firebase project instead:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### Firestore security rules

Each user should only be able to read the leaderboard and write to their own document:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null && request.auth.uid == uid;

      match /sessions/{sessionId} {
        allow read, create: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```

> ⚠️ Treat these as a starting point, not production-ready rules — review them before shipping.

---

## 📂 Project structure

```
lib/
├── models/        # Data models (WorkoutSession, UserProfile, Exercise, ...)
├── pose/          # Pose-detection logic: angle math, rep counting, skeleton overlay
├── providers/      # Riverpod providers (auth, sessions, leaderboard, theme, goals)
├── router/         # go_router route definitions
├── screens/        # Top-level app screens
├── theme/          # Colours, text styles, ThemeData
├── widgets/         # Reusable UI components
├── firebase_options.dart
└── main.dart
```

---

## 🧠 How rep counting works

Push-up form is evaluated from the joint positions ML Kit returns each frame:

1. **Elbow angle** (shoulder → elbow → wrist) tracks how low you go. A rep only counts once the elbow bends past a set depth threshold.
2. **Body-line angle** (shoulder → hip → ankle) checks that the body stays straight — sagging or piking hips rejects the rep.
3. A short frame-stability window filters out single noisy detections so one bad frame can't falsely count — or reject — a rep.

The same frames feed a **form score**: part rep accuracy (good reps ÷ attempted reps), part time spent in good form while actively exercising.

<p align="center">
  <img src="https://github.com/user-attachments/assets/a8263532-adc2-4526-86af-56c48f0105b6" alt="Push-up detection guide" width="600" />
</p>

---

## 🗺 Roadmap

- [ ] Voice feedback ("go lower", rep counts) so you don't need to watch the screen
- [ ] Additional exercises (squats, sit-ups, lunges, plank)
- [ ] Auto-calibration to each user's own range of motion
- [ ] Friends & challenges
- [ ] Workout reminders/notifications
- [ ] Achievements and badges

---

## 🤝 Contributing

Issues and pull requests are welcome. For larger changes, please open an issue first to discuss what you'd like to change.

## 📄 License

No license has been chosen yet for this project. All rights reserved by the author until one is added.

## 👤 Author

**Anas Ahmed** — [@AnasXCode](https://github.com/AnasXCode)
