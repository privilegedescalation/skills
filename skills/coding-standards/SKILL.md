---
name: coding-standards
description: >
  Coding standards for Privileged Escalation. Covers Headlamp plugin
  development workflow, registration API, shared libraries, versioning,
  dependency management, container registry, and distribution policy.
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

## Versioning & Distribution

- **All releases use SemVer.** ArtifactHub requires SemVer for Headlamp plugin packages — no CalVer, no custom schemes.
- **Plugin distribution is ArtifactHub only.** Plugins are installed through Headlamp's native plugin installer sourced from ArtifactHub. No Helm charts, install scripts, or custom install mechanisms.
- **Container images go to `ghcr.io` only.** Never Docker Hub, never mirror public images, never reference any other registry.

## Dependency Management

- **Dependency updates are owned by Mend Renovate.** Never enable Dependabot, never create `.github/dependabot.yml`, never reference Dependabot in workflows or docs.
- **No package mirrors.** Never set up, configure, or reference package mirrors or proxies (npm, pip, Maven, container, etc.). Always use upstream registries directly.
- **Security scanning uses local tools.** Run `npm audit` or `pnpm audit` for vulnerability scanning. Do not use the GitHub vulnerability alerts API.
