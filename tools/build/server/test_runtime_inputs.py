"""Runtime bundle selection tests for release-time rollout dependencies."""
import unittest

from tools.build.server.inputs import RUNTIME_PATHS


class RuntimeInputsTests(unittest.TestCase):
    def test_runtime_bundle_includes_livekit_private_path_preflight(self):
        self.assertIn("tools/release/rollout/livekit_private_path.py", RUNTIME_PATHS)


if __name__ == "__main__":
    unittest.main()
