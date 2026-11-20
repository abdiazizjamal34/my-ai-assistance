# Voice Setup

Voice is enabled by default in Flutter. Disable it while testing text-only behavior with:

```powershell
cd mobile
flutter run --dart-define=VOICE_ENABLED=false
```

Android requires `android.permission.RECORD_AUDIO`. iOS requires microphone and speech-recognition usage descriptions in `Runner/Info.plist`. The plugins request runtime permission when the user first starts voice input.

The first implementation uses device speech recognition and device text-to-speech. No STT/TTS API keys are stored in Flutter or sent through `--dart-define`. Provider-specific network processing and credentials are not part of this sprint.

Run setup and checks with:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```
