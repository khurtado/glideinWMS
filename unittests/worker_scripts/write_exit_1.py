#!/usr/bin/env python

import sys

# Attempt to fill the write buffer and exit abnormally
num_range = range(0, 10000)
for x in num_range:
    print sys.stdout.write(str(x))
    print sys.stdout.write("This is line %s" % str(x))

sys.exit(1)
