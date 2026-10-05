"""Capacity-bounded local attachment volume plus an owned real LiveKit instance."""
from tools.qa.upload_reservations.stack import UploadStack
from tools.qa.critical_client_acceptance.stack import Stack as MediaStack


class Stack(UploadStack, MediaStack):
    def restart(self):
        self.environment['LIVEKIT_PUBLIC_WS_URL'] = 'wss://localhost:4810/qa-sfu'
        super().restart()
