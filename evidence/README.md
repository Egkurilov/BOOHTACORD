# Записи evidence

В каталоге уже есть записи runtime/static checks, deployment, Android build и незакрытых POC/capacity/visual gates. Читайте дату, scope, sub-checks и limitations каждой записи: PASS_RUNTIME/PASS_STATIC или успешный APK build не означают полный release PASS.

Для нового прогона используйте `templates/evidence.json` либо соответствующую форму существующей записи. Заполняйте только наблюдаемые результаты; BLOCKED/NOT_RUN не закрывают gate. Не изменяйте прежние evidence для нового состояния кода.

Не сохраняйте пароли, cookies/tokens, DM/message bodies, вложения или media payload. Ссылки на чувствительные артефакты храните вне Git. Скриншоты для QA должны использовать безопасные тестовые данные. Обязательная запись содержит дату, окружение, revision, сценарий, наблюдателя/исполнителя, результаты, артефакты и ограничения.

Актуальный остаток — [verification TODO](../backlog/VERIFICATION_TODO.md); локальные tests/build от 24.09 описаны в [ревью](../docs/reviews/2026-09-24-functionality.md). Этот отчёт не заменяет аппаратную или release evidence.
