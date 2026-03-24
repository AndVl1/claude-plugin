# Dark Mode Skill

**Version:** 1.0.0
**Author:** Klavdii R&D
**Last Updated:** 2026-03-25

---

## Overview

Implement comprehensive dark mode support for web applications with theme persistence across sessions. This skill provides a systematic approach to adding dark mode functionality to React-based applications using CSS variables and local storage.

---

## What is Dark Mode?

Dark mode is a color scheme that uses a dark background with light text. It's popular because:

1. **Reduced eye strain** - Less blue light exposure
2. **Energy efficiency** - Screens use less power on OLED displays
3. **Aesthetic appeal** - Modern, sleek look
4. **User preference** - Many users prefer dark mode for night use

---

## Core Concepts

### 1. Theme Storage

Store the user's theme preference in `localStorage`:

```kotlin
// Backend: Store theme preference in database
data class UserSettings(
    val theme: ThemeMode = ThemeMode.SYSTEM, // LIGHT, DARK, SYSTEM
    // ... other settings
)

// Frontend: Read from localStorage
const THEME_STORAGE_KEY = 'theme-preference'

function loadThemePreference(): ThemeMode {
    const saved = localStorage.getItem(THEME_STORAGE_KEY)
    return saved ? (saved as ThemeMode) : ThemeMode.SYSTEM
}

function saveThemePreference(theme: ThemeMode) {
    localStorage.setItem(THEME_STORAGE_KEY, theme)
}
```

### 2. CSS Variables

Define semantic color tokens using CSS custom properties:

```css
/* Base styles */
:root {
    /* Light mode (default) */
    --bg-primary: #ffffff;
    --bg-secondary: #f5f5f5;
    --text-primary: #1a1a1a;
    --text-secondary: #666666;
    --border-color: #e0e0e0;
    --accent-color: #007bff;
    --accent-hover: #0056b3;
    --success-color: #28a745;
    --error-color: #dc3545;
    --warning-color: #ffc107;
}

/* Dark mode override */
[data-theme="dark"] {
    --bg-primary: #121212;
    --bg-secondary: #1e1e1e;
    --text-primary: #ffffff;
    --text-secondary: #b0b0b0;
    --border-color: #333333;
    --accent-color: #4dabf7;
    --accent-hover: #339af0;
    --success-color: #40c057;
    --error-color: #fa5252;
    --warning-color: #fcc419;
}

/* Semantic mapping for components */
.card {
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
}

.button {
    background: var(--accent-color);
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 0.25rem;
    cursor: pointer;
}

.button:hover {
    background: var(--accent-hover);
}

.text-secondary {
    color: var(--text-secondary);
}

.input-field {
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
}
```

### 3. Theme Detection

Detect user's system preference:

```typescript
export type ThemeMode = 'light' | 'dark' | 'system'

export function detectSystemTheme(): ThemeMode {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    return mediaQuery.matches ? 'dark' : 'light'
}

export function getEffectiveTheme(): ThemeMode {
    const saved = localStorage.getItem(THEME_STORAGE_KEY) as ThemeMode
    if (saved === 'light' || saved === 'dark') {
        return saved
    }
    return detectSystemTheme()
}

export function applyTheme(theme: ThemeMode) {
    const html = document.documentElement
    if (theme === 'system') {
        const systemTheme = detectSystemTheme()
        html.setAttribute('data-theme', systemTheme)
    } else {
        html.setAttribute('data-theme', theme)
    }
    localStorage.setItem(THEME_STORAGE_KEY, theme)
}
```

---

## Implementation Patterns

### Pattern 1: Simple Toggle

Add a toggle button in the header:

```tsx
// components/ThemeToggle.tsx
import React, { useEffect, useState } from 'react'
import { getEffectiveTheme, applyTheme, ThemeMode } from '../lib/theme'

export const ThemeToggle: React.FC = () => {
    const [theme, setTheme] = useState<ThemeMode>('system')

    useEffect(() => {
        setTheme(getEffectiveTheme())
    }, [])

    const toggleTheme = () => {
        const newTheme: ThemeMode = theme === 'system' ? 'dark' : 
                                     theme === 'dark' ? 'light' : 'system'
        setTheme(newTheme)
        applyTheme(newTheme)
    }

    return (
        <button
            onClick={toggleTheme}
            className="theme-toggle"
            aria-label="Toggle theme"
        >
            {theme === 'light' && '🌙 Dark Mode'}
            {theme === 'dark' && '☀️ Light Mode'}
            {theme === 'system' && '🔄 System'}
        </button>
    )
}
```

### Pattern 2: System Theme Detection

Auto-switch based on system preference:

```tsx
// App.tsx
import { useEffect } from 'react'
import { detectSystemTheme, applyTheme } from './lib/theme'

export const App: React.FC = () => {
    useEffect(() => {
        const systemTheme = detectSystemTheme()
        applyTheme('system')

        // Listen for theme changes
        const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
        const handleChange = (e: MediaQueryListEvent) => {
            applyTheme('system')
        }

        mediaQuery.addEventListener('change', handleChange)
        return () => mediaQuery.removeEventListener('change', handleChange)
    }, [])

    return (
        <div className="app">
            {/* Your app content */}
        </div>
    )
}
```

### Pattern 3: Theme Provider (React Context)

Provide theme globally:

```tsx
// contexts/ThemeContext.tsx
import React, { createContext, useContext, useState, useEffect } from 'react'
import { ThemeMode, getEffectiveTheme, applyTheme } from '../lib/theme'

interface ThemeContextType {
    theme: ThemeMode
    toggleTheme: () => void
    setTheme: (theme: ThemeMode) => void
    isDark: boolean
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined)

export const ThemeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [theme, setTheme] = useState<ThemeMode>('system')
    const [isDark, setIsDark] = useState(false)

    useEffect(() => {
        const savedTheme = getEffectiveTheme()
        setTheme(savedTheme)
        setIsDark(savedTheme === 'dark')
    }, [])

    useEffect(() => {
        applyTheme(theme)
        setIsDark(theme === 'dark')
    }, [theme])

    const toggleTheme = () => {
        const newTheme: ThemeMode = theme === 'system' ? 'dark' : 
                                     theme === 'dark' ? 'light' : 'system'
        setTheme(newTheme)
    }

    const setThemeHandler = (newTheme: ThemeMode) => {
        setTheme(newTheme)
    }

    return (
        <ThemeContext.Provider value={{ theme, toggleTheme, setTheme: setThemeHandler, isDark }}>
            {children}
        </ThemeContext.Provider>
    )
}

export const useTheme = () => {
    const context = useContext(ThemeContext)
    if (context === undefined) {
        throw new Error('useTheme must be used within a ThemeProvider')
    }
    return context
}
```

### Pattern 4: Conditional Classes

Use CSS variables with conditional classes:

```tsx
// components/Card.tsx
import React from 'react'

export const Card: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    return (
        <div className="card">
            {children}
        </div>
    )
}
```

```css
/* Card component styles */
.card {
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    padding: 1.5rem;
    transition: background 0.3s ease, border-color 0.3s ease;
}

.card:hover {
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}
```

---

## Component Integration

### Chart Components

Update chart components to respect theme:

```tsx
// components/PerformanceChart.tsx
import React from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

export const PerformanceChart: React.FC<{ data: any[] }> = ({ data }) => {
    const { isDark } = useTheme()

    return (
        <ResponsiveContainer width="100%" height={300}>
            <LineChart data={data}>
                <CartesianGrid 
                    stroke={isDark ? '#333333' : '#e0e0e0'} 
                    strokeDasharray="3 3" 
                />
                <XAxis 
                    dataKey="date" 
                    stroke={isDark ? '#b0b0b0' : '#666666'}
                />
                <YAxis 
                    stroke={isDark ? '#b0b0b0' : '#666666'}
                />
                <Tooltip 
                    contentStyle={{
                        backgroundColor: isDark ? '#1e1e1e' : '#ffffff',
                        border: `1px solid ${isDark ? '#333333' : '#e0e0e0'}`
                    }}
                />
                <Line 
                    type="monotone" 
                    dataKey="performance" 
                    stroke="#007bff" 
                    strokeWidth={2}
                />
            </LineChart>
        </ResponsiveContainer>
    )
}
```

---

## Backend Integration

### Spring Boot Configuration

Configure theme in backend:

```kotlin
// application.yml
spring:
  servlet:
    session:
      cookie:
        same-site: strict
        secure: true

# Theme configuration
theme:
  default-mode: system  # light, dark, or system
```

```kotlin
// ThemeConfig.kt
@Configuration
class ThemeConfig {
    
    @Bean
    fun themeResolver(): ThemeResolver {
        return DefaultThemeResolver()
    }
}

class DefaultThemeResolver : ThemeResolver {
    override fun resolveThemeName(request: HttpServletRequest): String {
        val session = request.session
        return session.getAttribute("theme")?.toString() ?: "system"
    }
    
    override fun resolveThemeName(request: HttpServletRequest, response: HttpServletResponse): String {
        return resolveThemeName(request)
    }
    
    override fun setThemeName(request: HttpServletRequest, response: HttpServletResponse, themeName: String) {
        request.session.setAttribute("theme", themeName)
    }
}
```

### REST API Endpoint

```kotlin
// controller/ThemeController.kt
@RestController
@RequestMapping("/api/theme")
class ThemeController {
    
    @GetMapping
    fun getTheme(): ResponseEntity<Map<String, String>> {
        val theme = WebUtils.getSessionAttribute(
            ServletUriComponentsBuilder.fromCurrentRequest().build().request.uri,
            "theme"
        ) as? String ?: "system"
        
        return ResponseEntity.ok(mapOf("theme" to theme))
    }
    
    @PutMapping("/{mode}")
    fun setTheme(
        @PathVariable mode: String,
        session: HttpSession
    ): ResponseEntity<Map<String, String>> {
        session.setAttribute("theme", mode)
        return ResponseEntity.ok(mapOf("theme" to mode, "message" to "Theme updated successfully"))
    }
}
```

---

## Testing

### Unit Tests

```typescript
// __tests__/theme.test.ts
import { getEffectiveTheme, detectSystemTheme, applyTheme } from '../lib/theme'

describe('Theme Detection', () => {
    beforeEach(() => {
        localStorage.clear()
        jest.spyOn(window, 'matchMedia')
    })

    afterEach(() => {
        jest.restoreAllMocks()
    })

    test('detects light theme by default', () => {
        (window.matchMedia as jest.Mock).mockReturnValue({ matches: false })
        expect(detectSystemTheme()).toBe('light')
    })

    test('detects dark theme when system prefers dark', () => {
        (window.matchMedia as jest.Mock).mockReturnValue({ matches: true })
        expect(detectSystemTheme()).toBe('dark')
    })

    test('gets effective theme from localStorage', () => {
        localStorage.setItem('theme-preference', 'dark')
        expect(getEffectiveTheme()).toBe('dark')
    })

    test('falls back to system theme when localStorage is empty', () => {
        (window.matchMedia as jest.Mock).mockReturnValue({ matches: true })
        expect(getEffectiveTheme()).toBe('dark')
    })
})
```

### Integration Tests

```typescript
// __tests__/theme-toggle.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ThemeToggle } from '../components/ThemeToggle'

describe('Theme Toggle', () => {
    beforeEach(() => {
        localStorage.clear()
    })

    test('toggles between light and dark', async () => {
        const user = userEvent.setup()
        render(<ThemeToggle />)
        
        const button = screen.getByRole('button')
        expect(button).toHaveTextContent('🌙 Dark Mode')
        
        await user.click(button)
        expect(button).toHaveTextContent('☀️ Light Mode')
    })
})
```

---

## Accessibility

### ARIA Labels

```tsx
<button
    onClick={toggleTheme}
    aria-label="Toggle dark mode"
    aria-pressed={isDark}
    className="theme-toggle"
>
    {isDark ? '☀️ Switch to light mode' : '🌙 Switch to dark mode'}
</button>
```

### Keyboard Navigation

```tsx
const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault()
        toggleTheme()
    }
}

<button
    onClick={toggleTheme}
    onKeyPress={handleKeyPress}
    tabIndex={0}
    aria-label="Toggle dark mode"
>
    Toggle Theme
</button>
```

---

## Performance Optimization

### 1. Batch Theme Updates

```typescript
// Avoid unnecessary re-renders
export const ThemeToggle = React.memo(() => {
    const { theme, toggleTheme } = useTheme()
    return (
        <button onClick={toggleTheme} aria-label="Toggle theme">
            {/* ... */}
        </button>
    )
})
```

### 2. CSS Transitions

```css
:root, [data-theme="light"], [data-theme="dark"] {
    --bg-primary: #ffffff;
    --bg-secondary: #f5f5f5;
    --text-primary: #1a1a1a;
    /* ... other variables */
    transition: background-color 0.3s ease, color 0.3s ease;
}

body {
    background-color: var(--bg-primary);
    color: var(--text-primary);
}
```

### 3. Avoid Inline Styles

```css
/* ✅ Good - use CSS variables */
.card {
    background: var(--bg-primary);
}

/* ❌ Bad - inline styles */
<div style={{ background: isDark ? '#121212' : '#ffffff' }} />
```

---

## Troubleshooting

### Issue 1: Theme Not Persisting

**Symptoms:** Theme resets to default on page refresh

**Solution:**
```typescript
useEffect(() => {
    const savedTheme = getEffectiveTheme()
    applyTheme(savedTheme)
}, [])
```

### Issue 2: Flash of Unstyled Content (FOUC)

**Symptoms:** White background appears briefly before dark mode loads

**Solution:**
```tsx
// App.tsx
export const App: React.FC = () => {
    const [loaded, setLoaded] = useState(false)
    
    useEffect(() => {
        // Initialize theme first
        getEffectiveTheme()
        applyTheme('system')
        setLoaded(true)
    }, [])
    
    if (!loaded) {
        return null // Or show loading spinner
    }
    
    return <div className="app">...</div>
}
```

### Issue 3: Charts Not Updating

**Symptoms:** Charts don't change colors when theme toggles

**Solution:**
```tsx
export const PerformanceChart: React.FC<{ data: any[] }> = ({ data }) => {
    const { isDark } = useTheme()
    
    // Add key prop to force re-render
    return <LineChart key={isDark ? 'dark' : 'light'} data={data} />
}
```

---

## Best Practices

### 1. Use Semantic Naming

```css
/* ✅ Good */
.card {
    background: var(--bg-primary);
}

/* ❌ Bad */
.card {
    background: var(--color-1);
}
```

### 2. Provide Theme Presets

```tsx
export const ThemePresets: React.FC = () => {
    const { setTheme } = useTheme()
    
    return (
        <div className="theme-presets">
            <button onClick={() => setTheme('light')}>Light</button>
            <button onClick={() => setTheme('dark')}>Dark</button>
            <button onClick={() => setTheme('system')}>System</button>
        </div>
    )
}
```

### 3. Consider High Contrast Mode

```css
[data-theme="high-contrast"] {
    --bg-primary: #000000;
    --bg-secondary: #000000;
    --text-primary: #ffffff;
    --text-secondary: #ffffff;
    --border-color: #ffffff;
    --accent-color: #00ffff;
    --accent-hover: #00ffff;
}
```

### 4. Test on Multiple Devices

Test on:
- Desktop (Windows, macOS)
- Mobile (iOS, Android)
- Different browsers (Chrome, Firefox, Safari, Edge)

---

## Resources

### Documentation
- [MDN - Prefers-color-scheme](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme)
- [CSS Custom Properties](https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties)
- [React Context](https://react.dev/reference/react/useContext)

### Tools
- [Theme Builder](https://builtin.com/design/theme-builder)
- [Color Palette Generator](https://coolors.co/contrast-checker)

### Related Patterns
- [Theme Provider Pattern](https://reactpatterns.com/patterns/theme-provider/)
- [Dark Mode Implementation Guide](https://web.dev/dark-mode/)
- [System Theme Detection](https://github.com/react-hook/web#use-prefers-color-scheme)

---

## Checklist

### Implementation
- [ ] Create CSS variables for light/dark themes
- [ ] Implement localStorage persistence
- [ ] Add theme toggle component
- [ ] Integrate with React Context
- [ ] Update all components to use CSS variables
- [ ] Add API endpoint for theme management
- [ ] Test on multiple browsers

### Testing
- [ ] Unit tests for theme detection
- [ ] Integration tests for theme toggle
- [ ] Test on mobile devices
- [ ] Test on different browsers
- [ ] Verify accessibility (ARIA labels, keyboard navigation)

### Documentation
- [ ] Update README with dark mode instructions
- [ ] Document API endpoints
- [ ] Create screenshots of light/dark modes
- [ ] Add theme switching examples

---

## Example Usage

```tsx
// App.tsx
import { ThemeProvider, useTheme } from './contexts/ThemeContext'
import { ThemeToggle } from './components/ThemeToggle'

function App() {
    return (
        <ThemeProvider>
            <Navigation />
            <ThemeToggle />
            <Dashboard />
        </ThemeProvider>
    )
}

function Dashboard() {
    const { isDark } = useTheme()
    
    return (
        <div className="dashboard" data-theme={isDark ? 'dark' : 'light'}>
            {/* Dashboard content */}
        </div>
    )
}
```

---

## Future Enhancements

- [ ] Automatic theme detection based on time of day
- [ ] Theme presets (blue light mode, sepia mode)
- [ ] Theme preview before applying
- [ ] Theme sharing feature
- [ ] Export/import theme settings
- [ ] Multi-device theme sync
- [ ] Accessibility-based theme detection
- [ ] Animated theme transitions

---

*End of Dark Mode Skill Documentation*

---

## Quick Start

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Test
npm test
```

---

**Version History:**
- v1.0.0 (2026-03-25) - Initial version
