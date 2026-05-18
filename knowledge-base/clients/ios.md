# iOS-приложение

> Источник: ревью репозитория `~/Developer/VCourse/iOS/VCourse` на коммите от 18.05.2026.
> Структура файла подобрана так, чтобы её можно было напрямую переложить в раздел 3.1 главы 3 ВКР.

---

## 1. Общая характеристика

- **Название продукта:** VCourse (бренд «ВКурсе»).
- **Bundle ID приложения:** `app.vcourse-llc.vcourse`.
- **Bundle ID расширения:** `app.vcourse-llc.vcourse.widgets` (по конвенции, фактическое имя см. в `Widgets.plist`).
- **App Group:** `group.app.vcourse-llc.vcourse-group` (используется для шаринга `UserDefaults` и SwiftData-хранилища с виджетами).
- **Минимальная поддерживаемая версия iOS:** 17.6 (по виджет-расширению). В `project.pbxproj` у основного таргета случайно повышено до 18.5 — нужно вернуть на 17.6 (TODO для автора).
- **Версия приложения на момент ревью:** 0.2.3 (build 1).
- **Команда разработки:** один разработчик (автор ВКР).
- **Объём кодовой базы:** ~140 файлов Swift, **≈18 500 строк** (включая виджет-расширение).
- **Внешние зависимости (Swift Package Manager):** одна — [`SwiftUI-Shimmer`](https://github.com/markiv/SwiftUI-Shimmer) для skeleton-анимации.

## 2. Технологический стек

| Категория | Используется |
| --- | --- |
| Язык | Swift 5 |
| UI-фреймворк | SwiftUI |
| Реактивность | Observation framework (`@Observable`, `@Bindable`) |
| Конкурентность | Swift Concurrency (`async/await`, `Task`, `TaskGroup`, `@MainActor`) |
| Локальное хранилище | SwiftData (`@Model`, `ModelContainer`, `ModelContext`, `FetchDescriptor`, `#Predicate`) |
| Хранилище настроек | `UserDefaults(suiteName:)` через App Group |
| Сеть | `URLSession` + `async/await`, без сторонних библиотек |
| Виджеты | WidgetKit (`TimelineProvider`, `StaticConfiguration`) |
| Подсказки | TipKit |
| Мониторинг сети | `Network.framework` (`NWPathMonitor`) |
| Локализация | String Catalogs (`.xcstrings`), русский и английский |
| Тактильная отдача | `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, `UISelectionFeedbackGenerator` |
| Менеджер зависимостей | Swift Package Manager |
| Управление сборками | Xcode (Archive → App Store Connect вручную; Xcode Cloud был отключён из-за региональных ограничений) |

Принципиально **только нативные технологии Apple**. Сторонняя зависимость только одна (визуальный shimmer) — это сознательная позиция: максимальная нативность, минимизация поверхности риска от внешних библиотек.

## 3. Архитектура

### 3.1. Архитектурный паттерн

Архитектура — **MV (Model-View) на базе SwiftUI и Observation framework**, без жёсткой привязки к классическому MVVM. Состояние приложения хранится в `@Observable`-моделях (`AppModel`, `LessonModel`, `UniversityModel` и т.д.), которые передаются во вью через SwiftUI `Environment`. Это идиоматический подход для iOS 17+ и заменяет ручные ViewModel-классы из эпохи Combine.

Поверх этого паттерна используются:

- **Repository pattern** для слоя данных (по одному репозиторию на сущность: `LessonRepository`, `UniversityRepository`, ...). Репозиторий инкапсулирует операции над SwiftData и предоставляет вью-моделям доменные типы.
- **Coordinator/Router pattern** для навигации (см. ниже).
- **DTO → Domain** разделение в сетевом слое: типы `*DTO` соответствуют форматам API, типы `*` (Domain) — внутренним моделям приложения, преобразование — через `*Mapper`.

### 3.2. Композиционный корень

Главный объект приложения — `AppModel` (`Shared/Core/AppModel/AppModel.swift`). Он создаётся в `VCourseApp` (`@main`) единственный раз, помечен `@MainActor` и `@Observable`, и хранит ссылки на все доменные модели:

```
AppModel
├── roleModel: RoleModel              // Студент / Преподаватель
├── universityModel: UniversityModel  // Список и выбранный вуз
├── studentGroupModel: StudentGroupModel
├── tutorModel: TutorModel
├── buildingModel: BuildingModel
├── classroomModel: ClassroomModel
├── recentModel: RecentModel          // Недавние поиски
└── lessonModel: LessonModel          // Расписание, текущая/следующая пара, заметки
```

`AppModel.loadData(container:)` запускает поэтапную загрузку всех моделей; `updateSelectedUniversity(_:)` параллельно (через `withTaskGroup`) поднимает справочники нового вуза.

### 3.3. Внедрение зависимостей

Используется комбинированный подход:

- **SwiftUI Environment** для передачи состояния и сервисов во вью (`.environment(model)`, `@Environment(\.navigate)`, `@Environment(\.sheetRouter)`, `@Environment(\.zoomNamespace)`).
- **Синглтоны** для процессо-уровневых сервисов: `NetworkClient.shared`, `NetworkMonitor.shared`, `UserManager.shared`. Это сознательное упрощение MVP: альтернативой был бы factory-метод или DI-контейнер, но при единственном источнике конфигурации и отсутствии тестов это избыточно.
- **Property injection в моделях:** `LessonModel.appModel: AppModel` (`weak`) проставляется в инициализаторе `AppModel`, чтобы избежать ретейн-цикла между моделями.

### 3.4. Навигация

Используется **stack-based роутер поверх `NavigationStack`**:

- `Router` (`Shared/Core/Navigation/Router.swift`) — `@Observable`-объект, держит `path: [Route]` и методы `push / replace / popToRoot`.
- `Route` (`Shared/Core/Navigation/Route.swift`) — единый перечисление со всеми экранами приложения, сгруппированное по доменам (`.onboarding(_)`, `.settings(_)`, `.studentGroup(_)`, ...). Это даёт типобезопасную навигацию без stringly-typed путей.
- `Router.destination(for:with:)` — `@ViewBuilder`-метод, по `Route` возвращает соответствующий экран. Для iOS 18+ перехода на экран урока используется `navigationTransition(.zoom(...))` — нативная zoom-анимация.

Параллельно работает **`SheetRouter`** — отдельный роутер для модальных листов (`.addFavorites`, `.addNote`). Это позволяет открывать модалки из любого места без прокидывания биндингов.

Действие навигации передаётся во вью через `EnvironmentKey` `\.navigate` (тип `NavigateAction`). Это инверсия зависимостей: вью не знает про `Router`, она знает про абстрактный `navigate(Route)`-колбэк.

### 3.5. Diagram (для пояснения в ВКР)

```
┌──────────────────────────────────────────────────────────┐
│                       VCourseApp                          │
│  • создаёт AppModel, sharedModelContainer                 │
│  • применяет accent color, theme, environment             │
└──────────────────┬───────────────────────────────────────┘
                   │ environment(model), modelContainer
                   ▼
┌──────────────────────────────────────────────────────────┐
│                      ContentView                          │
│  • хранит Router, SheetRouter                             │
│  • NavigationStack(path: $router.path)                    │
│  • обрабатывает deep links vcourse://...                  │
└──────────┬────────────────────────────────┬──────────────┘
           │                                │
           ▼                                ▼
    ┌─────────────┐                  ┌──────────────┐
    │ Onboarding  │                  │ HomeScreen + │
    │  Screens    │                  │  Schedule/   │
    │             │                  │  Settings/   │
    │             │                  │  Lesson...   │
    └─────────────┘                  └──────┬───────┘
                                            │ navigate(route)
                                            ▼
                                   ┌──────────────────┐
                                   │  Router.push()   │
                                   └──────────────────┘
```

## 4. Слой данных

### 4.1. Локальное хранилище — SwiftData

Используется `ModelContainer`, объявленный в `Shared/Core/Data/AppModelContainer.swift` как глобальный `let` (`sharedModelContainer`). Контейнер размещается в **App Group**-папке (`group.app.vcourse-llc.vcourse-group/VCourse.store`), чтобы виджет-расширение читало те же данные, что и основное приложение.

Зарегистрированные `@Model`-сущности:

| Сущность | Назначение |
| --- | --- |
| `UniversityDataModel` | Кэш списка вузов |
| `StudentGroupDataModel` | Кэш учебных групп |
| `TutorDataModel` | Кэш преподавателей |
| `BuildingDataModel` | Кэш корпусов |
| `ClassroomDataModel` | Кэш аудиторий |
| `LessonDTODataModel` | Кэш расписания (сырые DTO) |
| `ScheduleMetadataModel` | Метаданные расписания: дата последнего обновления, размер кэша на диске |
| `LessonNoteDataModel` | Пользовательские заметки к парам |

При неудаче открытия контейнера (например, после ломаной миграции) реализован **повтор с очисткой store-файла** — приложение не упадёт у пользователя после обновления, в худшем случае потеряется локальный кэш.

### 4.2. Repositories

Для каждой сущности — отдельный класс-репозиторий (например, `LessonRepository`). Репозиторий:

- получает `ModelContainer` в конструкторе и создаёт `ModelContext` на каждую операцию (паттерн «short-lived context»);
- выполняет fetch через `FetchDescriptor` с `#Predicate`;
- выполняет save после `insert`/`delete`;
- инкапсулирует доменную логику (например, `LessonRepository.deleteLessons(in:for:)` не удаляет уроки, которые принадлежат другому отслеживаемому ключу — это поддерживает дедупликацию между несколькими подписками на расписания).

### 4.3. UserDefaults

`UserManager` (`Shared/Core/User/UserManager.swift`) — синглтон-обёртка над `UserDefaults(suiteName: "group.app.vcourse-llc.vcourse-group")`. Ключи централизованы в `UserDefaultsKeys`:

- `role` — выбранная роль (`.student` / `.tutor`);
- `universityID`, `studentGroupID`, `tutorID` — выбранные сущности;
- `timetable` — сериализованная сетка пар выбранного вуза;
- `favoriteStudentGroupIDs`, `favoriteTutorIDs`, `favoriteClassroomIDs` — избранное;
- `recentSearches` — недавние поиски;
- `installationID` — уникальный UUID установки (генерируется при первом запуске, отправляется в API).

Класс расширен через `UserManager+Favorites`, `+Recent`, `+Selection`, `+Reset` — это разносит ответственность по доменным группам.

## 5. Сетевой слой

### 5.1. Архитектура

- **`Endpoint<Response>`** — generic-структура, описывающая URL-путь, query-параметры и тип ответа. `urlRequest()` собирает `URLRequest`, формирует заголовки и устанавливает HTTP-метод.
- **`NetworkClient`** (синглтон) — обёртка над `URLSession`, два метода: `fetch<T: Decodable>(_:)` с автоматическим декодированием и `fetchRaw(_:)` для случаев, когда декодирование выполняется специальным маппером (расписание).
- **`NetworkError`** — типизированные ошибки: `invalidURL`, `invalidResponse`, `httpError(statusCode:data:)`, `decodingFailed`, `unknown`.
- **`NetworkMonitor`** — `@Observable` обёртка над `NWPathMonitor`, отдаёт `isConnected: Bool`. Используется в `LessonModel.scheduleRetry(...)` для автоматической попытки повторной загрузки расписания при восстановлении сети.

API сгруппированы по доменам в виде `enum`-«namespace»:
`UniversityAPI`, `StudentGroupAPI`, `TutorAPI`, `BuildingAPI`, `ClassroomAPI`, `TimetableAPI`, `LessonAPI` — статические методы возвращают доменные модели.

### 5.2. Заголовки и идентификация

Все запросы автоматически снабжаются четырьмя заголовками:

| Заголовок | Содержание |
| --- | --- |
| `Authorization` | `Bearer <UUID>` — **единый клиентский ключ платформы**. Идентифицирует не пользователя, а сам факт того, что запрос пришёл из легитимного клиента «ВКурсе». Привязка к пользователю/устройству идёт не здесь. |
| `X-API-Version` | `2` — версия контракта API. Бэк может маршрутизировать запросы клиентов разных версий. |
| `X-Installation-ID` | UUID конкретной установки приложения (хранится в `UserDefaults` под ключом `installationID`, генерируется при первом запуске). Используется бэком для аналитики уникальных пользователей и для привязки выбранного вуза/группы к устройству, не требуя авторизации. |
| `User-Agent` | Собирается в `UserAgentGenerator`: имя приложения, версия, билд, платформа, версия системы, модель устройства, Darwin-версия. Пример: `VCourse/0.2.3.1 (iOS/18.5; iPhone15,3) Darwin/24.0.0` |

> **Что описать в ВКР отдельно:** на текущей стадии в проекте отсутствует персональная авторизация пользователя — приложение работает в read-mostly режиме (просмотр расписания + локальные заметки), поэтому модель «общий клиентский ключ + анонимный installation-ID» достаточна. Переход на per-user JWT / OAuth — пункт перспектив развития (необходим для редактирования расписания преподавателями и связки с административным веб-сервисом).

### 5.3. Пример: загрузка расписания

`LessonAPI.load(universityID:type:entityID:since:until:model:)`:

1. Собирает `Endpoint<Data>` с путём `schedule/{universityID}/{group|tutor|classroom}/{entityID}` и query-параметрами `since`/`until` в формате `yyyy-MM-dd`.
2. Вызывает `NetworkClient.shared.fetchRaw(...)`.
3. Передаёт `Data` в `LessonMapper.map(...)`, который:
   - декодирует `LessonResponse` через кастомный `JSONDecoder.vcourse`;
   - в фоновой `Task.detached(priority: .userInitiated)` маппит DTO в `[Lesson]` (доменные модели с навешенными заметками);
   - возвращает кортеж `([Lesson], [LessonDTO])`.
4. `LessonModel` сохраняет DTO в SwiftData-репозиторий и обновляет in-memory `lessonsByEntity`.

### 5.4. Параллелизм при загрузке списка вузов

Особый случай — `UniversityAPI.load()`. После получения списка вузов запускается `withTaskGroup`, который параллельно загружает PNG-логотипы каждого вуза (логотипы хранятся отдельно от метаданных). Это сокращает время холодного старта при первом подключении.

## 6. Кэширование расписания

Расписание загружается **глубоко** (`since = now - 1 год`, `until = now + 1 год`), однократно сохраняется в SwiftData и далее доступно офлайн. При входе на экран расписания приложение в первую очередь **показывает данные из репозитория** (`loadFromRepository`), и параллельно идёт сетевое обновление (`load()`).

Метаданные `ScheduleMetadataModel` фиксируют:

- идентификатор сущности (группы/преподавателя/аудитории);
- дату последнего успешного обновления;
- оценочный размер кэша (на основе `JSONEncoder().encode(dtos).count`).

Это позволяет в экране «Хранилище» показать пользователю, сколько занимают локальные данные и когда они обновлялись.

При смене выбранной группы/преподавателя приложение:

1. Сбрасывает `currentLesson` / `nextLesson` / `lessonNotes`;
2. Удаляет старые уроки из SwiftData, **сохраняя** уроки, которые принадлежат другим активным подпискам (умная дедупликация);
3. Запускает свежий запрос к API;
4. Сбрасывает таймлайны виджетов через `WidgetCenter.shared.reloadAllTimelines()`.

## 7. Расчёт текущей и следующей пары

Не запрашивается у бэкенда — рассчитывается на клиенте в `LessonModel`:

1. Из `UserManager.shared.timetable` (сериализованная сетка пар вуза) берутся `slots` и времена `start`/`end`.
2. По текущему `Date()` определяется, идёт ли сейчас какой-то слот → `currentLesson`.
3. По будущим парам сегодня и завтрашним дням находится ближайший слот → `nextLesson`.
4. На момент окончания текущего слота или начала следующего планируется `Timer` (через `Timer.scheduledTimer`), который перерасчитывает состояние без участия пользователя.

Это означает, что при выключенной сети главный экран всегда показывает корректное состояние «текущая/следующая пара», пока в кэше есть расписание.

## 8. Адаптация под Liquid Glass (iOS 26+)

В коде систематически используется доступность через `if #available(iOS 26.0, *)`:

- **Акцентные цвета.** Для iOS 26+ берутся «новые» colorset-ы (`AccentBlue`, `AccentMint`, ...); для iOS 18 и ниже — `*Legacy`-варианты, повторяющие старую палитру. Это позволило подобрать цвета, корректно сочетающиеся с эффектом Liquid Glass на новых системах, не ломая внешний вид на старых.
- **Иконки приложения.** Используется новый формат `.icon` (Icon Composer) для iOS 18+, который автоматически генерирует light/dark/tinted-варианты. Параллельно сохранены legacy-`.appiconset` под старые системы.
- **Радиусы скругления.** Helper `View.adaptiveCornerRadius(_:legacy:)` подменяет значения углов между «новыми» (для Liquid Glass) и «классическими».
- **Стилизация списков.** В onboarding-списках на iOS 26+ применяются увеличенные радиусы (`18`), на старых — стандартные (`12`).
- **Переход zoom.** На экран урока на iOS 18+ используется нативный `navigationTransition(.zoom(sourceID:in:))` через `@Namespace`. На старых системах — обычный push.

Принцип: **нативный внешний вид на каждой версии системы**, без насильственной мимикрии под один стиль.

## 9. Дизайн-система внутри приложения

### 9.1. Темы

`Theme.swift` — enum с тремя состояниями: `system`, `light`, `dark`. Текущая тема хранится в `@AppStorage("selectedTheme")` и применяется через `.preferredColorScheme(theme.colorScheme)` на корневом view.

### 9.2. Акцентные цвета (12 шт.)

`AccentColor.swift`: `blue, cyan, green, pink, orange, mint, indigo, red, yellow, purple, chartreuse, loving`. Текущий цвет хранится в `@AppStorage("accentColor")`. Применяется двумя способами:

- через SwiftUI `.accentColor(...)` на root-view;
- через **UIKit appearance** (`UINavigationBar.appearance().tintColor = ...`) — это нужно потому, что часть системных контроллеров (`UIAlertController`, `UIDatePicker`, `UIStepper`, `UIPageControl` и т.д.) тинтуется только через UIKit-API.

> Примечание: в `clients/ios.md` предыдущей версии указывалось «13 акцентных цветов». По факту в коде 12 — нужно сверить с цифрой, заявленной в App Store, или поправить в knowledge-base.

### 9.3. Иконки приложения (8 шт.)

`Default, Abstract, Black, Dev, Green, Isometric, Orange, Pinkie`. Каждая — отдельный `.icon` (Icon Composer) с автогенерируемыми light/dark/tinted-вариантами + дублирующий `.appiconset` для устаревших систем. Изменение иконки идёт через `UIApplication.shared.setAlternateIconName(_:)`.

### 9.4. Семантические иконки

Системные SF Symbols выведены в типобезопасное перечисление `Icon` (`Shared/Core/Common/Design/Icon.swift`), сгруппированное по доменам: `.role`, `.entity`, `.system`, `.feature`, `.action`. Вариант стиля (`.fill`, `.circle`, `.slash`, ...) задаётся через `Variant`. Это исключает «магические строки» вроде `"person.2.fill"` в коде вью.

### 9.5. Тактильная обратная связь

`HapticManager` централизует все вызовы. Поддерживаемые типы: `soft, light, medium, heavy, rigid, success, warning, error, selection`. Один источник — облегчает донастройку «силы» обратной связи без поиска по всему коду.

### 9.6. Локализация

String Catalogs (`.xcstrings`), русский и английский. Файлы разделены по доменам:

- `Common/`: Alert, Button, Confirmation, ContextMenu, List, Localizable, Navigation, Picker, Searchable, System, Theme, Tip;
- `Components/`: AppIcon, Break, DayInfoBar, EmptyState, HeaderRow, LessonCard, OnboardingInfoText, ScheduleCard, SettingsHeader, Warning, Widget;
- `Screens/`: Home, Lesson, Settings;
- `InfoPlist.xcstrings` — локализованные строки `Info.plist`.

Разнесение по таблицам сокращает «шум» в одном крупном файле и улучшает работу переводчиков.

## 10. Виджеты (WidgetKit)

Два виджета, оба — `StaticConfiguration` (без User Configuration Intent):

### 10.1. LessonsCountWidget

- Поддерживаемые семейства: `systemSmall`.
- Содержание: количество пар сегодня.
- Провайдер: `LessonsCountProvider` (`TimelineProvider`). Логика: запрашивает у бэка `LessonAPI.count(...)` для текущего пользователя; следующее обновление — через 10 минут.

### 10.2. NotesWidget

- Поддерживаемые семейства: `systemSmall`, `systemMedium`, `systemLarge`.
- Содержание: ближайшие заметки пользователя к парам, в трёх плотностях.
- Провайдер: `NotesProvider` (читает из общего SwiftData-стора).

### 10.3. Архитектурное наблюдение

Виджеты **читают тот же `sharedModelContainer`**, что и основное приложение, благодаря App Group. Это позволяет:

- не дублировать сетевой код в виджете;
- мгновенно отражать в виджете изменение заметок, сделанное в приложении (через `WidgetCenter.shared.reloadAllTimelines()`);
- сохранить таймлайн виджета актуальным даже офлайн.

## 11. Системные интеграции

- **Глубокие ссылки (URL scheme `vcourse://`).** Обрабатываются в `ContentView.handleDeepLink(_:)`. Поддерживаемые хосты: `vcourse://schedule` → расписание текущего пользователя; `vcourse://notes` → экран активных заметок.
- **Внешние карты.** `Info.plist → LSApplicationQueriesSchemes`: `yandexmaps`, `comgooglemaps`, `dgis`. Это позволяет проверять, какие картографические приложения установлены у пользователя, и предлагать открытие корпуса в выбранном.
- **TipKit.** Используется для onboarding-подсказок (`ScheduleCardTip`, `ContextMenuTip`, `LessonCardTip`, `SearchTip`, `LocationUnavailableTip`). Конфигурируется в `App.swift` (`Tips.configure()`), все подсказки локализованы через String Catalog `Tip`.
- **Mонитор сети.** `NWPathMonitor` запускается синглтоном `NetworkMonitor` и автоматически инициирует повтор загрузки при появлении сети.

## 12. CI/CD и публикация

- **Сборка релизов:** локально через Xcode → Product → Archive → App Store Connect (вручную).
- **Xcode Cloud не используется** — был отключён в России на момент разработки; решение зафиксировано как ограничение MVP.
- **Сертификаты и provisioning:** автоматический managed signing, Apple Developer Account `Z7XR59T664`.
- **Подпись:** через Xcode Automatic Signing.
- **Дистрибуция:** App Store (production).

## 13. Тестирование

В репозитории **отсутствуют автотесты** (unit / UI / snapshot). Это сознательное ограничение текущей стадии MVP: высокая скорость продуктовых итераций приоритетнее, инвариант проверяется ручным регрессом в TestFlight + анализом метрик и обратной связи пользователей. В ВКР подаётся честно: «автоматическое тестирование клиентских приложений вынесено в перспективы развития» (раздел 3.5.5 и заключение).

## 14. Ограничения текущей реализации (для главы 3.5.5 и заключения)

1. Отсутствуют автотесты (см. п. 13).
2. Нет схем сборки Debug/Staging/Release — приложение всегда стучится в продакшен-API (`https://api.vcourse.app/`). Разделение xcconfig-схем — задача дальнейшего развития.
3. Нет push-уведомлений — APNs не подключён. Обновления расписания пользователь видит при открытии приложения / обновлении виджета.
4. Нет персональной авторизации — все клиенты ходят под общим Bearer-токеном платформы, идентификация устройства — через `X-Installation-ID`. Не поддерживает редактирование пользователем с правами (преподаватель/методист).
5. Реал-тайм-обновлений нет — модель строго pull-based, частота обновления виджета ограничена политикой WidgetKit (~10 минут минимум).
6. У основного таргета в `project.pbxproj` deployment target случайно повышен до 18.5 (вместо 17.6 у виджета). Нужно вернуть на 17.6 — иначе сужается аудитория без причины.
7. Аналитика на клиенте отсутствует (нет Firebase / AppMetrica / собственного трекера). Метрики собираются по событиям на бэкенде (Grafana).

## 15. Соответствие требованиям из главы 1 (для главы 3.1)

| Требование | Как реализовано в iOS |
| --- | --- |
| Нативный внешний вид | SwiftUI, системные компоненты, отдельные адаптации под iOS 26+ Liquid Glass |
| Офлайн-режим | Глубокий кэш расписания на год вперёд/назад в SwiftData; расчёт текущей пары на клиенте |
| Скорость холодного старта | Локальные данные показываются первыми, сеть обновляет фоном; параллельная загрузка справочников вуза через `TaskGroup` |
| Персонализация | 12 акцентных цветов, 8 иконок, 3 режима темы, локализация RU/EN |
| Системные интеграции | Виджеты (2 шт., 4 семейства), TipKit, deep links, внешние карты |
| Доступность | SF Symbols, Dynamic Type через `.font(.subheadline)` и т.д., полная локализация |
| Адаптация под платформу | App Group-шаринг между приложением и виджетом, нативная zoom-навигация на iOS 18+ |

## 16. Куда дальше

После завершения ревью iOS-репо аналогичные файлы нужно сделать для:

- `clients/android.md` — после ревью репозитория `~/Developer/VCourse/Android` (или указать путь);
- `clients/web-public.md` и `clients/web-admin.md` — после ревью соответствующих репозиториев.

Когда все три клиента описаны, глава 3 ВКР наполняется параллельно: разделы 3.1, 3.2, 3.3 берутся почти напрямую из соответствующих knowledge-base файлов с минимальной литературной редактурой.
