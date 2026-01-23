# Chrome Testing Skill

Reference for manual QA testing of Telegram Mini Apps using Chrome browser automation tools.

## Quick Reference: MCP Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `navigate` | Load Mini App URL | Start of test, navigation |
| `computer` | Click, type, interact | Buttons, forms, UI elements |
| `form_input` | Type in text fields | Complex input validation |
| `read_network_requests` | Inspect HTTP traffic | API validation, auth testing |
| `read_console_messages` | Check JS errors | Error detection, debugging |
| `javascript_tool` | Run JS in page | State inspection, DOM querying |
| `find` | Locate elements | Element verification |
| `read_page` | Get full page content | DOM structure analysis |

## Testing Environments

### Local Development (Fastest)
```
URL: http://localhost:5173
SDK: Mocked via @telegram-apps/sdk
Use: Daily development testing
```

### TMA Studio (Realistic)
```
Download: https://github.com/erfanmola/TMA-Studio
Features: 90%+ Mini App API coverage
Use: Pre-release testing
```

### Real Device (Final)
```
Requires: HTTPS via Cloudflare Tunnel
Setup: cloudflared tunnel --url http://localhost:5173
Use: Final validation
```

## Standard Test Workflow

### 1. Setup
```
navigate("http://localhost:5173")
screenshot() -> verify page loads
```

### 2. UI Interaction
```
computer(click, element)
screenshot() -> verify state changed
```

### 3. API Verification
```
computer(click, saveButton)
read_network_requests() ->
  - Verify: PUT /api/v1/miniapp/chats/{id}/settings
  - Check: Authorization: tma {initData}
  - Status: 200 OK
```

### 4. Error Checking
```
read_console_messages() ->
  - No console.error entries
  - No "Failed to fetch" messages
```

### 5. State Inspection
```
javascript_tool("window.appState?.selectedChat")
javascript_tool("localStorage.getItem('key')")
```

## API Testing Checklist

### Request Verification
| Check | How |
|-------|-----|
| Correct endpoint | `read_network_requests()` + urlPattern |
| HTTP method | GET/POST/PUT/DELETE as expected |
| Auth header | `Authorization: tma <initData>` present |
| Request body | JSON payload matches expected |

### Response Verification
| Check | Expected |
|-------|----------|
| Success | Status 200, data returned |
| Not found | Status 404, error message |
| Unauthorized | Status 401, no data exposed |
| Validation error | Status 400, field errors |

### API Endpoints (Example)
```
GET    /api/v1/miniapp/chats              - List user's chats
GET    /api/v1/miniapp/chats/{id}         - Get chat details
GET    /api/v1/miniapp/chats/{id}/settings - Get chat settings
PUT    /api/v1/miniapp/chats/{id}/settings - Update settings
GET    /api/v1/miniapp/chats/{id}/blocklist - Get blocklist
POST   /api/v1/miniapp/chats/{id}/blocklist - Add pattern
DELETE /api/v1/miniapp/chats/{id}/blocklist/{id} - Remove pattern
GET    /api/v1/miniapp/chats/{id}/locks    - Get locks
PUT    /api/v1/miniapp/chats/{id}/locks    - Update locks
```

## Console Error Patterns

### Critical Errors (Must Fix)
```
Cannot read property 'WebApp' of undefined  -> Telegram SDK not loaded
initData is undefined                        -> Not in Telegram context
Authorization header missing                 -> API client misconfigured
CORS error                                   -> Backend CORS not configured
```

### Common Warnings (Review)
```
React key prop warning                       -> Add unique keys to lists
useEffect dependency warning                 -> Fix dependency array
Unused variable warning                      -> Clean up code
```

## JavaScript Inspection Examples

### Check Telegram SDK
```javascript
window.Telegram?.WebApp?.initDataUnsafe?.user
window.Telegram?.WebApp?.platform
window.Telegram?.WebApp?.version
```

### Check App State
```javascript
window.__store?.getState?.()
localStorage.getItem('lastSelectedChat')
sessionStorage.getItem('formData')
```

### Check DOM State
```javascript
document.querySelector('.error-message')?.textContent
document.querySelector('button[type="submit"]').disabled
getComputedStyle(document.documentElement).getPropertyValue('--tg-theme-bg-color')
```

## Test Scenarios

### Scenario: Chat Settings Save

1. **Navigate**: `navigate("http://localhost:5173")`
2. **Select Chat**: `computer(click, chatSelector)` -> select chat
3. **Toggle Setting**: `computer(click, collectionToggle)`
4. **Save**: `computer(click, saveButton)`
5. **Verify Request**:
   - `read_network_requests()` -> PUT /chats/{id}/settings
   - Authorization header present
   - Response 200
6. **Verify UI**: Success message displayed
7. **Verify State**: `javascript_tool("localStorage.getItem('settings')")`

### Scenario: Auth Failure

1. Mock invalid initData (if testing auth)
2. Perform action requiring auth
3. `read_network_requests()` -> Status 401
4. `read_console_messages()` -> No sensitive data leaked
5. UI shows generic "Not authorized" message

### Scenario: Form Validation

1. Fill form with invalid data
2. Click submit
3. `read_network_requests()` -> No request made (frontend validation)
4. UI shows validation errors
5. Fill with valid data
6. Click submit
7. `read_network_requests()` -> Request made, Status 200/400

## Platform Testing

### Desktop (Telegram Desktop Beta)
- Right-click in WebView -> Inspect
- Standard Chrome DevTools

### Android
- Enable USB debugging
- Connect device
- `chrome://inspect/#devices`
- Inspect WebView

### iOS (Requires macOS)
- Enable Web Inspector in Safari settings
- Safari -> Develop -> [Device] -> WebView

## Theme Testing

### Check Theme Variables
```javascript
javascript_tool(`
  const style = getComputedStyle(document.documentElement);
  return {
    bg: style.getPropertyValue('--tg-theme-bg-color'),
    text: style.getPropertyValue('--tg-theme-text-color'),
    hint: style.getPropertyValue('--tg-theme-hint-color'),
    button: style.getPropertyValue('--tg-theme-button-color')
  };
`)
```

### Toggle Theme (TMA Studio)
- Settings -> Theme -> Dark/Light
- Verify colors update
- Screenshot both themes

## Release Checklist

### Functionality
- [ ] All buttons respond to clicks
- [ ] Forms submit correctly
- [ ] Settings persist after refresh
- [ ] Lists paginate properly
- [ ] Modals open/close

### API Integration
- [ ] All endpoints return expected data
- [ ] Authorization headers sent
- [ ] Error responses handled gracefully
- [ ] Loading states visible

### Error Handling
- [ ] No console errors on normal flow
- [ ] Network errors show user-friendly messages
- [ ] Invalid input rejected with clear errors

### UI/UX
- [ ] Layout correct on all platforms
- [ ] Theme colors applied
- [ ] Loading spinners visible
- [ ] Success/error toasts work

### Security
- [ ] No sensitive data in console
- [ ] initData not exposed
- [ ] Admin checks enforced
- [ ] HTTPS in production

## Limitations & Workarounds

| Limitation | Workaround |
|-----------|-----------|
| HTTPS required in prod | Cloudflare Tunnel for local HTTPS |
| initData expires ~1hr | Refresh app or use mock |
| Can't test MainButton in browser | Use TMA Studio |
| iOS requires macOS | Use Android or Desktop |
| WebSocket may not work | Test HTTP polling first |
