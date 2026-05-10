# Audio Playback Safeguards & Regression Prevention

This document defines the critical requirements and technical standards for the music player implementation to prevent common regressions.

## 1. Core Requirements (Non-Negotiable)
- **Background Continuity**: Music MUST transition to the next track even when the app is suspended, the screen is locked, or another app is in focus.
- **Lock Screen Sync**: System media controls (iOS Control Center, Android Notification) MUST display the correct metadata (Title, Artist, Artwork) and respond to Play/Pause/Skip commands.
- **No Hangs**: The UI must never stay in a "Loading" state (90%) indefinitely. If a stream fails, it must fallback or skip.

## 2. Technical Standards
- **Initialization Order**: `AudioSession` MUST be configured before `AudioService.init`.
- **Decoupling**: `AudioHandler` (Background) must never have direct synchronous dependencies on `GetX` controllers or UI state. Use `Streams` for communication.
- **Playlist Management**: Use `ConcatenatingAudioSource` for OS-native transitions. Do not rely on Dart-side timers or "onCompletion" listeners for the primary transition.
- **Network Resilience**: All stream URL fetching MUST include:
    - Minimum 3 retries with exponential backoff.
    - Strict 10-second timeout.
    - HTTPS only.

## 3. Testing Protocol (Before Every Release)
1. **The "App Switch" Test**: Start a song, switch to a heavy app (e.g., Camera, Browser), and ensure the song finishes and the next one starts.
2. **The "Lock Screen" Test**: Lock the device, wait for track end, and verify the next track's info appears on the lock screen.
3. **The "Offline" Test**: Disable internet during playback; verify the player attempts retries and shows a user-friendly error instead of hanging at 90%.

## 4. Common Pitfalls to Avoid
- **Empty Playlists**: Never call `setAudioSource` with an empty `ConcatenatingAudioSource` in `onInit`.
- **UI Blocking**: Never `await` a "pre-load" or "related video fetch" before calling `audioPlayer.play()`.
- **Native Contexts**: Avoid calling native plugins (like Wakelock) inside high-frequency listeners without try-catch blocks.
