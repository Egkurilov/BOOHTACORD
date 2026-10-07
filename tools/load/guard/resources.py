"""Observe the owned API process and disposable attachment volume on Linux."""
import os
import shutil
import time
from pathlib import Path


class Resources:
    def __init__(self, stack):
        self.stack, self.previous = stack, None

    def read(self):
        process = self.stack.api
        if process is None or process.poll() is not None:
            raise ValueError('Owned API process is not alive')
        directory = Path('/proc')/str(process.pid)
        executable = (directory/'exe').resolve(strict=True)
        if executable != self.stack.binary.resolve():
            raise ValueError('Foreign API process identity')
        fields = (directory/'stat').read_text().rsplit(')', 1)[1].split()
        ticks = int(fields[11])+int(fields[12])
        now = time.monotonic()
        cpu = 0 if self.previous is None else 100*(ticks-self.previous[1])/os.sysconf('SC_CLK_TCK')/(now-self.previous[0])/os.cpu_count()
        self.previous = now, ticks
        rss = int(fields[21])*os.sysconf('SC_PAGE_SIZE')
        path = (self.stack.work/'attachments').resolve()
        if not path.is_relative_to(self.stack.work.resolve()):
            raise ValueError('Foreign attachment volume')
        path.mkdir(exist_ok=True)
        return dict(CPUPercent=cpu, RSSBytes=rss, FreeBytes=shutil.disk_usage(path).free)
