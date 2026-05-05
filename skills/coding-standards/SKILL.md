---
name: coding-standards
description: >
  Coding standards for Privileged Escalation. Covers Headlamp plugin
  development workflow, registration API, and shared libraries.
---

# Coding Standards

## Headlamp Plugins

All plugins extend [Headlamp](https://headlamp.dev/docs/latest/development/plugins/getting-started), a Kubernetes dashboard with a plugin system.

- **Language:** TypeScript + React 18, MUI v5
- **Scaffolding:** `npx --yes @kinvolk/headlamp-plugin create <plugin-name>`
- **Entry point:** `src/index.tsx`
- **Linting:** ESLint via `@headlamp-k8s/eslint-config` + Prettier
- **Testing:** Vitest + React Testing Library

### Plugin Commands

Run from the plugin directory:

| Command | Purpose |
|---|---|
| `npm run start` | Dev mode with hot reload |
| `npm run build` | Production build (`dist/main.js`) |
| `npm run format` | Prettier format |
| `npm run lint` | ESLint check |
| `npm run lint-fix` | ESLint auto-fix |
| `npm run tsc` | Typecheck |
| `npm run test` | Vitest tests |

### Registration API

Import from `@kinvolk/headlamp-plugin/lib`:

- `registerAppBarAction()` — add components to the nav bar
- `registerRoute()` — create new pages
- `registerSidebarEntry()` — add sidebar items
- `registerDetailsViewSection()` — extend resource detail views
- `registerPluginSettings()` — add plugin configuration UI

### K8s API Access

```typescript
import { K8s } from '@kinvolk/headlamp-plugin/lib';
const [pods, error] = K8s.ResourceClasses.Pod.useList();
```

### Shared Libraries

These are provided by Headlamp at runtime — **do not bundle them**:
React, React Router, Redux, MUI, Lodash, Monaco Editor, Notistack, Iconify.
