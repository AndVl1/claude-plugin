# Mobile Testing Skill

Reference for manual QA testing of KMP Compose Multiplatform apps using MCP mobile automation tools.

## Quick Reference: MCP Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `list_devices` | Find emulators/devices | Start of test |
| `set_device` | Select target device | Multi-device testing |
| `launch_app` | Start application | Begin test session |
| `screenshot` | Capture screen state | Visual verification |
| `get_ui` | Get UI hierarchy | Element discovery |
| `tap` | Click on element | Button clicks, navigation |
| `swipe` | Scroll/gesture | Lists, carousels |
| `input_text` | Type text | Form fields |
| `press_key` | Hardware keys | BACK, HOME, ENTER |
| `get_logs` | Read device logs | Error detection |
| `shell` | Execute commands | Advanced debugging |

## Testing Environments

### Android Emulator (Fastest)
```
Device: emulator-5554
Package: com.your-project.admin
Use: Daily development testing
Setup: Android Studio -> AVD Manager
```

### iOS Simulator (macOS)
```
Device: iPhone 15 Simulator
Bundle ID: com.your-project.admin
Use: iOS-specific testing
Setup: Xcode -> Simulators
```

### Physical Devices (Final)
```
Android: USB debugging enabled
iOS: Developer mode enabled
Use: Final validation, performance testing
```

### Desktop (JVM)
```
Run: ./gradlew :composeApp:run
Platforms: macOS, Windows, Linux
Use: Desktop-specific features
```

## Standard Test Workflow

### 1. Setup
```
list_devices(platform: "android")     # Find devices
set_device(deviceId: "emulator-5554") # Select device
clear_logs()                          # Clear log buffer
launch_app(package: "com.your-project.admin")
wait(ms: 2000)                        # Wait for launch
screenshot()                          # Verify initial state
```

### 2. UI Interaction
```
get_ui()                              # Discover elements
tap(text: "Settings")                 # Navigate
wait(ms: 500)
screenshot()                          # Verify transition
```

### 3. Form Input
```
tap(text: "Search")                   # Focus field
input_text(text: "test query")        # Type text
press_key(key: "ENTER")               # Submit
wait(ms: 1000)
screenshot()
```

### 4. Log Verification
```
get_logs(package: "com.your-project.admin", level: "E")
# Check for: crashes, exceptions, errors
```

### 5. State Inspection
```
get_current_activity()                # Verify screen
get_system_info()                     # Check resources
```

## MCP Tool Details

### Device Management

#### list_devices
```
list_devices()                        # All devices
list_devices(platform: "android")     # Android only
list_devices(platform: "ios")         # iOS only
```

#### set_device
```
set_device(deviceId: "emulator-5554")
set_device(deviceId: "iPhone 15")
```

#### get_system_info
```
get_system_info()
# Returns: battery level, memory usage (Android)
```

### App Control

#### launch_app
```
launch_app(package: "com.your-project.admin")      # Android
launch_app(package: "com.your-project.admin")      # iOS (bundle ID)
```

#### stop_app
```
stop_app(package: "com.your-project.admin")        # Force stop
```

#### install_app
```
install_app(path: "/path/to/app.apk")          # Android
install_app(path: "/path/to/App.app")          # iOS Simulator
```

#### get_current_activity
```
get_current_activity()                          # Android only
# Returns: current package/activity
```

### UI Interaction

#### screenshot
```
screenshot()                                    # Default quality
screenshot(quality: 90)                         # Higher quality
screenshot(maxWidth: 400, maxHeight: 800)       # Smaller size
```

#### get_ui
```
get_ui()                                        # Interactive elements
get_ui(showAll: true)                           # All elements
# Returns: UI hierarchy with element refs
```

#### tap
```
tap(x: 200, y: 400)                             # By coordinates
tap(text: "Settings")                           # By text (Android)
tap(index: 5)                                   # By index (Android)
tap(resourceId: "btn_save")                     # By ID (Android)
```

#### long_press
```
long_press(x: 200, y: 400)                      # Default 1000ms
long_press(x: 200, y: 400, duration: 2000)      # Custom duration
long_press(text: "Item")                        # By text (Android)
```

#### swipe
```
swipe(direction: "up")                          # Scroll down
swipe(direction: "down")                        # Scroll up
swipe(direction: "left")                        # Next page
swipe(direction: "right")                       # Previous page
swipe(x1: 200, y1: 800, x2: 200, y2: 200)       # Custom swipe
swipe(x1: 200, y1: 400, x2: 200, y2: 400, duration: 500)  # Slow swipe
```

#### input_text
```
input_text(text: "Hello World")                 # Type into focused field
```

#### press_key
```
press_key(key: "BACK")                          # Hardware back
press_key(key: "HOME")                          # Home button
press_key(key: "ENTER")                         # Enter/Return
press_key(key: "TAB")                           # Tab key
press_key(key: "DELETE")                        # Delete/Backspace
press_key(key: "VOLUME_UP")                     # Volume up
press_key(key: "VOLUME_DOWN")                   # Volume down
```

#### find_element
```
find_element(text: "Settings")                  # Android only
find_element(resourceId: "btn_save")            # Android only
find_element(className: "Button")               # Android only
find_element(clickable: true)                   # Filter by state
```

### Verification

#### get_logs
```
get_logs()                                      # Last 100 lines
get_logs(lines: 200)                            # More lines
get_logs(package: "com.your-project.admin")         # Filter by app
get_logs(level: "E")                            # Errors only
get_logs(tag: "NetworkClient")                  # Android: by tag

# Log levels (Android): V, D, I, W, E, F
# Log levels (iOS): debug, info, default, error, fault
```

#### clear_logs
```
clear_logs()                                    # Android only
```

#### shell
```
# Android (ADB shell)
shell(command: "dumpsys activity activities")  # Current activities
shell(command: "pm list packages")             # Installed packages
shell(command: "svc wifi disable")             # Disable WiFi
shell(command: "svc wifi enable")              # Enable WiFi
shell(command: "input keyevent 26")            # Power button

# iOS (simctl)
shell(command: "status_bar override --time '9:41'")
shell(command: "privacy grant all com.your-project.admin")
```

### Utilities

#### wait
```
wait(ms: 1000)                                  # Wait 1 second
wait(ms: 500)                                   # Wait 500ms
```

#### open_url
```
open_url(url: "https://your-project.ru")            # Open in browser
```

## Log Error Patterns

### Critical Errors (Must Fix)
```
FATAL EXCEPTION                     -> App crash
ANR in com.your-project.admin           -> App not responding
java.lang.NullPointerException      -> Null reference crash
java.lang.OutOfMemoryError          -> Memory issue
Process: com.your-project.admin, PID... -> Crash with stack trace
```

### Common Errors (Review)
```
NetworkError                        -> API call failed
SocketTimeoutException              -> Network timeout
UnknownHostException                -> No network/DNS issue
SSLHandshakeException               -> Certificate issue
JsonParseException                  -> Malformed response
```

### Compose/KMP Specific
```
IllegalStateException: Expected     -> State mismatch
Composition failed                  -> UI rendering error
Recomposition loop                  -> Infinite recomposition
Navigation error                    -> Decompose issue
```

## Test Scenarios

### Scenario: App Launch
1. `clear_logs()`
2. `launch_app(package: "com.your-project.admin")`
3. `wait(ms: 3000)`
4. `screenshot()` -> Verify home screen
5. `get_logs(level: "E")` -> No crashes

### Scenario: Navigation Flow
1. `get_ui()` -> Find navigation elements
2. `tap(text: "Settings")` -> Navigate
3. `wait(ms: 500)`
4. `get_current_activity()` -> Verify screen
5. `screenshot()`
6. `press_key(key: "BACK")` -> Navigate back
7. `wait(ms: 300)`
8. `screenshot()` -> Verify return

### Scenario: Form Submission
1. Navigate to form screen
2. `tap(text: "Name")` -> Focus field
3. `input_text(text: "Test User")`
4. `tap(text: "Email")`
5. `input_text(text: "test@example.com")`
6. `tap(text: "Save")`
7. `wait(ms: 1000)`
8. `screenshot()` -> Verify success
9. `get_logs(level: "E")` -> No errors

### Scenario: List Scrolling
1. Navigate to list screen
2. `screenshot()` -> Initial state
3. `swipe(direction: "up")` -> Scroll down
4. `wait(ms: 300)`
5. `screenshot()` -> New items
6. `swipe(direction: "up")` x3 -> Load more
7. `get_ui()` -> Verify items loaded

### Scenario: State Preservation
1. Navigate to detail screen
2. `screenshot()` -> Record state
3. `shell(command: "input keyevent 26")` -> Power button (lock)
4. `wait(ms: 1000)`
5. `shell(command: "input keyevent 26")` -> Unlock
6. `screenshot()` -> Verify state preserved
7. `press_key(key: "HOME")` -> Background app
8. `wait(ms: 2000)`
9. `launch_app(package: "com.your-project.admin")` -> Resume
10. `screenshot()` -> Verify navigation state

### Scenario: Error State
1. `shell(command: "svc wifi disable")` -> Disable network
2. Trigger network action
3. `wait(ms: 2000)`
4. `screenshot()` -> Verify error UI
5. `get_logs(level: "E")` -> Check error logged
6. `shell(command: "svc wifi enable")` -> Enable network
7. `wait(ms: 1000)`
8. Retry action
9. `screenshot()` -> Verify success

### Scenario: Deep Link
1. `stop_app(package: "com.your-project.admin")`
2. `shell(command: "am start -a android.intent.action.VIEW -d 'your-project://chat/123'")`
3. `wait(ms: 2000)`
4. `screenshot()` -> Verify deep link handled
5. `get_current_activity()` -> Verify correct screen

## Verification Checklist

### UI Verification
- [ ] App launches without crash
- [ ] Splash screen shows briefly
- [ ] Home screen renders correctly
- [ ] Navigation transitions are smooth
- [ ] Loading indicators visible
- [ ] Error dialogs/snackbars show correctly
- [ ] Empty states are informative
- [ ] Theme/colors consistent

### Compose-arch Compliance
- [ ] Screens handle loading state
- [ ] Screens handle error state
- [ ] Screens handle empty state
- [ ] Screens handle success state
- [ ] Back navigation works correctly
- [ ] State survives configuration change
- [ ] State survives process death

### Log Verification
- [ ] No crashes in logcat
- [ ] No ANRs (Application Not Responding)
- [ ] No uncaught exceptions
- [ ] Network errors logged appropriately
- [ ] No sensitive data in logs

### Performance Verification
- [ ] App startup < 2 seconds
- [ ] Screen transitions smooth (60fps)
- [ ] No memory leaks on repeated navigation
- [ ] Battery usage reasonable

## Platform-Specific Notes

### Android
```
Package name: com.your-project.admin
Log levels: V (Verbose), D (Debug), I (Info), W (Warning), E (Error), F (Fatal)
Shell: ADB commands available
Emulator: emulator-5554 (default)
```

### iOS
```
Bundle ID: com.your-project.admin
Log levels: debug, info, default, error, fault
Shell: simctl commands available
Simulator: iPhone 15 (default)
```

### Desktop (JVM)
```
Run: ./gradlew :composeApp:run
Platforms: macOS, Windows, Linux
Testing: Manual (no MCP tools)
Focus: Keyboard navigation, window resize
```

### WASM
```
Run: ./gradlew :composeApp:wasmJsBrowserRun
Testing: Use Chrome testing tools
Focus: Browser compatibility
```

## Limitations & Workarounds

| Limitation | Workaround |
|-----------|-----------|
| iOS get_ui limited | Use screenshot + coordinates |
| find_element Android only | Use tap(x, y) on iOS |
| clear_logs Android only | Restart simulator on iOS |
| shell varies by platform | Use platform-specific commands |
| No network mocking | Use shell to disable WiFi |
| No rotation via MCP | Use shell input commands |

## ADB Shell Commands (Android)

```bash
# Device info
adb shell getprop ro.build.version.sdk          # API level
adb shell dumpsys battery                       # Battery status
adb shell dumpsys meminfo com.your-project.admin    # Memory usage

# Screen control
adb shell input keyevent 26                     # Power button
adb shell input keyevent 82                     # Menu button
adb shell settings put system screen_brightness 200  # Brightness

# Network
adb shell svc wifi disable                      # WiFi off
adb shell svc wifi enable                       # WiFi on
adb shell svc data disable                      # Mobile data off

# App control
adb shell pm clear com.your-project.admin           # Clear app data
adb shell am force-stop com.your-project.admin      # Force stop
adb shell am start -a android.intent.action.VIEW -d "your-project://path"  # Deep link

# Input
adb shell input text "hello"                    # Type text
adb shell input tap 200 400                     # Tap at coords
adb shell input swipe 200 800 200 200           # Swipe gesture
```

## simctl Commands (iOS)

```bash
# Device control
xcrun simctl boot "iPhone 15"                   # Boot simulator
xcrun simctl shutdown "iPhone 15"               # Shutdown
xcrun simctl erase "iPhone 15"                  # Reset simulator

# App control
xcrun simctl install booted /path/to/App.app    # Install app
xcrun simctl uninstall booted com.your-project.admin  # Uninstall
xcrun simctl launch booted com.your-project.admin   # Launch app
xcrun simctl terminate booted com.your-project.admin  # Terminate

# Permissions
xcrun simctl privacy booted grant all com.your-project.admin   # Grant all
xcrun simctl privacy booted reset all com.your-project.admin   # Reset

# Status bar
xcrun simctl status_bar booted override --time "9:41"      # Set time
xcrun simctl status_bar booted clear                       # Reset

# Screenshots/Recording
xcrun simctl io booted screenshot /path/to/screenshot.png
xcrun simctl io booted recordVideo /path/to/video.mp4
```

## Release Checklist

### Functionality
- [ ] All screens accessible via navigation
- [ ] All buttons respond to taps
- [ ] Forms submit correctly
- [ ] Lists scroll and paginate
- [ ] Dialogs open/close properly
- [ ] Pull-to-refresh works

### Error Handling
- [ ] Network errors show user-friendly messages
- [ ] Invalid input rejected with clear errors
- [ ] App recovers from errors gracefully
- [ ] No crashes during normal flow

### State Management
- [ ] Navigation state preserved on back
- [ ] Form data preserved on rotation
- [ ] State survives backgrounding
- [ ] Deep links work correctly

### Performance
- [ ] App starts in < 2 seconds
- [ ] Transitions are smooth (60fps)
- [ ] Memory usage stable
- [ ] No jank on scrolling

### Security
- [ ] No sensitive data in logs
- [ ] Auth tokens not exposed
- [ ] Proper error messages (no stack traces)
