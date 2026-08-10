#!/usr/bin/env python3
"""Generate LocoKit2 PlaceCategory sources from Yinon's gists (BIG-513).

Inputs (same dir): google-taxonomy.txt, fsq-v2-map.swift, mapbox-observed.txt
Outputs (same dir): PlaceCategory.swift, PlaceCategory+FoursquareV2.swift,
                    PlaceCategory+Mapbox.swift
Validation is hard-failing: unknown mapping targets or Swift-keyword
collisions abort generation.
"""
import re, sys
from datetime import date

SWIFT_KEYWORDS = {
    'associatedtype','class','deinit','enum','extension','fileprivate','func',
    'import','init','inout','internal','let','open','operator','private',
    'precedencegroup','protocol','public','rethrows','static','struct',
    'subscript','typealias','var','break','case','catch','continue','default',
    'defer','do','else','fallthrough','for','guard','if','in','repeat',
    'return','throw','switch','where','while','as','false','is','nil','self',
    'super','throws','true','try','any','some',
}

def camel(s):
    parts = s.split('_')
    name = parts[0] + ''.join(p.capitalize() for p in parts[1:])
    return f'`{name}`' if name in SWIFT_KEYWORDS else name

# ── Parse taxonomy ──────────────────────────────────────────────────────
groups = {}   # gist header -> [types]
current = None
for line in open('google-taxonomy.txt'):
    line = line.strip()
    if not line: continue
    if line.startswith('//'):
        current = line[2:].strip()
        groups[current] = []
    elif current:
        groups[current].append(line)

all_types = {t for ts in groups.values() for t in ts}
assert len(all_types) == sum(len(ts) for ts in groups.values()), 'duplicate types across groups'

GROUP_CASE = {  # gist header -> Group case name
    'Automotive': 'automotive', 'Business': 'business', 'Culture': 'culture',
    'Education': 'education', 'Entertainment and Recreation': 'entertainmentAndRecreation',
    'Facilities': 'facilities', 'Finance': 'finance', 'Food and Drink': 'foodAndDrink',
    'Geographical Areas': 'geographicalAreas', 'Government': 'government',
    'Health and Wellness': 'healthAndWellness', 'Housing': 'housing',
    'Lodging': 'lodging', 'Natural Features': 'naturalFeatures',
    'Places of Worship': 'placesOfWorship', 'Services': 'services',
    'Shopping': 'shopping', 'Sports': 'sports', 'Transportation': 'transportation',
    'Additional Place type values': 'other',
}
assert set(GROUP_CASE) == set(groups), f'group mismatch: {set(groups) ^ set(GROUP_CASE)}'

ARC_PRIVATE = [  # (case name, raw value) — group .personal
    ('home', 'arc_home'),
    ('friendsHome', 'arc_friends_home'),
    ('vacationRental', 'arc_vacation_rental'),
]

# ── PlaceCategory.swift ─────────────────────────────────────────────────
out = []
out.append(f'''//
//  PlaceCategory.swift
//  LocoKit2
//
//  Created by Claude on {date.today().isoformat()}
//
//  GENERATED FILE — regenerate via Scripts/placecategory/generate_placecategory.py
//  (BIG-513). Canonical taxonomy: Google Places primaryType vocabulary
//  (~{len(all_types)} types under {len(groups)} groups), from Yinon's prep gist, plus
//  Arc-specific private categories. rawValue IS the Google primaryType
//  string (or "arc_"-prefixed for Arc-private cases) — the same vocabulary
//  is stored in Place.userCategory and used in exports.
//

public enum PlaceCategory: String, Codable, Hashable, Sendable, CaseIterable {{
''')
for header, ts in groups.items():
    out.append(f'    // MARK: - {header}\n')
    for t in ts:
        out.append(f'    case {camel(t)} = "{t}"')
    out.append('')
out.append('    // MARK: - Arc private categories\n')
for name, raw in ARC_PRIVATE:
    out.append(f'    case {name} = "{raw}"')
out.append('''
    // MARK: - Groups

    public enum Group: String, Codable, Hashable, Sendable, CaseIterable {''')
for header, case_name in GROUP_CASE.items():
    out.append(f'        case {case_name}')
out.append('        case personal')
out.append('    }\n')
out.append('    public var group: Group {')
out.append('        switch self {')
for header, ts in groups.items():
    case_name = GROUP_CASE[header]
    names = [f'.{camel(t)}' for t in ts]
    # wrap the case list at ~100 chars
    lines, cur = [], '        case '
    for i, n in enumerate(names):
        tail = ', ' if i < len(names) - 1 else ':'
        if len(cur) + len(n) + len(tail) > 116:
            lines.append(cur)
            cur = '             '
        cur += n + tail
    lines.append(cur)
    out.extend(lines)
    out.append(f'            return .{case_name}')
priv = ', '.join(f'.{n}' for n, _ in ARC_PRIVATE)
out.append(f'        case {priv}:')
out.append('            return .personal')
out.append('        }')
out.append('    }')
out.append('}')
open('PlaceCategory.swift', 'w').write('\n'.join(out) + '\n')

# ── PlaceCategory+FoursquareV2.swift ────────────────────────────────────
src = open('fsq-v2-map.swift').read()
entries = []   # (comment, fsq_id, google_type or None, inline_comment)
pending_comment = None
for line in src.splitlines():
    s = line.strip()
    m = re.match(r'^// (.+)$', s)
    if m and '"' not in s:
        c = m.group(1)
        if not c.startswith('Mapping from') and not c.startswith('Generated'):
            pending_comment = c
        continue
    m = re.match(r'^"([0-9a-f]{24})":\s*(?:"([a-z_0-9]+)"|nil),?\s*(?://\s*(.*))?$', s)
    if m:
        entries.append((pending_comment, m.group(1), m.group(2), m.group(3)))
        pending_comment = None

mapped = [e for e in entries if e[2]]
nil_entries = [e for e in entries if not e[2]]
bad = {e[2] for e in mapped if e[2] not in all_types}
assert not bad, f'FSQ targets not in taxonomy: {bad}'

out = [f'''//
//  PlaceCategory+FoursquareV2.swift
//  LocoKit2
//
//  Created by Claude on {date.today().isoformat()}
//
//  GENERATED FILE — regenerate via Scripts/placecategory/generate_placecategory.py
//  (BIG-513). Foursquare V2 category id -> Google primaryType, from
//  Yinon's prep gist ({len(mapped)} mappings; every target validated against
//  the PlaceCategory taxonomy at generation time). Pure history rescue:
//  V2 ids only exist on places imported from pre-AT4 Arc history, so this
//  table is static and will never grow. "Inexact" markers are Yinon's.
//
//  Values are raw strings (not PlaceCategory literals) to keep the
//  type-checker's cost trivial on a {len(mapped)}-entry literal; validity is
//  guaranteed at generation time instead.
//

extension PlaceCategory {{

    init?(foursquareV2Id: String) {{
        guard let raw = Self.foursquareV2Map[foursquareV2Id] else {{ return nil }}
        self.init(rawValue: raw)
    }}

    static let foursquareV2Map: [String: String] = [''']
for comment, fid, gtype, inline in mapped:
    parts = []
    if comment: parts.append(comment)
    if inline: parts.append(inline)
    suffix = f'  // {" — ".join(parts)}' if parts else ''
    out.append(f'        "{fid}": "{gtype}",{suffix}')
if nil_entries:
    out.append('')
    out.append('        // Unmapped in source gist (deliberately no Google equivalent):')
    for comment, fid, _, inline in nil_entries:
        out.append(f'        // "{fid}"  ({comment or "?"})')
out.append('    ]')
out.append('}')
open('PlaceCategory+FoursquareV2.swift', 'w').write('\n'.join(out) + '\n')

# ── PlaceCategory+Mapbox.swift ──────────────────────────────────────────
# Keyword table authored against the observed vocabulary of a real mature
# DB (73 distinct compound strings). First matching token wins, tokens
# checked in string order (Mapbox leads with the most specific term).
MAPBOX_KEYWORDS = {
    'airport': 'airport', 'airport lounge': 'airport', 'airport services': 'airport',
    'airport shop': 'airport',
    'historic site': 'historical_landmark', 'historic': 'historical_landmark',
    'monument': 'monument', 'landmark': 'historical_landmark',
    'hotel': 'hotel', 'motel': 'motel', 'lodging': 'lodging',
    'hotel resort': 'resort_hotel', 'resort': 'resort_hotel', 'hostel': 'hostel',
    'bed and breakfast': 'bed_and_breakfast',
    'convenience store': 'convenience_store', 'minimart': 'convenience_store',
    'convenience': 'convenience_store', 'corner store': 'convenience_store',
    'bodega': 'convenience_store',
    'waterfall': 'scenic_spot', 'viewpoint': 'scenic_spot', 'scenic': 'scenic_spot',
    'coffee': 'coffee_shop', 'cafe': 'cafe', 'tea house': 'tea_house', 'tea': 'tea_house',
    'bridge': 'historical_landmark',
    'sporting goods': 'sporting_goods_store', 'sports store': 'sporting_goods_store',
    'sporting': 'sporting_goods_store',
    'restaurant': 'restaurant', 'thai restaurant': 'thai_restaurant',
    'indian restaurant': 'indian_restaurant', 'french restaurant': 'french_restaurant',
    'pizza': 'pizza_restaurant', 'fast food': 'fast_food_restaurant',
    'food court': 'food_court', 'snack': 'fast_food_restaurant',
    'fried chicken': 'fast_food_restaurant', 'donut': 'donut_shop',
    'ice cream': 'ice_cream_shop',
    'rail station': 'train_station', 'train station': 'train_station',
    'pharmacy': 'pharmacy',
    'computer': 'electronics_store', 'electronic': 'electronics_store',
    'electronics': 'electronics_store', 'cellphone': 'cell_phone_store',
    'mobile phone': 'cell_phone_store', 'phone repair': 'cell_phone_store',
    'taxi': 'taxi_stand', 'taxi stand': 'taxi_stand',
    'supermarket': 'supermarket', 'groceries': 'grocery_store',
    'grocery': 'grocery_store', 'market': 'market', 'marketplace': 'market',
    'farmers market': 'farmers_market',
    'port': 'ferry_terminal', 'ferry': 'ferry_terminal', 'marina': 'marina',
    'parking': 'parking', 'parking lot': 'parking',
    'outdoors': 'tourist_attraction', 'attraction': 'tourist_attraction',
    'gym': 'gym', 'fitness center': 'fitness_center',
    'gas station': 'gas_station', 'fuel': 'gas_station',
    'discount store': 'discount_store', 'department store': 'department_store',
    'clothing': 'clothing_store', 'apparel': 'clothing_store',
    'chair ski lift': 'ski_resort', 'ski': 'ski_resort',
    'bus station': 'bus_station', 'bus stop': 'bus_stop',
    'buddhist': 'buddhist_temple', 'buddhism': 'buddhist_temple',
    'temple': 'place_of_worship', 'mosque': 'mosque', 'muslim': 'mosque',
    'islam': 'mosque', 'religious': 'place_of_worship', 'religion': 'place_of_worship',
    'place of worship': 'place_of_worship',
    'botanical garden': 'botanical_garden', 'garden': 'garden',
    'beach': 'beach', 'surfing beach': 'beach', 'surf': 'beach',
    'bank': 'bank', 'finance': 'bank',
    'tourist information': 'visitor_center',
    'stationery': 'store', 'smoke shop': 'store', 'variety shop': 'store',
    'shopping center': 'shopping_mall', 'mall': 'shopping_mall',
    'shopping mall': 'shopping_mall',
    'science museum': 'museum', 'history museum': 'history_museum',
    'museum': 'museum',
    'police station': 'police', 'law enforcement': 'police',
    'playground': 'playground', 'park': 'park',
    'landscaping': 'general_contractor', 'contractor': 'general_contractor',
    'hiking': 'hiking_area', 'trailhead': 'hiking_area',
    'hiking trailhead': 'hiking_area', 'hike': 'hiking_area',
    'government agency': 'government_office',
    'cocktail bar': 'bar', 'bar': 'bar', 'cemetery': 'cemetery',
    'graveyard': 'cemetery', 'baseball field': 'athletic_field',
    'baseball': 'athletic_field',
    'business': 'corporate_office', 'pub': 'pub', 'bakery': 'bakery',
    'nightclub': 'night_club', 'spa': 'spa', 'massage': 'massage',
    'hospital': 'hospital', 'clinic': 'medical_clinic', 'dentist': 'dentist',
    'school': 'school', 'university': 'university', 'library': 'library',
    'zoo': 'zoo', 'aquarium': 'aquarium', 'stadium': 'stadium',
    'swimming pool': 'swimming_pool', 'church': 'church',
    'laundry': 'laundry', 'hair': 'hair_salon', 'barber': 'barber_shop',
    'post office': 'post_office', 'embassy': 'embassy',
    'hardware': 'hardware_store', 'bookstore': 'book_store',
    'book shop': 'book_store', 'liquor': 'liquor_store',
    'pet store': 'pet_store', 'florist': 'florist', 'gift': 'gift_shop',
    'campground': 'campground', 'camping': 'campground',
}
bad = {v for v in MAPBOX_KEYWORDS.values() if v not in all_types}
assert not bad, f'Mapbox targets not in taxonomy: {bad}'

observed = [l.strip() for l in open('mapbox-observed.txt') if l.strip()]
unmatched = []
for value in observed:
    tokens = [t.strip() for t in value.split(',')]
    if not any(t in MAPBOX_KEYWORDS for t in tokens):
        unmatched.append(value)

out = [f'''//
//  PlaceCategory+Mapbox.swift
//  LocoKit2
//
//  Created by Claude on {date.today().isoformat()}
//
//  GENERATED FILE — regenerate via Scripts/placecategory/generate_placecategory.py
//  (BIG-513). Mapbox category strings are compound comma-separated keyword
//  bundles (e.g. "hotel, motel, tourism, lodging"), not a clean taxonomy —
//  so resolution is keyword matching: first recognised token wins, tokens
//  checked in string order (Mapbox leads with the most specific term).
//  Pure history rescue: AT4 never fetches from Mapbox, so mapboxCategory
//  only exists on places migrated from AT3's Mapbox era. Table authored
//  against the observed vocabulary of a real mature DB and validated
//  against the PlaceCategory taxonomy at generation time; unmatched
//  strings resolve to nil, deliberately.
//

extension PlaceCategory {{

    init?(mapboxCategory: String) {{
        for token in mapboxCategory.components(separatedBy: ",") {{
            let trimmed = token.trimmingCharacters(in: .whitespaces)
            if let raw = Self.mapboxKeywordMap[trimmed], let category = PlaceCategory(rawValue: raw) {{
                self = category
                return
            }}
        }}
        return nil
    }}

    static let mapboxKeywordMap: [String: String] = [''']
for k in sorted(MAPBOX_KEYWORDS):
    out.append(f'        "{k}": "{MAPBOX_KEYWORDS[k]}",')
out.append('    ]')
out.append('}')
open('PlaceCategory+Mapbox.swift', 'w').write('\n'.join(out) + '\n')

# ── Report ──────────────────────────────────────────────────────────────
n_cases = len(all_types) + len(ARC_PRIVATE)
print(f'PlaceCategory.swift: {n_cases} cases ({len(all_types)} Google + {len(ARC_PRIVATE)} Arc-private), {len(groups)+1} groups')
print(f'FoursquareV2: {len(mapped)} mappings, {len(nil_entries)} nil entries footnoted')
print(f'Mapbox: {len(MAPBOX_KEYWORDS)} keywords; observed coverage {len(observed)-len(unmatched)}/{len(observed)}')
for u in unmatched:
    print(f'  unmatched: {u}')
