"""Fresh-source fixture with no inherited production telemetry credentials."""
import os
from tools.qa.critical_client_acceptance.stack import Stack as ExistingStack


class Stack(ExistingStack):
    def __init__(self, root, work):
        if os.environ.get('QA_BIN_DIR'):
            raise ValueError('External fixture binaries cannot attest this checkout')
        super().__init__(root, work)
        self.environment = {name: value for name, value in self.environment.items()
                            if not name.startswith('OTEL_')}
