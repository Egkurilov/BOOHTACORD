"""Independent capacity uploader uses its own secure-cookie principal."""
import unittest
from unittest.mock import call, patch
from .client import Client


class ClientTests(unittest.TestCase):
    def test_registration_login_and_cookie_are_independent(self):
        replies = [(204, None, {'Set-Cookie': 'vp_session=fixture-admin; Secure'}),
                   (201, {'id': 'fixture-peer'}, {}),
                   (204, None, {'Set-Cookie': 'vp_session=fixture-peer; Secure'})]
        with patch.object(Client, 'request', side_effect=replies) as request:
            administrator = Client('synthetic-only')
            peer = administrator.create_peer('synthetic-only')
        self.assertEqual(request.call_args_list, [
            call('/auth/login', 'POST', {'login': 'qa_admin', 'password': 'synthetic-only'}),
            call('/auth/register', 'POST', {'login': 'qa_upload_peer', 'password': 'synthetic-only'}),
            call('/auth/login', 'POST', {'login': 'qa_upload_peer', 'password': 'synthetic-only'})])
        self.assertNotEqual(administrator.cookie, peer.cookie)

    def test_failed_registration_cannot_fall_back_to_admin_cookie(self):
        replies = [(204, None, {'Set-Cookie': 'vp_session=fixture-admin; Secure'}), (403, None, {})]
        with patch.object(Client, 'request', side_effect=replies) as request:
            administrator = Client('synthetic-only')
            with self.assertRaisesRegex(AssertionError, '403'):
                administrator.create_peer('synthetic-only')
        self.assertEqual(request.call_count, 2)
