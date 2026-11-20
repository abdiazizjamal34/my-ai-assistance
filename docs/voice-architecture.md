# Voice Architecture

Sprint 7 adds voice as an interface to the existing chat agent. No backend voice endpoint or voice-specific conversation store is required.

```text
Flutter microphone
  -> SpeechToTextProvider
  -> transcript
  -> PersonalApiService.sendAgentMessage
  -> existing AgentService, memory, tasks, reminders
  -> response text
  -> TextToSpeechProvider
  -> device speaker
```

`VoiceAssistantService` owns the state machine:

```text
IDLE -> REQUESTING_PERMISSION -> READY -> LISTENING -> PROCESSING -> SPEAKING -> IDLE
```

Failures enter `ERROR`. Tapping the microphone while speaking stops TTS before recording begins. Push-to-talk is intentional for this sprint: the user taps to start, taps to stop, and then the transcript goes through the normal agent request.

`SpeechToTextProvider` and `TextToSpeechProvider` are interfaces. The default adapters use `speech_to_text` and `flutter_tts`, so providers can be replaced without changing the chat screen or agent.
