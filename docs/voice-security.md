# Voice Security and Privacy

Voice audio is processed by the device STT plugin and is not persisted by this application. Only the resulting transcript is sent to the existing authenticated `/api/agent/chat` endpoint. The transcript follows the existing agent, memory, task, reminder, ownership, and logging rules.

The application does not log raw audio or add provider credentials to Flutter. TTS receives the assistant response locally. Memory remains data rather than instructions, and voice cannot bypass the existing tool registry or user ownership checks.

The current authentication mechanism is the development `x-user-id` header. It must be replaced by production authentication before release. Device speech-recognition privacy and retention behavior may vary by OS/provider; users should review their platform settings.
