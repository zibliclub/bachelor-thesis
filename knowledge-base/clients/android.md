# Android-приложение

> Источник: ревью репозитория `~/Developer/VCourse/Android/VCourse` на коммите от 18.05.2026.
> Структура файла подобрана так, чтобы её можно было напрямую переложить в раздел 3.2 главы 3 ВКР.
> Перед использованием в ВКР — обязательно прочитать раздел 0 «Что НЕ упоминать в ВКР».

---

## 0. Что НЕ упоминать в ВКР

**Запрет на упоминание** в тексте диплома и на защите следующих фактов (по явной просьбе автора):

1. **Подключённые, но фактически не используемые зависимости Retrofit + converter-moshi.** В `build.gradle.kts` подключены `libs.retrofit` и `libs.converter.moshi`, но `NetworkClient` собирает HTTP-запросы напрямую через `OkHttpClient.newCall(...)`. Это **легаси-зависимости**, оставшиеся от ранних экспериментов. В файле они упомянуты для полноты картины, в дипломе — описываем сетевой слой как «OkHttp + Moshi», без упоминания Retrofit вовсе.
2. **Подпись release-сборки debug-ключом.** Подаём как «настройка production release signing — задача перспектив развития» без раскрытия деталей. Подробнее в разделе 12.

---

## 1. Общая характеристика

- **Название продукта:** VCourse (бренд «ВКурсе»).
- **Application ID:** `app.vcourse.vcourse`.
- **Минимальный SDK:** 29 (Android 10).
- **Целевой SDK:** 36 (Android 16).
- **Compile SDK:** 36, **JVM target:** Java 11, **Kotlin:** 2.2.21.
- **Версия приложения на момент ревью:** `versionName = 0.1.5`, `versionCode = 10`.
- **Структура проекта:** single-module (`:app`), весь код в одном Gradle-модуле.
- **Объём кодовой базы:** **225 файлов Kotlin, ≈23 500 строк** (заметно больше iOS, ~18 500 строк — отчасти из-за многословности Kotlin/Compose, отчасти из-за дополнительных хелперов под платформу).
- **Дистрибуция:** Google Play и RuStore.
- **Доля среди пользователей экосистемы:** ~19%.

## 2. Технологический стек

| Категория | Используется |
| --- | --- |
| Язык | Kotlin 2.2.21 |
| UI-фреймворк | Jetpack Compose (Compose BOM 2025.10.01) |
| Дизайн-система | Material Design 3 Expressive (`androidx.compose.material3:material3:1.5.0-alpha07`) |
| Сборка | Android Gradle Plugin 8.13.1, Gradle Version Catalog (`libs.versions.toml`) |
| Реактивность | Kotlin Coroutines + Flow (`StateFlow`, `MutableStateFlow`) |
| Конкурентность | Kotlin Coroutines (`CoroutineScope`, `SupervisorJob`, `Dispatchers.IO`, structured concurrency) |
| Локальное хранилище (SQL) | Room 2.8.4 (через kapt) |
| Локальное хранилище (key-value) | Jetpack DataStore Preferences (для UI-настроек) + `SharedPreferences` (для пользовательской сессии) |
| Сеть | OkHttp 5.3.2 + Moshi 1.15.2 (kotlin-reflect adapter) |
| Сериализация (общая) | kotlinx.serialization 1.9.0 (для DataStore-моделей и route-аргументов навигации) |
| Логирование сети | OkHttp logging-interceptor 5.3.2 |
| Навигация | Navigation Compose 2.9.5 (type-safe routes через `@Serializable`) |
| Splash | `androidx.core:core-splashscreen` 1.0.1 |
| Иконки | Material Icons Extended |
| Карты (внешние) | `transportation-consumer` 4.0 (Google Maps Platform — для интеграции с картами при показе корпуса; используется минимально) |
| Менеджер зависимостей | Gradle Version Catalog |

**Никаких DI-фреймворков (Hilt, Koin, Dagger) — сознательно.** Композиционный корень собирается вручную в синглтон-объекте `Dependencies` (подробнее в 3.3).

## 3. Архитектура

### 3.1. Архитектурный паттерн

Архитектура — **MVI/MV-гибрид на базе Jetpack Compose и `StateFlow`**, без AndroidX `ViewModel`. Состояние приложения хранится в обычных Kotlin-классах, помеченных `@Stable` (`AppModel`, `LessonModel`, ...), которые предоставляются дереву Composable-функций через `CompositionLocal`. Это идиоматический «Compose-first»-подход, концептуально симметричный iOS-приложению, где состояние держится в `@Observable`-моделях и пробрасывается через `Environment`.

Поверх этого паттерна:

- **Repository pattern** для слоя данных (по одному репозиторию на сущность: `LessonRepository`, `UniversityRepository`, ..., каждый поверх Room DAO);
- **Type-safe navigation** через `@Serializable`-объекты и data-классы (новый API Navigation Compose 2.9);
- **DTO → Domain** разделение в сетевом слое: типы `*Dto` — формат API, типы из `core/domain` — внутренние модели, преобразование — через `*Mapper`.

### 3.2. Композиционный корень

Главный объект состояния — `AppModel` (`core/model/AppModel.kt`). Он создаётся в `MainActivity.AppEntryPoint(...)` один раз через `remember { AppModel(...) }`, помечен `@Stable`, и хранит ссылки на доменные модели:

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

`AppModel.loadInitialData()` запускается из `init {}` и поэтапно поднимает все модели в собственной корутине (`SupervisorJob + Dispatchers.IO`). Часть моделей загружаются параллельно через `coroutineScope { launch { ... } }`, дальнейшая логика ждёт их готовности через `StateFlow<Boolean>` и `waitForModelLoaded(...)` с таймаутом 90 секунд.

`AppModel` предоставляется в дерево Composable через `staticCompositionLocalOf` (`LocalAppModel`). Любая экранная функция получает к нему доступ через `LocalAppModel.current` — это аналог `@Environment(AppModel.self)` из iOS.

### 3.3. Внедрение зависимостей

Используется **ручной DI без фреймворков** — синглтон-объект `Dependencies` (`core/Dependencies.kt`) с `lateinit var`-полями:

```kotlin
object Dependencies {
    lateinit var universityRepository: UniversityRepository
    lateinit var studentGroupRepository: StudentGroupRepository
    // ...
    lateinit var networkMonitor: NetworkMonitor

    fun init(context: Context) {
        val database = AppDatabase.getInstance(context)
        universityRepository = UniversityRepository(database.universityDao())
        // ...
    }
}
```

`Dependencies.init(this)` вызывается из `MainActivity.onCreate()` — один раз на жизнь процесса. Это сознательное упрощение MVP: при единственном источнике конфигурации и отсутствии тестов DI-фреймворк (Hilt) добавил бы compile-time-нагрузку и шаблонный код без выгоды. Симметрично iOS, где зависимости поднимаются вручную в `AppModel` без Swift-аналогов Hilt.

Дополнительно используется глобальный `object ContextHolder { lateinit var appContext: Context }` для доступа к `applicationContext` из мест, где он недоступен напрямую (например, из синглтонов внутри сетевого слоя).

### 3.4. Навигация

Используется **Jetpack Navigation Compose 2.9 с type-safe routes**:

- Каждый экран — `@Serializable object` или `@Serializable data class` (`core/navigation/Screens.kt`). Аргументы экрана выражаются как поля data-класса.
- Граф навигации — `AppNavGraph(navController)` (`core/navigation/AppNavGraph.kt`), плоский `NavHost` со всеми экранами.
- Переходы между экранами стилизованы тремя кастомными composables (`fadeComposable`, `horizontalSlideFadeComposable`, `verticalSlideFadeComposable`) — это «обёртки» над `composable<T>()` с заданными `enterTransition` / `exitTransition`, имитирующие нативные iOS-переходы (горизонтальный slide для push, вертикальный slide для модальных экранов).
- Аргументы экранов десериализуются типобезопасно через `navBackStackEntry.toRoute<T>()`.
- Флаг прохождения онбординга хранится в отдельных `SharedPreferences` (`app_prefs`), startDestination переключается в зависимости от него.

Симметрично iOS: вместо `enum Route` + `Router.path: [Route]` — `@Serializable`-классы + `NavController.navigate(...)`.

### 3.5. Диаграмма композиции (для пояснения в ВКР)

```
┌──────────────────────────────────────────────────────────┐
│                     MainActivity                          │
│  • installSplashScreen, enableEdgeToEdge                  │
│  • ContextHolder.init(this), Dependencies.init(this)      │
│  • setContent { AppEntryPoint(...) }                      │
└────────────────────┬─────────────────────────────────────┘
                     │ remember { AppModel(...) }
                     ▼
┌──────────────────────────────────────────────────────────┐
│                    AppEntryPoint                          │
│  • themeMode / themeColor / language: StateFlow → State   │
│  • CompositionLocalProvider {                             │
│      LocalLocalizedContext, LocalAppModel                 │
│    }                                                      │
│  • AppTheme(themeColor, themeMode) {                      │
│      AppNavGraph(rememberNavController())                 │
│    }                                                      │
└────────────────────┬─────────────────────────────────────┘
                     │ NavHost(startDestination=...)
                     ▼
        ┌──────────────────────────┐
        │  Onboarding / Home /     │
        │  Schedule / Lesson /     │
        │  Settings ...            │
        └──────────────────────────┘
```

## 4. Слой данных

### 4.1. Локальное хранилище — Room

Используется один Room-`AppDatabase` (`core/data/AppDatabase.kt`, version = 1, `exportSchema = false`), singleton через double-checked locking. Зарегистрированы 8 сущностей — **строго одно-в-одно с iOS-приложением**:

| Сущность Room (Android) | Соответствие SwiftData (iOS) | Назначение |
| --- | --- | --- |
| `UniversityEntity` | `UniversityDataModel` | Кэш вузов |
| `StudentGroupEntity` | `StudentGroupDataModel` | Кэш учебных групп |
| `TutorEntity` | `TutorDataModel` | Кэш преподавателей |
| `BuildingEntity` | `BuildingDataModel` | Кэш корпусов |
| `ClassroomEntity` | `ClassroomDataModel` | Кэш аудиторий |
| `LessonDtoEntity` | `LessonDTODataModel` | Кэш расписания (сырые DTO) |
| `ScheduleMetadataEntity` | `ScheduleMetadataModel` | Метаданные расписания: время обновления, размер кэша |
| `LessonNoteEntity` | `LessonNoteDataModel` | Пользовательские заметки к парам |

`RoomConverters` — TypeConverters для `Date` (хранится как `Long`-timestamp) и `List<Int>` (хранится как CSV-строка). Под каждую сущность — отдельный DAO (`UniversityDao`, ..., `LessonDtoDao`).

Repository — обёртка над DAO с переводом в доменные типы:
- получает DAO в конструкторе;
- использует `withContext(Dispatchers.IO)` для всех операций;
- инкапсулирует доменную логику (умное удаление уроков в `LessonRepository.deleteLessons`, не задевающее уроки, принадлежащие другим активным подпискам).

### 4.2. Пользовательские настройки

Используется **двухуровневая модель хранения**, разделённая по семантике:

- **`androidx.datastore.preferences`** — для UI-настроек, читаемых **реактивно через `Flow`**:
  - тема (`ThemeMode.SYSTEM | LIGHT | DARK`) — `ThemeModeManager`;
  - акцентная цветовая схема (`ThemeColor.BLUE | CYAN | ...`) — `ThemeColorManager`;
  - язык интерфейса (`AppLanguage.RUSSIAN | ENGLISH`) — `LanguageManager`.

  Каждый менеджер — `object` со своим `stringPreferencesKey`, `flow: Flow<T>` (распространяется через `collectAsState`) и парой `saveX(...) / getSavedX()`. На уровне приложения это даёт «горячую» смену темы/цвета/языка без перезапуска.

- **`SharedPreferences`** (suite `"user_prefs"`) — для пользовательской сессии, не требующей реактивности:
  - роль (`user_role`);
  - выбранный вуз (`selected_university_id`, UUID);
  - выбранная группа (`selected_student_group_id`) или преподаватель (`selected_tutor_id`);
  - расписание звонков (`timetable`, JSON через kotlinx.serialization);
  - избранное (`favorite_student_group_ids`, `favorite_tutor_ids`, `favorite_classroom_ids`);
  - недавние поиски (`recent_searches`);
  - идентификатор установки (`installation_id`, UUID, генерируется при первом доступе).

  Класс `UserPreferences(context)` расширяется через extension-функции в `core/user/helpers/UserPreferencesSelection.kt`, `+Favorites.kt`, `+Recent.kt` — разнесение по доменным группам, аналог `UserManager+...` категорий в iOS.

Симметрично iOS: там единый `UserDefaults` через App Group, на Android аналогичной концепции App Group нет (виджетов и нет), поэтому разделение DataStore/SharedPreferences здесь — про реактивность, не про межпроцессный шаринг.

## 5. Сетевой слой

### 5.1. Архитектура

- **`Endpoint<T>`** (`core/networking/core/Endpoint.kt`) — generic-класс с `path`, `type: Class<T>`, `queryItems`. Метод `toRequest()` строит OkHttp `Request` с заголовками. URL базы (`https://api.vcourse.app/`) и единый `authToken` — `private val` внутри класса.
- **`NetworkClient`** (object) — обёртка над `OkHttpClient` (с таймаутами 30 сек на каждый этап). Единственный метод `suspend fun <T> fetch(endpoint: Endpoint<T>): T`:
  - выполняет `client.newCall(request).execute()` в `withContext(Dispatchers.IO)`;
  - если `response.code !in 200..299` — бросает `NetworkError.HttpError`;
  - если `endpoint.type == ByteArray::class.java` — возвращает сырые байты (используется для расписания, см. ниже);
  - иначе — десериализует JSON через `Moshi` (`KotlinJsonAdapterFactory + UUIDAdapter + Rfc3339DateJsonAdapter`).
- **`NetworkError`** — sealed-классы: `InvalidUrl`, `HttpError(code, body)`, `DecodingFailed`, `NoInternet`, `Unknown`.
- **`NetworkMonitor`** — обёртка над `ConnectivityManager` с `callbackFlow → StateFlow<Boolean>`. Используется в `LessonModel.load(...)`, который ждёт `isConnected.first { it }` перед сетевым запросом.
- **`Loadable`** — sealed-класс с состояниями `Idle / Loading / Loaded(data) / Failed(error)`. Полный аналог iOS-`Loadable<T>`.

> **Не упоминать в дипломе** (см. раздел 0): Retrofit и `converter-moshi` подключены в зависимостях, но не используются.

API сгруппированы по доменам как `object`-неймспейсы: `UniversityApi`, `StudentGroupApi`, `TutorApi`, `BuildingApi`, `ClassroomApi`, `TimetableApi`, `LessonApi` — `suspend fun load(...)` возвращают доменные модели.

### 5.2. Заголовки и идентификация

Все запросы автоматически снабжаются четырьмя заголовками — **полностью идентично iOS**:

| Заголовок | Содержание |
| --- | --- |
| `Authorization` | `Bearer 91ed68b2-a5bd-41a3-b0cb-df06a933e298` — **общий клиентский ключ платформы**, тот же UUID, что и в iOS-приложении. Идентифицирует не пользователя, а факт легитимного клиента «ВКурсе». |
| `X-API-Version` | `2` — версия контракта API. |
| `X-Installation-ID` | UUID конкретной установки приложения (хранится в `SharedPreferences` под ключом `installation_id`, генерируется при первом обращении через `UserPreferences.getInstallationId()`). |
| `User-Agent` | Собирается в `UserAgentGenerator` через `BuildConfig.VERSION_NAME`, `Build.MODEL`, `Build.BRAND`, `Build.VERSION.RELEASE`. Пример: `VCourse/0.1.5.10 (Android/14; Samsung SM-G990B)`. |

Этот блок — критическая точка кросс-платформенного единства: контракт идентификации на бэкенде один и тот же для iOS и Android, что упрощает аналитику и дальнейший переход на per-user JWT (отмечено в перспективах).

### 5.3. Пример: загрузка расписания

`LessonApi.load(universityId, type, entityId, since, until, model)`:

1. Маппит `ScheduleType` в URL-segment: `STUDENT_GROUP → "group"`, `TUTOR → "tutor"`, `CLASSROOM → "classroom"`.
2. Форматирует даты в `yyyy-MM-dd` (UTC).
3. Собирает `Endpoint<ByteArray>` с путём `schedule/{universityId}/{entityPath}/{entityId}` и query-параметрами `since`/`until`.
4. Вызывает `NetworkClient.fetch(...)` → получает `ByteArray`.
5. Передаёт байты в `LessonMapper.map(...)`, который декодирует `LessonResponse` через Moshi и параллельно через `LessonDtoMapper.convert` маппит DTO в доменные `Lesson`-ы с навешенными заметками.

`LessonModel.load(type, entityId, since, until)` оборачивает вызов в корутину: устанавливает `Loadable.Loading`, **ждёт восстановления сети** через `networkMonitor.isConnected.filter { it }.first()`, делает запрос, сохраняет результат через `LessonRepository.save(...)`, обновляет `_lessonsByEntity`, `_scheduleMetadata`, `_loadingStates`.

## 6. Кэширование расписания

Концептуально совпадает с iOS:

- расписание загружается глубоко (`since = now − 1 год`, `until = now + 1 год`);
- сохраняется в Room (`LessonDtoEntity`);
- при входе на экран приложение сначала вызывает `LessonModel.loadFromRepository(key)` (мгновенный показ из кэша), потом `load()` идёт в сеть и обновляет данные;
- метаданные `ScheduleMetadataEntity` хранят `entityId`, `entityTypeRaw`, `date` (последнее обновление), `size` (оценка через `JSONEncoder().toJson(...).toByteArray(UTF_8).size`);
- при смене группы/преподавателя приложение сбрасывает текущую/следующую пары, очищает заметки, удаляет уроки старой подписки (через `LessonRepository.deleteLessons`), запускает свежую загрузку;
- виджетов нет, поэтому `WidgetCenter.shared.reloadAllTimelines()`-аналог отсутствует.

## 7. Расчёт текущей и следующей пары

`LessonModel.scheduleNextSlotEvent()` — полный аналог iOS-логики:

1. Из `UserPreferences.getTimetable()` достаёт сетку слотов (`slot.start`, `slot.end` в формате `H:mm`).
2. По текущему `Date()` определяется `currentSlot` (если есть) и ближайшее будущее событие (`Started(slot)` / `Ended(slot)`).
3. Планируется `java.util.Timer` на момент следующего события: при срабатывании обновляются `_currentLesson`/`_nextLesson` (как `MutableStateFlow`) и таймер перезаказывается.
4. Состояние `_isCurrentLessonLoading` / `_isNextLessonLoading` экспортируется как `StateFlow<Boolean>` для отображения skeleton-state в UI.

Логика **не зависит от сети** — при наличии кэша приложение всегда показывает корректное состояние «текущая/следующая пара».

## 8. Дизайн-система внутри приложения

### 8.1. Темы

`ThemeMode.SYSTEM | LIGHT | DARK` (`core/managers/theme/ThemeMode.kt`). Менеджер `ThemeModeManager`:
- `themeModeFlow: Flow<ThemeMode>` — реактивно из DataStore;
- `@Composable fun isDarkTheme(themeMode)` — учитывает `isSystemInDarkTheme()` для `SYSTEM`.

В `AppTheme(...)` дополнительно настраиваются цвета status bar / navigation bar через `WindowCompat.getInsetsController(...).isAppearanceLightStatusBars`. Edge-to-edge включается через `enableEdgeToEdge()` в `MainActivity`.

### 8.2. Акцентные цветовые схемы (9 шт.)

`ThemeColor`: `BLUE, CYAN, GREEN, RED, ORANGE, MINT, PURPLE, YELLOW, LOVING`.

Для каждого цвета — отдельный `object`-тема в `ui/theme/themes/<Color>Theme.kt`, реализующий интерфейс `AppTheme` (`lightScheme: ColorScheme`, `darkScheme: ColorScheme`). Каждая схема прописана **вручную** в 100+ строк (все Material 3 token-ы: `primary`, `onPrimary`, `primaryContainer`, ..., `surfaceContainerHighest`, `primaryFixed`, ...).

Активная схема выбирается через `themeMap[themeColor]` и подаётся в `MaterialTheme(colorScheme = ..., typography = Typography)`.

**Dynamic color (Material You) сознательно не используется** — приоритет единого визуального стиля бренда на всех устройствах. План перехода на dynamic color как дополнительный режим — пункт перспектив развития (см. раздел 14).

> **Несоответствие со старым knowledge-base:** в `clients/android.md` ранее писалось «13 акцентных цветов с поддержкой dynamic color». По факту в коде **9 цветов, без dynamic color**. В файле и в ВКР используем фактическую цифру (9) + план dynamic color в перспективах.

### 8.3. Иконки приложения (8 шт.)

`AppIcon`: `BLUE, ORANGE, GREEN, BLACK, DEV, ISOMETRIC, DOODLE, ABSTRACT`. Реализованы через **классический Android-паттерн `<activity-alias>`**: в `AndroidManifest.xml` объявлено 8 alias-ов с разными `android:icon` и одним `targetActivity=".MainActivity"`. При первом запуске активен только `LauncherBlue` (`android:enabled="true"`), остальные — disabled.

`IconManager.changeIcon(context, icon)` через `PackageManager.setComponentEnabledSetting(...)` включает alias выбранной иконки и выключает все остальные. Из-за этого при смене иконки система на пару секунд снимает приложение с лаунчера и вешает заново — известное системное поведение, обходных путей нет.

Симметрично iOS (`setAlternateIconName`), но реализация принципиально разная — на iOS это API уровня OS, на Android — манифест-плюс-PackageManager.

### 8.4. Семантические иконки

`Icon` (`core/common/design/icon/Icon.kt`) — sealed-class, обёртка над `Icons.*` (Material Icons Extended). Используется для типобезопасного указания иконки в UI-коде. Концептуально совпадает с iOS-`Icon`-enum.

### 8.5. Локализация

Ресурсы:
- `res/values/strings*.xml` — английская локаль (по умолчанию);
- `res/values-ru/strings*.xml` — русская локаль;
- 26 файлов на локаль, разнесены по доменам (`strings_settings.xml`, `strings_lesson.xml`, ..., `strings_tooltip.xml`) — симметрично iOS String Catalogs.

Менеджер `LanguageManager`:
- хранит выбранную локаль в DataStore (`app_language`);
- предоставляет `createLocalizedContext(context, language)` — создаёт `Configuration`-копию с нужной локалью и оборачивает в `createConfigurationContext`;
- получившийся контекст пробрасывается в Composable-дерево через `LocalLocalizedContext`. UI обращается к `stringResource(...)` уже через локализованный контекст.

> **Архитектурное замечание:** этот подход отличается от рекомендуемого Google `AppCompatDelegate.setApplicationLocales(...)` (per-app language preferences, появилось в Android 13). Текущая реализация работает на Android 10+ и не требует перезапуска Activity, но не интегрируется с системным экраном «Языки» приложений. Возможный пункт перспектив развития — переход на per-app language preferences (но это снизит контроль за моментом применения новой локали в Compose-дереве).

### 8.6. Типографика

`Typography` (`ui/theme/Type.kt`) — стандартная Material 3 typography. Кастомный шрифт не используется.

## 9. Виджеты

**Отсутствуют.** На текущей стадии Android-приложения нет ни Glance App Widgets, ни классических `RemoteViews`-виджетов. В ВКР это подаётся в двух точках:

- 3.2.5 (или аналогичный пункт) — «функциональный паритет с iOS за исключением системных виджетов, реализация запланирована»;
- 3.5.5 (ограничения) / Заключение (перспективы) — пункт «добавление Glance App Widgets с использованием Jetpack Glance API».

## 10. Системные интеграции

- **Splash screen** — `androidx.core:core-splashscreen`, кастомная тема `Theme.VCourse.Splash`. Условие удержания сплеша на экране — `splash.setKeepOnScreenCondition { appState.isLoading }`, где `appState` ждёт первой загрузки темы/цвета/языка из DataStore.
- **Edge-to-edge** — `enableEdgeToEdge()` в `MainActivity.onCreate()`, плюс настройка `isAppearanceLightStatusBars / isAppearanceLightNavigationBars` в `AppTheme`.
- **Принудительная portrait-ориентация** — `android:screenOrientation="portrait"` для `MainActivity` (соответствует iOS-приложению, тоже только portrait).
- **`configChanges`** для `MainActivity`: `uiMode|orientation|screenSize|screenLayout|smallestScreenSize` — Activity не пересоздаётся при смене темы/размера, всё перерисовывается через Compose-рекомпозицию.
- **FileProvider** — `app.vcourse.vcourse.provider`, для безопасного шаринга файлов экспорта расписания/заметок (см. `LessonExporter`).
- **`allowBackup="true"`** + кастомные правила `backup_rules.xml` / `data_extraction_rules.xml`.
- **Карты:** подключён `transportation-consumer` (Google Maps Platform). Используется минимально — для открытия корпуса в карте; деталь будет уточнена в разделе 3.2 главы 3 при описании screen-уровня.

## 11. Конкурентность и реактивность

- Все долгоиграющие операции — внутри корутин на `CoroutineScope(SupervisorJob() + Dispatchers.IO)` (по `scope` на каждую модель).
- `withContext(Dispatchers.Main)` перед обновлением `StateFlow`, который читается из Composable-кода.
- Параллельная загрузка нескольких источников — `coroutineScope { launch { ... } }` (structured concurrency, корневая корутина дожидается всех дочерних).
- Состояние компонентов выражено через `MutableStateFlow → StateFlow` (private setter, public getter) — это удобный pattern для unidirectional data flow.
- На уровне `MainActivity` реактивные потоки преобразуются в Compose-State через `collectAsState(initial)`.

## 12. CI/CD и публикация

- **Локальная сборка:** Android Studio → Build → Generate Signed App Bundle (`.aab`).
- **Дистрибуция:** Google Play (через **App Signing by Google Play** — Play хранит app signing key и перешивает подпись), RuStore (отдельный workflow).
- **Особенность текущей конфигурации (для дальнейшего исправления, в ВКР не раскрывать детально):** в `app/build.gradle.kts` для `buildTypes.release` указано `signingConfig = signingConfigs.getByName("debug")`. Это означает, что upload-AAB подписывается debug-ключом из `~/.android/debug.keystore`. Конфигурация работает с App Signing by Google Play (Google всё равно перешивает подпись для пользователей), но завязана на конкретный debug-keystore конкретной машины разработчика — потеря keystore эквивалентна потере возможности обновлять приложение в Play. В RuStore модель доверия другая (своё app signing) и debug-keystore там может не пройти валидацию повторно.

  **Что подаём в ВКР:** «настройка production-уровня release signing (выделенный upload keystore с длительной валидностью, secret management) — задача перспектив развития». Без раскрытия деталей текущей конфигурации.

- **CI отсутствует.** Сборки делаются локально, GitHub Actions / Bitrise / Codemagic не подключены. Подаётся как ограничение MVP (раздел 14).

## 13. Тестирование

В репозитории присутствуют **только дефолтные стабы**, сгенерированные Android Studio:
- `app/src/test/java/.../ExampleUnitTest.kt` — JVM-тест с `assertEquals(4, 2 + 2)`;
- `app/src/androidTest/java/.../ExampleInstrumentedTest.kt` — instrumented-тест с проверкой `packageName`.

Эти файлы фактически не покрывают код приложения, осмысленных автотестов **нет**. Подаётся в ВКР честно как ограничение текущей стадии MVP (раздел 14 и заключение): «автоматическое тестирование клиентских приложений вынесено в перспективы развития».

## 14. Ограничения текущей реализации (для главы 3.5.5 и заключения)

1. **Нет автотестов** (см. п. 13).
2. **Нет CI/CD** — все сборки локальные, без автоматизации (`fastlane`, GitHub Actions, Bitrise).
3. **Нет схем сборки Debug/Staging/Release** — приложение всегда стучится в продакшен-API (`https://api.vcourse.app/`). Аналогично iOS, это пункт перспектив развития (build flavors / `BuildConfig`-разделение).
4. **Нет персональной авторизации** — все клиенты ходят под общим клиентским ключом, идентификация устройства — через `X-Installation-ID`. Полностью симметрично iOS.
5. **Нет виджетов** — приоритет догнать iOS-приложение по виджетам через Jetpack Glance.
6. **Нет dynamic color (Material You)** — 9 фиксированных цветовых схем. План — добавить dynamic color как дополнительный режим в Settings/Appearance.
7. **Нет push-уведомлений** — FCM не подключён.
8. **Нет реал-тайма** — модель строго pull-based.
9. **Нет аналитики на клиенте** — нет Firebase Analytics, AppMetrica, своего трекера. Метрики собираются на бэкенде.
10. **Настройка production-уровня release signing** — см. раздел 12.
11. **kapt вместо KSP** — Room генерируется через kapt, что значительно медленнее современного KSP. Миграция — мелкая, но полезная задача.
12. **`viewBinding = true`** в `build.gradle.kts` при чисто Compose-UI — наследие шаблона Android Studio, фактически не используется. Можно отключить.

## 15. Соответствие требованиям из главы 1 (для главы 3.2)

| Требование | Как реализовано в Android |
| --- | --- |
| Нативный внешний вид | Jetpack Compose, Material Design 3 Expressive (`material3:1.5.0-alpha07`), без сторонних UI-китов |
| Офлайн-режим | Глубокий кэш расписания (год вперёд / назад) в Room; расчёт текущей пары на клиенте через `LessonModel.scheduleNextSlotEvent()` |
| Скорость холодного старта | Splash screen с условием на загрузку DataStore-настроек; локальный кэш Room отрисовывается до сетевого ответа; параллельная загрузка справочников вуза через structured concurrency |
| Персонализация | 9 цветовых схем, 8 иконок (через activity-alias), 3 режима темы, языки RU/EN |
| Системные интеграции | Splash screen, edge-to-edge, FileProvider для экспорта, кастомные backup rules |
| Доступность | Material Icons Extended, локализация RU/EN, динамическая смена локали |
| Адаптация под платформу | Глубокая интеграция с Compose / Material 3 token system, реактивные DataStore-настройки, нативные переходы между экранами |

## 16. Кросс-платформенные наблюдения (для главы 3 и сравнения)

Архитектура Android-приложения **изоморфна iOS-приложению** на уровне модели данных и сетевого слоя:

| Слой | iOS | Android |
| --- | --- | --- |
| Composition root | `AppModel` в `VCourseApp` | `AppModel` через `Dependencies` + `LocalAppModel` |
| Доменные модели | `LessonModel`, `UniversityModel`, ... (`@Observable`, `@MainActor`) | `LessonModel`, `UniversityModel`, ... (`@Stable`, `StateFlow`) |
| Repository | `LessonRepository`, ..., над SwiftData | `LessonRepository`, ..., над Room DAO |
| Sync storage | `UserDefaults` (App Group) | `SharedPreferences` (`user_prefs`) + DataStore (UI) |
| Networking | `URLSession + async/await`, `Endpoint<T>` | `OkHttp + Moshi + coroutines`, `Endpoint<T>` |
| Заголовки | `Authorization`, `X-API-Version`, `X-Installation-ID`, `User-Agent` | **те же самые** |
| Domain ↔ DTO | `*DTO + *Mapper` | `*Dto + *Mapper` (одно-в-одно) |
| Navigation | `NavigationStack + Route enum + Router` | `Navigation Compose + @Serializable Screens + NavController` |
| Sheet/modal | `SheetRouter + SheetRoute` | `verticalSlideFadeComposable` + те же экраны |
| Кэш расписания | `±1 год` + `ScheduleMetadata` + умное удаление | **тот же подход и тот же набор полей** |
| Текущая/следующая пара | расчёт на клиенте через `Timer` | расчёт на клиенте через `java.util.Timer` |
| 8 иконок | `setAlternateIconName` + `.icon` бандлы | `activity-alias` + `setComponentEnabledSetting` |
| Цветовые темы | 12 акцентов (Asset Catalog Color Sets + legacy variants) | 9 акцентов (Material 3 `ColorScheme`, hand-tuned) |
| Локализация | String Catalogs (`.xcstrings`) | `res/values-{locale}/strings*.xml` + `createConfigurationContext` |
| Виджеты | 2 виджета (WidgetKit) | нет (план — Glance) |
| Адаптация ОС | `if #available(iOS 26.0, *)` для Liquid Glass | отсутствует — Material 3 Expressive на всех minSdk 29+ |
| Тесты | нет | нет |
| CI/CD | Xcode Archive вручную | Android Studio вручную |

Этот изоморфизм **намеренный**: один автор пишет оба клиента, единый продуктовый подход реализован за счёт переноса архитектурных решений между платформами с учётом идиоматики каждой. Это содержание для разделов **2.1.1**, **2.2.1**, **3** (вводная) ВКР.

## 17. Куда дальше

После Android — Web (`clients/web-public.md`, `clients/web-admin.md`). После всех трёх клиентов — четвёртый файл `clients/_cross-platform.md` со сравнительным анализом, который ляжет в основу:
- 2.1.1 «Состав клиентских приложений»;
- 2.2.1 «Принцип нативности и единого подхода»;
- 3 (вводная к главе) — изоморфизм архитектуры между платформами;
- 3.5.5 / заключение — общие ограничения и пункты развития.
