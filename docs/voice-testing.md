# Voice Testing

The Flutter voice tests use fake STT, TTS, and HTTP clients. They verify that:

- A transcript reaches the existing agent API.
- The returned agent response is spoken.
- Empty transcripts never reach the agent.
- Voice errors are recoverable.
- Markdown and URLs are normalized before TTS.

Run them with:

```powershell
cd mobile
flutter test test/voice_assistant_test.dart
```

The full Flutter checks remain:

```powershell
flutter analyze
flutter test
```

Hardware microphone permission, device speech recognition, speaker output, OS interruptions, and real task/reminder conversations require a manual test on a configured Android or iOS device. No always-on listening or wake-word behavior is implemented.
