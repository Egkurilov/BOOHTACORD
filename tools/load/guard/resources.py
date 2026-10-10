"""Observe the owned API container through its private Prometheus metrics."""
import os
import time
from .metrics import snapshot
from .ownership import owned


class Resources:
    def __init__(self, stack):
        self.stack, self.previous = stack, None

    def read(self):
        container = owned(self.stack, 'api')
        if self.stack.api != container:
            raise ValueError('Owned API container is not active')
        values = snapshot()
        now = time.monotonic()
        try:
            cpu_seconds = values['process_cpu_seconds_total']
            rss = int(values['process_resident_memory_bytes'])
            free = int(values['voice_platform_attachment_filesystem_available_bytes'])
        except (KeyError, TypeError, ValueError):
            raise ValueError('Owned API resource metrics are incomplete') from None
        cpu = 0 if self.previous is None else (
            100*(cpu_seconds-self.previous[1])/(now-self.previous[0])/(os.cpu_count() or 1))
        if rss < 0 or free < 0 or (self.previous is not None and cpu_seconds < self.previous[1]):
            raise ValueError('Owned API resource metrics are invalid')
        self.previous = now, cpu_seconds
        return dict(CPUPercent=cpu, RSSBytes=rss, FreeBytes=free)
