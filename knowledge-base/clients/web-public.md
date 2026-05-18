# Web: лендинг + просмотр расписания

> Источник: ревью репозитория `~/Developer/VCourse/Web/vcourse` на ветке `service` (коммит от 18.05.2026).
> Этот файл описывает **публичную часть** Web-приложения — лендинг и веб-просмотр расписания. Сервис администрирования вынесен в [web-admin.md](web-admin.md).
> Структура файла подобрана так, чтобы её можно было напрямую переложить в раздел 3.3.1 главы 3 ВКР.

---

## 0. Общая характеристика монорепо

Весь Web — это **один Next.js-проект** (`vcourse-app`, версия 0.1.1). Внутри `src/app/[locale]/` три роут-группы:

| Роут-группа | Назначение | Описано в |
| --- | --- | --- |
| `(landing)` | Лендинг: главная, о нас, скачать, FAQ, блог, privacy | этот файл |
| `(schedule)` | Веб-просмотр расписания `/schedule` | этот файл |
| `(service)` | Закрытый сервис администрирования `/authorization`, `/onboarding`, `/workspace/*` | [web-admin.md](web-admin.md) |

В ВКР этот монорепо разбивается **на два подраздела главы 3**:
- 3.3.1 «Публичная часть» (этот файл) — лендинг и веб-просмотр расписания, общий стек, общая инфраструктура;
- 3.3.2 «Сервис администрирования» — управление справочниками, составление расписания.

Общий стек, инфраструктура, i18n, темизация описаны **здесь** и от admin-файла не дублируются.

## 1. Общая характеристика

- **Бренд:** «ВКурсе».
- **Домен:** `https://vcourse.app`.
- **Назначение публичной части:**
  1. **Лендинг** — точка входа экосистемы: рассказ о продукте, ссылки на мобильные приложения, блог, юридические страницы.
  2. **Веб-просмотр расписания** — самостоятельный продукт для пользователей без мобильного приложения и для тех вузов, которые мы парсим.
- **Доля среди пользователей экосистемы:** ~1%.
- **Объём кодовой базы (весь Web-проект):** 470 файлов TypeScript/TSX, ≈48 800 строк (с учётом admin-сервиса; на публичную часть приходится ориентировочно треть).

## 2. Технологический стек

| Категория | Используется |
| --- | --- |
| Фреймворк | **Next.js 16** (App Router, `output: "standalone"`) |
| Язык | TypeScript 5 |
| React | **React 19** |
| CSS | **Tailwind CSS v4** (`@tailwindcss/postcss`), `tailwind-merge`, `class-variance-authority`, `tailwindcss-animate` |
| UI-кит | **shadcn/ui** — 36 компонентов в `src/components/ui/` поверх **Radix UI** primitives (`alert-dialog`, `popover`, `select`, `dropdown-menu`, `tooltip` и т.д.) + `@base-ui/react` для отдельных кейсов |
| Иконки | `lucide-react` |
| Шрифты | `Geist` и `Geist Mono` (через `next/font/google`) |
| Локализация | **next-intl 4** (`en` / `ru`, defaultLocale `en`) |
| Темизация | **next-themes** (`light` / `dark` / `system`) |
| Контент (блог/FAQ/privacy) | **MDX** через `@next/mdx` + `@mdx-js/react`, frontmatter через `gray-matter` |
| Toast | `sonner` |
| Календарь | `react-day-picker` + `date-fns` 4 |
| Графики | `recharts` (используется в admin-сервисе) |
| Cookies | `js-cookie` |
| Линтинг | ESLint 9 + `eslint-config-next` |
| Pre-commit | Husky 9 |
| Менеджер пакетов | npm (lockfile `package-lock.json`) |
| Контейнеризация | Docker (`Dockerfile` с многослойной сборкой, базовый образ `node:22-alpine`) |

**Принципиально нет** Redux/Zustand/Jotai-стейт-менеджеров — состояние держится в React-хуках и React Context. Нет React Query / SWR — данные грузятся через `useEffect` + `fetch` (для публичной части достаточно, см. раздел 5).

## 3. Структура проекта

```
src/
├── app/
│   ├── layout.tsx              — корневой <html>+ThemeProvider+шрифты
│   ├── globals.css             — Tailwind v4 + дизайн-токены
│   ├── [locale]/
│   │   ├── layout.tsx          — NextIntlClientProvider, generateMetadata
│   │   ├── not-found.tsx
│   │   ├── [...rest]/page.tsx  — catch-all для 404
│   │   ├── (landing)/          — лендинг
│   │   ├── (schedule)/         — просмотр расписания
│   │   └── (service)/          — сервис администрирования (см. web-admin.md)
│   └── api/
│       ├── vcourse/[...path]/route.ts  — прокси-API на бэкенд
│       └── static/[...path]/route.ts   — прокси для статики (логотипы вузов)
├── components/
│   ├── ui/                     — 36 shadcn/ui компонентов
│   ├── home/                   — секции главной страницы
│   ├── header/, faq/, download/, icons/  — другие домены
│   └── theme-provider.tsx, footer.tsx, settings-button.tsx, ...
├── content/
│   ├── blog/<slug>/{en,ru}.mdx — статьи блога с локализованным контентом
│   ├── faq/{en,ru}.mdx
│   └── privacy/{en,ru}.mdx
├── core/
│   ├── domain/                 — доменные модели (university, classroom, lesson, ...)
│   ├── network/                — networking + DTO + Mappers + API namespace
│   ├── common/                 — enums, hooks, utils
│   ├── config/, models/, mocks/, service/
├── hooks/, lib/, i18n/         — служебное
└── messages/{en,ru}/{common,components,pages}/*.json  — переводы
```

Корневой `src/app/layout.tsx` подключает `ThemeProvider` (next-themes), `Geist` и `Geist Mono`, ставит `suppressHydrationWarning` на `<html>` (требование next-themes). `src/app/[locale]/layout.tsx` оборачивает дерево в `NextIntlClientProvider`, валидирует locale (`hasLocale(routing.locales, locale) || notFound()`), вызывает `setRequestLocale(locale)` для статической оптимизации.

## 4. Маршрутизация и страницы

### 4.1. Лендинг (`src/app/[locale]/(landing)/`)

| Путь | Файл | Что показывает |
| --- | --- | --- |
| `/[locale]` | `page.tsx` | Главная: hero с изометрическими карточками, секции «Возможности», «Мобильное приложение», «Университеты» |
| `/[locale]/about` | `about/page.tsx` + `about-content.tsx` | О проекте |
| `/[locale]/download` | `download/page.tsx` | Витрина магазинов (App Store, Google Play, RuStore) |
| `/[locale]/faq` | `faq/page.tsx` | FAQ из MDX (`src/content/faq/{en,ru}.mdx`) |
| `/[locale]/blog` | `blog/page.tsx` + `blog-grid.tsx` + `blog-card.tsx` | Список статей |
| `/[locale]/blog/[slug]` | `blog/[slug]/page.tsx` | Статья из MDX |
| `/[locale]/privacy` | `privacy/page.tsx` | Privacy Policy (MDX) |

Общий лейаут лендинга (`(landing)/layout.tsx`) подключает шапку (`<Header />` с `ThemeToggle`, `LanguageToggle`, `DownloadButton`), футер и формирует `generateMetadata` (OG, Twitter, canonical).

> **Точка развития (для ВКР подаём как реализованное к моменту защиты):** отдельная страница `/[locale]/for-universities` — посадка для лица, принимающего решения в учебном заведении: описание сервиса администрирования, ключевые сценарии, контактная форма. Сейчас в коде её ещё нет.

### 4.2. Веб-просмотр расписания (`src/app/[locale]/(schedule)/`)

Одна страница: `/[locale]/schedule` (`schedule/page.tsx` → `<ScheduleContent />`).

**Архитектура:** один большой client-component `ScheduleContent` (`schedule-content.tsx`, ~600 строк), который оркестрирует:

- **Список вузов** — `UniversityAPI.load()` (через прокси `/api/vcourse/universities`);
- **Выбор вуза** — `UniversityCombobox` (cmdk-based combobox), сохранение в `localStorage` (`selected-university-id`);
- **Метаданные вуза** — параллельная загрузка `Promise.all([TimetableAPI, StudentGroupAPI, TutorAPI, ClassroomAPI])` сразу после смены вуза;
- **Историю выбранных сущностей** — `getHistory(universityId)` / `setCachedEntity(...)` в `localStorage`;
- **URL state** — `universityId`, `type`, `id` в `useSearchParams` для shareable-ссылок (`router.replace(...)` без скролла);
- **Загрузку расписания** — `LessonAPI.load(universityId, type, entityId, since, until, groups, tutors, classrooms)` с диапазоном `±1 год`;
- **Сетку расписания** — `<ScheduleGrid range timetable lessons scheduleType />`;
- **Боковую панель и navigation island** — desktop-сайдбар (collapsible, состояние в `localStorage`) и мобильный «остров» внизу экрана.

**Адаптивность:** breakpoints через `window.innerWidth` + `addEventListener("resize")` → `isLg < 1024`, `isMobile < 640`. На мобильных скрывается боковая панель, появляется «островная» навигация.

**Запоминание состояния:** университет, история выбранных сущностей, сворачивание сайдбара — всё в `localStorage`. Это даёт UX, близкий к нативному приложению: один раз настроил — каждый визит сразу к нужной группе/преподавателю.

**Поиск:** глобальный поиск по группам/преподавателям/аудиториям через `cmdk` (`SearchDialog`, `SearchCommand`), горячая клавиша `⌘K` / `Ctrl+K`.

> **Точка развития (для ВКР подаём как реализованное к моменту защиты):** переход на список вузов **собственного сервиса** (UniversityData из admin-сервиса) — сейчас просмотр расписания работает с теми вузами, которые мы парсим (через бэкенд-парсер). К защите запланирован объединённый список: «парсинговые вузы + вузы собственного сервиса», с пометкой источника.

## 5. Сетевой слой и прокси-API

### 5.1. Прокси-роуты Next.js

Web не ходит на бэкенд напрямую — все запросы идут **через серверные Route Handlers Next.js**, которые подставляют секрет авторизации:

- **`/api/vcourse/[...path]/route.ts`** — прокси к основному API. Из переменных окружения подставляет `VC_API_URL`, `VC_AUTH_TOKEN`, `VC_API_VERSION`. Все GET-запросы кешируются Next.js на час (`next: { revalidate: 3600 }`). Для пути `universities` принудительно добавляется `?available=true` (фильтр на бэке).
- **`/api/static/[...path]/route.ts`** — прокси для статики (логотипы вузов). Кеш-флаги: ISR `revalidate: 86400` (сутки) + браузерный `Cache-Control: public, max-age=31536000, immutable`.

Это критическая архитектурная точка: **общий клиентский ключ платформы (`Authorization: Bearer <UUID>`), который зашит в мобильных приложениях, на вебе НЕ передаётся клиенту**. Он живёт только в server-side переменной окружения `VC_AUTH_TOKEN` и подставляется на стороне Next.js-сервера. Это устраняет риск «расшарить токен через DevTools» и одновременно даёт серверный кеш на час, что снижает нагрузку на бэкенд.

### 5.2. Клиентский слой

В `src/core/network/`:

- **`networking.ts`** — generic `Endpoint<Response>` и `NetworkClient` поверх `fetch`. `BASE_URL = "/api/vcourse/"` — все запросы идут на свой Next.js-сервер.
- **`api/*.ts`** — namespace-объекты по доменам: `UniversityAPI`, `StudentGroupAPI`, `TutorAPI`, `ClassroomAPI`, `TimetableAPI`, `LessonAPI`. Симметрично iOS/Android.
- **`dto/*.ts`** — формы DTO API.
- **`responses/*.ts`** — обёртки ответов (`LessonResponse`, `StudentGroupResponse`, ...).
- **`mappers/*.ts`** — `*Mapper.map(dtos)` → доменные модели.
- **`domain/*.ts`** — `university`, `student-group`, `tutor`, `classroom`, `lesson`, `timetable` — те же модели, что в iOS/Android.

Изоморфизм с мобильными клиентами сохранён: тот же контракт DTO → Domain через Mappers, те же namespace-API, та же логика загрузки `since/until ±1 год`.

## 6. Локализация (next-intl)

- Поддерживаемые locale: `en`, `ru`. defaultLocale: `en`.
- Конфигурация — в `src/i18n/routing.ts` (locales, defaultLocale) и `src/i18n/request.ts` (загрузка translation-файлов).
- Все маршруты префиксируются `[locale]`; `LocaleSwitcher` использует `Link` из `@/i18n/navigation`, который добавляет/меняет префикс.
- Переводы лежат в `messages/<locale>/{common,components,pages}/*.json` — разделены на три домена:
  - `common/` — переиспользуемые элементы (button, input, validation, toast, ...);
  - `components/` — переводы компонентов (header, footer, lesson-card, ...);
  - `pages/` — переводы экранов (home, about, faq, blog, schedule, ...).

  Такое разделение — точный аналог iOS String Catalogs / Android `strings_<domain>.xml`. Файлы загружаются динамическим импортом в `getRequestConfig`, отсутствующие — заменяются пустым объектом (fault-tolerant).

## 7. Темизация

- Через `next-themes` (`<ThemeProvider>` в корневом `layout.tsx`, `suppressHydrationWarning` на `<html>`).
- 3 режима: `light`, `dark`, `system` — соответствует iOS/Android.
- Тема переключается через `ThemeToggle` в шапке, состояние хранится в `localStorage`.
- Цветовая палитра задана в `src/app/globals.css` через CSS-переменные Tailwind v4. **Акцентные цветовые схемы из мобильных приложений на вебе пока не реализованы** — продукт работает в одной фирменной палитре. Это точка развития (см. раздел 11).

## 8. Контент (блог / FAQ / Privacy)

### 8.1. Блог

- Контент: MDX-файлы в `src/content/blog/<slug>/{en,ru}.mdx` (один slug — две локали).
- Чтение — серверная утилита `src/lib/blog.ts`: `fs.readFileSync` + `gray-matter` для frontmatter (createdAt, title, cover, ...).
- На момент ревью две статьи: `2025-wrapped`, `android-web-and-new-universities`.
- Обложки — в `public/blog/<slug>/cover.jpg`, в коде используется helper `getCoverImageUrl(slug)` с опцией оффлоада на CDN (`NEXT_PUBLIC_BLOG_CDN_URL`).
- Сортировка превью — по `createdAt` (новые сверху).
- Опасный slug-injection отсекается через `path.basename(slug)` перед чтением файла.

### 8.2. FAQ и Privacy Policy

Тоже MDX (`src/content/faq/{en,ru}.mdx`, `src/content/privacy/{en,ru}.mdx`) — компилируются Next.js через `@next/mdx`, рендерятся как обычные страницы. Это разделяет контент от компонентов: правки текста делаются без правки кода.

## 9. SEO и метаданные

- `generateMetadata()` в `[locale]/(landing)/layout.tsx` и `[locale]/layout.tsx` строит:
  - `metadataBase: new URL("https://vcourse.app")`;
  - локализованные `title` / `description` из `pages.home.metadata` / `pages.schedule.metadata`;
  - **OpenGraph**: `type: "article"`, локализованные изображения (`/opengraph/home-opengraph-{locale}.png`, 1200×630), `locale: "ru_RU" | "en_US"`, `siteName`;
  - **Twitter Cards**: `summary_large_image`.
- `generateStaticParams()` возвращает обе локали — Next.js статически пререндерит `/en`, `/ru` и подстраницы лендинга на build.

`robots.txt` / `sitemap.xml` на момент ревью отсутствуют — точка развития.

## 10. CI/CD и деплой

- **Сборка:** `next build` с `output: "standalone"` (Next.js собирает минимальный `server.js` + только нужные `node_modules`).
- **Контейнеризация:** `Dockerfile` — многослойная сборка на `node:22-alpine`:
  1. `deps` — `npm ci`;
  2. `builder` — `npm run build`;
  3. `runner` — копируется `.next/standalone`, `.next/static`, `public/`, переключается на non-root user `nextjs:nodejs (1001)`, экспонируется `3000`, запускается `node server.js`.
- **Дистрибуция:** собственный VPS, деплой через push в ветку → SSH-сборка контейнера и перезапуск. CI/CD через GitHub Actions **не настроен** (директория `.github/` отсутствует) — это точка развития.
- **Pre-commit hook:** Husky (`.husky/pre-commit`) запускает линтер перед коммитом.

## 11. Ограничения текущей реализации (для главы 3.5.5 и заключения)

1. **Нет автотестов** (полностью симметрично iOS/Android).
2. **Нет CI/CD** — деплой полу-ручной (push → SSH-перезапуск контейнера).
3. **Управление данными «руками»** — `useEffect + fetch + setState`, без React Query / SWR. Для текущего объёма публичной части достаточно, но при росте интерактивности (например, real-time-обновлений) понадобится миграция.
4. **Нет акцентных цветовых схем** — в отличие от iOS (12 цветов) и Android (9 цветов), на вебе одна фирменная палитра. Перенос акцентных тем — задача дальнейшего развития.
5. **Нет SEO-инфраструктуры** — `sitemap.xml`, `robots.txt`, structured data (JSON-LD) не настроены.
6. **Нет аналитики на клиенте** — отсутствует Plausible / Yandex.Metrica / собственный трекер. Метрики собираются на бэкенде.
7. **Нет страницы «Университетам»** в текущем коде. Запланировано к моменту защиты (заверено автором).
8. **Веб-просмотр расписания работает только с парсинговыми вузами**, без вузов собственного сервиса. Объединённый список — задача к защите (заверено автором).

## 12. Соответствие требованиям из главы 1

| Требование | Как реализовано в публичной части Web |
| --- | --- |
| Нативный внешний вид | shadcn/ui + Radix + Tailwind v4 — поверх HTML5-семантики |
| Скорость | `output: "standalone"`, статический пререндеринг лендинга, кеш 1 час на API-прокси, immutable cache на статике |
| Адаптивность | desktop / tablet / mobile через Tailwind-брейкпойнты + JS-watcher `window.innerWidth` для расписания |
| Доступность | Radix UI primitives (ARIA-correct по умолчанию), keyboard navigation в combobox/cmdk |
| Локализация | next-intl, две локали, переводы разнесены на 3 домена (common/components/pages) |
| Темизация | next-themes с поддержкой system-preference |
| Безопасность | клиентский ключ платформы не утекает в браузер — Next.js Route Handler подставляет его на сервере |

## 13. Кросс-платформенные наблюдения (для главы 3 и `_cross-platform.md`)

| Слой | iOS | Android | Web (public) |
| --- | --- | --- | --- |
| UI-фреймворк | SwiftUI | Jetpack Compose | React 19 + Next.js 16 |
| Реактивность | Observation framework | `StateFlow` | React hooks + Context |
| Networking | `URLSession` | OkHttp | `fetch` + **Next.js proxy** |
| Auth-токен | в коде клиента | в коде клиента | **только на сервере (env)** |
| Domain/DTO/Mapper | да | да | да |
| Кэш расписания | SwiftData ±1 год | Room ±1 год | `localStorage` (выбор сущности) + ISR на API-прокси |
| Локализация | String Catalogs | `values-<locale>` XML | `next-intl` JSON, three-tier |
| Темизация | 3 mode + 12 акцентов | 3 mode + 9 акцентов | 3 mode (без акцентов) |
| Кеш изображений | URLSession.shared | Coil (если нужен) | Next.js proxy + browser immutable cache |
| Поделиться ссылкой на расписание | deep link `vcourse://...` | deep link `vcourse://...` | URL params `?universityId=...&type=...&id=...` |

Главная архитектурная особенность web-клиента — **Next.js как BFF (Backend-For-Frontend)**: прокси-роуты выступают тонкой прослойкой, которая решает три задачи: скрыть клиентский ключ, кешировать ответы бэкенда, нормализовать формат. Это содержание для пункта 3.3.1 главы 3 и одна из ключевых точек защиты «единого продуктового подхода».

## 14. Куда дальше

- Содержание перейдёт в раздел **3.3.1 «Публичная часть»** главы 3 ВКР: ~5–7 страниц.
- После завершения ревью админ-сервиса (см. [web-admin.md](web-admin.md)) — собрать сводный `clients/_cross-platform.md` с матрицей единого подхода iOS ↔ Android ↔ Web. Из неё в ВКР пойдёт раздел 2.2.1 «Принцип нативности и единого подхода» и вводная глава 3.
