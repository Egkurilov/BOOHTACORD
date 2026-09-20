# Исследовательские заметки — не продуктовые решения

Этот файл отделяет факты, требующие проверки, от утверждённых требований. Он не может переписывать исходное ТЗ без ADR.

| Неизвестное | Необходимое evidence | Затронутый gate |
| --- | --- | --- |
| Захват game audio и предотвращение playout loop на Windows/macOS | POC-01 на физических устройствах | media и release |
| Поддерживаемые сочетания Chrome/OS и фактический video profile | измерения POC-01/02 | claims о совместимости |
| Надёжный media admission после revocation | POC-03 на закреплённом LiveKit | security |
| VM throughput, traffic limit и CPU scheduling | preflight и load run | production capacity |
| Domain, DNS/TLS, registry, SSH и network access | owner deployment-input record | фактический deployment |
| Encoding parameters и достаточность resources | ADR на основе measurements | claims 1080p/60 и 100 users |

Исходное описание VM (4 vCPU, 8 GiB RAM, 30 GiB SSD) — только контекст, а не доказанное capacity promise. Само приложение не должно создавать или зависеть от backups либо provider snapshots.
