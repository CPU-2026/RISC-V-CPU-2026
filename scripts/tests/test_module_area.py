import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from module_area import KEYS, functional_blocks, summarize


def node(name, source, comb=0, seq=0, ram=0, children=()):
    direct = dict(zip(KEYS, (comb, seq, ram, comb + seq + ram)))
    return dict(instance=name, module=source, source_module=source, direct=direct,
                **{k: direct[k] + sum(c[k] for c in children) for k in KEYS}, children=list(children))


class ModuleAreaTests(unittest.TestCase):
    def report(self):
        ram = node('top/cache/ram', 'sram_fakeram_128x32_m8', 2, 0, 40)
        cache = node('top/cache', 'rv32_dcache', 10, 5, children=[ram])
        r1 = node('top/rs1', 'rv32_rs', 3, 4)
        r2 = node('top/rs2', 'rv32_rs', 6, 8)
        root = node('top', 'student_top', 1, 2, children=[cache, r1, r2])
        return dict(mode='diagnose', area=dict(module_tree=root, combinational_area_um2=22,
                                              sequential_area_um2=19, sram_area_um2=40, area_um2=81))

    def test_no_parent_child_double_counting(self):
        rows, hierarchy = summarize(self.report())
        self.assertEqual(sum(r['area_um2'] for r in rows), 81)
        self.assertEqual(len(hierarchy), 5)
        cache = next(r for r in rows if r['source_module'] == 'rv32_dcache')
        self.assertEqual([cache[k] for k in KEYS], [12, 5, 40, 57])
        self.assertNotIn('sram_fakeram_128x32_m8', [r['source_module'] for r in rows])

    def test_repeated_instances_sum_not_average(self):
        rows, _ = summarize(self.report())
        rs = next(r for r in rows if r['source_module'] == 'rv32_rs')
        self.assertEqual(rs['instances'], 2)
        self.assertEqual(rs['area_um2'], 21)
        self.assertAlmostEqual(sum(r['percent_of_total'] for r in rows), 100)

    def test_functional_blocks_include_children_once(self):
        rows = functional_blocks(self.report())
        self.assertEqual(sum(r['area_um2'] for r in rows), 81)
        self.assertEqual(len(rows), 4)
        cache = next(r for r in rows if r['source_module'] == 'rv32_dcache')
        self.assertTrue(cache['includes_children'])
        self.assertEqual(cache['area_um2'], 57)

    def test_flattened_report_rejected(self):
        report = self.report()
        report['mode'] = 'opt'
        with self.assertRaisesRegex(ValueError, 'requires diagnose'):
            summarize(report)

    def test_wrong_total_rejected(self):
        report = self.report()
        report['area']['area_um2'] = 99
        with self.assertRaisesRegex(ValueError, 'accounting mismatch'):
            summarize(report)
        with self.assertRaisesRegex(ValueError, 'accounting mismatch'):
            functional_blocks(report)

    def test_duplicate_path_rejected(self):
        report = self.report()
        children = report['area']['module_tree']['children']
        children.append(copy.deepcopy(children[0]))
        with self.assertRaisesRegex(ValueError, 'duplicate instance'):
            summarize(report)


if __name__ == '__main__':
    unittest.main()
