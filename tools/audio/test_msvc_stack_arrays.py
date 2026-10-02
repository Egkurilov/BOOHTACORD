import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RNNOISE = ROOT / 'clients/flutter/packages/flutter_webrtc/common/rnnoise'


class MsvcStackArrayCompatibilityTest(unittest.TestCase):
    def test_variable_scratch_arrays_use_the_msvc_compatibility_macro(self):
        cases = {
            'upstream/src/pitch.c': (
                ('opus_val16 x_lp4[len>>2];',
                 'RNNOISE_STACK_ARRAY(opus_val16, x_lp4, len >> 2);'),
                ('opus_val16 y_lp4[lag>>2];',
                 'RNNOISE_STACK_ARRAY(opus_val16, y_lp4, lag >> 2);'),
                ('opus_val32 xcorr[max_pitch>>1];',
                 'RNNOISE_STACK_ARRAY(opus_val32, xcorr, max_pitch >> 1);'),
                ('opus_val32 yy_lookup[maxperiod+1];',
                 'RNNOISE_STACK_ARRAY(opus_val32, yy_lookup, maxperiod + 1);'),
            ),
            'upstream/src/celt_lpc.c': (
                ('opus_val16 rnum[ord];',
                 'RNNOISE_STACK_ARRAY(opus_val16, rnum, ord);'),
                ('opus_val16 rden[ord];',
                 'RNNOISE_STACK_ARRAY(opus_val16, rden, ord);'),
                ('opus_val16 y[N+ord];',
                 'RNNOISE_STACK_ARRAY(opus_val16, y, N + ord);'),
                ('opus_val16 xx[n];',
                 'RNNOISE_STACK_ARRAY(opus_val16, xx, n);'),
            ),
        }

        for relative_path, declarations in cases.items():
            with self.subTest(source=relative_path):
                source = (RNNOISE / relative_path).read_text(encoding='utf-8')
                self.assertIn('#include "../../rnnoise_platform_compat.h"', source)
                for original, replacement in declarations:
                    self.assertNotIn(original, source)
                    self.assertIn(replacement, source)

        compatibility = RNNOISE / 'rnnoise_platform_compat.h'
        self.assertIn('RNNOISE_STACK_ARRAY', compatibility.read_text(encoding='utf-8'))

        checksums = json.loads(
            (ROOT / 'tools/audio/rnnoise_upstream_checksums.json').read_text(
                encoding='utf-8'
            )
        )
        for relative_path in ('src/pitch.c', 'src/celt_lpc.c'):
            digest = hashlib.sha256((RNNOISE / 'upstream' / relative_path).read_bytes()).hexdigest()
            self.assertEqual(digest, checksums[relative_path])


if __name__ == '__main__':
    unittest.main()
