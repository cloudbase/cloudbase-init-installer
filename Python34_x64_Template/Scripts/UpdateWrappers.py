import os
import sys

from pip._vendor.distlib import scripts

if not len(sys.argv[1:]):
    print("Usage: %(cmd)s <specs>+, e.g.: %(cmd)s \"foo = bar:main\"" %
          {"cmd": sys.argv[0]})
    sys.exit(1)

scripts_path = os.path.join(os.path.dirname(sys.executable), 'Scripts')

for specs in sys.argv[1:]:
    m = scripts.ScriptMaker(None, scripts_path)
    m.executable = sys.executable
    m.make(specs)
