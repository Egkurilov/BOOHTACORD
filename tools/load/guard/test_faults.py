import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from .faults import Faults


class IsolatedFaultTests(unittest.TestCase):
    def test_disk_pressure_is_bounded_and_restored(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            try:
                faults.apply('disk_pressure')
                self.assertEqual(faults.pressure.stat().st_size, 32 << 20)
                with self.assertRaises(ValueError):
                    faults.apply('erase-production')
            finally:
                faults.restore()
            self.assertFalse(faults.pressure.exists())

    def test_pause_and_restore_verify_owner_before_each_action(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            with patch('tools.load.guard.faults.owned', return_value='owned-sfu') as owner, \
                    patch('tools.load.guard.faults.subprocess.run') as run:
                faults.apply('sfu_outage')
                faults.restore()
                self.assertEqual(owner.call_count, 2)
                self.assertEqual(run.call_args_list[0].args[0], ['docker', 'pause', 'owned-sfu'])
                self.assertEqual(run.call_args_list[1].args[0], ['docker', 'unpause', 'owned-sfu'])


if __name__ == '__main__':
    unittest.main()
