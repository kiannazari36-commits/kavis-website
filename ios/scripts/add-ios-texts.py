#!/usr/bin/env python3
"""Adds iOS-only texts to Resources/Data/i18n-ios.json: python3 add-ios-texts.py new.json  ({key:{tr,en,fa,ar}})."""
import json, sys, os
p = os.path.join(os.path.dirname(__file__), '..', 'KavisStudy', 'Resources', 'Data', 'i18n-ios.json')
d = json.load(open(p))
for k, v in json.load(open(sys.argv[1])).items():
    for l in ('tr', 'en', 'fa', 'ar'): d[l][k] = v[l]
json.dump(d, open(p, 'w'), ensure_ascii=False, indent=1); open(p, 'a').write('\n')
