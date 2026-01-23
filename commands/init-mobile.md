---
description: Create KMP Compose Multiplatform mobile project (Android/iOS/Desktop/WASM)
argument-hint: project-name (default your-project-admin)
---

# Initialize Mobile Project

Creates a complete, buildable Kotlin Multiplatform mobile application.

## What Gets Created

A full KMP project with:
- **Multi-module architecture** (feature-based + api/impl separation)
- **All platforms**: Android, iOS, Desktop (JVM), Web (WASM)
- **Compose Multiplatform** for shared UI
- **Decompose** for navigation and components
- **Metro DI** for compile-time dependency injection
- **Ktor Client** for HTTP networking
- **Room** database (Android/iOS/JVM)
- **DataStore** for preferences
- **Material3** theming
- **Sample feature** demonstrating all patterns

## Project Structure

```
$ARGUMENTS/ (default: your-project-admin/)
├── core/
│   ├── common/       # Utilities, Result types
│   ├── data/         # DataStore preferences
│   ├── database/     # Room (mobile + desktop)
│   ├── network/      # Ktor HTTP client
│   └── ui/           # Theme, components, resources
│
├── feature/
│   └── home/
│       ├── api/      # Public interfaces
│       └── impl/     # Implementation + UI
│
├── composeApp/       # Platform entry points
│   ├── androidMain/  # MainActivity
│   ├── iosMain/      # MainViewController
│   ├── jvmMain/      # Desktop main()
│   └── wasmJsMain/   # Web entry
│
└── iosApp/           # Xcode project
```

## Usage

```
/init-mobile                    # Creates your-project-admin/
/init-mobile my-app             # Creates my-app/
```

## After Creation

```bash
# Navigate to project
cd $ARGUMENTS

# Build all platforms
./gradlew assemble

# Run on Android
./gradlew :composeApp:installDebug

# Run Desktop
./gradlew :composeApp:run

# For iOS: open iosApp/ in Xcode
```

## Standalone Capability

The generated project is fully standalone:
- No dependencies on parent project
- Can be moved to separate repository
- Includes all Gradle wrapper files
- Complete build configuration

---

## Execution

Project name: **$ARGUMENTS** (defaults to "your-project-admin" if empty)

Launching init-mobile agent to create the project...
