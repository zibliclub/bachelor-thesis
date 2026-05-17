# iOS-приложение

## Известное на сейчас

- **UI-фреймворк:** SwiftUI.
- **Поддержка:** iOS 18− (без Liquid Glass) и iOS 26+ (с Liquid Glass во всех уместных компонентах).
- **Принцип:** максимальная нативность, родные системные компоненты.
- **Статус:** опубликовано в App Store, ~3000 установок в экосистеме (включая Android и Web), доля iOS среди пользователей — 79%.
- **CI/CD:** Xcode Archive → App Store Connect вручную (раньше использовался Xcode Cloud, но он был ограничен на территории России).

## Известные фичи

- Кэширование расписания и сущностей.
- Заметки к парам.
- Избранные группы / преподаватели / аудитории.
- Персонализация: тема, 13 акцентных цветов, 8 иконок приложения, язык RU/EN.
- Актуальная пара на главном экране.
- Виджеты на рабочем столе:
  - количество пар на сегодня;
  - список заметок (несколько размеров).

## TODO: при ревью репозитория уточнить

- [ ] Архитектурный паттерн: MVVM / TCA (The Composable Architecture) / SwiftUI + Observation framework / иное.
- [ ] DI / Composition Root.
- [ ] Локальное хранилище: SwiftData / Core Data / GRDB / Realm / просто JSON-файлы.
- [ ] Сетевой слой: URLSession в чистом виде, async/await, Combine, Alamofire — что именно.
- [ ] Использование Swift Concurrency (actors, structured concurrency, MainActor).
- [ ] Структура модулей (Swift Packages, единый таргет, многотаргетный проект).
- [ ] Конфигурация: схемы Debug/Release, xcconfig, environment variables.
- [ ] Локализация: использование String Catalogs vs Localizable.strings.
- [ ] Темы / акцентные цвета: реализация (Asset Catalog Color Sets, программно).
- [ ] Виджеты: количество и точные размеры (systemSmall/Medium/Large/extraLarge, accessory*), используется ли WidgetKit Intents.
- [ ] Используются ли Live Activities, App Intents, ShortcutsKit.
- [ ] Push-уведомления: подключены ли APNs, маршрутизация.
- [ ] Deep Links / Universal Links.
- [ ] Аналитика на клиенте: что именно отслеживается, чем (Firebase, AppMetrica, своё).
- [ ] Сборка и подпись: автоматический provisioning, ручной, fastlane match.
- [ ] Объём кодовой базы: количество файлов, ориентировочно строк кода.
- [ ] Минимальная цель iOS deployment target.
- [ ] Какие зависимости подключены (через SPM).

После ревью репозитория этот файл будет переработан в полноценный раздел для главы 3 ВКР.
