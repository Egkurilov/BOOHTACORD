import runpy
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
globals().update(runpy.run_path(str(Path(__file__).resolve().parents[2] / 'tools/qa/otlp_smoke/smoke_otlp.py'), run_name='__main__' if __name__ == '__main__' else '<run_path>'))
