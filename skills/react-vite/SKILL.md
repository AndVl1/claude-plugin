---
name: react-vite
description: React 18+ with Vite patterns - use for Mini App frontend development, component structure, hooks, and TypeScript setup
---

# React + Vite Patterns for Telegram Mini App

## Project Architecture

```
mini-app/
├── public/
│   └── favicon.ico
├── src/
│   ├── components/           # Reusable UI components
│   │   ├── common/           # Generic UI (Button, Card, Modal, etc.)
│   │   ├── layout/           # Layout components (AppLayout, Navigation)
│   │   └── features/         # Feature-specific components
│   │       ├── chat/         # Chat selector, chat card
│   │       ├── settings/     # Settings toggles, forms
│   │       ├── blocklist/    # Blocklist CRUD components
│   │       └── locks/        # Lock toggles, categories
│   ├── hooks/                # Custom React hooks
│   │   ├── api/              # Data fetching hooks
│   │   ├── telegram/         # Telegram-specific hooks
│   │   └── ui/               # UI state hooks
│   ├── pages/                # Route pages (one per route)
│   ├── services/             # API client and external services
│   ├── stores/               # Zustand stores (global state)
│   ├── types/                # TypeScript type definitions
│   ├── utils/                # Helper functions
│   ├── constants/            # App constants, enums
│   ├── App.tsx               # App root with providers
│   ├── main.tsx              # Entry point
│   ├── mockEnv.ts            # Mock Telegram environment
│   └── vite-env.d.ts         # Vite type declarations
├── index.html
├── package.json
├── tsconfig.json
├── vite.config.ts
└── .env.example
```

## Layer Responsibilities

### 1. Pages (Route Level)
- One file per route
- Compose feature components
- Handle route params
- Connect to stores if needed

### 2. Components
- **common/**: Generic, reusable across features
- **layout/**: App shell, navigation
- **features/**: Feature-specific, can use hooks

### 3. Hooks
- **api/**: `useQuery`-like data fetching
- **telegram/**: `useTelegramAuth`, `useMainButton`
- **ui/**: `useModal`, `useToast`

### 4. Stores (Zustand)
- Global state only (selected chat, user)
- Feature state stays in components

### 5. Services
- API client (single instance)
- Type-safe request/response

---

## Component Patterns

### Base Component Template

```tsx
// src/components/features/chat/ChatCard.tsx
import { memo } from 'react';
import { Cell } from '@telegram-apps/ui';
import type { Chat } from '@/types';
import styles from './ChatCard.module.css';

interface ChatCardProps {
  chat: Chat;
  isActive?: boolean;
  onSelect: (chatId: number) => void;
}

export const ChatCard = memo(function ChatCard({
  chat,
  isActive = false,
  onSelect,
}: ChatCardProps) {
  return (
    <Cell
      className={isActive ? styles.active : undefined}
      onClick={() => onSelect(chat.id)}
      subtitle={`${chat.memberCount} members`}
    >
      {chat.title}
    </Cell>
  );
});
```

### Page Component Pattern

```tsx
// src/pages/SettingsPage.tsx
import { useParams, Navigate } from 'react-router-dom';
import { Section, Spinner, Placeholder } from '@telegram-apps/ui';
import { useSettings } from '@/hooks/api/useSettings';
import { SettingsForm } from '@/components/features/settings/SettingsForm';
import { useSelectedChat } from '@/stores/chatStore';

export function SettingsPage() {
  const { chatId } = useParams<{ chatId: string }>();
  const numericChatId = Number(chatId);

  const { data: settings, isLoading, error } = useSettings(numericChatId);

  if (!chatId || isNaN(numericChatId)) {
    return <Navigate to="/" replace />;
  }

  if (isLoading) {
    return <Spinner size="large" />;
  }

  if (error || !settings) {
    return (
      <Placeholder
        header="Error"
        description={error?.message || 'Failed to load settings'}
      />
    );
  }

  return (
    <Section header="Chat Settings">
      <SettingsForm settings={settings} chatId={numericChatId} />
    </Section>
  );
}
```

### Compound Component Pattern (For Complex UI)

```tsx
// src/components/features/locks/LockGrid.tsx
import { createContext, useContext, ReactNode } from 'react';
import type { LockType, LockCategory } from '@/types';

interface LockGridContextValue {
  lockedTypes: Set<LockType>;
  onToggle: (type: LockType) => void;
}

const LockGridContext = createContext<LockGridContextValue | null>(null);

function useLockGridContext() {
  const ctx = useContext(LockGridContext);
  if (!ctx) throw new Error('LockGrid.* must be used within LockGrid');
  return ctx;
}

// Root component
interface LockGridProps {
  lockedTypes: Set<LockType>;
  onToggle: (type: LockType) => void;
  children: ReactNode;
}

function LockGridRoot({ lockedTypes, onToggle, children }: LockGridProps) {
  return (
    <LockGridContext.Provider value={{ lockedTypes, onToggle }}>
      <div className="lock-grid">{children}</div>
    </LockGridContext.Provider>
  );
}

// Category component
interface CategoryProps {
  category: LockCategory;
  types: LockType[];
}

function Category({ category, types }: CategoryProps) {
  const { lockedTypes, onToggle } = useLockGridContext();

  return (
    <Section header={category}>
      {types.map(type => (
        <LockToggle
          key={type}
          type={type}
          locked={lockedTypes.has(type)}
          onToggle={() => onToggle(type)}
        />
      ))}
    </Section>
  );
}

// Export compound component
export const LockGrid = Object.assign(LockGridRoot, {
  Category,
});

// Usage:
// <LockGrid lockedTypes={locked} onToggle={handleToggle}>
//   <LockGrid.Category category="CONTENT" types={contentTypes} />
//   <LockGrid.Category category="URL" types={urlTypes} />
// </LockGrid>
```

---

## Hooks Patterns

### Data Fetching Hook (SWR-like)

```tsx
// src/hooks/api/useSettings.ts
import { useState, useEffect, useCallback } from 'react';
import { api } from '@/services/api';
import type { ChatSettings } from '@/types';

interface UseSettingsResult {
  data: ChatSettings | null;
  isLoading: boolean;
  error: Error | null;
  mutate: (settings: Partial<ChatSettings>) => Promise<void>;
  refetch: () => Promise<void>;
}

export function useSettings(chatId: number): UseSettingsResult {
  const [data, setData] = useState<ChatSettings | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchSettings = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);
      const settings = await api.getSettings(chatId);
      setData(settings);
    } catch (err) {
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  }, [chatId]);

  useEffect(() => {
    fetchSettings();
  }, [fetchSettings]);

  const mutate = useCallback(async (updates: Partial<ChatSettings>) => {
    // Optimistic update
    setData(prev => prev ? { ...prev, ...updates } : null);

    try {
      const updated = await api.updateSettings(chatId, updates);
      setData(updated);
    } catch (err) {
      // Rollback on error
      await fetchSettings();
      throw err;
    }
  }, [chatId, fetchSettings]);

  return {
    data,
    isLoading,
    error,
    mutate,
    refetch: fetchSettings,
  };
}
```

### Telegram Hooks

```tsx
// src/hooks/telegram/useTelegramAuth.ts
import { useMemo } from 'react';
import { useInitData, useInitDataRaw } from '@telegram-apps/sdk-react';

export interface TelegramUser {
  id: number;
  firstName: string;
  lastName?: string;
  username?: string;
  isPremium: boolean;
  languageCode?: string;
}

export function useTelegramAuth() {
  const initData = useInitData();
  const initDataRaw = useInitDataRaw();

  const user = useMemo<TelegramUser | null>(() => {
    if (!initData?.user) return null;
    return {
      id: initData.user.id,
      firstName: initData.user.firstName,
      lastName: initData.user.lastName,
      username: initData.user.username,
      isPremium: initData.user.isPremium ?? false,
      languageCode: initData.user.languageCode,
    };
  }, [initData]);

  const getAuthHeader = useCallback(() => {
    if (!initDataRaw) return {};
    return { Authorization: `tma ${initDataRaw}` };
  }, [initDataRaw]);

  return {
    user,
    isAuthenticated: !!user && !!initDataRaw,
    initDataRaw,
    getAuthHeader,
  };
}
```

```tsx
// src/hooks/telegram/useMainButton.ts
import { useEffect, useCallback } from 'react';
import { useMainButton as useTMAMainButton } from '@telegram-apps/sdk-react';

interface UseMainButtonOptions {
  text: string;
  onClick: () => void | Promise<void>;
  disabled?: boolean;
  visible?: boolean;
}

export function useMainButton({
  text,
  onClick,
  disabled = false,
  visible = true,
}: UseMainButtonOptions) {
  const mainButton = useTMAMainButton();

  useEffect(() => {
    mainButton.setParams({
      text,
      isEnabled: !disabled,
      isVisible: visible,
    });
  }, [mainButton, text, disabled, visible]);

  useEffect(() => {
    const handler = async () => {
      mainButton.showProgress();
      try {
        await onClick();
      } finally {
        mainButton.hideProgress();
      }
    };

    mainButton.on('click', handler);
    return () => mainButton.off('click', handler);
  }, [mainButton, onClick]);

  const showProgress = useCallback(() => mainButton.showProgress(), [mainButton]);
  const hideProgress = useCallback(() => mainButton.hideProgress(), [mainButton]);

  return { showProgress, hideProgress };
}
```

### UI Hooks

```tsx
// src/hooks/ui/useConfirmDialog.ts
import { useState, useCallback } from 'react';
import { usePopup } from '@telegram-apps/sdk-react';

export function useConfirmDialog() {
  const popup = usePopup();

  const confirm = useCallback(async (
    message: string,
    title?: string
  ): Promise<boolean> => {
    const result = await popup.open({
      title: title || 'Confirm',
      message,
      buttons: [
        { id: 'cancel', type: 'cancel' },
        { id: 'ok', type: 'destructive', text: 'Delete' },
      ],
    });
    return result === 'ok';
  }, [popup]);

  return { confirm };
}
```

---

## State Management (Zustand)

### Store Pattern

```tsx
// src/stores/chatStore.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Chat } from '@/types';

interface ChatState {
  // State
  selectedChatId: number | null;
  chats: Chat[];

  // Actions
  setSelectedChat: (chatId: number | null) => void;
  setChats: (chats: Chat[]) => void;

  // Selectors
  getSelectedChat: () => Chat | undefined;
}

export const useChatStore = create<ChatState>()(
  persist(
    (set, get) => ({
      // Initial state
      selectedChatId: null,
      chats: [],

      // Actions
      setSelectedChat: (chatId) => set({ selectedChatId: chatId }),
      setChats: (chats) => set({ chats }),

      // Selectors
      getSelectedChat: () => {
        const { selectedChatId, chats } = get();
        return chats.find(c => c.id === selectedChatId);
      },
    }),
    {
      name: 'chat-storage',
      partialize: (state) => ({ selectedChatId: state.selectedChatId }),
    }
  )
);

// Selector hooks for performance
export const useSelectedChatId = () => useChatStore(s => s.selectedChatId);
export const useChats = () => useChatStore(s => s.chats);
export const useSelectedChat = () => useChatStore(s => s.getSelectedChat());
```

### Settings Store (Feature-specific)

```tsx
// src/stores/settingsStore.ts
import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';
import type { ChatSettings, LockType } from '@/types';

interface SettingsState {
  // Cache by chatId
  settingsCache: Record<number, ChatSettings>;
  pendingChanges: Record<number, Partial<ChatSettings>>;

  // Actions
  setSettings: (chatId: number, settings: ChatSettings) => void;
  updatePending: (chatId: number, updates: Partial<ChatSettings>) => void;
  commitPending: (chatId: number) => void;
  clearPending: (chatId: number) => void;

  // Lock-specific
  toggleLock: (chatId: number, lockType: LockType) => void;
}

export const useSettingsStore = create<SettingsState>()(
  immer((set, get) => ({
    settingsCache: {},
    pendingChanges: {},

    setSettings: (chatId, settings) => {
      set(state => {
        state.settingsCache[chatId] = settings;
      });
    },

    updatePending: (chatId, updates) => {
      set(state => {
        state.pendingChanges[chatId] = {
          ...state.pendingChanges[chatId],
          ...updates,
        };
      });
    },

    commitPending: (chatId) => {
      set(state => {
        const pending = state.pendingChanges[chatId];
        if (pending && state.settingsCache[chatId]) {
          Object.assign(state.settingsCache[chatId], pending);
        }
        delete state.pendingChanges[chatId];
      });
    },

    clearPending: (chatId) => {
      set(state => {
        delete state.pendingChanges[chatId];
      });
    },

    toggleLock: (chatId, lockType) => {
      set(state => {
        const settings = state.settingsCache[chatId];
        if (settings) {
          const current = settings.lockedTypes[lockType]?.locked ?? false;
          settings.lockedTypes[lockType] = { locked: !current };
        }
      });
    },
  }))
);
```

---

## API Client

```tsx
// src/services/api.ts
import ky from 'ky';
import type {
  Chat,
  ChatSettings,
  BlocklistPattern,
  LockSettings,
  ChannelReplySettings,
} from '@/types';

const API_BASE = import.meta.env.VITE_API_URL || '/api/v1/miniapp';

// Auth header will be set via hook
let authHeader: Record<string, string> = {};

export function setAuthHeader(header: Record<string, string>) {
  authHeader = header;
}

const client = ky.create({
  prefixUrl: API_BASE,
  timeout: 30000,
  hooks: {
    beforeRequest: [
      (request) => {
        Object.entries(authHeader).forEach(([key, value]) => {
          request.headers.set(key, value);
        });
      },
    ],
    afterResponse: [
      async (_request, _options, response) => {
        if (!response.ok) {
          const error = await response.json().catch(() => ({}));
          throw new ApiError(response.status, error.message || 'Request failed');
        }
      },
    ],
  },
});

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

export const api = {
  // Chats
  getChats: () => client.get('chats').json<Chat[]>(),

  // Settings
  getSettings: (chatId: number) =>
    client.get(`chats/${chatId}/settings`).json<ChatSettings>(),

  updateSettings: (chatId: number, settings: Partial<ChatSettings>) =>
    client.put(`chats/${chatId}/settings`, { json: settings }).json<ChatSettings>(),

  // Blocklist
  getBlocklist: (chatId: number) =>
    client.get(`chats/${chatId}/blocklist`).json<BlocklistPattern[]>(),

  addBlocklistPattern: (chatId: number, pattern: Omit<BlocklistPattern, 'id' | 'createdAt'>) =>
    client.post(`chats/${chatId}/blocklist`, { json: pattern }).json<BlocklistPattern>(),

  deleteBlocklistPattern: (chatId: number, patternId: number) =>
    client.delete(`chats/${chatId}/blocklist/${patternId}`),

  // Locks
  getLocks: (chatId: number) =>
    client.get(`chats/${chatId}/locks`).json<LockSettings>(),

  updateLocks: (chatId: number, locks: Partial<LockSettings>) =>
    client.put(`chats/${chatId}/locks`, { json: locks }).json<LockSettings>(),

  // Channel Reply
  getChannelReply: (chatId: number) =>
    client.get(`chats/${chatId}/channel-reply`).json<ChannelReplySettings>(),

  updateChannelReply: (chatId: number, settings: Partial<ChannelReplySettings>) =>
    client.put(`chats/${chatId}/channel-reply`, { json: settings }).json<ChannelReplySettings>(),
};
```

---

## TypeScript Types

```tsx
// src/types/index.ts

// === Domain Types ===

export interface Chat {
  id: number;
  title: string;
  type: 'group' | 'supergroup' | 'channel';
  memberCount: number;
  isAdmin: boolean;
}

export interface ChatSettings {
  chatId: number;
  chatTitle: string;
  collectionEnabled: boolean;
  cleanServiceEnabled: boolean;
  maxWarnings: number;
  warningTtlHours: number;
  thresholdAction: PunishmentType;
  thresholdDurationHours: number;
  defaultBlocklistAction: PunishmentType;
  logChannelId: number | null;
  lockwarnsEnabled: boolean;
  lockedTypes: Record<LockType, LockInfo>;
}

export type PunishmentType = 'NOTHING' | 'WARN' | 'MUTE' | 'BAN' | 'KICK';

export interface LockInfo {
  locked: boolean;
  reason?: string;
}

export type LockCategory = 'CONTENT' | 'FORWARD' | 'URL' | 'TEXT' | 'ENTITY' | 'OTHER';

export type LockType =
  // CONTENT
  | 'PHOTO' | 'VIDEO' | 'GIF' | 'AUDIO' | 'VOICE' | 'VIDEO_NOTE'
  | 'DOCUMENT' | 'STICKER' | 'POLL' | 'CONTACT' | 'LOCATION' | 'VENUE'
  // FORWARD
  | 'FORWARD' | 'FORWARD_USER' | 'FORWARD_BOT' | 'FORWARD_CHANNEL' | 'FORWARD_ANONYMOUS'
  // URL
  | 'URL' | 'TELEGRAM_LINK' | 'EMAIL' | 'PHONE'
  // TEXT
  | 'TEXT_TOO_LONG' | 'RTLO' | 'ZALGO' | 'ARABIC' | 'CHINESE' | 'CYRILLIC'
  // ENTITY
  | 'MENTION' | 'BOT_COMMAND' | 'HASHTAG' | 'CASHTAG' | 'SPOILER' | 'CUSTOM_EMOJI'
  // OTHER
  | 'DICE' | 'GAME' | 'STORY' | 'PREMIUM_EMOJI' | 'TOPIC_CHANGE' | 'INLINE_BOT';

export interface BlocklistPattern {
  id: number;
  pattern: string;
  matchType: 'EXACT' | 'WILDCARD';
  action: PunishmentType;
  severity?: number;
  createdAt: string;
}

export interface LockSettings {
  lockedTypes: Record<LockType, LockInfo>;
  lockwarnsEnabled: boolean;
  allowlist: AllowlistEntry[];
}

export interface AllowlistEntry {
  id: number;
  type: 'URL' | 'DOMAIN' | 'COMMAND';
  value: string;
}

export interface ChannelReplySettings {
  enabled: boolean;
  replyText: string | null;
  mediaFileId: string | null;
  mediaType: 'photo' | 'video' | 'animation' | null;
  buttons: ReplyButton[];
}

export interface ReplyButton {
  text: string;
  url: string;
}

// === Lock Type Metadata ===

export const LOCK_CATEGORIES: Record<LockCategory, LockType[]> = {
  CONTENT: ['PHOTO', 'VIDEO', 'GIF', 'AUDIO', 'VOICE', 'VIDEO_NOTE', 'DOCUMENT', 'STICKER', 'POLL', 'CONTACT', 'LOCATION', 'VENUE'],
  FORWARD: ['FORWARD', 'FORWARD_USER', 'FORWARD_BOT', 'FORWARD_CHANNEL', 'FORWARD_ANONYMOUS'],
  URL: ['URL', 'TELEGRAM_LINK', 'EMAIL', 'PHONE'],
  TEXT: ['TEXT_TOO_LONG', 'RTLO', 'ZALGO', 'ARABIC', 'CHINESE', 'CYRILLIC'],
  ENTITY: ['MENTION', 'BOT_COMMAND', 'HASHTAG', 'CASHTAG', 'SPOILER', 'CUSTOM_EMOJI'],
  OTHER: ['DICE', 'GAME', 'STORY', 'PREMIUM_EMOJI', 'TOPIC_CHANGE', 'INLINE_BOT'],
};

export const LOCK_TYPE_LABELS: Record<LockType, string> = {
  PHOTO: 'Photos',
  VIDEO: 'Videos',
  GIF: 'GIFs',
  // ... etc
};
```

---

## Routing

```tsx
// src/App.tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { SDKProvider } from '@telegram-apps/sdk-react';
import { AppRoot } from '@telegram-apps/ui';
import { AppLayout } from '@/components/layout/AppLayout';
import { HomePage } from '@/pages/HomePage';
import { SettingsPage } from '@/pages/SettingsPage';
import { BlocklistPage } from '@/pages/BlocklistPage';
import { LocksPage } from '@/pages/LocksPage';
import { ChannelReplyPage } from '@/pages/ChannelReplyPage';
import { AuthGuard } from '@/components/common/AuthGuard';
import './mockEnv'; // Import mock environment

export function App() {
  return (
    <SDKProvider acceptCustomStyles debug={import.meta.env.DEV}>
      <AppRoot>
        <BrowserRouter>
          <AuthGuard>
            <Routes>
              <Route element={<AppLayout />}>
                <Route index element={<HomePage />} />
                <Route path="chat/:chatId">
                  <Route path="settings" element={<SettingsPage />} />
                  <Route path="blocklist" element={<BlocklistPage />} />
                  <Route path="locks" element={<LocksPage />} />
                  <Route path="channel-reply" element={<ChannelReplyPage />} />
                </Route>
                <Route path="*" element={<Navigate to="/" replace />} />
              </Route>
            </Routes>
          </AuthGuard>
        </BrowserRouter>
      </AppRoot>
    </SDKProvider>
  );
}
```

---

## Vite Configuration

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import basicSsl from '@vitejs/plugin-basic-ssl';
import { resolve } from 'path';

export default defineConfig({
  plugins: [
    react(),
    // Uncomment for HTTPS in development
    // basicSsl(),
  ],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  server: {
    host: true, // Expose to network for mobile testing
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom'],
          telegram: ['@telegram-apps/sdk', '@telegram-apps/sdk-react', '@telegram-apps/ui'],
        },
      },
    },
  },
  base: './',
});
```

---

## Best Practices

### Do's
- Use TypeScript strict mode
- Memoize callbacks with `useCallback`
- Memoize computed values with `useMemo`
- Use `memo()` for list item components
- Keep components small and focused
- Colocate styles with components
- Use Telegram theme CSS variables
- Handle loading/error states explicitly

### Don'ts
- Don't use `any` type
- Don't mutate state directly
- Don't fetch data in render
- Don't create inline callbacks in render
- Don't use index as key for dynamic lists
- Don't ignore TypeScript errors
