import unittest

from tools.load.screen_share_matrix.planner import load_catalog, plan_profile


class ScreenShareMatrixTest(unittest.TestCase):
    def test_catalog_contains_ten_valid_profiles_and_no_impossible_topology(self):
        catalog = load_catalog()
        self.assertEqual([f['id'] for f in catalog['profiles']], [f'L{i:02}' for i in range(1, 11)])
        room_shapes = {(r['participants'], r['publishers']) for p in catalog['profiles'] for r in p['rooms']}
        self.assertNotIn((10, 20), room_shapes)
        for profile in catalog['profiles']:
            plan = plan_profile(catalog, profile['id'])
            self.assertEqual(plan['participants'], profile['participants'])
            self.assertLessEqual(plan['max_subscriptions_per_viewer'], profile['subscriptions_per_viewer'])
            for viewer, source in plan['subscriptions']:
                self.assertNotEqual(viewer, source)

    def test_multroom_profiles_isolate_ids_and_keep_room_caps(self):
        plan = plan_profile(load_catalog(), 'L06')
        self.assertEqual([len(room['members']) for room in plan['rooms']], [15, 15])
        self.assertEqual(len({person for room in plan['rooms'] for person in room['members']}), 30)
        self.assertTrue(all(source.split('-')[0] == viewer.split('-')[0]
                            for viewer, source in plan['subscriptions']))

    def test_plan_never_claims_runtime_acceptance(self):
        plan = plan_profile(load_catalog(), 'L10')
        self.assertEqual(plan['evidence']['generator'], 'NOT_RUN')
        self.assertEqual(plan['evidence']['sfu'], 'NOT_RUN')
        self.assertEqual(plan['evidence']['physical_decode'], 'NOT_RUN')
        self.assertEqual(plan['outcome'], 'NOT_RUN')

    def test_timing_repeats_soak_and_network_axes_are_explicit(self):
        catalog = load_catalog()
        self.assertEqual(catalog['phases_seconds']['steady'], 600)
        self.assertEqual(catalog['phases_seconds']['soak'], 7200)
        for profile_id in ('L01', 'L04', 'L05', 'L09'):
            self.assertEqual(plan_profile(catalog, profile_id)['repeats'], 3)
        targets = [axis['target'] for axis in next(p for p in catalog['profiles'] if p['id'] == 'L09')['impairments']]
        self.assertEqual(targets, ['sender-uplink', 'one-receiver-downlink'])
        self.assertEqual(len(set(targets)), len(targets))

    def test_required_participant_publisher_matrix_is_exact(self):
        catalog = load_catalog()
        expected = {'L01': (10, [4]), 'L02': (10, [10]), 'L03': (20, [4]),
                    'L04': (20, [10]), 'L05': (20, [20]), 'L06': (30, [5, 5]),
                    'L07': (30, [10, 10]), 'L08': (20, [10]), 'L09': (20, [10]), 'L10': (20, [10])}
        for profile in catalog['profiles']:
            shape = (profile['participants'], [r['publishers'] for r in profile['rooms']])
            self.assertEqual(shape, expected[profile['id']])

    def test_planner_rejects_room_size_outside_envelope(self):
        catalog = load_catalog()
        profile = dict(catalog['profiles'][0], participants=21,
                       rooms=[{'participants': 21, 'publishers': 4}])
        catalog['profiles'] = [profile]
        with self.assertRaisesRegex(ValueError, 'envelope'):
            plan_profile(catalog, 'L01')


if __name__ == '__main__':
    unittest.main()
