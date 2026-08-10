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
# DB (179 distinct compound strings, see mapbox-observed.txt). Resolution
# walks the *input string's* comma-separated tokens left to right and takes
# the first one present here — Mapbox leads with its most specific term, so
# "dim sum, dim sum restaurant, chinese restaurant" lands on dim sum. Order
# within this dict is therefore purely cosmetic (lookup is by key, and the
# emitted Swift is sorted); sections exist for human navigation only, so
# put a new keyword wherever it reads best and never reorder to "fix" a
# resolution. Sections are grouped by Google taxonomy area.
MAPBOX_KEYWORDS = {
    # ── food and drink: restaurants ──
    'restaurant': 'restaurant', 'diner': 'diner', 'gastropub': 'gastropub',
    'fast food': 'fast_food_restaurant', 'food court': 'food_court',
    'breakfast spot': 'breakfast_restaurant', 'snack': 'snack_bar',
    'burger joint': 'hamburger_restaurant', 'pizza': 'pizza_restaurant',

    # ── food and drink: cuisines ──
    # Mapbox spells these "<cuisine> restaurant, <cuisine> food, restaurant",
    # so both forms are keyed; the generic 'restaurant' tail only wins when
    # Google has no matching cuisine type (e.g. "gluten free").
    'african restaurant': 'african_restaurant', 'african food': 'african_restaurant',
    'american restaurant': 'american_restaurant', 'american food': 'american_restaurant',
    'new american restaurant': 'american_restaurant',
    'new american food': 'american_restaurant',
    'asian restaurant': 'asian_restaurant', 'asian food': 'asian_restaurant',
    'cajun restaurant': 'cajun_restaurant', 'cajun food': 'cajun_restaurant',
    'caribbean restaurant': 'caribbean_restaurant',
    'caribbean food': 'caribbean_restaurant',
    'chinese restaurant': 'chinese_restaurant', 'chinese food': 'chinese_restaurant',
    'szechuan restaurant': 'chinese_restaurant',  # no szechuan type in Google
    'szechuan food': 'chinese_restaurant',
    'cuban restaurant': 'cuban_restaurant', 'cuban food': 'cuban_restaurant',
    'eastern european restaurant': 'eastern_european_restaurant',
    'eastern european': 'eastern_european_restaurant',
    'ethiopian restaurant': 'ethiopian_restaurant',
    'ethiopian food': 'ethiopian_restaurant',
    'french restaurant': 'french_restaurant', 'french food': 'french_restaurant',
    'greek restaurant': 'greek_restaurant', 'greek food': 'greek_restaurant',
    'indian restaurant': 'indian_restaurant', 'indian food': 'indian_restaurant',
    'israeli restaurant': 'israeli_restaurant', 'israeli food': 'israeli_restaurant',
    'italian restaurant': 'italian_restaurant', 'italian food': 'italian_restaurant',
    'japanese restaurant': 'japanese_restaurant',
    'japanese food': 'japanese_restaurant',
    'mediterranean restaurant': 'mediterranean_restaurant',
    'mediterranean food': 'mediterranean_restaurant',
    'mexican restaurant': 'mexican_restaurant', 'mexican food': 'mexican_restaurant',
    'middle eastern restaurant': 'middle_eastern_restaurant',
    'middle eastern food': 'middle_eastern_restaurant',
    'thai restaurant': 'thai_restaurant', 'thai food': 'thai_restaurant',
    'turkish restaurant': 'turkish_restaurant', 'turkish food': 'turkish_restaurant',
    'vietnamese restaurant': 'vietnamese_restaurant',
    'vietnamese food': 'vietnamese_restaurant',

    # ── food and drink: dishes and formats ──
    'dim sum': 'dim_sum_restaurant', 'dim sum restaurant': 'dim_sum_restaurant',
    'dumpling': 'dumpling_restaurant',
    'dumpling restaurant': 'dumpling_restaurant',
    'falafel': 'falafel_restaurant', 'falafel restaurant': 'falafel_restaurant',
    'ramen': 'ramen_restaurant', 'noodles': 'noodle_shop', 'soba': 'noodle_shop',
    'sushi': 'sushi_restaurant', 'sushi restaurant': 'sushi_restaurant',
    'taco': 'taco_restaurant', 'seafood': 'seafood_restaurant',
    'seafood restaurant': 'seafood_restaurant',
    'southern soul food': 'soul_food_restaurant',
    'southern soul food restaurant': 'soul_food_restaurant',
    'vegetarian': 'vegetarian_restaurant',
    'vegetarian restaurant': 'vegetarian_restaurant',
    'vegetarian food': 'vegetarian_restaurant',
    'vegan': 'vegan_restaurant', 'vegan restaurant': 'vegan_restaurant',
    'vegan food': 'vegan_restaurant',
    'fried chicken': 'chicken_restaurant', 'chicken': 'chicken_restaurant',
    'juice bar': 'juice_shop', 'salad': 'salad_shop', 'sandwich': 'sandwich_shop',
    'deli': 'deli',

    # ── food and drink: cafes, bakeries, sweets ──
    'cafe': 'cafe', 'coffee': 'coffee_shop', 'tea house': 'tea_house',
    'tea': 'tea_house', 'bubble tea': 'tea_house', 'bakery': 'bakery',
    'bagel': 'bagel_shop', 'donut': 'donut_shop', 'ice cream': 'ice_cream_shop',
    'confectionery': 'confectionery', 'confection': 'confectionery',
    'candy store': 'candy_store', 'candy': 'candy_store',
    'candies': 'candy_store', 'sweets': 'candy_store',
    'chocolatier': 'chocolate_shop', 'chocolate': 'chocolate_shop',

    # ── food and drink: bars ──
    'bar': 'bar', 'cocktail bar': 'cocktail_bar', 'sports bar': 'sports_bar',
    'wine bar': 'wine_bar',  # keyed so the 'wine' retail token can't claim it
    'beach bar': 'bar', 'pub': 'pub', 'brewery': 'brewery',
    'lounge': 'lounge_bar', 'nightclub': 'night_club',

    # ── shopping: food retail ──
    'supermarket': 'supermarket', 'grocery': 'grocery_store',
    'groceries': 'grocery_store', 'fruit vegetable shop': 'grocery_store',
    'organic grocery': 'health_food_store', 'gourmet': 'food_store',
    'food and drink': 'food_store', 'market': 'market', 'marketplace': 'market',
    'fish market': 'market', 'farmers market': 'farmers_market',
    'convenience store': 'convenience_store', 'convenience': 'convenience_store',
    'minimart': 'convenience_store', 'corner store': 'convenience_store',
    'bodega': 'convenience_store',
    'liquor': 'liquor_store', 'beer': 'liquor_store', 'wine': 'liquor_store',
    'spirit': 'liquor_store', 'booze': 'liquor_store',

    # ── shopping: general retail ──
    'mall': 'shopping_mall', 'shopping mall': 'shopping_mall',
    'shopping center': 'shopping_mall', 'department store': 'department_store',
    'discount store': 'discount_store', 'outlet store': 'discount_store',
    'outlet shop': 'discount_store', 'bargain': 'discount_store',
    'clothing': 'clothing_store', 'apparel': 'clothing_store',
    'vintage': 'thrift_store', 'thrift': 'thrift_store',
    'second-hand': 'thrift_store', 'second hand': 'thrift_store',
    'furniture': 'furniture_store', 'home store': 'home_goods_store',
    'decor': 'home_goods_store', 'hardware': 'hardware_store',
    'computer': 'electronics_store', 'electronic': 'electronics_store',
    'electronics': 'electronics_store', 'cellphone': 'cell_phone_store',
    'mobile phone': 'cell_phone_store', 'phone repair': 'cell_phone_store',
    'bookstore': 'book_store', 'book shop': 'book_store',
    'sporting goods': 'sporting_goods_store', 'sports store': 'sporting_goods_store',
    'sporting': 'sporting_goods_store', 'bicycle rental': 'bicycle_store',
    'pet store': 'pet_store', 'florist': 'florist', 'gift': 'gift_shop',
    'antique': 'store', 'collectibles': 'store', 'stationery': 'store',
    'smoke shop': 'store', 'variety shop': 'store',
    'photography lab': 'store', 'photo lab': 'store', 'photo': 'store',
    'framing': 'store', 'frame': 'store',

    # ── automotive ──
    'auto repair': 'car_repair', 'car repair': 'car_repair',
    'body shop': 'car_repair', 'car wash': 'car_wash',
    'car rental': 'car_rental', 'truck rental': 'car_rental',
    'automotive dealer': 'car_dealer', 'automotive dealership': 'car_dealer',
    'automotive sales': 'car_dealer', 'automotive leasing': 'car_dealer',
    'auto dealer': 'car_dealer', 'auto dealership': 'car_dealer',
    'auto sales': 'car_dealer', 'car dealer': 'car_dealer',
    'car dealership': 'car_dealer', 'car sales': 'car_dealer',
    'dealership': 'car_dealer',
    'gas station': 'gas_station', 'fuel': 'gas_station',
    'parking': 'parking', 'parking lot': 'parking',

    # ── transportation ──
    'airport': 'airport', 'airport lounge': 'airport',
    'airport services': 'airport', 'airport shop': 'airport',
    'travel lounge': 'airport',
    'rail station': 'train_station', 'train station': 'train_station',
    'bus station': 'bus_station', 'bus stop': 'bus_stop',
    'taxi': 'taxi_stand', 'taxi stand': 'taxi_stand',
    'port': 'ferry_terminal', 'ferry': 'ferry_terminal', 'marina': 'marina',

    # ── lodging ──
    'hotel': 'hotel', 'motel': 'motel', 'lodging': 'lodging',
    'hotel resort': 'resort_hotel', 'resort': 'resort_hotel',
    'hostel': 'hostel', 'bed and breakfast': 'bed_and_breakfast',
    'campground': 'campground', 'camping': 'campground',

    # ── culture: museums, galleries, landmarks ──
    'museum': 'museum', 'science museum': 'museum',
    'history museum': 'history_museum', 'art museum': 'art_museum',
    'art gallery': 'art_gallery', 'art galleries': 'art_gallery',
    'galleries': 'art_gallery', 'gallery': 'art_gallery', 'art': 'art_gallery',
    'public artwork': 'sculpture',
    'historic site': 'historical_landmark', 'historic': 'historical_landmark',
    'landmark': 'historical_landmark', 'bridge': 'historical_landmark',
    'monument': 'monument',

    # ── entertainment and recreation ──
    'theatre': 'performing_arts_theater', 'theater': 'performing_arts_theater',
    'indie theatre': 'movie_theater', 'indie theater': 'movie_theater',
    'concert hall': 'concert_hall', 'concert': 'concert_hall',
    'music': 'live_music_venue', 'show venue': 'event_venue',
    'event space': 'event_venue', 'events venue': 'event_venue',
    'zoo': 'zoo', 'aquarium': 'aquarium', 'playground': 'playground',
    'outdoors': 'tourist_attraction', 'attraction': 'tourist_attraction',
    'tourist information': 'visitor_center',

    # ── natural features and outdoors ──
    'park': 'park', 'state park': 'state_park',
    'garden': 'garden', 'botanical garden': 'botanical_garden',
    'beach': 'beach', 'surfing beach': 'beach', 'surf': 'beach',
    'mountain': 'mountain_peak', 'peak': 'mountain_peak',
    'waterfall': 'scenic_spot', 'viewpoint': 'scenic_spot',
    'scenic': 'scenic_spot',
    'hiking': 'hiking_area', 'hike': 'hiking_area',
    'trailhead': 'hiking_area', 'hiking trailhead': 'hiking_area',

    # ── sports and fitness ──
    'gym': 'gym', 'fitness center': 'fitness_center', 'stadium': 'stadium',
    'swimming pool': 'swimming_pool', 'baseball field': 'athletic_field',
    'baseball': 'athletic_field', 'ski': 'ski_resort',
    'chair ski lift': 'ski_resort',

    # ── education ──
    'school': 'school', 'university': 'university', 'college': 'university',
    'college quad': 'university', 'college student center': 'university',
    'college art building': 'academic_department',
    'college classrooms': 'academic_department', 'library': 'library',

    # ── health and wellness ──
    'hospital': 'hospital', 'clinic': 'medical_clinic',
    'doctor': 'doctor', 'eye doctor': 'doctor', 'optometrist': 'doctor',
    'physician': 'doctor', 'dentist': 'dentist', 'pharmacy': 'pharmacy',
    'spa': 'spa', 'massage': 'massage',

    # ── places of worship ──
    'place of worship': 'place_of_worship', 'religious': 'place_of_worship',
    'religion': 'place_of_worship', 'temple': 'place_of_worship',
    'church': 'church', 'mosque': 'mosque', 'muslim': 'mosque',
    'islam': 'mosque', 'buddhist': 'buddhist_temple',
    'buddhism': 'buddhist_temple',

    # ── government and civic ──
    'government agency': 'government_office', 'police station': 'police',
    'law enforcement': 'police', 'post office': 'post_office',
    'embassy': 'embassy', 'cemetery': 'cemetery', 'graveyard': 'cemetery',

    # ── finance ──
    'bank': 'bank', 'finance': 'bank', 'atm': 'atm', 'abm': 'atm',
    'mac': 'atm', 'cash point': 'atm', 'minibank': 'atm',

    # ── offices and services ──
    'business': 'corporate_office', 'office': 'corporate_office',
    'coworking space': 'coworking_space',
    'advertising agency': 'marketing_consultant',
    'advertising': 'marketing_consultant', 'marketing': 'marketing_consultant',
    'ngo': 'non_profit_organization', 'charity': 'non_profit_organization',
    'non-profit': 'non_profit_organization',
    'nonprofit': 'non_profit_organization',
    'non profit': 'non_profit_organization',
    'not for profit': 'non_profit_organization',
    'landscaping': 'general_contractor', 'contractor': 'general_contractor',
    'laundry': 'laundry', 'hair': 'hair_salon', 'barber': 'barber_shop',
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
