//
//  PlaceCategory+FoursquareV3.swift
//  LocoKit2
//
//  Created by Claude on 2026-08-10
//
//  GENERATED FILE — regenerate via Scripts/placecategory/generate_placecategory.py
//  (BIG-513). Foursquare V3 numeric category id -> Google primaryType
//  (1232 mappings). Composed at generation time from two inputs:
//  the V3 -> V2 id pairing (fsq-v3-to-v2.txt, 1:1) and the V2 -> Google
//  table in PlaceCategory+FoursquareV2.swift. That table remains the single
//  source of category semantics — edit it, regenerate, and this file follows,
//  so the two can never drift. Each entry's trailing comment records the V2
//  id it hopped through, so the composition stays auditable here.
//
//  Values are raw strings (not PlaceCategory literals) to keep the
//  type-checker's cost trivial on a 1232-entry literal; validity is
//  guaranteed at generation time instead.
//

extension PlaceCategory {

    init?(foursquareV3Id: Int) {
        guard let raw = Self.foursquareV3Map[foursquareV3Id] else { return nil }
        self.init(rawValue: raw)
    }

    static let foursquareV3Map: [Int: String] = [
        10000: "establishment",  // 4d4b7104d754a06370d81259 — Arts and Entertainment — REVIEW: no clear google place type
        10001: "amusement_park",  // 4bf58dd8d48988d182941735 — Arts and Entertainment > Amusement Park
        10002: "aquarium",  // 4fceea171983d5d06c3e9823 — Arts and Entertainment > Aquarium
        10003: "video_arcade",  // 4bf58dd8d48988d1e1931735 — Arts and Entertainment > Arcade
        10004: "art_gallery",  // 4bf58dd8d48988d1e2931735 — Arts and Entertainment > Art Gallery
        10005: "event_venue",  // 63be6904847c3692a84b9b20 — Arts and Entertainment > Bingo Center — Inexact
        10006: "bowling_alley",  // 4bf58dd8d48988d1e4931735 — Arts and Entertainment > Bowling Alley
        10007: "amusement_park",  // 63be6904847c3692a84b9b21 — Arts and Entertainment > Carnival — Inexact
        10008: "casino",  // 4bf58dd8d48988d17c941735 — Arts and Entertainment > Casino
        10009: "performing_arts_theater",  // 52e81612bcbc57f1066b79e7 — Arts and Entertainment > Circus
        10010: "comedy_club",  // 4bf58dd8d48988d18e941735 — Arts and Entertainment > Comedy Club
        10011: "event_venue",  // 63be6904847c3692a84b9b22 — Arts and Entertainment > Country Club
        10012: "dance_hall",  // 52e81612bcbc57f1066b79ef — Arts and Entertainment > Country Dance Club
        10013: "dance_hall",  // 63be6904847c3692a84b9b23 — Arts and Entertainment > Dance Hall
        10014: "sports_activity_location",  // 63be6904847c3692a84b9c03 — Arts and Entertainment > Disc Golf Course — Inexact
        10015: "amusement_center",  // 5f2c2834b6d05514c704451e — Arts and Entertainment > Escape Room
        10016: "art_gallery",  // 56aa371be4b08b9a8d573532 — Arts and Entertainment > Exhibit
        10017: "amusement_park",  // 4eb1daf44b900d56c88a4600 — Arts and Entertainment > Fair — Inexact
        10018: "internet_cafe",  // 4bf58dd8d48988d18d941735 — Arts and Entertainment > Gaming Cafe
        10019: "go_karting_venue",  // 52e81612bcbc57f1066b79ea — Arts and Entertainment > Go Kart Track
        10020: "internet_cafe",  // 4bf58dd8d48988d1f0941735 — Arts and Entertainment > Internet Cafe
        10021: "karaoke",  // 5744ccdfe4b0c0459246b4bb — Arts and Entertainment > Karaoke Box
        10022: "amusement_center",  // 52e81612bcbc57f1066b79e6 — Arts and Entertainment > Laser Tag Center
        10023: "miniature_golf_course",  // 52e81612bcbc57f1066b79eb — Arts and Entertainment > Mini Golf Course
        10024: "movie_theater",  // 4bf58dd8d48988d17f941735 — Arts and Entertainment > Movie Theater
        10025: "movie_theater",  // 56aa371be4b08b9a8d5734de — Arts and Entertainment > Movie Theater > Drive-in Theater
        10026: "movie_theater",  // 4bf58dd8d48988d17e941735 — Arts and Entertainment > Movie Theater > Indie Movie Theater
        10027: "museum",  // 4bf58dd8d48988d181941735 — Arts and Entertainment > Museum
        10028: "art_museum",  // 4bf58dd8d48988d18f941735 — Arts and Entertainment > Museum > Art Museum
        10029: "museum",  // 559acbe0498e472f1a53fa23 — Arts and Entertainment > Museum > Erotic Museum
        10030: "history_museum",  // 4bf58dd8d48988d190941735 — Arts and Entertainment > Museum > History Museum
        10031: "museum",  // 4bf58dd8d48988d191941735 — Arts and Entertainment > Museum > Science Museum
        10032: "night_club",  // 4bf58dd8d48988d11f941735 — Arts and Entertainment > Night Club
        10033: "casino",  // 5744ccdfe4b0c0459246b4b8 — Arts and Entertainment > Pachinko Parlor
        10034: "event_venue",  // 63be6904847c3692a84b9b24 — Arts and Entertainment > Party Center
        10035: "performing_arts_theater",  // 4bf58dd8d48988d1f2931735 — Arts and Entertainment > Performing Arts Venue
        10036: "amphitheatre",  // 56aa371be4b08b9a8d5734db — Arts and Entertainment > Performing Arts Venue > Amphitheater
        10037: "concert_hall",  // 5032792091d4c4b30a586d5c — Arts and Entertainment > Performing Arts Venue > Concert Hall
        10038: "performing_arts_theater",  // 4bf58dd8d48988d135941735 — Arts and Entertainment > Performing Arts Venue > Indie Theater
        10039: "live_music_venue",  // 4bf58dd8d48988d1e5931735 — Arts and Entertainment > Performing Arts Venue > Music Venue
        10040: "live_music_venue",  // 4bf58dd8d48988d1e7931735 — Arts and Entertainment > Performing Arts Venue > Music Venue > Jazz and Blues Venue
        10041: "live_music_venue",  // 4bf58dd8d48988d1e9931735 — Arts and Entertainment > Performing Arts Venue > Music Venue > Rock Club
        10042: "opera_house",  // 4bf58dd8d48988d136941735 — Arts and Entertainment > Performing Arts Venue > Opera House
        10043: "performing_arts_theater",  // 4bf58dd8d48988d137941735 — Arts and Entertainment > Performing Arts Venue > Theater
        10044: "planetarium",  // 4bf58dd8d48988d192941735 — Arts and Entertainment > Planetarium
        10045: "amusement_center",  // 4bf58dd8d48988d1e3931735 — Arts and Entertainment > Pool Hall
        10046: "astrologer",  // 52f2ab2ebcbc57f1066b8b43 — Arts and Entertainment > Psychic and Astrologer
        10047: "sculpture",  // 507c8c4091d498d9fc8c67a9 — Arts and Entertainment > Public Art
        10048: "sports_activity_location",  // 52e81612bcbc57f1066b79e9 — Arts and Entertainment > Roller Rink — Inexact
        10049: "dance_hall",  // 52e81612bcbc57f1066b79ec — Arts and Entertainment > Salsa Club
        10050: "dance_hall",  // 56aa371be4b08b9a8d5734f9 — Arts and Entertainment > Samba School
        10051: "stadium",  // 4bf58dd8d48988d184941735 — Arts and Entertainment > Stadium
        10052: "night_club",  // 4bf58dd8d48988d1d6941735 — Arts and Entertainment > Strip Club — Inexact
        10053: "point_of_interest",  // 63be6904847c3692a84b9b25 — Arts and Entertainment > Ticket Seller — Very general: no clear google place type
        10054: "video_arcade",  // 5f2c14a5b6d05514c7042eb7 — Arts and Entertainment > VR Cafe
        10055: "water_park",  // 4bf58dd8d48988d193941735 — Arts and Entertainment > Water Park
        10056: "zoo",  // 4bf58dd8d48988d17b941735 — Arts and Entertainment > Zoo
        10057: "sports_activity_location",  // 52e81612bcbc57f1066b79e8 — Arts and Entertainment > Disc Golf — Inexact
        10058: "tourist_attraction",  // 5109983191d435c0d71c2bb1 — Arts and Entertainment > Amusement Park > Attraction
        10059: "sculpture",  // 52e81612bcbc57f1066b79ee — Arts and Entertainment > Public Art > Street Art — Inexact
        10060: "stadium",  // 4bf58dd8d48988d18c941735 — Arts and Entertainment > Stadium > Baseball Stadium
        10061: "stadium",  // 4bf58dd8d48988d18b941735 — Arts and Entertainment > Stadium > Basketball Stadium
        10062: "stadium",  // 4bf58dd8d48988d189941735 — Arts and Entertainment > Stadium > Football Stadium
        10063: "stadium",  // 4bf58dd8d48988d185941735 — Arts and Entertainment > Stadium > Hockey Stadium
        10064: "stadium",  // 56aa371be4b08b9a8d573556 — Arts and Entertainment > Stadium > Rugby Stadium
        10065: "stadium",  // 4bf58dd8d48988d188941735 — Arts and Entertainment > Stadium > Soccer Stadium
        10066: "stadium",  // 4e39a891bd410d7aed40cbc2 — Arts and Entertainment > Stadium > Tennis Stadium
        10067: "stadium",  // 4bf58dd8d48988d187941735 — Arts and Entertainment > Stadium > Track Stadium
        10068: "zoo",  // 58daa1558bbb0b01f18ec1fd — Arts and Entertainment > Zoo > Zoo Exhibit
        10069: "sculpture",  // 52e81612bcbc57f1066b79ed — Arts and Entertainment > Public Art > Outdoor Sculpture
        11000: "service",  // 4d4b7105d754a06375d81259 — Business and Professional Services — REVIEW: no clear google place type
        11001: "corporate_office",  // 52e81612bcbc57f1066b7a3d — Business and Professional Services > Advertising Agency
        11002: "farm",  // 63be6904847c3692a84b9b26 — Business and Professional Services > Agriculture and Forestry Service
        11003: "corporate_office",  // 5fac002599ce226e27fe72e5 — Business and Professional Services > Architecture Firm
        11004: "service",  // 63be6904847c3692a84b9b28 — Business and Professional Services > Art Restoration Service
        11005: "art_studio",  // 58daa1558bbb0b01f18ec1d6 — Business and Professional Services > Art Studio
        11006: "service",  // 63be6904847c3692a84b9b29 — Business and Professional Services > Audiovisual Service
        11007: "auditorium",  // 4bf58dd8d48988d173941735 — Business and Professional Services > Auditorium
        11008: "service",  // 63be6904847c3692a84b9b2a — Business and Professional Services > Automation and Control System
        11009: "car_repair",  // 63be6904847c3692a84b9b2b — Business and Professional Services > Automotive Service
        11010: "car_repair",  // 52f2ab2ebcbc57f1066b8b44 — Business and Professional Services > Automotive Service > Automotive Repair Shop
        11011: "car_wash",  // 4f04ae1f2fb6e1c99f3db0ba — Business and Professional Services > Automotive Service > Car Wash and Detail
        11012: "car_repair",  // 63be6904847c3692a84b9b2c — Business and Professional Services > Automotive Service > Motorcycle Repair Shop
        11013: "car_repair",  // 63be6904847c3692a84b9b2d — Business and Professional Services > Automotive Service > Oil Change Service
        11014: "car_repair",  // 63be6904847c3692a84b9b2e — Business and Professional Services > Automotive Service > Smog Check Shop
        11015: "tire_shop",  // 63be6904847c3692a84b9b2f — Business and Professional Services > Automotive Service > Tire Repair Shop
        11016: "car_repair",  // 63be6904847c3692a84b9b30 — Business and Professional Services > Automotive Service > Towing Service
        11017: "car_repair",  // 63be6904847c3692a84b9b31 — Business and Professional Services > Automotive Service > Transmissions Shop
        11018: "car_repair",  // 5f2c1e0db6d05514c70436d4 — Business and Professional Services > Automotive Service > Vehicle Inspection Station
        11019: "banquet_hall",  // 56aa371be4b08b9a8d5734cf — Business and Professional Services > Ballroom
        11020: "consultant",  // 63be6904847c3692a84b9b32 — Business and Professional Services > Office > Business and Strategy Consulting Office
        11021: "business_center",  // 56aa371be4b08b9a8d573517 — Business and Professional Services > Business Center
        11022: "corporate_office",  // 5032764e91d4c4b30a586d5a — Business and Professional Services > Office > Campaign Office
        11023: "consultant",  // 63be6904847c3692a84b9b33 — Business and Professional Services > Career Counselor
        11024: "manufacturer",  // 63be6904847c3692a84b9b34 — Business and Professional Services > Chemicals and Gasses Manufacturer
        11025: "child_care_agency",  // 5744ccdfe4b0c0459246b4c7 — Business and Professional Services > Child Care Service
        11026: "child_care_agency",  // 4f4532974b9074f6e4fb0104 — Business and Professional Services > Child Care Service > Daycare
        11027: "service",  // 63be6904847c3692a84b9b35 — Business and Professional Services > Computer Repair Service
        11028: "general_contractor",  // 63be6904847c3692a84b9b36 — Business and Professional Services > Construction
        11029: "convention_center",  // 4bf58dd8d48988d1ff931735 — Business and Professional Services > Convention Center
        11030: "art_studio",  // 4bf58dd8d48988d1f4941735 — Business and Professional Services > Design Studio
        11031: "supplier",  // 52e81612bcbc57f1066b7a37 — Business and Professional Services > Distribution Center
        11032: "supplier",  // 63be6904847c3692a84b9b39 — Business and Professional Services > Electrical Equipment Supplier
        11033: "employment_agency",  // 52f2ab2ebcbc57f1066b8b57 — Business and Professional Services > Employment Agency
        11034: "consultant",  // 63be6904847c3692a84b9b3a — Business and Professional Services > Engineer
        11035: "corporate_office",  // 63be6904847c3692a84b9b3b — Business and Professional Services > Entertainment Agency
        11036: "service",  // 56aa371be4b08b9a8d573554 — Business and Professional Services > Entertainment Service
        11037: "service",  // 63be6904847c3692a84b9b3c — Business and Professional Services > Equipment Rental Service
        11038: "service",  // 5454152e498ef71e2b9132c6 — Business and Professional Services > Event Service
        11039: "event_venue",  // 4bf58dd8d48988d171941735 — Business and Professional Services > Event Space
        11040: "manufacturer",  // 4eb1bea83b7b6f98df247e06 — Business and Professional Services > Factory
        11041: "television_studio",  // 56aa371be4b08b9a8d573523 — Business and Professional Services > Film Studio
        11042: "finance",  // 63be6904847c3692a84b9b3d — Business and Professional Services > Financial Service
        11043: "accounting",  // 63be6904847c3692a84b9b3e — Business and Professional Services > Financial Service > Accounting and Bookkeeping Service
        11044: "atm",  // 52f2ab2ebcbc57f1066b8b56 — Business and Professional Services > Financial Service > Banking and Finance > ATM
        11045: "bank",  // 4bf58dd8d48988d10a951735 — Business and Professional Services > Financial Service > Banking and Finance > Bank
        11046: "bank",  // 63be6904847c3692a84b9b3f — Business and Professional Services > Financial Service > Banking and Finance
        11047: "finance",  // 63be6904847c3692a84b9b40 — Business and Professional Services > Financial Service > Business Broker
        11048: "finance",  // 52f2ab2ebcbc57f1066b8b2d — Business and Professional Services > Financial Service > Check Cashing Service
        11049: "finance",  // 63be6904847c3692a84b9b41 — Business and Professional Services > Financial Service > Collections Service
        11050: "finance",  // 63be6904847c3692a84b9b42 — Business and Professional Services > Financial Service > Credit Counseling and Bankruptcy Service
        11051: "bank",  // 5032850891d4c4b30a586d62 — Business and Professional Services > Financial Service > Banking and Finance > Credit Union
        11052: "finance",  // 5744ccdfe4b0c0459246b4be — Business and Professional Services > Financial Service > Currency Exchange
        11053: "finance",  // 63be6904847c3692a84b9b43 — Business and Professional Services > Financial Service > Financial Planner
        11054: "finance",  // 63be6904847c3692a84b9b44 — Business and Professional Services > Financial Service > Loans Agency
        11055: "finance",  // 63be6904847c3692a84b9b45 — Business and Professional Services > Financial Service > Stock Broker
        11056: "service",  // 56aa371be4b08b9a8d573550 — Business and Professional Services > Food and Beverage Service
        11057: "catering_service",  // 63be6904847c3692a84b9b46 — Business and Professional Services > Food and Beverage Service > Caterer
        11058: "supplier",  // 63be6904847c3692a84b9b47 — Business and Professional Services > Food and Beverage Service > Food Distribution Center
        11059: "funeral_home",  // 4f4534884b9074f6e4fb0174 — Business and Professional Services > Funeral Home
        11060: "service",  // 63be6904847c3692a84b9b48 — Business and Professional Services > Geological Service
        11061: "beauty_salon",  // 54541900498ea6ccd0202697 — Business and Professional Services > Health and Beauty Service
        11062: "barber_shop",  // 63be6904847c3692a84b9b49 — Business and Professional Services > Health and Beauty Service > Barbershop
        11063: "public_bath",  // 52e81612bcbc57f1066b7a27 — Business and Professional Services > Health and Beauty Service > Bath House
        11064: "hair_salon",  // 4bf58dd8d48988d110951735 — Business and Professional Services > Health and Beauty Service > Hair Salon
        11065: "body_art_service",  // 52f2ab2ebcbc57f1066b8b20 — Business and Professional Services > Health and Beauty Service > Body Piercing Shop
        11066: "laundry",  // 52f2ab2ebcbc57f1066b8b1d — Business and Professional Services > Health and Beauty Service > Dry Cleaner
        11067: "beauty_salon",  // 63be6904847c3692a84b9b4a — Business and Professional Services > Health and Beauty Service > Hair Removal Service
        11068: "laundry",  // 52f2ab2ebcbc57f1066b8b33 — Business and Professional Services > Laundromat
        11069: "laundry",  // 4bf58dd8d48988d1fc941735 — Business and Professional Services > Laundry Service
        11070: "massage",  // 52f2ab2ebcbc57f1066b8b3c — Business and Professional Services > Health and Beauty Service > Massage Clinic
        11071: "nail_salon",  // 4f04aa0c2fb6e1c99f3db0b8 — Business and Professional Services > Health and Beauty Service > Nail Salon
        11072: "skin_care_clinic",  // 63be6904847c3692a84b9b4b — Business and Professional Services > Health and Beauty Service > Skin Care Clinic
        11073: "spa",  // 4bf58dd8d48988d1ed941735 — Business and Professional Services > Health and Beauty Service > Spa
        11074: "tanning_studio",  // 4d1cf8421a97d635ce361c31 — Business and Professional Services > Health and Beauty Service > Tanning Salon
        11075: "body_art_service",  // 4bf58dd8d48988d1de931735 — Business and Professional Services > Health and Beauty Service > Tattoo Parlor
        11076: "general_contractor",  // 63be6904847c3692a84b9b58 — Business and Professional Services > Home Improvement Service
        11077: "general_contractor",  // 63be6904847c3692a84b9b4c — Business and Professional Services > Home Improvement Service > Bathroom Contractor
        11078: "general_contractor",  // 63be6904847c3692a84b9b4d — Business and Professional Services > Home Improvement Service > Carpenter
        11079: "general_contractor",  // 63be6904847c3692a84b9b4e — Business and Professional Services > Home Improvement Service > Carpet and Flooring Contractor
        11080: "service",  // 63be6904847c3692a84b9b4f — Business and Professional Services > Home Improvement Service > Chimney Sweep
        11081: "general_contractor",  // 63be6904847c3692a84b9b50 — Business and Professional Services > Home Improvement Service > Deck and Patio Contractor
        11082: "general_contractor",  // 63be6904847c3692a84b9b51 — Business and Professional Services > Home Improvement Service > Doors and Windows Contractor
        11083: "electrician",  // 63be6904847c3692a84b9b52 — Business and Professional Services > Home Improvement Service > Electrician
        11084: "general_contractor",  // 63be6904847c3692a84b9b53 — Business and Professional Services > Home Improvement Service > Fence Contractor
        11085: "general_contractor",  // 63be6904847c3692a84b9b54 — Business and Professional Services > Home Improvement Service > Garage Door Supplier
        11086: "general_contractor",  // 63be6904847c3692a84b9b55 — Business and Professional Services > Home Improvement Service > General Contractor
        11087: "general_contractor",  // 63be6904847c3692a84b9b56 — Business and Professional Services > Home Improvement Service > Heating, Ventilating and Air Conditioning Contractor
        11088: "service",  // 63be6904847c3692a84b9b57 — Business and Professional Services > Home Improvement Service > Home Inspection
        11089: "service",  // 545419b1498ea6ccd0202f58 — Business and Professional Services > Home Improvement Service > Home Service
        11090: "consultant",  // 63be6904847c3692a84b9b59 — Business and Professional Services > Home Improvement Service > Interior Designer
        11091: "general_contractor",  // 63be6904847c3692a84b9b5a — Business and Professional Services > Home Improvement Service > Kitchen Remodeler
        11092: "service",  // 63be6904847c3692a84b9b5b — Business and Professional Services > Home Improvement Service > Landscaper and Gardener
        11093: "moving_company",  // 63be6904847c3692a84b9b5c — Business and Professional Services > Home Improvement Service > Mover
        11094: "painter",  // 63be6904847c3692a84b9b5d — Business and Professional Services > Home Improvement Service > Painter
        11095: "service",  // 63be6904847c3692a84b9b5e — Business and Professional Services > Home Improvement Service > Pest Control Service
        11096: "plumber",  // 63be6904847c3692a84b9b5f — Business and Professional Services > Home Improvement Service > Plumber
        11097: "service",  // 63be6904847c3692a84b9b60 — Business and Professional Services > Home Improvement Service > Professional Cleaning Service
        11098: "roofing_contractor",  // 63be6904847c3692a84b9b61 — Business and Professional Services > Home Improvement Service > Roofer
        11099: "general_contractor",  // 63be6904847c3692a84b9b62 — Business and Professional Services > Home Improvement Service > Sewer Contractor
        11100: "service",  // 63be6904847c3692a84b9b63 — Business and Professional Services > Home Improvement Service > Swimming Pool Maintenance and Service
        11101: "service",  // 63be6904847c3692a84b9b64 — Business and Professional Services > Home Improvement Service > Tree Service
        11102: "service",  // 63be6904847c3692a84b9b65 — Business and Professional Services > Home Improvement Service > Upholstery Service
        11103: "employment_agency",  // 63be6904847c3692a84b9b66 — Business and Professional Services > Human Resources Agency
        11104: "service",  // 63be6904847c3692a84b9b67 — Business and Professional Services > Import and Export Service
        11105: "supplier",  // 63be6904847c3692a84b9b68 — Business and Professional Services > Industrial Equipment Supplier
        11106: "supplier",  // 56aa371be4b08b9a8d5734d7 — Business and Professional Services > Industrial Estate
        11107: "insurance_agency",  // 58daa1558bbb0b01f18ec1f1 — Business and Professional Services > Insurance Agency
        11108: "service",  // 52f2ab2ebcbc57f1066b8b36 — Business and Professional Services > Technology Business > IT Service
        11109: "medical_lab",  // 63be6904847c3692a84b9b69 — Business and Professional Services > Laboratory
        11110: "supplier",  // 63be6904847c3692a84b9b6a — Business and Professional Services > Leather Supplier
        11111: "lawyer",  // 63be6904847c3692a84b9b6b — Business and Professional Services > Legal Service
        11112: "lawyer",  // 52f2ab2ebcbc57f1066b8b3f — Business and Professional Services > Legal Service > Law Office
        11113: "lawyer",  // 63be6904847c3692a84b9b6c — Business and Professional Services > Legal Service > Immigration Attorney
        11114: "lawyer",  // 5ae95d208a6f17002ce792b2 — Business and Professional Services > Legal Service > Notary
        11115: "locksmith",  // 52f2ab2ebcbc57f1066b8b1e — Business and Professional Services > Locksmith
        11116: "service",  // 63be6904847c3692a84b9b6d — Business and Professional Services > Logging Service
        11117: "store",  // 52f2ab2ebcbc57f1066b8b38 — Business and Professional Services > Lottery Retailer
        11118: "manufacturer",  // 63be6904847c3692a84b9b6e — Business and Professional Services > Machine Shop
        11119: "consultant",  // 63be6904847c3692a84b9b6f — Business and Professional Services > Management Consultant
        11120: "manufacturer",  // 63be6904847c3692a84b9b70 — Business and Professional Services > Manufacturer
        11121: "corporate_office",  // 63be6904847c3692a84b9b72 — Business and Professional Services > Media Agency
        11122: "supplier",  // 63be6904847c3692a84b9b73 — Business and Professional Services > Metals Supplier
        11123: "telecommunications_service_provider",  // 63be6904847c3692a84b9b74 — Business and Professional Services > Mobile Company
        11124: "corporate_office",  // 4bf58dd8d48988d124941735 — Business and Professional Services > Office
        11125: "cafeteria",  // 54f4ba06498e2cf5561da814 — Business and Professional Services > Office > Corporate Cafeteria
        11126: "coffee_shop",  // 5665c7b9498e7d8a4f2c0f06 — Business and Professional Services > Office > Corporate Coffee Shop
        11127: "real_estate_agency",  // 63be6904847c3692a84b9b75 — Business and Professional Services > Office > Corporate Housing Agency
        11128: "coworking_space",  // 4bf58dd8d48988d174941735 — Business and Professional Services > Office > Coworking Space
        11129: "convention_center",  // 4bf58dd8d48988d127941735 — Business and Professional Services > Office > Meeting Room
        11130: "corporate_office",  // 63be6904847c3692a84b9b76 — Business and Professional Services > Office > Office Building
        11131: "event_venue",  // 56aa371be4b08b9a8d57356a — Business and Professional Services > Outdoor Event Space
        11132: "supplier",  // 63be6904847c3692a84b9b78 — Business and Professional Services > Paper Supplier
        11133: "pet_care",  // 5032897c91d4c4b30a586d69 — Business and Professional Services > Pet Service
        11134: "pet_care",  // 63be6904847c3692a84b9b79 — Business and Professional Services > Pet Service > Pet Grooming Service
        11135: "pet_boarding_service",  // 63be6904847c3692a84b9b7a — Business and Professional Services > Pet Service > Pet Sitting and Boarding Service
        11136: "supplier",  // 63be6904847c3692a84b9b7b — Business and Professional Services > Petroleum Supplier
        11137: "service",  // 63be6904847c3692a84b9b7d — Business and Professional Services > Photography Service
        11138: "service",  // 63be6904847c3692a84b9b7c — Business and Professional Services > Photography Service > Photographer
        11139: "service",  // 4eb1bdde3b7b55596b4a7490 — Business and Professional Services > Photography Service > Photography Lab
        11140: "art_studio",  // 554a5e17498efabeda6cc559 — Business and Professional Services > Photography Service > Photography Studio
        11141: "supplier",  // 63be6904847c3692a84b9b7e — Business and Professional Services > Plastics Supplier
        11142: "service",  // 58daa1548bbb0b01f18ec1a9 — Business and Professional Services > Power Plant
        11143: "corporate_office",  // 63be6904847c3692a84b9b82 — Business and Professional Services > Publisher
        11144: "corporate_office",  // 5032856091d4c4b30a586d63 — Business and Professional Services > Radio Station
        11145: "real_estate_agency",  // 63be6904847c3692a84b9b83 — Business and Professional Services > Real Estate Service
        11146: "service",  // 63be6904847c3692a84b9b84 — Business and Professional Services > Real Estate Service > Building and Land Surveyor
        11147: "real_estate_agency",  // 63be6904847c3692a84b9b85 — Business and Professional Services > Real Estate Service > Commercial Real Estate Developer
        11148: "real_estate_agency",  // 63be6904847c3692a84b9b86 — Business and Professional Services > Real Estate Service > Property Management Office
        11149: "real_estate_agency",  // 5032885091d4c4b30a586d66 — Business and Professional Services > Real Estate Service > Real Estate Agency
        11150: "real_estate_agency",  // 63be6904847c3692a84b9b87 — Business and Professional Services > Real Estate Service > Real Estate Appraiser
        11151: "real_estate_agency",  // 63be6904847c3692a84b9b88 — Business and Professional Services > Real Estate Service > Real Estate Development and Title Company
        11152: "art_studio",  // 52f2ab2ebcbc57f1066b8b37 — Business and Professional Services > Recording Studio
        11153: "service",  // 4f4531084b9074f6e4fb0101 — Business and Professional Services > Recycling Facility
        11154: "supplier",  // 63be6904847c3692a84b9b89 — Business and Professional Services > Refrigeration and Ice Supplier
        11155: "service",  // 63be6904847c3692a84b9b8a — Business and Professional Services > Renewable Energy Service
        11156: "service",  // 56aa371be4b08b9a8d573552 — Business and Professional Services > Rental Service
        11157: "service",  // 52f2ab2ebcbc57f1066b8b2f — Business and Professional Services > Repair Service
        11158: "research_institute",  // 58daa1558bbb0b01f18ec1b2 — Business and Professional Services > Research Station
        11159: "supplier",  // 63be6904847c3692a84b9b8b — Business and Professional Services > Rubber Supplier
        11160: "service",  // 63be6904847c3692a84b9b8c — Business and Professional Services > Salvage Yard
        11161: "supplier",  // 63be6904847c3692a84b9b8d — Business and Professional Services > Scientific Equipment Supplier
        11162: "service",  // 63be6904847c3692a84b9b8f — Business and Professional Services > Security and Safety
        11163: "shipping_service",  // 52f2ab2ebcbc57f1066b8b1f — Business and Professional Services > Shipping, Freight, and Material Transportation Service
        11164: "service",  // 52f2ab2ebcbc57f1066b8b39 — Business and Professional Services > Shoe Repair Service
        11165: "storage",  // 4f04b1572fb6e1c99f3db0bf — Business and Professional Services > Storage Facility
        11166: "tailor",  // 5032781d91d4c4b30a586d5b — Business and Professional Services > Tailor
        11167: "corporate_office",  // 63be6904847c3692a84b9b90 — Business and Professional Services > Technology Business
        11168: "corporate_office",  // 63be6904847c3692a84b9b91 — Business and Professional Services > Technology Business > Software Company
        11169: "service",  // 63be6904847c3692a84b9b92 — Business and Professional Services > Technology Business > Website Designer
        11170: "telecommunications_service_provider",  // 63be6904847c3692a84b9b93 — Business and Professional Services > Telecommunication Service
        11171: "service",  // 63be6904847c3692a84b9b94 — Business and Professional Services > Translation Service
        11172: "school",  // 63be6904847c3692a84b9b95 — Business and Professional Services > Tutoring Service — Inexact
        11173: "television_studio",  // 52e81612bcbc57f1066b7a31 — Business and Professional Services > TV Station
        11174: "warehouse_store",  // 52e81612bcbc57f1066b7a36 — Business and Professional Services > Warehouse — Inexact
        11175: "service",  // 58daa1558bbb0b01f18ec1ac — Business and Professional Services > Waste Management Service
        11176: "service",  // 63be6904847c3692a84b9b96 — Business and Professional Services > Water Treatment Service
        11177: "wedding_venue",  // 56aa371be4b08b9a8d5734c5 — Business and Professional Services > Wedding Hall
        11178: "service",  // 63be6904847c3692a84b9b97 — Business and Professional Services > Welding Service
        11179: "wholesaler",  // 63be6904847c3692a84b9b98 — Business and Professional Services > Wholesaler
        11180: "corporate_office",  // 4bf58dd8d48988d125941735 — Business and Professional Services > Office > Tech Startup
        11181: "corporate_office",  // 63be6904847c3692a84b9b27 — Business and Professional Services > Appraiser
        11182: "service",  // 5453de49498eade8af355881 — Business and Professional Services > Business Service
        11183: "convention_center",  // 4bf58dd8d48988d100941735 — Business and Professional Services > Convention Center > Conference Room
        11184: "service",  // 63be6904847c3692a84b9b37 — Business and Professional Services > Creative Service
        11185: "marketing_consultant",  // 63be6904847c3692a84b9b38 — Business and Professional Services > Direct Mail and Email Marketing Service
        11186: "consultant",  // 63be6904847c3692a84b9b71 — Business and Professional Services > Market Research and Consulting Service
        11187: "corporate_office",  // 5665ef1d498ec706735f0e59 — Business and Professional Services > Office > Corporate Amenity
        11188: "marketing_consultant",  // 63be6904847c3692a84b9b77 — Business and Professional Services > Online Advertising Service
        11189: "marketing_consultant",  // 63be6904847c3692a84b9b7f — Business and Professional Services > Print, TV, Radio and Outdoor Advertising Service
        11190: "marketing_consultant",  // 63be6904847c3692a84b9b80 — Business and Professional Services > Promotional Item Service
        11191: "marketing_consultant",  // 63be6904847c3692a84b9b81 — Business and Professional Services > Public Relations Firm
        11192: "research_institute",  // 5744ccdfe4b0c0459246b4d6 — Business and Professional Services > Research Laboratory
        11193: "marketing_consultant",  // 63be6904847c3692a84b9b8e — Business and Professional Services > Search Engine Marketing and Optimization Service
        11194: "service",  // 63be6904847c3692a84b9b99 — Business and Professional Services > Writing, Copywriting and Technical Writing Service
        12000: "service",  // 63be6904847c3692a84b9b9a — Community and Government — REVIEW: no clear google place type
        12001: "medical_clinic",  // 63be6904847c3692a84b9b9b — Community and Government > Addiction Treatment Center — Inexact
        12002: "pet_care",  // 4e52d2d203646f7c19daa8ae — Community and Government > Animal Shelter
        12003: "cemetery",  // 4bf58dd8d48988d15c941735 — Community and Government > Cemetery
        12004: "community_center",  // 52e81612bcbc57f1066b7a34 — Community and Government > Community Center
        12005: "cultural_center",  // 52e81612bcbc57f1066b7a32 — Community and Government > Cultural Center
        12006: "service",  // 63be6904847c3692a84b9b9c — Community and Government > Disabled Persons Service
        12007: "service",  // 63be6904847c3692a84b9b9d — Community and Government > Domestic Abuse Treatment Center — Inexact
        12008: "service",  // 63be6904847c3692a84b9b9e — Community and Government > Dump
        12009: "educational_institution",  // 4bf58dd8d48988d13b941735 — Community and Government > Education
        12010: "school",  // 56aa371ce4b08b9a8d573570 — Community and Government > Education > Adult Education
        12011: "school",  // 63be6904847c3692a84b9b9f — Community and Government > Education > Art School
        12012: "school",  // 52e81612bcbc57f1066b7a43 — Community and Government > Education > Circus School
        12013: "university",  // 4d4b7105d754a06372d81259 — Community and Government > Education > College and University
        12014: "university",  // 4bf58dd8d48988d198941735 — Community and Government > Education > College and University > College Academic Building
        12015: "university",  // 4bf58dd8d48988d197941735 — Community and Government > Education > College and University > College Administrative Building
        12016: "university",  // 4bf58dd8d48988d199941735 — Community and Government > Education > College and University > College Arts Building
        12017: "auditorium",  // 4bf58dd8d48988d1af941735 — Community and Government > Education > College and University > College Auditorium
        12018: "athletic_field",  // 4bf58dd8d48988d1bb941735 — Community and Government > Education > College and University > College Baseball Diamond
        12019: "sports_complex",  // 4bf58dd8d48988d1ba941735 — Community and Government > Education > College and University > College Basketball Court
        12020: "book_store",  // 4bf58dd8d48988d1b1941735 — Community and Government > Education > College and University > College Bookstore
        12021: "cafeteria",  // 4bf58dd8d48988d1a1941735 — Community and Government > Education > College and University > College Cafeteria
        12022: "university",  // 4bf58dd8d48988d1a0941735 — Community and Government > Education > College and University > College Classroom
        12023: "university",  // 4bf58dd8d48988d19a941735 — Community and Government > Education > College and University > College Communications Building
        12024: "athletic_field",  // 4bf58dd8d48988d1b9941735 — Community and Government > Education > College and University > College Cricket Pitch
        12025: "university",  // 4bf58dd8d48988d19e941735 — Community and Government > Education > College and University > College Engineering Building
        12026: "athletic_field",  // 4bf58dd8d48988d1b8941735 — Community and Government > Education > College and University > College Football Field
        12027: "gym",  // 4bf58dd8d48988d1b2941735 — Community and Government > Education > College and University > College Gym
        12028: "university",  // 4bf58dd8d48988d19d941735 — Community and Government > Education > College and University > College History Building
        12029: "ice_skating_rink",  // 4bf58dd8d48988d1b5941735 — Community and Government > Education > College and University > College Hockey Rink
        12030: "university",  // 4bf58dd8d48988d1a5941735 — Community and Government > Education > College and University > College Lab
        12031: "library",  // 4bf58dd8d48988d1a7941735 — Community and Government > Education > College and University > College Library
        12032: "university",  // 4bf58dd8d48988d19c941735 — Community and Government > Education > College and University > College Math Building
        12033: "university",  // 4bf58dd8d48988d1aa941735 — Community and Government > Education > College and University > College Quad
        12034: "fitness_center",  // 4bf58dd8d48988d1a9941735 — Community and Government > Education > College and University > College Rec Center
        12035: "university",  // 4bf58dd8d48988d1a3941735 — Community and Government > Education > College and University > College Residence Hall
        12036: "university",  // 4bf58dd8d48988d19b941735 — Community and Government > Education > College and University > College Science Building
        12037: "athletic_field",  // 4bf58dd8d48988d1b7941735 — Community and Government > Education > College and University > College Soccer Field
        12038: "stadium",  // 4bf58dd8d48988d1b4941735 — Community and Government > Education > College and University > College Stadium
        12039: "university",  // 4bf58dd8d48988d19f941735 — Community and Government > Education > College and University > College Technology Building
        12040: "tennis_court",  // 4e39a9cebd410d7aed40cbc4 — Community and Government > Education > College and University > College Tennis Court
        12041: "performing_arts_theater",  // 4bf58dd8d48988d1ac941735 — Community and Government > Education > College and University > College Theater
        12042: "athletic_field",  // 4bf58dd8d48988d1b6941735 — Community and Government > Education > College and University > College Track
        12043: "university",  // 4bf58dd8d48988d1b0941735 — Community and Government > Education > College and University > Fraternity House
        12044: "university",  // 4bf58dd8d48988d1a6941735 — Community and Government > Education > College and University > Law School
        12045: "university",  // 4bf58dd8d48988d1b3941735 — Community and Government > Education > College and University > Medical School
        12046: "university",  // 4bf58dd8d48988d141941735 — Community and Government > Education > College and University > Sorority House
        12047: "university",  // 4bf58dd8d48988d1ab941735 — Community and Government > Education > College and University > Student Center
        12048: "university",  // 4bf58dd8d48988d1a2941735 — Community and Government > Education > College and University > Community College
        12049: "school",  // 63be6904847c3692a84b9ba0 — Community and Government > Education > Computer Training School
        12050: "school",  // 58daa1558bbb0b01f18ec200 — Community and Government > Education > Culinary School
        12051: "school",  // 52e81612bcbc57f1066b7a42 — Community and Government > Education > Driving School
        12052: "school",  // 52e81612bcbc57f1066b7a49 — Community and Government > Education > Flight School
        12053: "school",  // 52e81612bcbc57f1066b7a48 — Community and Government > Education > Language School
        12054: "school",  // 4f04b10d2fb6e1c99f3db0be — Community and Government > Education > Music School
        12055: "preschool",  // 4f4533814b9074f6e4fb0107 — Community and Government > Education > Nursery School
        12056: "preschool",  // 52e81612bcbc57f1066b7a45 — Community and Government > Education > Preschool
        12057: "school",  // 63be6904847c3692a84b9ba1 — Community and Government > Education > Primary and Secondary School
        12058: "primary_school",  // 4f4533804b9074f6e4fb0105 — Community and Government > Education > Primary and Secondary School > Elementary School
        12059: "secondary_school",  // 4bf58dd8d48988d13d941735 — Community and Government > Education > Primary and Secondary School > High School
        12060: "primary_school",  // 4f4533814b9074f6e4fb0106 — Community and Government > Education > Primary and Secondary School > Middle School
        12061: "school",  // 52e81612bcbc57f1066b7a46 — Community and Government > Education > Private School
        12062: "school",  // 52e81612bcbc57f1066b7a47 — Community and Government > Education > Religious School
        12063: "school",  // 4bf58dd8d48988d1ad941735 — Community and Government > Education > Trade School
        12064: "government_office",  // 4bf58dd8d48988d126941735 — Community and Government > Government Building
        12065: "government_office",  // 4bf58dd8d48988d12a941735 — Community and Government > Government Building > Capitol Building
        12066: "city_hall",  // 4bf58dd8d48988d129941735 — Community and Government > Government Building > City Hall
        12067: "courthouse",  // 4bf58dd8d48988d12b941735 — Community and Government > Government Building > Courthouse
        12068: "embassy",  // 4bf58dd8d48988d12c951735 — Community and Government > Government Building > Embassy or Consulate
        12069: "government_office",  // 63be6904847c3692a84b9ba2 — Community and Government > Government Building > Government Department
        12070: "police",  // 63be6904847c3692a84b9ba3 — Community and Government > Government Building > Law Enforcement and Public Safety
        12071: "fire_station",  // 4bf58dd8d48988d12c941735 — Community and Government > Government Building > Law Enforcement and Public Safety > Fire Station
        12072: "police",  // 4bf58dd8d48988d12e941735 — Community and Government > Government Building > Law Enforcement and Public Safety > Police Station
        12073: "government_office",  // 63be6904847c3692a84b9ba6 — Community and Government > Government Building > Military
        12074: "government_office",  // 4e52adeebd41615f56317744 — Community and Government > Government Building > Military > Military Base
        12075: "post_office",  // 4bf58dd8d48988d172941735 — Community and Government > Government Building > Post Office
        12076: "government_office",  // 63be6904847c3692a84b9ba7 — Community and Government > Government Lobbyist
        12077: "service",  // 63be6904847c3692a84b9ba8 — Community and Government > Homeless Shelter — Inexact
        12078: "government_office",  // 63be6904847c3692a84b9ba9 — Community and Government > Housing Authority
        12079: "housing_complex",  // 4f2a210c4b9023bd5841ed28 — Community and Government > Housing Development
        12080: "library",  // 4bf58dd8d48988d12f941735 — Community and Government > Library
        12081: "planetarium",  // 5744ccdfe4b0c0459246b4d9 — Community and Government > Observatory — Inexact
        12082: "association_or_organization",  // 63be6904847c3692a84b9baa — Community and Government > Organization
        12083: "non_profit_organization",  // 63be6904847c3692a84b9bab — Community and Government > Organization > Charity
        12084: "association_or_organization",  // 52e81612bcbc57f1066b7a35 — Community and Government > Organization > Club House
        12085: "non_profit_organization",  // 63be6904847c3692a84b9bac — Community and Government > Organization > Environmental Organization
        12086: "non_profit_organization",  // 50328a8e91d4c4b30a586d6c — Community and Government > Organization > Non-Profit Organization
        12087: "non_profit_organization",  // 63be6904847c3692a84b9baf — Community and Government > Organization > Social Services Organization
        12088: "non_profit_organization",  // 5f2c5de85b4c177b9a6de29c — Community and Government > Organization > Veterans' Organization
        12089: "non_profit_organization",  // 63be6904847c3692a84b9bb0 — Community and Government > Organization > Youth Organization
        12090: "establishment",  // 5310b8e5bcbc57f1066bcbf1 — Community and Government > Prison — Inexact
        12091: "local_government_office",  // 63be6904847c3692a84b9bb1 — Community and Government > Public and Social Service
        12092: "public_bathroom",  // 5744ccdfe4b0c0459246b4c4 — Community and Government > Public Bathroom
        12093: "medical_center",  // 56aa371be4b08b9a8d57351d — Community and Government > Rehabilitation Center
        12094: "apartment_building",  // 4e67e38e036454776db1fb3a — Community and Government > Residential Building
        12095: "establishment",  // 63be6904847c3692a84b9bb2 — Community and Government > Retirement Home — Inexact
        12096: "service",  // 63be6904847c3692a84b9bb3 — Community and Government > Senior Citizen Service
        12097: "association_or_organization",  // 52e81612bcbc57f1066b7a33 — Community and Government > Social Club
        12098: "place_of_worship",  // 4bf58dd8d48988d131941735 — Community and Government > Spiritual Center
        12099: "buddhist_temple",  // 52e81612bcbc57f1066b7a3e — Community and Government > Spiritual Center > Buddhist Temple
        12100: "place_of_worship",  // 58daa1558bbb0b01f18ec1eb — Community and Government > Spiritual Center > Cemevi
        12101: "church",  // 4bf58dd8d48988d132941735 — Community and Government > Spiritual Center > Church
        12102: "place_of_worship",  // 56aa371be4b08b9a8d5734fc — Community and Government > Spiritual Center > Confucian Temple
        12103: "hindu_temple",  // 52e81612bcbc57f1066b7a3f — Community and Government > Spiritual Center > Hindu Temple
        12104: "place_of_worship",  // 5744ccdfe4b0c0459246b4ac — Community and Government > Spiritual Center > Kingdom Hall
        12105: "place_of_worship",  // 52e81612bcbc57f1066b7a40 — Community and Government > Spiritual Center > Monastery
        12106: "mosque",  // 4bf58dd8d48988d138941735 — Community and Government > Spiritual Center > Mosque
        12107: "place_of_worship",  // 52e81612bcbc57f1066b7a41 — Community and Government > Spiritual Center > Prayer Room
        12108: "shinto_shrine",  // 4eb1d80a4b900d56c88a45ff — Community and Government > Spiritual Center > Shrine — Inexact
        12109: "place_of_worship",  // 5bae9231bedf3950379f89c9 — Community and Government > Spiritual Center > Sikh Temple
        12110: "synagogue",  // 4bf58dd8d48988d139941735 — Community and Government > Spiritual Center > Synagogue
        12111: "place_of_worship",  // 4bf58dd8d48988d13a941735 — Community and Government > Spiritual Center > Temple
        12112: "place_of_worship",  // 56aa371be4b08b9a8d5734f6 — Community and Government > Spiritual Center > Terreiro
        12113: "childrens_camp",  // 52e81612bcbc57f1066b7a10 — Community and Government > Summer Camp
        12114: "mobile_home_park",  // 52f2ab2ebcbc57f1066b8b55 — Community and Government > Trailer Park
        12115: "service",  // 63be6904847c3692a84b9bb4 — Community and Government > Utility Company
        12116: "government_office",  // 4cae28ecbf23941eb1190695 — Community and Government > Polling Place
        12117: "health",  // 5032891291d4c4b30a586d68 — Community and Government > Assisted Living — Inexact
        12118: "government_office",  // 63be6904847c3692a84b9ba4 — Community and Government > Government Building > Law Enforcement and Public Safety > Probation Office
        12119: "fire_station",  // 63be6904847c3692a84b9ba5 — Community and Government > Government Building > Law Enforcement and Public Safety > Rescue Service
        12120: "association_or_organization",  // 63be6904847c3692a84b9bad — Community and Government > Organization > Labor Union
        12121: "non_profit_organization",  // 63be6904847c3692a84b9bae — Community and Government > Organization > LGBTQ Organization
        12122: "apartment_building",  // 4d954b06a243a5684965b473 — Community and Government > Residential Building > Apartment or Condo
        12123: "premise",  // 4bf58dd8d48988d103941735 — Community and Government > Residential Building > Home (private) — Inexact. Might warrant a non-Google category
        12124: "city_hall",  // 52e81612bcbc57f1066b7a38 — Community and Government > Town Hall
        12125: "university",  // 4bf58dd8d48988d1ae941735 — Community and Government > Education > College and University > University
        13000: "restaurant",  // 63be6904847c3692a84b9bb5 — Dining and Drinking
        13001: "bagel_shop",  // 4bf58dd8d48988d179941735 — Dining and Drinking > Bagel Shop
        13002: "bakery",  // 4bf58dd8d48988d16a941735 — Dining and Drinking > Bakery
        13003: "bar",  // 4bf58dd8d48988d116941735 — Dining and Drinking > Bar
        13004: "bar",  // 4bf58dd8d48988d1ea941735 — Dining and Drinking > Bar > Apres Ski Bar
        13005: "bar",  // 52e81612bcbc57f1066b7a0d — Dining and Drinking > Bar > Beach Bar
        13006: "bar",  // 56aa371ce4b08b9a8d57356c — Dining and Drinking > Bar > Beer Bar
        13007: "beer_garden",  // 4bf58dd8d48988d117941735 — Dining and Drinking > Bar > Beer Garden
        13008: "wine_bar",  // 52e81612bcbc57f1066b7a0e — Dining and Drinking > Bar > Champagne Bar
        13009: "cocktail_bar",  // 4bf58dd8d48988d11e941735 — Dining and Drinking > Bar > Cocktail Bar
        13010: "bar",  // 4bf58dd8d48988d118941735 — Dining and Drinking > Bar > Dive Bar
        13011: "bar",  // 4bf58dd8d48988d1d8941735 — Dining and Drinking > Bar > Gay Bar
        13012: "hookah_bar",  // 4bf58dd8d48988d119941735 — Dining and Drinking > Bar > Hookah Bar
        13013: "bar",  // 4bf58dd8d48988d1d5941735 — Dining and Drinking > Bar > Hotel Bar
        13014: "bar",  // 5f2c40f15b4c177b9a6dc684 — Dining and Drinking > Bar > Ice Bar
        13015: "karaoke",  // 4bf58dd8d48988d120941735 — Dining and Drinking > Bar > Karaoke Bar
        13016: "lounge_bar",  // 4bf58dd8d48988d121941735 — Dining and Drinking > Bar > Lounge
        13017: "lounge_bar",  // 4bf58dd8d48988d1e8931735 — Dining and Drinking > Bar > Piano Bar
        13018: "pub",  // 4bf58dd8d48988d11b941735 — Dining and Drinking > Bar > Pub
        13019: "bar",  // 5f2c224bb6d05514c70440a3 — Dining and Drinking > Bar > Rooftop Bar
        13020: "bar",  // 4bf58dd8d48988d11c941735 — Dining and Drinking > Bar > Sake Bar
        13021: "cocktail_bar",  // 4bf58dd8d48988d1d4941735 — Dining and Drinking > Bar > Speakeasy
        13022: "sports_bar",  // 4bf58dd8d48988d11d941735 — Dining and Drinking > Bar > Sports Bar
        13023: "bar",  // 56aa371be4b08b9a8d57354d — Dining and Drinking > Bar > Tiki Bar
        13024: "bar",  // 4bf58dd8d48988d122941735 — Dining and Drinking > Bar > Whisky Bar
        13025: "wine_bar",  // 4bf58dd8d48988d123941735 — Dining and Drinking > Bar > Wine Bar
        13026: "barbecue_restaurant",  // 4bf58dd8d48988d1df931735 — Dining and Drinking > Restaurant > BBQ Joint
        13027: "bistro",  // 52e81612bcbc57f1066b79f1 — Dining and Drinking > Restaurant > Bistro
        13028: "breakfast_restaurant",  // 4bf58dd8d48988d143941735 — Dining and Drinking > Breakfast Spot
        13029: "brewery",  // 50327c8591d4c4b30a586d5d — Dining and Drinking > Brewery
        13030: "buffet_restaurant",  // 52e81612bcbc57f1066b79f4 — Dining and Drinking > Restaurant > Buffet
        13031: "hamburger_restaurant",  // 4bf58dd8d48988d16c941735 — Dining and Drinking > Restaurant > Burger Joint
        13032: "coffee_shop",  // 63be6904847c3692a84b9bb6 — Dining and Drinking > Cafe, Coffee, and Tea House
        13033: "tea_house",  // 52e81612bcbc57f1066b7a0c — Dining and Drinking > Cafe, Coffee, and Tea House > Bubble Tea Shop
        13034: "cafe",  // 4bf58dd8d48988d16d941735 — Dining and Drinking > Cafe, Coffee, and Tea House > Café
        13035: "coffee_shop",  // 4bf58dd8d48988d1e0931735 — Dining and Drinking > Cafe, Coffee, and Tea House > Coffee Shop
        13036: "tea_house",  // 4bf58dd8d48988d1dc931735 — Dining and Drinking > Cafe, Coffee, and Tea House > Tea Room
        13037: "cafeteria",  // 4bf58dd8d48988d128941735 — Dining and Drinking > Cafeteria
        13038: "brewery",  // 5e189fd6eee47d000759bbfd — Dining and Drinking > Cidery — Inexact
        13039: "deli",  // 4bf58dd8d48988d146941735 — Dining and Drinking > Restaurant > Deli
        13040: "dessert_shop",  // 4bf58dd8d48988d1d0941735 — Dining and Drinking > Dessert Shop
        13041: "restaurant",  // 52e81612bcbc57f1066b79f2 — Dining and Drinking > Creperie — Inexact
        13042: "dessert_shop",  // 4bf58dd8d48988d1bc941735 — Dining and Drinking > Dessert Shop > Cupcake Shop
        13043: "donut_shop",  // 4bf58dd8d48988d148941735 — Dining and Drinking > Donut Shop
        13044: "ice_cream_shop",  // 512e7cae91d4cbb4e5efe0af — Dining and Drinking > Dessert Shop > Frozen Yogurt Shop
        13045: "ice_cream_shop",  // 5f2c407c5b4c177b9a6dc536 — Dining and Drinking > Dessert Shop > Gelato Shop
        13046: "ice_cream_shop",  // 4bf58dd8d48988d1c9941735 — Dining and Drinking > Dessert Shop > Ice Cream Parlor
        13047: "pastry_shop",  // 5744ccdfe4b0c0459246b4e2 — Dining and Drinking > Dessert Shop > Pastry Shop
        13048: "dessert_shop",  // 52e81612bcbc57f1066b7a0a — Dining and Drinking > Dessert Shop > Pie Shop
        13049: "diner",  // 4bf58dd8d48988d147941735 — Dining and Drinking > Restaurant > Diner
        13050: "brewery",  // 4e0e22f5a56208c4ea9a85a0 — Dining and Drinking > Distillery — Inexact
        13051: "fish_and_chips_restaurant",  // 4edd64a0c7ddd24ca188df1a — Dining and Drinking > Restaurant > Fish and Chips Shop
        13052: "food_court",  // 4bf58dd8d48988d120951735 — Dining and Drinking > Food Court
        13053: "snack_bar",  // 56aa371be4b08b9a8d57350b — Dining and Drinking > Food Stand
        13054: "meal_takeaway",  // 4bf58dd8d48988d1cb941735 — Dining and Drinking > Food Truck — Inexact
        13055: "chicken_restaurant",  // 4d4ae6fc7a7b7dea34424761 — Dining and Drinking > Restaurant > Fried Chicken Joint
        13056: "fast_food_restaurant",  // 55d25775498e9f6a0816a37a — Dining and Drinking > Restaurant > Friterie
        13057: "gastropub",  // 4bf58dd8d48988d155941735 — Dining and Drinking > Restaurant > Gastropub
        13058: "hot_dog_restaurant",  // 4bf58dd8d48988d16f941735 — Dining and Drinking > Restaurant > Hot Dog Joint
        13059: "juice_shop",  // 4bf58dd8d48988d112941735 — Dining and Drinking > Juice Bar
        13060: "american_restaurant",  // 4bf58dd8d48988d1bf941735 — Dining and Drinking > Restaurant > Mac and Cheese Joint
        13061: "brewery",  // 5e189d71eee47d000759b7e2 — Dining and Drinking > Meadery — Inexact
        13062: "market",  // 53e510b7498ebcb1801b55d4 — Dining and Drinking > Night Market
        13063: "cat_cafe",  // 56aa371be4b08b9a8d573508 — Dining and Drinking > Cafe, Coffee, and Tea House > Pet Café — Inexact
        13064: "pizza_restaurant",  // 4bf58dd8d48988d1ca941735 — Dining and Drinking > Restaurant > Pizzeria
        13065: "restaurant",  // 4d4b7105d754a06374d81259 — Dining and Drinking > Restaurant
        13066: "afghani_restaurant",  // 503288ae91d4c4b30a586d67 — Dining and Drinking > Restaurant > Afghan Restaurant
        13067: "african_restaurant",  // 4bf58dd8d48988d1c8941735 — Dining and Drinking > Restaurant > African Restaurant
        13068: "american_restaurant",  // 4bf58dd8d48988d14e941735 — Dining and Drinking > Restaurant > American Restaurant
        13069: "latin_american_restaurant",  // 4bf58dd8d48988d152941735 — Dining and Drinking > Restaurant > Latin American Restaurant > Arepa Restaurant
        13070: "argentinian_restaurant",  // 4bf58dd8d48988d107941735 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Argentinian Restaurant
        13071: "restaurant",  // 5f2c2b7db6d05514c7044837 — Dining and Drinking > Restaurant > Armenian Restaurant
        13072: "asian_restaurant",  // 4bf58dd8d48988d142941735 — Dining and Drinking > Restaurant > Asian Restaurant
        13073: "australian_restaurant",  // 4bf58dd8d48988d169941735 — Dining and Drinking > Restaurant > Australian Restaurant
        13074: "austrian_restaurant",  // 52e81612bcbc57f1066b7a01 — Dining and Drinking > Restaurant > Austrian Restaurant
        13075: "bangladeshi_restaurant",  // 5e179ee74ae8e90006e9a746 — Dining and Drinking > Restaurant > Bangladeshi Restaurant
        13076: "eastern_european_restaurant",  // 52e928d0bcbc57f1066b7e97 — Dining and Drinking > Restaurant > Eastern European Restaurant > Belarusian Restaurant
        13077: "belgian_restaurant",  // 52e81612bcbc57f1066b7a02 — Dining and Drinking > Restaurant > Belgian Restaurant
        13078: "eastern_european_restaurant",  // 58daa1558bbb0b01f18ec1ee — Dining and Drinking > Restaurant > Eastern European Restaurant > Bosnian Restaurant
        13079: "brazilian_restaurant",  // 4bf58dd8d48988d16b941735 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant
        13080: "acai_shop",  // 5294c7523cf9994f4e043a62 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Acai House
        13081: "brazilian_restaurant",  // 52939ae13cf9994f4e043a3b — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Baiano Restaurant
        13082: "brazilian_restaurant",  // 52939a9e3cf9994f4e043a36 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Central Brazilian Restaurant
        13083: "brazilian_restaurant",  // 52939a643cf9994f4e043a33 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Churrascaria
        13084: "brazilian_restaurant",  // 5294c55c3cf9994f4e043a61 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Empada House
        13085: "brazilian_restaurant",  // 52939af83cf9994f4e043a3d — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Goiano Restaurant
        13086: "brazilian_restaurant",  // 52939aed3cf9994f4e043a3c — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Mineiro Restaurant
        13087: "brazilian_restaurant",  // 52939aae3cf9994f4e043a37 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Northeastern Brazilian Restaurant
        13088: "brazilian_restaurant",  // 52939ab93cf9994f4e043a38 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Northern Brazilian Restaurant
        13089: "brazilian_restaurant",  // 5294cbda3cf9994f4e043a63 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Pastelaria
        13090: "brazilian_restaurant",  // 52939ac53cf9994f4e043a39 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Southeastern Brazilian Restaurant
        13091: "brazilian_restaurant",  // 52939ad03cf9994f4e043a3a — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Southern Brazilian Restaurant
        13092: "brazilian_restaurant",  // 52939a7d3cf9994f4e043a34 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Tapiocaria
        13093: "eastern_european_restaurant",  // 56aa371be4b08b9a8d5734f3 — Dining and Drinking > Restaurant > Eastern European Restaurant > Bulgarian Restaurant
        13094: "burmese_restaurant",  // 56aa371be4b08b9a8d573568 — Dining and Drinking > Restaurant > Asian Restaurant > Burmese Restaurant
        13095: "cajun_restaurant",  // 4bf58dd8d48988d17a941735 — Dining and Drinking > Restaurant > Cajun and Creole Restaurant
        13096: "cambodian_restaurant",  // 52e81612bcbc57f1066b7a03 — Dining and Drinking > Restaurant > Asian Restaurant > Cambodian Restaurant
        13097: "caribbean_restaurant",  // 4bf58dd8d48988d144941735 — Dining and Drinking > Restaurant > Caribbean Restaurant
        13098: "restaurant",  // 5293a7d53cf9994f4e043a45 — Dining and Drinking > Restaurant > Caucasian Restaurant
        13099: "chinese_restaurant",  // 4bf58dd8d48988d145941735 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant
        13100: "chinese_restaurant",  // 52af3a5e3cf9994f4e043bea — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Anhui Restaurant
        13101: "chinese_restaurant",  // 52af3a723cf9994f4e043bec — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Beijing Restaurant
        13102: "cantonese_restaurant",  // 52af3a7c3cf9994f4e043bed — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Cantonese Restaurant
        13103: "chinese_restaurant",  // 58daa1558bbb0b01f18ec1d3 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Cha Chaan Teng
        13104: "chinese_restaurant",  // 52af3a673cf9994f4e043beb — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Chinese Aristocrat Restaurant
        13105: "chinese_restaurant",  // 52af3a903cf9994f4e043bee — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Chinese Breakfast Restaurant
        13106: "dim_sum_restaurant",  // 4bf58dd8d48988d1f5931735 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Dim Sum Restaurant
        13107: "chinese_restaurant",  // 52af3a9f3cf9994f4e043bef — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Dongbei Restaurant
        13108: "chinese_restaurant",  // 52af3aaa3cf9994f4e043bf0 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Fujian Restaurant
        13109: "chinese_restaurant",  // 52af3ab53cf9994f4e043bf1 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Guizhou Restaurant
        13110: "chinese_restaurant",  // 52af3abe3cf9994f4e043bf2 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hainan Restaurant
        13111: "chinese_restaurant",  // 52af3ac83cf9994f4e043bf3 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hakka Restaurant
        13112: "chinese_restaurant",  // 52af3ad23cf9994f4e043bf4 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Henan Restaurant
        13113: "chinese_restaurant",  // 52af3add3cf9994f4e043bf5 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hong Kong Restaurant
        13114: "chinese_restaurant",  // 52af3af23cf9994f4e043bf7 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Huaiyang Restaurant
        13115: "chinese_restaurant",  // 52af3ae63cf9994f4e043bf6 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hubei Restaurant
        13116: "chinese_restaurant",  // 52af3afc3cf9994f4e043bf8 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hunan Restaurant
        13117: "chinese_restaurant",  // 52af3b053cf9994f4e043bf9 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Imperial Restaurant
        13118: "chinese_restaurant",  // 52af3b213cf9994f4e043bfa — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Jiangsu Restaurant
        13119: "chinese_restaurant",  // 52af3b293cf9994f4e043bfb — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Jiangxi Restaurant
        13120: "chinese_restaurant",  // 52af3b343cf9994f4e043bfc — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Macanese Restaurant
        13121: "chinese_restaurant",  // 52af3b3b3cf9994f4e043bfd — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Manchu Restaurant
        13122: "chinese_restaurant",  // 52af3b463cf9994f4e043bfe — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Peking Duck Restaurant
        13123: "chinese_restaurant",  // 52af3b633cf9994f4e043c01 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Shaanxi Restaurant
        13124: "chinese_restaurant",  // 52af3b513cf9994f4e043bff — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Shandong Restaurant
        13125: "chinese_restaurant",  // 52af3b593cf9994f4e043c00 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Shanghai Restaurant
        13126: "chinese_restaurant",  // 52af3b6e3cf9994f4e043c02 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Shanxi Restaurant
        13127: "chinese_restaurant",  // 52af3b773cf9994f4e043c03 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Szechuan Restaurant
        13128: "taiwanese_restaurant",  // 52af3b813cf9994f4e043c04 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Taiwanese Restaurant
        13129: "chinese_restaurant",  // 52af3b893cf9994f4e043c05 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Tianjin Restaurant
        13130: "chinese_restaurant",  // 52af3b913cf9994f4e043c06 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Xinjiang Restaurant
        13131: "chinese_restaurant",  // 52af3b9a3cf9994f4e043c07 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Yunnan Restaurant
        13132: "chinese_restaurant",  // 52af3ba23cf9994f4e043c08 — Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Zhejiang Restaurant
        13133: "colombian_restaurant",  // 58daa1558bbb0b01f18ec1f4 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Colombian Restaurant
        13134: "american_restaurant",  // 52e81612bcbc57f1066b7a00 — Dining and Drinking > Restaurant > Comfort Food Restaurant
        13135: "cuban_restaurant",  // 4bf58dd8d48988d154941735 — Dining and Drinking > Restaurant > Caribbean Restaurant > Cuban Restaurant
        13136: "czech_restaurant",  // 52f2ae52bcbc57f1066b8b81 — Dining and Drinking > Restaurant > Czech Restaurant
        13137: "dumpling_restaurant",  // 4bf58dd8d48988d108941735 — Dining and Drinking > Restaurant > Dumpling Restaurant
        13138: "dutch_restaurant",  // 5744ccdfe4b0c0459246b4d0 — Dining and Drinking > Restaurant > Dutch Restaurant
        13139: "eastern_european_restaurant",  // 4bf58dd8d48988d109941735 — Dining and Drinking > Restaurant > Eastern European Restaurant
        13140: "middle_eastern_restaurant",  // 5bae9231bedf3950379f89e1 — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Egyptian Restaurant
        13141: "latin_american_restaurant",  // 52939a8c3cf9994f4e043a35 — Dining and Drinking > Restaurant > Latin American Restaurant > Empanada Restaurant
        13142: "british_restaurant",  // 52e81612bcbc57f1066b7a05 — Dining and Drinking > Restaurant > English Restaurant
        13143: "ethiopian_restaurant",  // 4bf58dd8d48988d10a941735 — Dining and Drinking > Restaurant > African Restaurant > Ethiopian Restaurant
        13144: "falafel_restaurant",  // 4bf58dd8d48988d10b941735 — Dining and Drinking > Restaurant > Falafel Restaurant
        13145: "fast_food_restaurant",  // 4bf58dd8d48988d16e941735 — Dining and Drinking > Restaurant > Fast Food Restaurant
        13146: "filipino_restaurant",  // 4eb1bd1c3b7b55596b4a748f — Dining and Drinking > Restaurant > Asian Restaurant > Filipino Restaurant
        13147: "fondue_restaurant",  // 52e81612bcbc57f1066b7a09 — Dining and Drinking > Restaurant > Fondue Restaurant
        13148: "french_restaurant",  // 4bf58dd8d48988d10c941735 — Dining and Drinking > Restaurant > French Restaurant
        13149: "french_restaurant",  // 57558b36e4b065ecebd306b6 — Dining and Drinking > Restaurant > French Restaurant > Alsatian Restaurant
        13150: "french_restaurant",  // 57558b36e4b065ecebd306b8 — Dining and Drinking > Restaurant > French Restaurant > Auvergne Restaurant
        13151: "basque_restaurant",  // 57558b36e4b065ecebd306bc — Dining and Drinking > Restaurant > French Restaurant > Basque Restaurant
        13152: "french_restaurant",  // 57558b36e4b065ecebd306b0 — Dining and Drinking > Restaurant > French Restaurant > Brasserie
        13153: "french_restaurant",  // 57558b36e4b065ecebd306c5 — Dining and Drinking > Restaurant > French Restaurant > Breton Restaurant
        13154: "french_restaurant",  // 57558b36e4b065ecebd306c0 — Dining and Drinking > Restaurant > French Restaurant > Burgundian Restaurant
        13155: "french_restaurant",  // 57558b36e4b065ecebd306cb — Dining and Drinking > Restaurant > French Restaurant > Catalan Restaurant
        13156: "french_restaurant",  // 57558b36e4b065ecebd306ce — Dining and Drinking > Restaurant > French Restaurant > Ch'ti Restaurant
        13157: "french_restaurant",  // 57558b36e4b065ecebd306d1 — Dining and Drinking > Restaurant > French Restaurant > Corsican Restaurant
        13158: "french_restaurant",  // 57558b36e4b065ecebd306b4 — Dining and Drinking > Restaurant > French Restaurant > Estaminet
        13159: "french_restaurant",  // 57558b36e4b065ecebd306b2 — Dining and Drinking > Restaurant > French Restaurant > Labour Canteen
        13160: "french_restaurant",  // 57558b35e4b065ecebd306ad — Dining and Drinking > Restaurant > French Restaurant > Lyonese Bouchon
        13161: "french_restaurant",  // 57558b36e4b065ecebd306d4 — Dining and Drinking > Restaurant > French Restaurant > Norman Restaurant
        13162: "french_restaurant",  // 57558b36e4b065ecebd306d7 — Dining and Drinking > Restaurant > French Restaurant > Provençal Restaurant
        13163: "french_restaurant",  // 57558b36e4b065ecebd306da — Dining and Drinking > Restaurant > French Restaurant > Savoyard Restaurant
        13164: "french_restaurant",  // 57558b36e4b065ecebd306ba — Dining and Drinking > Restaurant > French Restaurant > Southwestern French Restaurant
        13165: "german_restaurant",  // 4bf58dd8d48988d10d941735 — Dining and Drinking > Restaurant > German Restaurant
        13166: "german_restaurant",  // 56aa371ce4b08b9a8d573583 — Dining and Drinking > Restaurant > German Restaurant > Apple Wine Pub
        13167: "bavarian_restaurant",  // 56aa371ce4b08b9a8d573572 — Dining and Drinking > Restaurant > German Restaurant > Bavarian Restaurant
        13168: "german_restaurant",  // 56aa371ce4b08b9a8d57358e — Dining and Drinking > Restaurant > German Restaurant > Bratwurst Joint
        13169: "german_restaurant",  // 56aa371ce4b08b9a8d57358b — Dining and Drinking > Restaurant > German Restaurant > Currywurst Joint
        13170: "german_restaurant",  // 56aa371ce4b08b9a8d573574 — Dining and Drinking > Restaurant > German Restaurant > Franconian Restaurant
        13171: "german_restaurant",  // 56aa371ce4b08b9a8d573592 — Dining and Drinking > Restaurant > German Restaurant > German Pop-Up Restaurant
        13172: "german_restaurant",  // 56aa371ce4b08b9a8d573578 — Dining and Drinking > Restaurant > German Restaurant > Palatine Restaurant
        13173: "german_restaurant",  // 56aa371ce4b08b9a8d57357b — Dining and Drinking > Restaurant > German Restaurant > Rhenisch Restaurant
        13174: "german_restaurant",  // 56aa371ce4b08b9a8d573587 — Dining and Drinking > Restaurant > German Restaurant > Schnitzel Restaurant
        13175: "german_restaurant",  // 56aa371ce4b08b9a8d57357f — Dining and Drinking > Restaurant > German Restaurant > Silesian Restaurant
        13176: "german_restaurant",  // 56aa371ce4b08b9a8d573576 — Dining and Drinking > Restaurant > German Restaurant > Swabian Restaurant
        13177: "greek_restaurant",  // 4bf58dd8d48988d10e941735 — Dining and Drinking > Restaurant > Greek Restaurant
        13178: "greek_restaurant",  // 53d6c1b0e4b02351e88a83e8 — Dining and Drinking > Restaurant > Greek Restaurant > Bougatsa Shop
        13179: "greek_restaurant",  // 53d6c1b0e4b02351e88a83e2 — Dining and Drinking > Restaurant > Greek Restaurant > Cretan Restaurant
        13180: "greek_restaurant",  // 53d6c1b0e4b02351e88a83d8 — Dining and Drinking > Restaurant > Greek Restaurant > Fish Taverna
        13181: "greek_restaurant",  // 53d6c1b0e4b02351e88a83d6 — Dining and Drinking > Restaurant > Greek Restaurant > Grilled Meat Restaurant
        13182: "greek_restaurant",  // 53d6c1b0e4b02351e88a83e6 — Dining and Drinking > Restaurant > Greek Restaurant > Kafenio
        13183: "greek_restaurant",  // 53d6c1b0e4b02351e88a83e4 — Dining and Drinking > Restaurant > Greek Restaurant > Magirio
        13184: "greek_restaurant",  // 53d6c1b0e4b02351e88a83da — Dining and Drinking > Restaurant > Greek Restaurant > Meze Restaurant
        13185: "greek_restaurant",  // 53d6c1b0e4b02351e88a83d4 — Dining and Drinking > Restaurant > Greek Restaurant > Modern Greek Restaurant
        13186: "greek_restaurant",  // 53d6c1b0e4b02351e88a83dc — Dining and Drinking > Restaurant > Greek Restaurant > Ouzeri
        13187: "greek_restaurant",  // 53d6c1b0e4b02351e88a83e0 — Dining and Drinking > Restaurant > Greek Restaurant > Patsa Restaurant
        13188: "greek_restaurant",  // 52e81612bcbc57f1066b79f3 — Dining and Drinking > Restaurant > Greek Restaurant > Souvlaki Shop
        13189: "greek_restaurant",  // 53d6c1b0e4b02351e88a83d2 — Dining and Drinking > Restaurant > Greek Restaurant > Taverna
        13190: "greek_restaurant",  // 53d6c1b0e4b02351e88a83de — Dining and Drinking > Restaurant > Greek Restaurant > Tsipouro Restaurant
        13191: "halal_restaurant",  // 52e81612bcbc57f1066b79ff — Dining and Drinking > Restaurant > Halal Restaurant
        13192: "hawaiian_restaurant",  // 52e81612bcbc57f1066b79fe — Dining and Drinking > Restaurant > Hawaiian Restaurant
        13193: "hawaiian_restaurant",  // 5bae9231bedf3950379f89d4 — Dining and Drinking > Restaurant > Hawaiian Restaurant > Poke Restaurant
        13194: "asian_restaurant",  // 52e81612bcbc57f1066b79fb — Dining and Drinking > Restaurant > Asian Restaurant > Himalayan Restaurant
        13195: "latin_american_restaurant",  // 5f2c32587ff30c0d7ac09638 — Dining and Drinking > Restaurant > Latin American Restaurant > Honduran Restaurant
        13196: "hot_pot_restaurant",  // 52af0bd33cf9994f4e043bdd — Dining and Drinking > Restaurant > Asian Restaurant > Hotpot Restaurant
        13197: "hungarian_restaurant",  // 52e81612bcbc57f1066b79fa — Dining and Drinking > Restaurant > Hungarian Restaurant
        13198: "asian_fusion_restaurant",  // 54135bf5e4b08f3d2429dfdf — Dining and Drinking > Restaurant > Indian Chinese Restaurant — Inexact
        13199: "indian_restaurant",  // 4bf58dd8d48988d10f941735 — Dining and Drinking > Restaurant > Indian Restaurant
        13200: "indian_restaurant",  // 54135bf5e4b08f3d2429dfe5 — Dining and Drinking > Restaurant > Indian Restaurant > Andhra Restaurant
        13201: "indian_restaurant",  // 54135bf5e4b08f3d2429dff3 — Dining and Drinking > Restaurant > Indian Restaurant > Awadhi Restaurant
        13202: "indian_restaurant",  // 54135bf5e4b08f3d2429dff5 — Dining and Drinking > Restaurant > Indian Restaurant > Bengali Restaurant
        13203: "indian_restaurant",  // 54135bf5e4b08f3d2429dfe2 — Dining and Drinking > Restaurant > Indian Restaurant > Chaat Place
        13204: "indian_restaurant",  // 54135bf5e4b08f3d2429dff2 — Dining and Drinking > Restaurant > Indian Restaurant > Chettinad Restaurant
        13205: "indian_restaurant",  // 54135bf5e4b08f3d2429dfe1 — Dining and Drinking > Restaurant > Indian Restaurant > Dhaba
        13206: "south_indian_restaurant",  // 54135bf5e4b08f3d2429dfe3 — Dining and Drinking > Restaurant > Indian Restaurant > Dosa Place
        13207: "indian_restaurant",  // 54135bf5e4b08f3d2429dfe8 — Dining and Drinking > Restaurant > Indian Restaurant > Goan Restaurant
        13208: "indian_restaurant",  // 54135bf5e4b08f3d2429dfe9 — Dining and Drinking > Restaurant > Indian Restaurant > Gujarati Restaurant
        13209: "indian_restaurant",  // 54135bf5e4b08f3d2429dfe6 — Dining and Drinking > Restaurant > Indian Restaurant > Hyderabadi Restaurant
        13210: "indian_restaurant",  // 54135bf5e4b08f3d2429dfe4 — Dining and Drinking > Restaurant > Indian Restaurant > Indian Sweet Shop
        13211: "indian_restaurant",  // 54135bf5e4b08f3d2429dfe7 — Dining and Drinking > Restaurant > Indian Restaurant > Irani Cafe
        13212: "indian_restaurant",  // 54135bf5e4b08f3d2429dfea — Dining and Drinking > Restaurant > Indian Restaurant > Jain Restaurant
        13213: "south_indian_restaurant",  // 54135bf5e4b08f3d2429dfeb — Dining and Drinking > Restaurant > Indian Restaurant > Karnataka Restaurant
        13214: "south_indian_restaurant",  // 54135bf5e4b08f3d2429dfed — Dining and Drinking > Restaurant > Indian Restaurant > Kerala Restaurant
        13215: "indian_restaurant",  // 54135bf5e4b08f3d2429dfee — Dining and Drinking > Restaurant > Indian Restaurant > Maharashtrian Restaurant
        13216: "north_indian_restaurant",  // 54135bf5e4b08f3d2429dff4 — Dining and Drinking > Restaurant > Indian Restaurant > Mughlai Restaurant
        13217: "indian_restaurant",  // 54135bf5e4b08f3d2429dfe0 — Dining and Drinking > Restaurant > Indian Restaurant > Multicuisine Indian Restaurant
        13218: "north_indian_restaurant",  // 54135bf5e4b08f3d2429dfdd — Dining and Drinking > Restaurant > Indian Restaurant > North Indian Restaurant
        13219: "indian_restaurant",  // 54135bf5e4b08f3d2429dff6 — Dining and Drinking > Restaurant > Indian Restaurant > Northeast Indian Restaurant
        13220: "indian_restaurant",  // 54135bf5e4b08f3d2429dfef — Dining and Drinking > Restaurant > Indian Restaurant > Parsi Restaurant
        13221: "north_indian_restaurant",  // 54135bf5e4b08f3d2429dff0 — Dining and Drinking > Restaurant > Indian Restaurant > Punjabi Restaurant
        13222: "indian_restaurant",  // 54135bf5e4b08f3d2429dff1 — Dining and Drinking > Restaurant > Indian Restaurant > Rajasthani Restaurant
        13223: "south_indian_restaurant",  // 54135bf5e4b08f3d2429dfde — Dining and Drinking > Restaurant > Indian Restaurant > South Indian Restaurant
        13224: "south_indian_restaurant",  // 54135bf5e4b08f3d2429dfec — Dining and Drinking > Restaurant > Indian Restaurant > Udupi Restaurant
        13225: "indonesian_restaurant",  // 4deefc054765f83613cdba6f — Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant
        13226: "indonesian_restaurant",  // 52960eda3cf9994f4e043ac9 — Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Acehnese Restaurant
        13227: "indonesian_restaurant",  // 52960eda3cf9994f4e043acb — Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Balinese Restaurant
        13228: "indonesian_restaurant",  // 52960eda3cf9994f4e043aca — Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Betawinese Restaurant
        13229: "indonesian_restaurant",  // 52960eda3cf9994f4e043acc — Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Indonesian Meatball Restaurant
        13230: "indonesian_restaurant",  // 52960eda3cf9994f4e043ac7 — Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Javanese Restaurant
        13231: "indonesian_restaurant",  // 52960eda3cf9994f4e043ac8 — Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Manadonese Restaurant
        13232: "indonesian_restaurant",  // 52960eda3cf9994f4e043ac5 — Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Padangnese Restaurant
        13233: "indonesian_restaurant",  // 52960eda3cf9994f4e043ac6 — Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Sundanese Restaurant
        13234: "middle_eastern_restaurant",  // 5bae9231bedf3950379f89e7 — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Iraqi Restaurant
        13235: "israeli_restaurant",  // 56aa371be4b08b9a8d573529 — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Israeli Restaurant
        13236: "italian_restaurant",  // 4bf58dd8d48988d110941735 — Dining and Drinking > Restaurant > Italian Restaurant
        13237: "italian_restaurant",  // 55a5a1ebe4b013909087cbb6 — Dining and Drinking > Restaurant > Italian Restaurant > Abruzzo Restaurant
        13238: "italian_restaurant",  // 55a5a1ebe4b013909087cb7c — Dining and Drinking > Restaurant > Italian Restaurant > Agriturismo
        13239: "italian_restaurant",  // 55a5a1ebe4b013909087cba7 — Dining and Drinking > Restaurant > Italian Restaurant > Aosta Restaurant
        13240: "italian_restaurant",  // 55a5a1ebe4b013909087cba1 — Dining and Drinking > Restaurant > Italian Restaurant > Basilicata Restaurant
        13241: "italian_restaurant",  // 55a5a1ebe4b013909087cba4 — Dining and Drinking > Restaurant > Italian Restaurant > Calabria Restaurant
        13242: "italian_restaurant",  // 55a5a1ebe4b013909087cb95 — Dining and Drinking > Restaurant > Italian Restaurant > Campanian Restaurant
        13243: "italian_restaurant",  // 55a5a1ebe4b013909087cb89 — Dining and Drinking > Restaurant > Italian Restaurant > Emilia Restaurant
        13244: "italian_restaurant",  // 55a5a1ebe4b013909087cb9b — Dining and Drinking > Restaurant > Italian Restaurant > Friuli Restaurant
        13245: "italian_restaurant",  // 55a5a1ebe4b013909087cb98 — Dining and Drinking > Restaurant > Italian Restaurant > Ligurian Restaurant
        13246: "italian_restaurant",  // 55a5a1ebe4b013909087cbbf — Dining and Drinking > Restaurant > Italian Restaurant > Lombard Restaurant
        13247: "italian_restaurant",  // 55a5a1ebe4b013909087cb79 — Dining and Drinking > Restaurant > Italian Restaurant > Malga
        13248: "italian_restaurant",  // 55a5a1ebe4b013909087cbb0 — Dining and Drinking > Restaurant > Italian Restaurant > Marche Restaurant
        13249: "italian_restaurant",  // 55a5a1ebe4b013909087cbb3 — Dining and Drinking > Restaurant > Italian Restaurant > Molise Restaurant
        13250: "italian_restaurant",  // 55a5a1ebe4b013909087cb74 — Dining and Drinking > Restaurant > Italian Restaurant > Piadineria
        13251: "italian_restaurant",  // 55a5a1ebe4b013909087cbaa — Dining and Drinking > Restaurant > Italian Restaurant > Piedmontese Restaurant
        13252: "italian_restaurant",  // 55a5a1ebe4b013909087cb83 — Dining and Drinking > Restaurant > Italian Restaurant > Puglia Restaurant
        13253: "italian_restaurant",  // 55a5a1ebe4b013909087cb8c — Dining and Drinking > Restaurant > Italian Restaurant > Romagna Restaurant
        13254: "italian_restaurant",  // 55a5a1ebe4b013909087cb92 — Dining and Drinking > Restaurant > Italian Restaurant > Roman Restaurant
        13255: "italian_restaurant",  // 55a5a1ebe4b013909087cb8f — Dining and Drinking > Restaurant > Italian Restaurant > Sardinian Restaurant
        13256: "italian_restaurant",  // 55a5a1ebe4b013909087cb86 — Dining and Drinking > Restaurant > Italian Restaurant > Sicilian Restaurant
        13257: "italian_restaurant",  // 55a5a1ebe4b013909087cbb9 — Dining and Drinking > Restaurant > Italian Restaurant > South Tyrolean Restaurant
        13258: "italian_restaurant",  // 55a5a1ebe4b013909087cb7f — Dining and Drinking > Restaurant > Italian Restaurant > Trattoria
        13259: "italian_restaurant",  // 55a5a1ebe4b013909087cbbc — Dining and Drinking > Restaurant > Italian Restaurant > Trentino Restaurant
        13260: "italian_restaurant",  // 55a5a1ebe4b013909087cb9e — Dining and Drinking > Restaurant > Italian Restaurant > Tuscan Restaurant
        13261: "italian_restaurant",  // 55a5a1ebe4b013909087cbc2 — Dining and Drinking > Restaurant > Italian Restaurant > Umbrian Restaurant
        13262: "italian_restaurant",  // 55a5a1ebe4b013909087cbad — Dining and Drinking > Restaurant > Italian Restaurant > Veneto Restaurant
        13263: "japanese_restaurant",  // 4bf58dd8d48988d111941735 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant
        13264: "japanese_restaurant",  // 55a59bace4b013909087cb0c — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Donburi Restaurant
        13265: "japanese_curry_restaurant",  // 55a59bace4b013909087cb30 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Japanese Curry Restaurant
        13266: "japanese_restaurant",  // 5f2c2436b6d05514c704433e — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Japanese Family Restaurant
        13267: "japanese_restaurant",  // 55a59bace4b013909087cb21 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Kaiseki Restaurant
        13268: "japanese_restaurant",  // 55a59bace4b013909087cb06 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Kushikatsu Restaurant
        13269: "japanese_restaurant",  // 55a59bace4b013909087cb1b — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Monjayaki Restaurant
        13270: "japanese_restaurant",  // 55a59bace4b013909087cb1e — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Nabe Restaurant
        13271: "japanese_restaurant",  // 55a59bace4b013909087cb18 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Okonomiyaki Restaurant
        13272: "ramen_restaurant",  // 55a59bace4b013909087cb24 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Ramen Restaurant
        13273: "japanese_restaurant",  // 55a59bace4b013909087cb15 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Shabu-Shabu Restaurant
        13274: "japanese_restaurant",  // 55a59bace4b013909087cb27 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Soba Restaurant
        13275: "japanese_restaurant",  // 55a59bace4b013909087cb12 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Sukiyaki Restaurant
        13276: "sushi_restaurant",  // 4bf58dd8d48988d1d2941735 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Sushi Restaurant
        13277: "japanese_restaurant",  // 55a59bace4b013909087cb2d — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Takoyaki Place
        13278: "japanese_restaurant",  // 5f2c239eb6d05514c70441ee — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Teishoku Restaurant
        13279: "japanese_restaurant",  // 55a59a31e4b013909087cb00 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Tempura Restaurant
        13280: "tonkatsu_restaurant",  // 55a59af1e4b013909087cb03 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Tonkatsu Restaurant
        13281: "japanese_restaurant",  // 55a59bace4b013909087cb2a — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Udon Restaurant
        13282: "japanese_restaurant",  // 55a59bace4b013909087cb0f — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Unagi Restaurant
        13283: "japanese_restaurant",  // 55a59bace4b013909087cb33 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Wagashi Place
        13284: "yakitori_restaurant",  // 55a59bace4b013909087cb09 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Yakitori Restaurant
        13285: "japanese_restaurant",  // 55a59bace4b013909087cb36 — Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Yoshoku Restaurant
        13286: "restaurant",  // 52e81612bcbc57f1066b79fd — Dining and Drinking > Restaurant > Jewish Restaurant
        13287: "restaurant",  // 52e81612bcbc57f1066b79fc — Dining and Drinking > Restaurant > Jewish Restaurant > Kosher Restaurant — REVIEW
        13288: "kebab_shop",  // 5283c7b4e4b094cb91ec88d7 — Dining and Drinking > Restaurant > Kebab Restaurant
        13289: "korean_restaurant",  // 4bf58dd8d48988d113941735 — Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant
        13290: "korean_restaurant",  // 56aa371be4b08b9a8d5734e4 — Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Bossam/Jokbal Restaurant
        13291: "korean_restaurant",  // 56aa371be4b08b9a8d5734f0 — Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Bunsik Restaurant
        13292: "korean_restaurant",  // 56aa371be4b08b9a8d5734e7 — Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Gukbap Restaurant
        13293: "korean_restaurant",  // 56aa371be4b08b9a8d5734ed — Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Janguh Restaurant
        13294: "korean_barbecue_restaurant",  // 5f2c3f6b5b4c177b9a6dc388 — Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Korean BBQ Restaurant
        13295: "korean_restaurant",  // 56aa371be4b08b9a8d5734ea — Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Samgyetang Restaurant
        13296: "middle_eastern_restaurant",  // 5744ccdfe4b0c0459246b4ca — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Kurdish Restaurant
        13297: "latin_american_restaurant",  // 4bf58dd8d48988d1be941735 — Dining and Drinking > Restaurant > Latin American Restaurant
        13298: "lebanese_restaurant",  // 58daa1558bbb0b01f18ec1cd — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Lebanese Restaurant
        13299: "malaysian_restaurant",  // 4bf58dd8d48988d156941735 — Dining and Drinking > Restaurant > Asian Restaurant > Malay Restaurant
        13300: "malaysian_restaurant",  // 5ae9595eb77c77002c2f9f26 — Dining and Drinking > Restaurant > Asian Restaurant > Malay Restaurant > Mamak Restaurant
        13301: "african_restaurant",  // 5f2c344a5b4c177b9a6dc011 — Dining and Drinking > Restaurant > African Restaurant > Mauritian Restaurant
        13302: "mediterranean_restaurant",  // 4bf58dd8d48988d1c0941735 — Dining and Drinking > Restaurant > Mediterranean Restaurant
        13303: "mexican_restaurant",  // 4bf58dd8d48988d1c1941735 — Dining and Drinking > Restaurant > Mexican Restaurant
        13304: "mexican_restaurant",  // 58daa1558bbb0b01f18ec1d9 — Dining and Drinking > Restaurant > Mexican Restaurant > Botanero
        13305: "burrito_restaurant",  // 4bf58dd8d48988d153941735 — Dining and Drinking > Restaurant > Mexican Restaurant > Burrito Restaurant
        13306: "taco_restaurant",  // 4bf58dd8d48988d151941735 — Dining and Drinking > Restaurant > Mexican Restaurant > Taco Restaurant
        13307: "tex_mex_restaurant",  // 56aa371ae4b08b9a8d5734ba — Dining and Drinking > Restaurant > Mexican Restaurant > Tex-Mex Restaurant
        13308: "mexican_restaurant",  // 5744ccdfe4b0c0459246b4d3 — Dining and Drinking > Restaurant > Mexican Restaurant > Yucatecan Restaurant
        13309: "middle_eastern_restaurant",  // 4bf58dd8d48988d115941735 — Dining and Drinking > Restaurant > Middle Eastern Restaurant
        13310: "european_restaurant",  // 52e81612bcbc57f1066b79f9 — Dining and Drinking > Restaurant > Modern European Restaurant
        13311: "fine_dining_restaurant",  // 4bf58dd8d48988d1c2941735 — Dining and Drinking > Restaurant > Molecular Gastronomy Restaurant
        13312: "mongolian_barbecue_restaurant",  // 4eb1d5724b900d56c88a45fe — Dining and Drinking > Restaurant > Asian Restaurant > Mongolian Restaurant
        13313: "moroccan_restaurant",  // 4bf58dd8d48988d1c3941735 — Dining and Drinking > Restaurant > Moroccan Restaurant
        13314: "american_restaurant",  // 4bf58dd8d48988d157941735 — Dining and Drinking > Restaurant > American Restaurant > New American Restaurant
        13315: "noodle_shop",  // 4bf58dd8d48988d1d1941735 — Dining and Drinking > Restaurant > Asian Restaurant > Noodle Restaurant
        13316: "pakistani_restaurant",  // 52e81612bcbc57f1066b79f8 — Dining and Drinking > Restaurant > Pakistani Restaurant
        13317: "persian_restaurant",  // 52e81612bcbc57f1066b79f7 — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant
        13318: "persian_restaurant",  // 58daa1558bbb0b01f18ec1bc — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Ash and Haleem Place
        13319: "persian_restaurant",  // 58daa1558bbb0b01f18ec1c0 — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Dizi Place
        13320: "persian_restaurant",  // 58daa1558bbb0b01f18ec1c4 — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Gilaki Restaurant
        13321: "persian_restaurant",  // 58daa1558bbb0b01f18ec1c7 — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Jegaraki
        13322: "peruvian_restaurant",  // 4eb1bfa43b7b52c0e1adc2e8 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Peruvian Restaurant
        13323: "peruvian_restaurant",  // 5f2c1c31b6d05514c704334c — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Peruvian Restaurant > Peruvian Roast Chicken Joint
        13324: "polish_restaurant",  // 52e81612bcbc57f1066b7a04 — Dining and Drinking > Restaurant > Polish Restaurant
        13325: "portuguese_restaurant",  // 4def73e84765ae376e57713a — Dining and Drinking > Restaurant > Portuguese Restaurant
        13326: "restaurant",  // 56aa371be4b08b9a8d5734c7 — Dining and Drinking > Restaurant > Poutine Restaurant
        13327: "caribbean_restaurant",  // 5f2c2abab6d05514c70446e4 — Dining and Drinking > Restaurant > Caribbean Restaurant > Puerto Rican Restaurant
        13328: "romanian_restaurant",  // 52960bac3cf9994f4e043ac4 — Dining and Drinking > Restaurant > Eastern European Restaurant > Romanian Restaurant
        13329: "russian_restaurant",  // 5293a7563cf9994f4e043a44 — Dining and Drinking > Restaurant > Russian Restaurant
        13330: "russian_restaurant",  // 52e928d0bcbc57f1066b7e9d — Dining and Drinking > Restaurant > Russian Restaurant > Blini House
        13331: "russian_restaurant",  // 52e928d0bcbc57f1066b7e9c — Dining and Drinking > Restaurant > Russian Restaurant > Pelmeni House
        13332: "salad_shop",  // 4bf58dd8d48988d1bd941735 — Dining and Drinking > Restaurant > Salad Restaurant
        13333: "latin_american_restaurant",  // 5745c7ac498e5d0483112fdb — Dining and Drinking > Restaurant > Latin American Restaurant > Salvadoran Restaurant
        13334: "sandwich_shop",  // 4bf58dd8d48988d1c5941735 — Dining and Drinking > Restaurant > Sandwich Spot
        13335: "indonesian_restaurant",  // 56aa371be4b08b9a8d57350e — Dining and Drinking > Restaurant > Asian Restaurant > Satay Restaurant
        13336: "scandinavian_restaurant",  // 4bf58dd8d48988d1c6941735 — Dining and Drinking > Restaurant > Scandinavian Restaurant
        13337: "british_restaurant",  // 5744ccdde4b0c0459246b4a3 — Dining and Drinking > Restaurant > Scottish Restaurant
        13338: "seafood_restaurant",  // 4bf58dd8d48988d1ce941735 — Dining and Drinking > Restaurant > Seafood Restaurant
        13339: "shawarma_restaurant",  // 5bae9231bedf3950379f89e4 — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Shawarma Restaurant
        13340: "asian_restaurant",  // 5f2c430e5b4c177b9a6dcabd — Dining and Drinking > Restaurant > Asian Restaurant > Singaporean Restaurant
        13341: "eastern_european_restaurant",  // 56aa371be4b08b9a8d57355a — Dining and Drinking > Restaurant > Slovak Restaurant
        13342: "soup_restaurant",  // 4bf58dd8d48988d1dd931735 — Dining and Drinking > Restaurant > Soup Spot
        13343: "south_american_restaurant",  // 4bf58dd8d48988d1cd941735 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant
        13344: "soul_food_restaurant",  // 4bf58dd8d48988d14f941735 — Dining and Drinking > Restaurant > Southern Food Restaurant
        13345: "spanish_restaurant",  // 4bf58dd8d48988d150941735 — Dining and Drinking > Restaurant > Spanish Restaurant
        13346: "spanish_restaurant",  // 4bf58dd8d48988d14d941735 — Dining and Drinking > Restaurant > Spanish Restaurant > Paella Restaurant
        13347: "tapas_restaurant",  // 4bf58dd8d48988d1db931735 — Dining and Drinking > Restaurant > Spanish Restaurant > Tapas Restaurant
        13348: "sri_lankan_restaurant",  // 5413605de4b0ae91d18581a9 — Dining and Drinking > Restaurant > Sri Lankan Restaurant
        13349: "swiss_restaurant",  // 4bf58dd8d48988d158941735 — Dining and Drinking > Restaurant > Swiss Restaurant
        13350: "middle_eastern_restaurant",  // 5bae9231bedf3950379f89da — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Syrian Restaurant
        13351: "eastern_european_restaurant",  // 52e928d0bcbc57f1066b7e98 — Dining and Drinking > Restaurant > Eastern European Restaurant > Tatar Restaurant
        13352: "thai_restaurant",  // 4bf58dd8d48988d149941735 — Dining and Drinking > Restaurant > Asian Restaurant > Thai Restaurant
        13353: "thai_restaurant",  // 56aa371be4b08b9a8d573502 — Dining and Drinking > Restaurant > Asian Restaurant > Thai Restaurant > Som Tum Restaurant
        13354: "restaurant",  // 56aa371be4b08b9a8d573538 — Dining and Drinking > Restaurant > Theme Restaurant
        13355: "tibetan_restaurant",  // 52af39fb3cf9994f4e043be9 — Dining and Drinking > Restaurant > Asian Restaurant > Tibetan Restaurant
        13356: "turkish_restaurant",  // 4f04af1f2fb6e1c99f3db0bb — Dining and Drinking > Restaurant > Turkish Restaurant
        13357: "turkish_restaurant",  // 530faca9bcbc57f1066bc2f3 — Dining and Drinking > Restaurant > Turkish Restaurant > Borek Place
        13358: "turkish_restaurant",  // 530faca9bcbc57f1066bc2f4 — Dining and Drinking > Restaurant > Turkish Restaurant > Cigkofte Place
        13359: "turkish_restaurant",  // 58daa1558bbb0b01f18ec1e2 — Dining and Drinking > Restaurant > Turkish Restaurant > Çöp Şiş Place
        13360: "turkish_restaurant",  // 5283c7b4e4b094cb91ec88d8 — Dining and Drinking > Restaurant > Turkish Restaurant > Doner Restaurant
        13361: "turkish_restaurant",  // 5283c7b4e4b094cb91ec88d9 — Dining and Drinking > Restaurant > Turkish Restaurant > Gozleme Place
        13362: "turkish_restaurant",  // 5283c7b4e4b094cb91ec88db — Dining and Drinking > Restaurant > Turkish Restaurant > Kofte Place
        13363: "turkish_restaurant",  // 5283c7b4e4b094cb91ec88d6 — Dining and Drinking > Restaurant > Turkish Restaurant > Kokoreç Restaurant
        13364: "turkish_restaurant",  // 56aa371be4b08b9a8d573535 — Dining and Drinking > Restaurant > Turkish Restaurant > Kumpir Restaurant
        13365: "turkish_restaurant",  // 56aa371be4b08b9a8d5734bd — Dining and Drinking > Restaurant > Turkish Restaurant > Kumru Restaurant
        13366: "turkish_restaurant",  // 5283c7b4e4b094cb91ec88d5 — Dining and Drinking > Restaurant > Turkish Restaurant > Manti Place
        13367: "turkish_restaurant",  // 5283c7b4e4b094cb91ec88da — Dining and Drinking > Restaurant > Turkish Restaurant > Meyhane
        13368: "turkish_restaurant",  // 530faca9bcbc57f1066bc2f2 — Dining and Drinking > Restaurant > Turkish Restaurant > Pide Place
        13369: "turkish_restaurant",  // 58daa1558bbb0b01f18ec1df — Dining and Drinking > Restaurant > Turkish Restaurant > Pilavcı
        13370: "turkish_restaurant",  // 58daa1558bbb0b01f18ec1dc — Dining and Drinking > Restaurant > Turkish Restaurant > Söğüş Place
        13371: "turkish_restaurant",  // 56aa371be4b08b9a8d5734bf — Dining and Drinking > Restaurant > Turkish Restaurant > Tantuni Restaurant
        13372: "turkish_restaurant",  // 56aa371be4b08b9a8d5734c1 — Dining and Drinking > Restaurant > Turkish Restaurant > Turkish Coffeehouse
        13373: "turkish_restaurant",  // 5283c7b4e4b094cb91ec88d4 — Dining and Drinking > Restaurant > Turkish Restaurant > Turkish Home Cooking Restaurant
        13374: "ukrainian_restaurant",  // 52e928d0bcbc57f1066b7e96 — Dining and Drinking > Restaurant > Ukrainian Restaurant
        13375: "ukrainian_restaurant",  // 52e928d0bcbc57f1066b7e9a — Dining and Drinking > Restaurant > Ukrainian Restaurant > Varenyky Restaurant
        13376: "ukrainian_restaurant",  // 52e928d0bcbc57f1066b7e9b — Dining and Drinking > Restaurant > Ukrainian Restaurant > West-Ukrainian Restaurant
        13377: "vegetarian_restaurant",  // 4bf58dd8d48988d1d3941735 — Dining and Drinking > Restaurant > Vegan and Vegetarian Restaurant — Inexact
        13378: "south_american_restaurant",  // 56aa371be4b08b9a8d573558 — Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Venezuelan Restaurant
        13379: "vietnamese_restaurant",  // 4bf58dd8d48988d14a941735 — Dining and Drinking > Restaurant > Asian Restaurant > Vietnamese Restaurant
        13380: "middle_eastern_restaurant",  // 5bae9231bedf3950379f89ea — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Yemeni Restaurant
        13381: "juice_shop",  // 52f2ab2ebcbc57f1066b8b41 — Dining and Drinking > Smoothie Shop
        13382: "snack_bar",  // 4bf58dd8d48988d1c7941735 — Dining and Drinking > Snack Place
        13383: "steak_house",  // 4bf58dd8d48988d1cc941735 — Dining and Drinking > Restaurant > Steakhouse
        13384: "persian_restaurant",  // 5744ccdfe4b0c0459246b4a8 — Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Tabbakhi
        13386: "vineyard",  // 4bf58dd8d48988d1de941735 — Dining and Drinking > Vineyard
        13387: "winery",  // 4bf58dd8d48988d14b941735 — Dining and Drinking > Winery
        13388: "chicken_wings_restaurant",  // 4bf58dd8d48988d14c941735 — Dining and Drinking > Restaurant > Wings Joint
        13389: "irish_pub",  // 52e81612bcbc57f1066b7a06 — Dining and Drinking > Bar > Irish Pub
        13390: "restaurant",  // 4c2cd86ed066bed06c3c5209 — Dining and Drinking > Restaurant > Gluten-Free Restaurant
        13392: "dessert_shop",  // 62d5af45da6648532de303ee — Dining and Drinking > Dessert Shop > Waffle Shop
        14000: "event_venue",  // 4d4b7105d754a06373d81259 — Event
        14001: "convention_center",  // 5267e4d9e4b0ec79466e48c6 — Event > Conference
        14002: "convention_center",  // 5267e4d9e4b0ec79466e48c9 — Event > Convention
        14003: "event_venue",  // 63be6904847c3692a84b9bb7 — Event > Entertainment Event
        14004: "event_venue",  // 5267e4d9e4b0ec79466e48c7 — Event > Entertainment Event > Festival
        14005: "event_venue",  // 5267e4d9e4b0ec79466e48d1 — Event > Entertainment Event > Music Festival
        14006: "event_venue",  // 52741d85e4b0d5d1e3c6a6d9 — Event > Entertainment Event > Parade
        14007: "event_venue",  // 5bae9231bedf3950379f89c5 — Event > Entertainment Event > Sporting Event
        14008: "point_of_interest",  // 58daa1558bbb0b01f18ec1fa — Event > Line — Inexact
        14009: "market",  // 63be6904847c3692a84b9bb8 — Event > Marketplace
        14010: "market",  // 52f2ab2ebcbc57f1066b8b3b — Event > Marketplace > Christmas Market
        14011: "flea_market",  // 52f2ab2ebcbc57f1066b8b54 — Event > Marketplace > Stoop Sale
        14012: "event_venue",  // 5267e4d8e4b0ec79466e48c5 — Event > Marketplace > Street Fair — Inexact
        14013: "food_court",  // 53e0feef498e5aac066fd8a9 — Event > Marketplace > Street Food Gathering — Inexact
        14014: "convention_center",  // 5bae9231bedf3950379f89c3 — Event > Marketplace > Trade Fair
        14015: "event_venue",  // 5267e4d9e4b0ec79466e48c8 — Event > Other Event
        14016: "event_venue",  // 62d587aeda6648532de2b88c — Event > Entertainment Event > Festival > Beer Festival
        15000: "health",  // 63be6904847c3692a84b9bb9 — Health and Medicine — REVIEW: no clear google place type
        15001: "wellness_center",  // 52e81612bcbc57f1066b7a3b — Health and Medicine > Acupuncture Clinic
        15002: "medical_clinic",  // 63be6904847c3692a84b9bba — Health and Medicine > AIDS Resource
        15003: "wellness_center",  // 52e81612bcbc57f1066b7a3c — Health and Medicine > Alternative Medicine Clinic
        15004: "service",  // 63be6904847c3692a84b9bbb — Health and Medicine > Assisted Living Service
        15005: "medical_clinic",  // 5f2c43a65b4c177b9a6dcc62 — Health and Medicine > Blood Bank
        15006: "chiropractor",  // 52e81612bcbc57f1066b7a3a — Health and Medicine > Chiropractor
        15007: "dentist",  // 4bf58dd8d48988d178941735 — Health and Medicine > Dentist
        15008: "hospital",  // 63be6904847c3692a84b9bbc — Health and Medicine > Emergency Service
        15009: "service",  // 63be6904847c3692a84b9bbd — Health and Medicine > Emergency Service > Ambulance Service
        15010: "hospital",  // 4bf58dd8d48988d194941735 — Health and Medicine > Emergency Service > Emergency Room
        15011: "medical_clinic",  // 63be6904847c3692a84b9bbe — Health and Medicine > Healthcare Clinic
        15012: "service",  // 63be6904847c3692a84b9bbf — Health and Medicine > Home Health Care Service
        15013: "medical_clinic",  // 5f2c5b8b5b4c177b9a6ddf0b — Health and Medicine > Hospice
        15014: "hospital",  // 4bf58dd8d48988d196941735 — Health and Medicine > Hospital
        15015: "medical_clinic",  // 56aa371be4b08b9a8d5734ff — Health and Medicine > Maternity Clinic
        15016: "medical_center",  // 4bf58dd8d48988d104941735 — Health and Medicine > Medical Center
        15017: "medical_lab",  // 4f4531b14b9074f6e4fb0103 — Health and Medicine > Medical Lab
        15018: "doctor",  // 63be6904847c3692a84b9bc1 — Health and Medicine > Mental Health Service
        15019: "medical_clinic",  // 52e81612bcbc57f1066b7a39 — Health and Medicine > Mental Health Service > Mental Health Clinic
        15020: "doctor",  // 63be6904847c3692a84b9bc2 — Health and Medicine > Mental Health Service > Psychologist
        15021: "doctor",  // 63be6904847c3692a84b9bc3 — Health and Medicine > Nurse
        15022: "health",  // 63be6904847c3692a84b9bc4 — Health and Medicine > Nursing Home — Inexact
        15023: "doctor",  // 58daa1558bbb0b01f18ec1d0 — Health and Medicine > Nutritionist
        15024: "doctor",  // 522e32fae4b09b556e370f19 — Health and Medicine > Optometrist
        15025: "doctor",  // 63be6904847c3692a84b9bc5 — Health and Medicine > Other Healthcare Professional
        15026: "physiotherapist",  // 5744ccdfe4b0c0459246b4af — Health and Medicine > Physical Therapy Clinic
        15027: "doctor",  // 63be6904847c3692a84b9bc6 — Health and Medicine > Physician
        15028: "doctor",  // 63be6904847c3692a84b9bc7 — Health and Medicine > Physician > Anesthesiologist
        15029: "doctor",  // 63be6904847c3692a84b9bc8 — Health and Medicine > Physician > Cardiologist
        15030: "doctor",  // 63be6904847c3692a84b9bc9 — Health and Medicine > Physician > Dermatologist
        15031: "doctor",  // 4bf58dd8d48988d177941735 — Health and Medicine > Physician > Doctor's Office
        15032: "doctor",  // 63be6904847c3692a84b9bca — Health and Medicine > Physician > Ear, Nose and Throat Doctor
        15033: "doctor",  // 63be6904847c3692a84b9bcb — Health and Medicine > Physician > Family Medicine Doctor
        15034: "doctor",  // 63be6904847c3692a84b9bcc — Health and Medicine > Physician > Gastroenterologist
        15035: "doctor",  // 63be6904847c3692a84b9bcd — Health and Medicine > Physician > General Surgeon
        15036: "doctor",  // 63be6904847c3692a84b9bce — Health and Medicine > Physician > Geriatric Doctor
        15037: "doctor",  // 63be6904847c3692a84b9bcf — Health and Medicine > Physician > Internal Medicine Doctor
        15038: "doctor",  // 63be6904847c3692a84b9bd0 — Health and Medicine > Physician > Neurologist
        15039: "doctor",  // 63be6904847c3692a84b9bd1 — Health and Medicine > Physician > Obstetrician Gynecologist (Ob-gyn)
        15040: "doctor",  // 63be6904847c3692a84b9bd2 — Health and Medicine > Physician > Oncologist
        15041: "doctor",  // 63be6904847c3692a84b9bd3 — Health and Medicine > Physician > Ophthalmologist
        15042: "doctor",  // 63be6904847c3692a84b9bd4 — Health and Medicine > Physician > Oral Surgeon
        15043: "doctor",  // 63be6904847c3692a84b9bd5 — Health and Medicine > Physician > Orthopedic Surgeon
        15044: "doctor",  // 63be6904847c3692a84b9bd6 — Health and Medicine > Physician > Pathologist
        15045: "doctor",  // 63be6904847c3692a84b9bd7 — Health and Medicine > Physician > Pediatrician
        15046: "doctor",  // 63be6904847c3692a84b9bd8 — Health and Medicine > Physician > Plastic Surgeon
        15047: "doctor",  // 63be6904847c3692a84b9bd9 — Health and Medicine > Physician > Psychiatrist
        15048: "doctor",  // 63be6904847c3692a84b9bda — Health and Medicine > Physician > Radiologist
        15049: "doctor",  // 63be6904847c3692a84b9bdb — Health and Medicine > Physician > Respiratory Doctor
        15050: "doctor",  // 63be6904847c3692a84b9bdc — Health and Medicine > Physician > Urologist
        15051: "doctor",  // 63be6904847c3692a84b9bdd — Health and Medicine > Podiatrist
        15052: "medical_clinic",  // 63be6904847c3692a84b9bde — Health and Medicine > Sports Medicine Clinic
        15053: "medical_clinic",  // 56aa371be4b08b9a8d573526 — Health and Medicine > Urgent Care Center
        15054: "veterinary_care",  // 4d954af4a243a5684765b473 — Health and Medicine > Veterinarian
        15055: "wellness_center",  // 590a0744340a5803fd8508c3 — Health and Medicine > Weight Loss Center
        15056: "medical_clinic",  // 63be6904847c3692a84b9bdf — Health and Medicine > Women's Health Clinic
        15058: "hospital",  // 63be6904847c3692a84b9bc0 — Health and Medicine > Hospital > Children's Hospital
        15059: "hospital",  // 58daa1558bbb0b01f18ec1f7 — Health and Medicine > Hospital > Hospital Unit
        16000: "point_of_interest",  // 4d4b7105d754a06377d81259 — Landmarks and Outdoors — REVIEW: no clear google place type
        16001: "beach",  // 52e81612bcbc57f1066b7a28 — Landmarks and Outdoors > Bathing Area — Inexact
        16002: "natural_feature",  // 56aa371be4b08b9a8d573544 — Landmarks and Outdoors > Bay
        16003: "beach",  // 4bf58dd8d48988d1e2941735 — Landmarks and Outdoors > Beach
        16004: "hiking_area",  // 56aa371be4b08b9a8d57355e — Landmarks and Outdoors > Bike Trail — Inexact
        16005: "botanical_garden",  // 52e81612bcbc57f1066b7a22 — Landmarks and Outdoors > Botanical Garden
        16006: "bridge",  // 4bf58dd8d48988d1df941735 — Landmarks and Outdoors > Bridge
        16007: "point_of_interest",  // 4bf58dd8d48988d130941735 — Landmarks and Outdoors > Structure — Inexact
        16008: "campground",  // 4bf58dd8d48988d1e4941735 — Landmarks and Outdoors > Campground
        16009: "natural_feature",  // 56aa371be4b08b9a8d573562 — Landmarks and Outdoors > Canal
        16010: "natural_feature",  // 56aa371be4b08b9a8d57353b — Landmarks and Outdoors > Canal Lock
        16011: "castle",  // 50aaa49e4b90af0d42d5de11 — Landmarks and Outdoors > Castle
        16012: "natural_feature",  // 56aa371be4b08b9a8d573511 — Landmarks and Outdoors > Cave
        16013: "scenic_spot",  // 52e81612bcbc57f1066b7a12 — Landmarks and Outdoors > Dive Spot
        16014: "farm",  // 4bf58dd8d48988d15b941735 — Landmarks and Outdoors > Farm
        16015: "woods",  // 52e81612bcbc57f1066b7a23 — Landmarks and Outdoors > Forest
        16016: "fountain",  // 56aa371be4b08b9a8d573547 — Landmarks and Outdoors > Fountain
        16017: "garden",  // 4bf58dd8d48988d15a941735 — Landmarks and Outdoors > Garden
        16018: "marina",  // 4bf58dd8d48988d1e0941735 — Landmarks and Outdoors > Harbor or Marina
        16019: "hiking_area",  // 4bf58dd8d48988d159941735 — Landmarks and Outdoors > Hiking Trail
        16020: "historical_landmark",  // 4deefb944765f83613cdba6e — Landmarks and Outdoors > Historic and Protected Site
        16021: "natural_feature",  // 4bf58dd8d48988d160941735 — Landmarks and Outdoors > Hot Spring
        16022: "island",  // 50aaa4314b90af0d42d5de10 — Landmarks and Outdoors > Island
        16023: "lake",  // 4bf58dd8d48988d161941735 — Landmarks and Outdoors > Lake
        16024: "tourist_attraction",  // 4bf58dd8d48988d15d941735 — Landmarks and Outdoors > Lighthouse — Inexact
        16025: "monument",  // 5642206c498e4bfca532186c — Landmarks and Outdoors > Memorial Site
        16026: "monument",  // 4bf58dd8d48988d12d941735 — Landmarks and Outdoors > Monument
        16027: "mountain_peak",  // 4eb1d4d54b900d56c88a45fc — Landmarks and Outdoors > Mountain
        16028: "nature_preserve",  // 52e81612bcbc57f1066b7a13 — Landmarks and Outdoors > Nature Preserve
        16029: "beach",  // 52e81612bcbc57f1066b7a30 — Landmarks and Outdoors > Nudist Beach
        16030: "natural_feature",  // 4bf58dd8d48988d162941735 — Landmarks and Outdoors > Other Great Outdoors
        16031: "historical_landmark",  // 52e81612bcbc57f1066b7a14 — Landmarks and Outdoors > Palace
        16032: "park",  // 4bf58dd8d48988d163941735 — Landmarks and Outdoors > Park
        16033: "dog_park",  // 4bf58dd8d48988d1e5941735 — Landmarks and Outdoors > Park > Dog Park
        16034: "national_park",  // 52e81612bcbc57f1066b7a21 — Landmarks and Outdoors > Park > National Park
        16035: "park",  // 63be6904847c3692a84b9be0 — Landmarks and Outdoors > Park > Natural Park
        16036: "picnic_ground",  // 5fabfe3599ce226e27fe709a — Landmarks and Outdoors > Park > Picnic Area
        16037: "playground",  // 4bf58dd8d48988d1e7941735 — Landmarks and Outdoors > Park > Playground
        16038: "state_park",  // 5bae9231bedf3950379f89d0 — Landmarks and Outdoors > Park > State or Provincial Park
        16039: "city_park",  // 63be6904847c3692a84b9be1 — Landmarks and Outdoors > Park > Urban Park
        16040: "plaza",  // 52e81612bcbc57f1066b7a25 — Landmarks and Outdoors > Pedestrian Plaza
        16041: "plaza",  // 4bf58dd8d48988d164941735 — Landmarks and Outdoors > Plaza
        16042: "lake",  // 56aa371be4b08b9a8d573541 — Landmarks and Outdoors > Reservoir
        16043: "river",  // 4eb1d4dd4b900d56c88a45fd — Landmarks and Outdoors > River
        16044: "adventure_sports_center",  // 50328a4b91d4c4b30a586d6b — Landmarks and Outdoors > Rock Climbing Spot — Inexact
        16045: "scenic_spot",  // 4bf58dd8d48988d133951735 — Landmarks and Outdoors > Roof Deck — Inexact
        16046: "scenic_spot",  // 4bf58dd8d48988d165941735 — Landmarks and Outdoors > Scenic Lookout
        16047: "garden",  // 4bf58dd8d48988d166941735 — Landmarks and Outdoors > Sculpture Garden — Inexact
        16048: "stable",  // 4eb1baf03b7b2c5b1d4306ca — Landmarks and Outdoors > Stable
        16049: "beach",  // 4bf58dd8d48988d1e3941735 — Landmarks and Outdoors > Surf Spot — Inexact
        16050: "landmark",  // 52f2ab2ebcbc57f1066b8b4a — Landmarks and Outdoors > Tunnel
        16051: "mountain_peak",  // 5032848691d4c4b30a586d61 — Landmarks and Outdoors > Volcano
        16052: "natural_feature",  // 56aa371be4b08b9a8d573560 — Landmarks and Outdoors > Waterfall
        16053: "natural_feature",  // 56aa371be4b08b9a8d5734c3 — Landmarks and Outdoors > Waterfront
        16054: "tourist_attraction",  // 5bae9231bedf3950379f89c7 — Landmarks and Outdoors > Windmill
        16055: "marina",  // 5fabfc8099ce226e27fe6b0d — Landmarks and Outdoors > Boat Launch
        16056: "natural_feature",  // 5fac018b99ce226e27fe7573 — Landmarks and Outdoors > Dam
        16057: "natural_feature",  // 4bf58dd8d48988d15f941735 — Landmarks and Outdoors > Field
        16058: "natural_feature",  // 5bae9231bedf3950379f89cd — Landmarks and Outdoors > Hill
        16059: "lodging",  // 55a5a1ebe4b013909087cb77 — Landmarks and Outdoors > Mountain Hut
        16060: "picnic_ground",  // 5fac010d99ce226e27fe7467 — Landmarks and Outdoors > Picnic Shelter
        16061: "locality",  // 530e33ccbcbc57f1066bbfe4 — Landmarks and Outdoors > States and Municipalities
        16062: "locality",  // 50aa9e094b90af0d42d5de0d — Landmarks and Outdoors > States and Municipalities > City
        16063: "country",  // 530e33ccbcbc57f1066bbff7 — Landmarks and Outdoors > States and Municipalities > Country
        16064: "administrative_area_level_2",  // 5345731ebcbc57f1066c39b2 — Landmarks and Outdoors > States and Municipalities > County
        16065: "neighborhood",  // 4f2a25ac4b909258e854f55f — Landmarks and Outdoors > States and Municipalities > Neighborhood
        16066: "administrative_area_level_1",  // 530e33ccbcbc57f1066bbff8 — Landmarks and Outdoors > States and Municipalities > State
        16067: "locality",  // 530e33ccbcbc57f1066bbff3 — Landmarks and Outdoors > States and Municipalities > Town
        16068: "locality",  // 530e33ccbcbc57f1066bbff9 — Landmarks and Outdoors > States and Municipalities > Village
        16069: "natural_feature",  // 52e81612bcbc57f1066b7a24 — Landmarks and Outdoors > Tree
        16070: "natural_feature",  // 4fbc1be21983fc883593e321 — Landmarks and Outdoors > Well
        17000: "store",  // 4d4b7105d754a06378d81259 — Retail
        17001: "store",  // 5267e446e4b0ec79466e48c4 — Retail > Adult Store — Inexact
        17002: "store",  // 4bf58dd8d48988d116951735 — Retail > Antique Store
        17003: "store",  // 4bf58dd8d48988d127951735 — Retail > Arts and Crafts Store
        17004: "store",  // 63be6904847c3692a84b9be2 — Retail > Auction House
        17005: "auto_parts_store",  // 63be6904847c3692a84b9be3 — Retail > Automotive Retail
        17006: "car_dealer",  // 4eb1c1623b7b52c0e1adc2ec — Retail > Automotive Retail > Car Dealership
        17007: "car_dealer",  // 63be6904847c3692a84b9be4 — Retail > Automotive Retail > Car Dealership > Classic and Antique Car Dealership
        17008: "car_dealer",  // 5e8f50bd03c7a9000c1e2fbc — Retail > Automotive Retail > Car Dealership > New Car Dealership
        17009: "car_dealer",  // 63be6904847c3692a84b9be5 — Retail > Automotive Retail > Car Dealership > RV and Motorhome Dealership
        17010: "car_dealer",  // 5e8f501a03c7a9000c1e2e88 — Retail > Automotive Retail > Car Dealership > Used Car Dealership
        17011: "auto_parts_store",  // 63be6904847c3692a84b9be6 — Retail > Automotive Retail > Car Parts and Accessories
        17012: "car_dealer",  // 5032833091d4c4b30a586d60 — Retail > Automotive Retail > Motorcycle Dealership
        17013: "store",  // 59d79d6b2e268052fa2a3332 — Retail > Automotive Retail > Motorsports Store
        17014: "store",  // 52f2ab2ebcbc57f1066b8b32 — Retail > Baby Store
        17015: "store",  // 52f2ab2ebcbc57f1066b8b40 — Retail > Betting Shop — Inexact
        17016: "warehouse_store",  // 52f2ab2ebcbc57f1066b8b42 — Retail > Big Box Store
        17017: "sporting_goods_store",  // 4bf58dd8d48988d1f1941735 — Retail > Board Store
        17018: "book_store",  // 4bf58dd8d48988d114951735 — Retail > Bookstore
        17019: "book_store",  // 52f2ab2ebcbc57f1066b8b30 — Retail > Bookstore > Used Bookstore
        17020: "clothing_store",  // 4bf58dd8d48988d104951735 — Retail > Boutique
        17021: "store",  // 63be6904847c3692a84b9be9 — Retail > Cannabis Store — Inexact
        17022: "book_store",  // 52f2ab2ebcbc57f1066b8b18 — Retail > Comic Book Store
        17023: "electronics_store",  // 63be6904847c3692a84b9bea — Retail > Computers and Electronics Retail
        17024: "electronics_store",  // 4eb1bdf03b7b55596b4a7491 — Retail > Computers and Electronics Retail > Camera Store
        17025: "electronics_store",  // 4bf58dd8d48988d122951735 — Retail > Computers and Electronics Retail > Electronics Store
        17026: "cell_phone_store",  // 4f04afc02fb6e1c99f3db0bc — Retail > Computers and Electronics Retail > Mobile Phone Store
        17027: "store",  // 4bf58dd8d48988d10b951735 — Retail > Computers and Electronics Retail > Video Games Store
        17028: "building_materials_store",  // 5454144b498ec1f095bff2f2 — Retail > Construction Supplies Store
        17029: "convenience_store",  // 4d954b0ea243a5684a65b473 — Retail > Convenience Store
        17030: "cosmetics_store",  // 4bf58dd8d48988d10c951735 — Retail > Cosmetics Store
        17031: "clothing_store",  // 52f2ab2ebcbc57f1066b8b17 — Retail > Costume Store
        17032: "store",  // 63be6904847c3692a84b9beb — Retail > Dance Store
        17033: "department_store",  // 4bf58dd8d48988d1f6941735 — Retail > Department Store
        17034: "discount_store",  // 52dea92d3cf9994f4e043dbb — Retail > Discount Store
        17035: "drugstore",  // 5745c2e4498e11e7bccabdbd — Retail > Drugstore
        17036: "store",  // 589ddde98ae3635c072819ee — Retail > Duty-free Store
        17037: "store",  // 4d954afda243a5684865b473 — Retail > Eyecare Store
        17038: "store",  // 52f2ab2ebcbc57f1066b8b26 — Retail > Textiles Store
        17039: "clothing_store",  // 63be6904847c3692a84b9bec — Retail > Fashion Retail
        17040: "clothing_store",  // 56aa371be4b08b9a8d5734cb — Retail > Fashion Retail > Batik Store
        17041: "clothing_store",  // 4bf58dd8d48988d11a951735 — Retail > Fashion Retail > Bridal Store
        17042: "clothing_store",  // 4bf58dd8d48988d105951735 — Retail > Fashion Retail > Children's Clothing Store
        17043: "clothing_store",  // 4bf58dd8d48988d103951735 — Retail > Fashion Retail > Clothing Store
        17044: "clothing_store",  // 4bf58dd8d48988d102951735 — Retail > Fashion Retail > Fashion Accessories Store
        17045: "jewelry_store",  // 4bf58dd8d48988d111951735 — Retail > Fashion Retail > Jewelry Store
        17046: "clothing_store",  // 4bf58dd8d48988d109951735 — Retail > Fashion Retail > Lingerie Store
        17047: "clothing_store",  // 4bf58dd8d48988d106951735 — Retail > Fashion Retail > Men's Store
        17048: "shoe_store",  // 4bf58dd8d48988d107951735 — Retail > Fashion Retail > Shoe Store
        17049: "store",  // 63be6904847c3692a84b9bed — Retail > Fashion Retail > Sunglasses Store
        17050: "clothing_store",  // 63be6904847c3692a84b9bee — Retail > Fashion Retail > Swimwear Store
        17051: "jewelry_store",  // 52f2ab2ebcbc57f1066b8b2e — Retail > Fashion Retail > Watch Store
        17052: "womens_clothing_store",  // 4bf58dd8d48988d108951735 — Retail > Fashion Retail > Women's Store
        17053: "store",  // 52f2ab2ebcbc57f1066b8b3a — Retail > Fireworks Store
        17054: "flea_market",  // 4bf58dd8d48988d1f7941735 — Retail > Flea Market
        17055: "market",  // 56aa371be4b08b9a8d573505 — Retail > Floating Market
        17056: "florist",  // 4bf58dd8d48988d11b951735 — Retail > Flower Store
        17057: "food_store",  // 4bf58dd8d48988d1f9941735 — Retail > Food and Beverage Retail
        17058: "liquor_store",  // 5370f356bcbc57f1066c94c2 — Retail > Food and Beverage Retail > Beer Store
        17059: "butcher_shop",  // 4bf58dd8d48988d11d951735 — Retail > Food and Beverage Retail > Butcher
        17060: "candy_store",  // 4bf58dd8d48988d117951735 — Retail > Food and Beverage Retail > Candy Store
        17061: "food_store",  // 4bf58dd8d48988d11e951735 — Retail > Food and Beverage Retail > Cheese Store
        17062: "chocolate_shop",  // 52f2ab2ebcbc57f1066b8b31 — Retail > Food and Beverage Retail > Chocolate Store
        17063: "coffee_roastery",  // 5e18993feee47d000759b256 — Retail > Food and Beverage Retail > Coffee Roaster
        17064: "food_store",  // 58daa1558bbb0b01f18ec1ca — Retail > Food and Beverage Retail > Dairy Store
        17065: "farmers_market",  // 4bf58dd8d48988d1fa941735 — Retail > Food and Beverage Retail > Farmers Market
        17066: "market",  // 4bf58dd8d48988d10e951735 — Retail > Food and Beverage Retail > Fish Market
        17067: "food_store",  // 52f2ab2ebcbc57f1066b8b1c — Retail > Food and Beverage Retail > Fruit and Vegetable Store
        17068: "food_store",  // 4bf58dd8d48988d1f5941735 — Retail > Food and Beverage Retail > Gourmet Store
        17069: "grocery_store",  // 4bf58dd8d48988d118951735 — Retail > Food and Beverage Retail > Grocery Store
        17070: "grocery_store",  // 52f2ab2ebcbc57f1066b8b45 — Retail > Food and Beverage Retail > Grocery Store > Organic Grocery
        17071: "health_food_store",  // 50aa9e744b90af0d42d5de0e — Retail > Food and Beverage Retail > Health Food Store
        17072: "food_store",  // 52f2ab2ebcbc57f1066b8b2c — Retail > Food and Beverage Retail > Herbs and Spices Store
        17073: "food_store",  // 5f2c41945b4c177b9a6dc7d6 — Retail > Food and Beverage Retail > Imported Food Store
        17074: "food_store",  // 63be6904847c3692a84b9bef — Retail > Food and Beverage Retail > Kosher Store
        17075: "food_store",  // 58daa1558bbb0b01f18ec1e8 — Retail > Food and Beverage Retail > Kuruyemişçi Shop
        17076: "liquor_store",  // 4bf58dd8d48988d186941735 — Retail > Food and Beverage Retail > Liquor Store
        17077: "butcher_shop",  // 63be6904847c3692a84b9bf0 — Retail > Food and Beverage Retail > Meat and Seafood Store
        17078: "butcher_shop",  // 56aa371be4b08b9a8d573564 — Retail > Food and Beverage Retail > Sausage Store
        17079: "food_store",  // 58daa1558bbb0b01f18ec1e5 — Retail > Food and Beverage Retail > Turşucu Shop
        17080: "liquor_store",  // 4bf58dd8d48988d119951735 — Retail > Food and Beverage Retail > Wine Store
        17081: "store",  // 52f2ab2ebcbc57f1066b8b24 — Retail > Framing Store
        17082: "home_goods_store",  // 4bf58dd8d48988d1f8941735 — Retail > Furniture and Home Store
        17083: "home_goods_store",  // 52f2ab2ebcbc57f1066b8b2a — Retail > Furniture and Home Store > Carpet Store
        17084: "home_goods_store",  // 63be6904847c3692a84b9bf1 — Retail > Furniture and Home Store > Home Appliance Store
        17085: "home_goods_store",  // 63be6904847c3692a84b9bf2 — Retail > Furniture and Home Store > Housewares Store
        17086: "home_goods_store",  // 58daa1558bbb0b01f18ec1b4 — Retail > Furniture and Home Store > Kitchen Supply Store
        17087: "home_goods_store",  // 55888a5a498e782e3303b43a — Retail > Furniture and Home Store > Lighting Store
        17088: "home_goods_store",  // 52f2ab2ebcbc57f1066b8b27 — Retail > Furniture and Home Store > Mattress Store
        17089: "gift_shop",  // 4bf58dd8d48988d128951735 — Retail > Gift Store
        17090: "hardware_store",  // 4bf58dd8d48988d112951735 — Retail > Hardware Store
        17091: "store",  // 4bf58dd8d48988d1fb941735 — Retail > Hobby Store
        17092: "store",  // 52f2ab2ebcbc57f1066b8b25 — Retail > Knitting Store
        17093: "store",  // 52f2ab2ebcbc57f1066b8b2b — Retail > Leather Goods Store
        17094: "store",  // 52f2ab2ebcbc57f1066b8b29 — Retail > Luggage Store
        17095: "store",  // 58daa1558bbb0b01f18ec206 — Retail > Medical Supply Store
        17096: "store",  // 4bf58dd8d48988d1ff941735 — Retail > Miscellaneous Store
        17097: "store",  // 56aa371be4b08b9a8d57354a — Retail > Mobility Store
        17098: "store",  // 4bf58dd8d48988d1fe941735 — Retail > Music Store
        17099: "store",  // 5f2c5a295b4c177b9a6ddd0e — Retail > Newsagent
        17100: "store",  // 4f04ad622fb6e1c99f3db0b9 — Retail > Newsstand
        17101: "garden_center",  // 4eb1c0253b7b52c0e1adc2e9 — Retail > Garden Center
        17102: "store",  // 4bf58dd8d48988d121951735 — Retail > Office Supply Store
        17103: "sporting_goods_store",  // 52f2ab2ebcbc57f1066b8b22 — Retail > Outdoor Supply Store
        17104: "shopping_mall",  // 5744ccdfe4b0c0459246b4df — Retail > Outlet Mall
        17105: "store",  // 52f2ab2ebcbc57f1066b8b35 — Retail > Outlet Store
        17106: "store",  // 63be6904847c3692a84b9bf3 — Retail > Packaging Supply Store
        17107: "store",  // 63be6904847c3692a84b9bf4 — Retail > Party Supply Store
        17108: "store",  // 52f2ab2ebcbc57f1066b8b34 — Retail > Pawn Shop
        17109: "cosmetics_store",  // 52f2ab2ebcbc57f1066b8b23 — Retail > Perfume Store
        17110: "pet_store",  // 4bf58dd8d48988d100951735 — Retail > Pet Supplies Store
        17111: "store",  // 52f2ab2ebcbc57f1066b8b3d — Retail > Pop-Up Store
        17112: "store",  // 52f2ab2ebcbc57f1066b8b28 — Retail > Print Store
        17113: "store",  // 4bf58dd8d48988d10d951735 — Retail > Record Store
        17114: "shopping_mall",  // 4bf58dd8d48988d1fd941735 — Retail > Shopping Mall
        17115: "shopping_mall",  // 5744ccdfe4b0c0459246b4dc — Retail > Shopping Plaza
        17116: "gift_shop",  // 52f2ab2ebcbc57f1066b8b1b — Retail > Souvenir Store
        17117: "sporting_goods_store",  // 4bf58dd8d48988d1f2941735 — Retail > Sporting Goods Retail
        17118: "sporting_goods_store",  // 63be6904847c3692a84b9bf5 — Retail > Sporting Goods Retail > Baseball Store
        17119: "bicycle_store",  // 4bf58dd8d48988d115951735 — Retail > Sporting Goods Retail > Bicycle Store
        17120: "sporting_goods_store",  // 52f2ab2ebcbc57f1066b8b1a — Retail > Sporting Goods Retail > Dive Store
        17121: "sporting_goods_store",  // 52f2ab2ebcbc57f1066b8b16 — Retail > Sporting Goods Retail > Fishing Store
        17122: "sporting_goods_store",  // 63be6904847c3692a84b9bf6 — Retail > Sporting Goods Retail > Golf Store
        17123: "sporting_goods_store",  // 52f2ab2ebcbc57f1066b8b19 — Retail > Sporting Goods Retail > Gun Store
        17124: "sporting_goods_store",  // 50aaa5234b90af0d42d5de12 — Retail > Sporting Goods Retail > Hunting Supply Store
        17125: "sporting_goods_store",  // 63be6904847c3692a84b9bf7 — Retail > Sporting Goods Retail > Running Store
        17126: "sporting_goods_store",  // 5bae9231bedf3950379f89d2 — Retail > Sporting Goods Retail > Skate Store
        17127: "sporting_goods_store",  // 56aa371be4b08b9a8d573566 — Retail > Sporting Goods Retail > Ski Store
        17128: "sporting_goods_store",  // 63be6904847c3692a84b9bf8 — Retail > Sporting Goods Retail > Soccer Store
        17129: "sporting_goods_store",  // 63be6904847c3692a84b9bf9 — Retail > Sporting Goods Retail > Surf Store
        17130: "sporting_goods_store",  // 63be6904847c3692a84b9bfa — Retail > Sporting Goods Retail > Tennis Store
        17131: "store",  // 52f2ab2ebcbc57f1066b8b21 — Retail > Stationery Store
        17132: "health_food_store",  // 5744ccdfe4b0c0459246b4cd — Retail > Supplement Store
        17133: "store",  // 63be6904847c3692a84b9bfb — Retail > Swimming Pool Supply Store
        17134: "store",  // 63be6904847c3692a84b9bfc — Retail > Tobacco Store
        17135: "toy_store",  // 4bf58dd8d48988d1f3941735 — Retail > Toy Store
        17136: "store",  // 56aa371be4b08b9a8d57355c — Retail > Vape Store
        17137: "store",  // 4bf58dd8d48988d126951735 — Retail > Video Store
        17138: "thrift_store",  // 4bf58dd8d48988d101951735 — Retail > Vintage and Thrift Store
        17139: "warehouse_store",  // 52e816a6bcbc57f1066b7a54 — Retail > Warehouse or Wholesale Store
        17140: "car_dealer",  // 63be6904847c3692a84b9be7 — Retail > Automotive Retail > Moped Dealership
        17141: "car_dealer",  // 63be6904847c3692a84b9be8 — Retail > Automotive Retail > Motor Scooter Dealership
        17142: "supermarket",  // 52f2ab2ebcbc57f1066b8b46 — Retail > Food and Beverage Retail > Supermarket
        17143: "store",  // 52c71aaf3cf9994f4e043d17 — Retail > Marijuana Dispensary
        17144: "market",  // 50be8ee891d4fa8dcc7199a7 — Retail > Market
        17145: "pharmacy",  // 4bf58dd8d48988d10f951735 — Retail > Pharmacy
        17146: "store",  // 4bf58dd8d48988d123951735 — Retail > Smoke Shop
        18000: "sports_activity_location",  // 4f4528bc4b90abdf24c9de85 — Sports and Recreation — REVIEW: no clear google place type
        18001: "athletic_field",  // 63be6904847c3692a84b9bfd — Sports and Recreation > Athletic Field
        18002: "athletic_field",  // 63be6904847c3692a84b9bfe — Sports and Recreation > Baseball
        18003: "sports_club",  // 63be6904847c3692a84b9bff — Sports and Recreation > Baseball > Baseball Club
        18004: "athletic_field",  // 4bf58dd8d48988d1e8941735 — Sports and Recreation > Baseball > Baseball Field
        18005: "sports_activity_location",  // 63be6904847c3692a84b9c00 — Sports and Recreation > Baseball > Batting Cages
        18006: "sports_complex",  // 63be6904847c3692a84b9c01 — Sports and Recreation > Basketball
        18007: "sports_club",  // 63be6904847c3692a84b9c02 — Sports and Recreation > Basketball > Basketball Club
        18008: "athletic_field",  // 4bf58dd8d48988d1e1941735 — Sports and Recreation > Basketball > Basketball Court
        18009: "park",  // 52e81612bcbc57f1066b7a2f — Sports and Recreation > Bowling Green
        18010: "athletic_field",  // 4bf58dd8d48988d18a941735 — Sports and Recreation > Cricket Ground
        18011: "ice_skating_rink",  // 56aa371be4b08b9a8d57351a — Sports and Recreation > Curling Ice
        18012: "stable",  // 63be6904847c3692a84b9c04 — Sports and Recreation > Equestrian Facility
        18013: "athletic_field",  // 63be6904847c3692a84b9c05 — Sports and Recreation > Football
        18014: "sports_club",  // 63be6904847c3692a84b9c06 — Sports and Recreation > Football > Football Club
        18015: "athletic_field",  // 63be6904847c3692a84b9c07 — Sports and Recreation > Football > Football Field
        18016: "golf_course",  // 63be6904847c3692a84b9c08 — Sports and Recreation > Golf
        18017: "golf_course",  // 63be6904847c3692a84b9c09 — Sports and Recreation > Golf > Golf Club
        18018: "golf_course",  // 4bf58dd8d48988d1e6941735 — Sports and Recreation > Golf > Golf Course
        18019: "golf_course",  // 58daa1558bbb0b01f18ec1b0 — Sports and Recreation > Golf > Golf Driving Range
        18020: "sports_activity_location",  // 52e81612bcbc57f1066b7a11 — Sports and Recreation > Gun Range
        18021: "gym",  // 4bf58dd8d48988d175941735 — Sports and Recreation > Gym and Studio
        18022: "gym",  // 52f2ab2ebcbc57f1066b8b47 — Sports and Recreation > Gym and Studio > Boxing Gym
        18023: "gym",  // 503289d391d4c4b30a586d6a — Sports and Recreation > Gym and Studio > Climbing Gym
        18024: "fitness_center",  // 52f2ab2ebcbc57f1066b8b49 — Sports and Recreation > Gym and Studio > Cycle Studio
        18025: "sports_school",  // 4bf58dd8d48988d134941735 — Sports and Recreation > Gym and Studio > Dance Studio
        18026: "gym",  // 58daa1558bbb0b01f18ec203 — Sports and Recreation > Gym and Studio > Outdoor Gym
        18027: "fitness_center",  // 5744ccdfe4b0c0459246b4b2 — Sports and Recreation > Gym and Studio > Pilates Studio
        18028: "yoga_studio",  // 4bf58dd8d48988d102941735 — Sports and Recreation > Gym and Studio > Yoga Studio
        18029: "sports_activity_location",  // 63be6904847c3692a84b9c0a — Sports and Recreation > Gymnastics
        18030: "sports_complex",  // 52f2ab2ebcbc57f1066b8b48 — Sports and Recreation > Gymnastics > Gymnastics Center
        18031: "ice_skating_rink",  // 63be6904847c3692a84b9c0b — Sports and Recreation > Hockey
        18032: "sports_club",  // 63be6904847c3692a84b9c0c — Sports and Recreation > Hockey > Hockey Club
        18033: "athletic_field",  // 4f452cd44b9081a197eba860 — Sports and Recreation > Hockey > Hockey Field
        18034: "ice_skating_rink",  // 56aa371be4b08b9a8d57352c — Sports and Recreation > Hockey > Hockey Rink
        18035: "indoor_playground",  // 5744ccdfe4b0c0459246b4b5 — Sports and Recreation > Indoor Play Area
        18036: "sports_school",  // 4bf58dd8d48988d101941735 — Sports and Recreation > Martial Arts Dojo
        18037: "paintball_center",  // 5032829591d4c4b30a586d5e — Sports and Recreation > Paintball Field
        18038: "sports_coaching",  // 63be6904847c3692a84b9c0e — Sports and Recreation > Personal Trainer
        18039: "race_course",  // 4bf58dd8d48988d1f4931735 — Sports and Recreation > Race Track
        18040: "sports_complex",  // 63be6904847c3692a84b9c0f — Sports and Recreation > Racquet Sports
        18041: "sports_complex",  // 52e81612bcbc57f1066b7a2b — Sports and Recreation > Racquet Sports > Badminton Court
        18042: "sports_club",  // 63be6904847c3692a84b9c10 — Sports and Recreation > Racquet Sports > Racquet Sport Club
        18043: "sports_club",  // 63be6904847c3692a84b9c11 — Sports and Recreation > Racquet Sports > Racquetball Club
        18044: "sports_complex",  // 52e81612bcbc57f1066b7a2d — Sports and Recreation > Racquet Sports > Squash Court
        18045: "tennis_court",  // 63be6904847c3692a84b9c12 — Sports and Recreation > Racquet Sports > Tennis
        18046: "sports_club",  // 63be6904847c3692a84b9c13 — Sports and Recreation > Racquet Sports > Tennis > Tennis Club
        18047: "tennis_court",  // 4e39a956bd410d7aed40cbc3 — Sports and Recreation > Racquet Sports > Tennis > Tennis Court
        18048: "community_center",  // 52e81612bcbc57f1066b7a26 — Sports and Recreation > Recreation Center
        18049: "athletic_field",  // 63be6904847c3692a84b9c14 — Sports and Recreation > Rugby
        18050: "athletic_field",  // 52e81612bcbc57f1066b7a2c — Sports and Recreation > Rugby > Rugby Pitch
        18051: "athletic_field",  // 63be6904847c3692a84b9c15 — Sports and Recreation > Running and Track
        18052: "sports_club",  // 63be6904847c3692a84b9c16 — Sports and Recreation > Running and Track > Running Club
        18053: "athletic_field",  // 4bf58dd8d48988d106941735 — Sports and Recreation > Running and Track > Track
        18054: "ice_skating_rink",  // 63be6904847c3692a84b9c17 — Sports and Recreation > Skating
        18055: "skateboard_park",  // 4bf58dd8d48988d167941735 — Sports and Recreation > Skating > Skate Park
        18056: "ice_skating_rink",  // 4bf58dd8d48988d168941735 — Sports and Recreation > Skating > Skating Rink
        18057: "adventure_sports_center",  // 63be6904847c3692a84b9c18 — Sports and Recreation > Skydiving Center
        18058: "ski_resort",  // 63be6904847c3692a84b9c19 — Sports and Recreation > Snow Sports
        18059: "ski_resort",  // 4bf58dd8d48988d1ec941735 — Sports and Recreation > Snow Sports > Ski Chalet
        18060: "ski_resort",  // 4bf58dd8d48988d1eb941735 — Sports and Recreation > Snow Sports > Ski Lodge
        18061: "ski_resort",  // 4bf58dd8d48988d1e9941735 — Sports and Recreation > Snow Sports > Ski Resort and Area
        18062: "athletic_field",  // 63be6904847c3692a84b9c1a — Sports and Recreation > Soccer
        18063: "sports_club",  // 63be6904847c3692a84b9c1b — Sports and Recreation > Soccer > Soccer Club
        18064: "athletic_field",  // 4cce455aebf7b749d5e191f5 — Sports and Recreation > Soccer > Soccer Field
        18065: "sports_club",  // 52e81612bcbc57f1066b7a2e — Sports and Recreation > Sports Club
        18066: "athletic_field",  // 4eb1bf013b7b6f98df247e07 — Sports and Recreation > Volleyball Court
        18067: "adventure_sports_center",  // 63be6904847c3692a84b9c1c — Sports and Recreation > Water Sports
        18068: "adventure_sports_center",  // 63be6904847c3692a84b9c1d — Sports and Recreation > Water Sports > Canoe and Kayak Rental
        18069: "adventure_sports_center",  // 63be6904847c3692a84b9c1e — Sports and Recreation > Water Sports > Rafting Outfitter
        18070: "sports_club",  // 63be6904847c3692a84b9c1f — Sports and Recreation > Water Sports > Sailing Club
        18071: "sports_coaching",  // 63be6904847c3692a84b9c20 — Sports and Recreation > Water Sports > Scuba Diving Instructor
        18072: "adventure_sports_center",  // 63be6904847c3692a84b9c21 — Sports and Recreation > Water Sports > Surfing
        18073: "swimming_pool",  // 63be6904847c3692a84b9c22 — Sports and Recreation > Water Sports > Swimming
        18074: "sports_club",  // 63be6904847c3692a84b9c23 — Sports and Recreation > Water Sports > Swimming > Swimming Club
        18075: "swimming_pool",  // 4bf58dd8d48988d15e941735 — Sports and Recreation > Water Sports > Swimming > Swimming Pool
        18076: "sports_school",  // 52e81612bcbc57f1066b7a44 — Sports and Recreation > Water Sports > Swimming > Swim School
        18077: "gym",  // 4bf58dd8d48988d176941735 — Sports and Recreation > Gym and Studio > Gym
        18078: "swimming_pool",  // 4bf58dd8d48988d105941735 — Sports and Recreation > Gym and Studio > Gym Pool
        18079: "sports_activity_location",  // 63be6904847c3692a84b9c0d — Sports and Recreation > Hunting Area
        18080: "race_course",  // 56aa371be4b08b9a8d573514 — Sports and Recreation > Race Track > Racecourse
        18081: "sauna",  // 58daa1558bbb0b01f18ec1ae — Sports and Recreation > Sauna
        18082: "adventure_sports_center",  // 58daa1558bbb0b01f18ec1b9 — Sports and Recreation > Skydiving Center > Skydiving Drop Zone
        18083: "ski_resort",  // 4eb1c0ed3b7b52c0e1adc2ea — Sports and Recreation > Snow Sports > Ski Resort and Area > Ski Chairlift
        18084: "ski_resort",  // 4eb1c0f63b7b52c0e1adc2eb — Sports and Recreation > Snow Sports > Ski Resort and Area > Ski Trail
        18085: "adventure_sports_center",  // 52e81612bcbc57f1066b7a29 — Sports and Recreation > Water Sports > Rafting Spot
        18086: "fishing_pond",  // 52e81612bcbc57f1066b7a0f — Sports and Recreation > Fishing Area
        19000: "point_of_interest",  // 4d4b7105d754a06379d81259 — Travel and Transportation — REVIEW: no clear google place type
        19001: "storage",  // 5744ccdfe4b0c0459246b4e8 — Travel and Transportation > Baggage Locker
        19002: "bike_sharing_station",  // 4e4c9077bd41f78e849722f9 — Travel and Transportation > Bike Rental — Inexact
        19003: "marina",  // 5744ccdfe4b0c0459246b4c1 — Travel and Transportation > Boat Rental — Inexact
        19004: "transit_station",  // 52f2ab2ebcbc57f1066b8b4b — Travel and Transportation > Border Crossing
        19005: "marina",  // 55077a22498e5e9248869ba2 — Travel and Transportation > Cruise — Inexact
        19006: "electric_vehicle_charging_station",  // 5032872391d4c4b30a586d64 — Travel and Transportation > Electric Vehicle Charging Station
        19007: "gas_station",  // 4bf58dd8d48988d113951735 — Travel and Transportation > Fuel Station
        19008: "tour_agency",  // 63be6904847c3692a84b9c24 — Travel and Transportation > Hot Air Balloon Tour Agency
        19009: "lodging",  // 63be6904847c3692a84b9c25 — Travel and Transportation > Lodging
        19010: "bed_and_breakfast",  // 4bf58dd8d48988d1f8931735 — Travel and Transportation > Lodging > Bed and Breakfast
        19011: "guest_house",  // 4f4530a74b9074f6e4fb0100 — Travel and Transportation > Lodging > Boarding House
        19012: "camping_cabin",  // 63be6904847c3692a84b9c26 — Travel and Transportation > Lodging > Cabin
        19013: "hostel",  // 4bf58dd8d48988d1ee931735 — Travel and Transportation > Lodging > Hostel
        19014: "hotel",  // 4bf58dd8d48988d1fa931735 — Travel and Transportation > Lodging > Hotel
        19015: "inn",  // 5bae9231bedf3950379f89cb — Travel and Transportation > Lodging > Inn
        19016: "lodging",  // 63be6904847c3692a84b9c27 — Travel and Transportation > Lodging > Lodge
        19017: "motel",  // 4bf58dd8d48988d1fb931735 — Travel and Transportation > Lodging > Motel
        19018: "resort_hotel",  // 4bf58dd8d48988d12f951735 — Travel and Transportation > Lodging > Resort
        19019: "lodging",  // 56aa371be4b08b9a8d5734e1 — Travel and Transportation > Lodging > Vacation Rental
        19020: "parking",  // 4c38df4de52ce0d596b336e1 — Travel and Transportation > Parking
        19021: "point_of_interest",  // 4e74f6cabd41c4836eac4c31 — Travel and Transportation > Pier — Inexact
        19022: "transit_station",  // 4f4531504b9074f6e4fb0102 — Travel and Transportation > Platform
        19023: "ferry_terminal",  // 56aa371be4b08b9a8d57353e — Travel and Transportation > Port — Inexact
        19024: "rest_stop",  // 4d954b16a243a5684b65b473 — Travel and Transportation > Rest Area
        19025: "rv_park",  // 52f2ab2ebcbc57f1066b8b53 — Travel and Transportation > RV Park
        19026: "toll_station",  // 52f2ab2ebcbc57f1066b8b4d — Travel and Transportation > Toll Booth
        19027: "toll_station",  // 52f2ab2ebcbc57f1066b8b4e — Travel and Transportation > Toll Plaza
        19028: "tourist_information_center",  // 4f4530164b9074f6e4fb00ff — Travel and Transportation > Tourist Information and Service
        19029: "tour_agency",  // 56aa371be4b08b9a8d573520 — Travel and Transportation > Tourist Information and Service > Tour Provider
        19030: "transit_station",  // 63be6904847c3692a84b9c28 — Travel and Transportation > Transport Hub
        19031: "airport",  // 4bf58dd8d48988d1ed931735 — Travel and Transportation > Transport Hub > Airport
        19032: "airstrip",  // 5f2c42335b4c177b9a6dc927 — Travel and Transportation > Transport Hub > Airport > Airfield
        19033: "food_court",  // 4bf58dd8d48988d1ef931735 — Travel and Transportation > Transport Hub > Airport > Airport Food Court
        19034: "airport",  // 4bf58dd8d48988d1f0931735 — Travel and Transportation > Transport Hub > Airport > Airport Gate
        19035: "airport",  // 4eb1bc533b7b2c5b1d4306cb — Travel and Transportation > Transport Hub > Airport > Airport Lounge
        19036: "airport",  // 56aa371be4b08b9a8d57352f — Travel and Transportation > Transport Hub > Airport > Airport Service
        19037: "airport",  // 4bf58dd8d48988d1eb931735 — Travel and Transportation > Transport Hub > Airport > Airport Terminal
        19038: "tram_stop",  // 4bf58dd8d48988d1ec931735 — Travel and Transportation > Transport Hub > Airport > Airport Tram Station
        19039: "airport",  // 5744ccdfe4b0c0459246b4e5 — Travel and Transportation > Transport Hub > Airport > Baggage Claim
        19040: "international_airport",  // 63be6904847c3692a84b9c29 — Travel and Transportation > Transport Hub > Airport > International Airport
        19041: "airport",  // 63be6904847c3692a84b9c2a — Travel and Transportation > Transport Hub > Airport > Private Airport
        19042: "bus_station",  // 4bf58dd8d48988d1fe931735 — Travel and Transportation > Transport Hub > Bus Station
        19043: "bus_stop",  // 52f2ab2ebcbc57f1066b8b4f — Travel and Transportation > Transport Hub > Bus Stop
        19044: "heliport",  // 56aa371ce4b08b9a8d57356e — Travel and Transportation > Transport Hub > Heliport
        19045: "ferry_terminal",  // 5f2c1af1b6d05514c704319d — Travel and Transportation > Transport Hub > Marine Terminal
        19046: "subway_station",  // 4bf58dd8d48988d1fd931735 — Travel and Transportation > Transport Hub > Metro Station
        19047: "train_station",  // 4bf58dd8d48988d129951735 — Travel and Transportation > Transport Hub > Rail Station
        19048: "car_rental",  // 4bf58dd8d48988d1ef941735 — Travel and Transportation > Transport Hub > Rental Car Location
        19049: "taxi_stand",  // 53fca564498e1a175f32528b — Travel and Transportation > Transport Hub > Taxi Stand
        19050: "tram_stop",  // 52f2ab2ebcbc57f1066b8b51 — Travel and Transportation > Transport Hub > Tram Station
        19051: "transportation_service",  // 54541b70498ea6ccd0204bff — Travel and Transportation > Transportation Service
        19052: "transportation_service",  // 63be6904847c3692a84b9c2b — Travel and Transportation > Transportation Service > Charter Bus
        19053: "chauffeur_service",  // 63be6904847c3692a84b9c2c — Travel and Transportation > Transportation Service > Limo Service
        19054: "transit_station",  // 63be6904847c3692a84b9c2d — Travel and Transportation > Transportation Service > Public Transportation
        19055: "travel_agency",  // 4f04b08c2fb6e1c99f3db0bd — Travel and Transportation > Travel Agency
        19056: "transit_station",  // 4f04b25d2fb6e1c99f3db0c0 — Travel and Transportation > Travel Lounge
        19057: "truck_stop",  // 57558b36e4b065ecebd306dd — Travel and Transportation > Truck Stop
        19058: "swimming_pool",  // 4bf58dd8d48988d132951735 — Travel and Transportation > Lodging > Hotel > Hotel Pool
        19060: "route",  // 4bf58dd8d48988d1f9931735 — Travel and Transportation > Road
        19061: "intersection",  // 52f2ab2ebcbc57f1066b8b4c — Travel and Transportation > Road > Intersection
        19062: "airport",  // 4bf58dd8d48988d1f7931735 — Travel and Transportation > Transport Hub > Airport > Plane
        19063: "light_rail_station",  // 4bf58dd8d48988d1fc931735 — Travel and Transportation > Transport Hub > Light Rail Station
        19064: "ferry_terminal",  // 4bf58dd8d48988d12d951735 — Travel and Transportation > Boat or Ferry
        19065: "transit_station",  // 52f2ab2ebcbc57f1066b8b50 — Travel and Transportation > Cable Car
        19066: "train_station",  // 4bf58dd8d48988d12a951735 — Travel and Transportation > Train
        19067: "bus_station",  // 4bf58dd8d48988d12b951735 — Travel and Transportation > Transportation Service > Public Transportation > Bus Line
        19068: "taxi_service",  // 4bf58dd8d48988d130951735 — Travel and Transportation > Transportation Service > Taxi
        19070: "airport",  // 60a674555c7917283bad6839 — Travel and Transportation > Transport Hub > Airport > Airport Ticket Counter

        // V3 ids whose V2 target resolves to nothing:
        // 19059 -> 4f2a23984b9023bd5841ed2c  (no Google equivalent)
    ]
}
