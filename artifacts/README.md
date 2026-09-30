# Где находятся сборки BOOHTACORD

Git содержит исходники и необходимые для сборки ресурсы, например иконки.
Готовые APK, ZIP, IPA, EXE и другие результаты сборки в Git не добавляются.
Скачанный при Windows сборке `libwebrtc` также остаётся только в рабочем
каталоге runner и не входит в Git.

| Результат | Где скачать | Срок |
| --- | --- | --- |
| Windows CI | [Flutter Windows CI](https://github.com/Egkurilov/BOOHTACORD/actions/workflows/flutter-windows.yaml) → успешный запуск → **Artifacts** → `BOOHTACORD-windows-x64-<commit SHA>` | 30 дней |
| macOS CI | [Flutter macOS CI](https://github.com/Egkurilov/BOOHTACORD/actions/workflows/flutter-macos.yaml) → ручной успешный запуск → **Artifacts** → `BOOHTACORD-macos-universal-<commit SHA>` | 30 дней |
| Подписанные Android и macOS релизы | [GitHub Releases](https://github.com/Egkurilov/BOOHTACORD/releases) | Пока опубликован релиз |
| Web/API | GHCR-образы с тегом точного commit SHA; production использует проверенные локальные digest | По политике реестра |

Windows artifact содержит всю папку Flutter `Release`: EXE, DLL и `data/flutter_assets`.
После скачивания распакуйте ZIP из GitHub Actions целиком и запускайте
`boohtacord_desktop.exe` из полученной папки. macOS artifact содержит ZIP
приложения и файл `.sha256`. CI artifacts служат для проверки конкретного
коммита; долговременные пользовательские сборки публикуются в Releases.

Старые APK/ZIP в локальной истории GitVerse не входят в историю GitHub `master`
или опубликованных там тегов. Исторические GitVerse release assets описаны в
[Android README](android/README.md). Переписывать GitHub history для очистки
текущего репозитория не требуется.
