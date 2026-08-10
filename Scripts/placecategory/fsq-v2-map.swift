// Mapping from Foursquare V2 category IDs to Google place types.
// Generated mapping. Items marked with `// REVIEW:` may need attention.

let foursquareToGooglePlaceType: [String: String?] = [
    // Arts and Entertainment > Amusement Park
    "4bf58dd8d48988d182941735": "amusement_park",
    // Arts and Entertainment > Aquarium
    "4fceea171983d5d06c3e9823": "aquarium",
    // Arts and Entertainment > Arcade
    "4bf58dd8d48988d1e1931735": "video_arcade",
    // Arts and Entertainment > Art Gallery
    "4bf58dd8d48988d1e2931735": "art_gallery",
    // Arts and Entertainment > Bingo Center
    "63be6904847c3692a84b9b20": "event_venue", // Inexact
    // Arts and Entertainment > Bowling Alley
    "4bf58dd8d48988d1e4931735": "bowling_alley",
    // Arts and Entertainment > Carnival
    "63be6904847c3692a84b9b21": "amusement_park", // Inexact
    // Arts and Entertainment > Casino
    "4bf58dd8d48988d17c941735": "casino",
    // Arts and Entertainment > Circus
    "52e81612bcbc57f1066b79e7": "performing_arts_theater",
    // Arts and Entertainment > Comedy Club
    "4bf58dd8d48988d18e941735": "comedy_club",
    // Arts and Entertainment > Country Club
    "63be6904847c3692a84b9b22": "event_venue",
    // Arts and Entertainment > Country Dance Club
    "52e81612bcbc57f1066b79ef": "dance_hall",
    // Arts and Entertainment > Dance Hall
    "63be6904847c3692a84b9b23": "dance_hall",
    // Arts and Entertainment > Disc Golf
    "52e81612bcbc57f1066b79e8": "sports_activity_location", // Inexact
    // Arts and Entertainment > Disc Golf Course
    "63be6904847c3692a84b9c03": "sports_activity_location",  // Inexact
    // Arts and Entertainment > Escape Room
    "5f2c2834b6d05514c704451e": "amusement_center",
    // Arts and Entertainment > Exhibit
    "56aa371be4b08b9a8d573532": "art_gallery", 
    // Arts and Entertainment > Fair
    "4eb1daf44b900d56c88a4600": "amusement_park", // Inexact
    // Arts and Entertainment > Gaming Cafe
    "4bf58dd8d48988d18d941735": "internet_cafe",
    // Arts and Entertainment > Go Kart Track
    "52e81612bcbc57f1066b79ea": "go_karting_venue",
    // Arts and Entertainment > Internet Cafe
    "4bf58dd8d48988d1f0941735": "internet_cafe",
    // Arts and Entertainment > Karaoke Box
    "5744ccdfe4b0c0459246b4bb": "karaoke",
    // Arts and Entertainment > Laser Tag Center
    "52e81612bcbc57f1066b79e6": "amusement_center",
    // Arts and Entertainment > Mini Golf Course
    "52e81612bcbc57f1066b79eb": "miniature_golf_course",
    // Arts and Entertainment > Movie Theater
    "4bf58dd8d48988d17f941735": "movie_theater",
    // Arts and Entertainment > Museum
    "4bf58dd8d48988d181941735": "museum",
    // Arts and Entertainment > Night Club
    "4bf58dd8d48988d11f941735": "night_club",
    // Arts and Entertainment > Pachinko Parlor
    "5744ccdfe4b0c0459246b4b8": "casino",
    // Arts and Entertainment > Party Center
    "63be6904847c3692a84b9b24": "event_venue",
    // Arts and Entertainment > Performing Arts Venue
    "4bf58dd8d48988d1f2931735": "performing_arts_theater",
    // Arts and Entertainment > Planetarium
    "4bf58dd8d48988d192941735": "planetarium",
    // Arts and Entertainment > Pool Hall
    "4bf58dd8d48988d1e3931735": "amusement_center",
    // Arts and Entertainment > Psychic and Astrologer
    "52f2ab2ebcbc57f1066b8b43": "astrologer",
    // Arts and Entertainment > Public Art
    "507c8c4091d498d9fc8c67a9": "sculpture",
    // Arts and Entertainment > Roller Rink
    "52e81612bcbc57f1066b79e9": "sports_activity_location", // Inexact
    // Arts and Entertainment > Salsa Club
    "52e81612bcbc57f1066b79ec": "dance_hall",
    // Arts and Entertainment > Samba School
    "56aa371be4b08b9a8d5734f9": "dance_hall",
    // Arts and Entertainment > Stadium
    "4bf58dd8d48988d184941735": "stadium",
    // Arts and Entertainment > Strip Club
    "4bf58dd8d48988d1d6941735": "night_club", // Inexact
    // Arts and Entertainment > Ticket Seller
    "63be6904847c3692a84b9b25": "point_of_interest", // Very general: no clear google place type
    // Arts and Entertainment > VR Cafe
    "5f2c14a5b6d05514c7042eb7": "video_arcade",
    // Arts and Entertainment > Water Park
    "4bf58dd8d48988d193941735": "water_park",
    // Arts and Entertainment > Zoo
    "4bf58dd8d48988d17b941735": "zoo",
    // Arts and Entertainment > Amusement Park > Attraction
    "5109983191d435c0d71c2bb1": "tourist_attraction",
    // Arts and Entertainment > Movie Theater > Drive-in Theater
    "56aa371be4b08b9a8d5734de": "movie_theater",
    // Arts and Entertainment > Movie Theater > Indie Movie Theater
    "4bf58dd8d48988d17e941735": "movie_theater",
    // Arts and Entertainment > Museum > Art Museum
    "4bf58dd8d48988d18f941735": "art_museum",
    // Arts and Entertainment > Museum > Erotic Museum
    "559acbe0498e472f1a53fa23": "museum",
    // Arts and Entertainment > Museum > History Museum
    "4bf58dd8d48988d190941735": "history_museum",
    // Arts and Entertainment > Museum > Science Museum
    "4bf58dd8d48988d191941735": "museum",
    // Arts and Entertainment > Performing Arts Venue > Amphitheater
    "56aa371be4b08b9a8d5734db": "amphitheatre",
    // Arts and Entertainment > Performing Arts Venue > Concert Hall
    "5032792091d4c4b30a586d5c": "concert_hall",
    // Arts and Entertainment > Performing Arts Venue > Indie Theater
    "4bf58dd8d48988d135941735": "performing_arts_theater",
    // Arts and Entertainment > Performing Arts Venue > Music Venue
    "4bf58dd8d48988d1e5931735": "live_music_venue",
    // Arts and Entertainment > Performing Arts Venue > Opera House
    "4bf58dd8d48988d136941735": "opera_house",
    // Arts and Entertainment > Performing Arts Venue > Theater
    "4bf58dd8d48988d137941735": "performing_arts_theater",
    // Arts and Entertainment > Performing Arts Venue > Music Venue > Jazz and Blues Venue
    "4bf58dd8d48988d1e7931735": "live_music_venue",
    // Arts and Entertainment > Performing Arts Venue > Music Venue > Rock Club
    "4bf58dd8d48988d1e9931735": "live_music_venue",
    // Arts and Entertainment > Public Art > Outdoor Sculpture
    "52e81612bcbc57f1066b79ed": "sculpture",
    // Arts and Entertainment > Public Art > Street Art
    "52e81612bcbc57f1066b79ee": "sculpture", // Inexact
    // Arts and Entertainment > Stadium > Baseball Stadium
    "4bf58dd8d48988d18c941735": "stadium",
    // Arts and Entertainment > Stadium > Basketball Stadium
    "4bf58dd8d48988d18b941735": "stadium",
    // Arts and Entertainment > Stadium > Football Stadium
    "4bf58dd8d48988d189941735": "stadium",
    // Arts and Entertainment > Stadium > Hockey Stadium
    "4bf58dd8d48988d185941735": "stadium",
    // Arts and Entertainment > Stadium > Rugby Stadium
    "56aa371be4b08b9a8d573556": "stadium",
    // Arts and Entertainment > Stadium > Soccer Stadium
    "4bf58dd8d48988d188941735": "stadium",
    // Arts and Entertainment > Stadium > Tennis Stadium
    "4e39a891bd410d7aed40cbc2": "stadium",
    // Arts and Entertainment > Stadium > Track Stadium
    "4bf58dd8d48988d187941735": "stadium",
    // Arts and Entertainment > Zoo > Zoo Exhibit
    "58daa1558bbb0b01f18ec1fd": "zoo",
    // Business and Professional Services > Advertising Agency
    "52e81612bcbc57f1066b7a3d": "corporate_office",
    // Business and Professional Services > Agriculture and Forestry Service
    "63be6904847c3692a84b9b26": "farm",
    // Business and Professional Services > Appraiser
    "63be6904847c3692a84b9b27": "corporate_office",
    // Business and Professional Services > Architecture Firm
    "5fac002599ce226e27fe72e5": "corporate_office",
    // Business and Professional Services > Art Restoration Service
    "63be6904847c3692a84b9b28": "service",
    // Business and Professional Services > Art Studio
    "58daa1558bbb0b01f18ec1d6": "art_studio",
    // Business and Professional Services > Audiovisual Service
    "63be6904847c3692a84b9b29": "service",
    // Business and Professional Services > Auditorium
    "4bf58dd8d48988d173941735": "auditorium",
    // Business and Professional Services > Automation and Control System
    "63be6904847c3692a84b9b2a": "service",
    // Business and Professional Services > Automotive Service
    "63be6904847c3692a84b9b2b": "car_repair",
    // Business and Professional Services > Ballroom
    "56aa371be4b08b9a8d5734cf": "banquet_hall",
    // Business and Professional Services > Business Center
    "56aa371be4b08b9a8d573517": "business_center",
    // Business and Professional Services > Business Service
    "5453de49498eade8af355881": "service",
    // Business and Professional Services > Career Counselor
    "63be6904847c3692a84b9b33": "consultant",
    // Business and Professional Services > Chemicals and Gasses Manufacturer
    "63be6904847c3692a84b9b34": "manufacturer",
    // Business and Professional Services > Child Care Service
    "5744ccdfe4b0c0459246b4c7": "child_care_agency",
    // Business and Professional Services > Computer Repair Service
    "63be6904847c3692a84b9b35": "service",
    // Business and Professional Services > Construction
    "63be6904847c3692a84b9b36": "general_contractor",
    // Business and Professional Services > Convention Center
    "4bf58dd8d48988d1ff931735": "convention_center",
    // Business and Professional Services > Creative Service
    "63be6904847c3692a84b9b37": "service",
    // Business and Professional Services > Design Studio
    "4bf58dd8d48988d1f4941735": "art_studio",
    // Business and Professional Services > Direct Mail and Email Marketing Service
    "63be6904847c3692a84b9b38": "marketing_consultant",
    // Business and Professional Services > Distribution Center
    "52e81612bcbc57f1066b7a37": "supplier",
    // Business and Professional Services > Electrical Equipment Supplier
    "63be6904847c3692a84b9b39": "supplier",
    // Business and Professional Services > Employment Agency
    "52f2ab2ebcbc57f1066b8b57": "employment_agency",
    // Business and Professional Services > Engineer
    "63be6904847c3692a84b9b3a": "consultant",
    // Business and Professional Services > Entertainment Agency
    "63be6904847c3692a84b9b3b": "corporate_office",
    // Business and Professional Services > Entertainment Service
    "56aa371be4b08b9a8d573554": "service",
    // Business and Professional Services > Equipment Rental Service
    "63be6904847c3692a84b9b3c": "service",
    // Business and Professional Services > Event Service
    "5454152e498ef71e2b9132c6": "service",
    // Business and Professional Services > Event Space
    "4bf58dd8d48988d171941735": "event_venue",
    // Business and Professional Services > Factory
    "4eb1bea83b7b6f98df247e06": "manufacturer",
    // Business and Professional Services > Film Studio
    "56aa371be4b08b9a8d573523": "television_studio",
    // Business and Professional Services > Financial Service
    "63be6904847c3692a84b9b3d": "finance",
    // Business and Professional Services > Food and Beverage Service
    "56aa371be4b08b9a8d573550": "service",
    // Business and Professional Services > Funeral Home
    "4f4534884b9074f6e4fb0174": "funeral_home",
    // Business and Professional Services > Geological Service
    "63be6904847c3692a84b9b48": "service",
    // Business and Professional Services > Health and Beauty Service
    "54541900498ea6ccd0202697": "beauty_salon",
    // Business and Professional Services > Home Improvement Service
    "63be6904847c3692a84b9b58": "general_contractor",
    // Business and Professional Services > Human Resources Agency
    "63be6904847c3692a84b9b66": "employment_agency",
    // Business and Professional Services > Import and Export Service
    "63be6904847c3692a84b9b67": "service",
    // Business and Professional Services > Industrial Equipment Supplier
    "63be6904847c3692a84b9b68": "supplier",
    // Business and Professional Services > Industrial Estate
    "56aa371be4b08b9a8d5734d7": "supplier",
    // Business and Professional Services > Insurance Agency
    "58daa1558bbb0b01f18ec1f1": "insurance_agency",
    // Business and Professional Services > Laboratory
    "63be6904847c3692a84b9b69": "medical_lab",
    // Business and Professional Services > Laundromat
    "52f2ab2ebcbc57f1066b8b33": "laundry",
    // Business and Professional Services > Laundry Service
    "4bf58dd8d48988d1fc941735": "laundry",
    // Business and Professional Services > Leather Supplier
    "63be6904847c3692a84b9b6a": "supplier",
    // Business and Professional Services > Legal Service
    "63be6904847c3692a84b9b6b": "lawyer",
    // Business and Professional Services > Locksmith
    "52f2ab2ebcbc57f1066b8b1e": "locksmith",
    // Business and Professional Services > Logging Service
    "63be6904847c3692a84b9b6d": "service",
    // Business and Professional Services > Lottery Retailer
    "52f2ab2ebcbc57f1066b8b38": "store",
    // Business and Professional Services > Machine Shop
    "63be6904847c3692a84b9b6e": "manufacturer",
    // Business and Professional Services > Management Consultant
    "63be6904847c3692a84b9b6f": "consultant",
    // Business and Professional Services > Manufacturer
    "63be6904847c3692a84b9b70": "manufacturer",
    // Business and Professional Services > Market Research and Consulting Service
    "63be6904847c3692a84b9b71": "consultant",
    // Business and Professional Services > Media Agency
    "63be6904847c3692a84b9b72": "corporate_office",
    // Business and Professional Services > Metals Supplier
    "63be6904847c3692a84b9b73": "supplier",
    // Business and Professional Services > Mobile Company
    "63be6904847c3692a84b9b74": "telecommunications_service_provider",
    // Business and Professional Services > Office
    "4bf58dd8d48988d124941735": "corporate_office",
    // Business and Professional Services > Online Advertising Service
    "63be6904847c3692a84b9b77": "marketing_consultant",
    // Business and Professional Services > Outdoor Event Space
    "56aa371be4b08b9a8d57356a": "event_venue",
    // Business and Professional Services > Paper Supplier
    "63be6904847c3692a84b9b78": "supplier",
    // Business and Professional Services > Petroleum Supplier
    "63be6904847c3692a84b9b7b": "supplier",
    // Business and Professional Services > Pet Service
    "5032897c91d4c4b30a586d69": "pet_care",
    // Business and Professional Services > Photography Service
    "63be6904847c3692a84b9b7d": "service",
    // Business and Professional Services > Plastics Supplier
    "63be6904847c3692a84b9b7e": "supplier",
    // Business and Professional Services > Power Plant
    "58daa1548bbb0b01f18ec1a9": "service",
    // Business and Professional Services > Print, TV, Radio and Outdoor Advertising Service
    "63be6904847c3692a84b9b7f": "marketing_consultant",
    // Business and Professional Services > Promotional Item Service
    "63be6904847c3692a84b9b80": "marketing_consultant",
    // Business and Professional Services > Public Relations Firm
    "63be6904847c3692a84b9b81": "marketing_consultant",
    // Business and Professional Services > Publisher
    "63be6904847c3692a84b9b82": "corporate_office",
    // Business and Professional Services > Radio Station
    "5032856091d4c4b30a586d63": "corporate_office",
    // Business and Professional Services > Real Estate Service
    "63be6904847c3692a84b9b83": "real_estate_agency",
    // Business and Professional Services > Recording Studio
    "52f2ab2ebcbc57f1066b8b37": "art_studio",
    // Business and Professional Services > Recycling Facility
    "4f4531084b9074f6e4fb0101": "service",
    // Business and Professional Services > Refrigeration and Ice Supplier
    "63be6904847c3692a84b9b89": "supplier",
    // Business and Professional Services > Renewable Energy Service
    "63be6904847c3692a84b9b8a": "service",
    // Business and Professional Services > Rental Service
    "56aa371be4b08b9a8d573552": "service",
    // Business and Professional Services > Repair Service
    "52f2ab2ebcbc57f1066b8b2f": "service",
    // Business and Professional Services > Research Laboratory
    "5744ccdfe4b0c0459246b4d6": "research_institute",
    // Business and Professional Services > Research Station
    "58daa1558bbb0b01f18ec1b2": "research_institute",
    // Business and Professional Services > Rubber Supplier
    "63be6904847c3692a84b9b8b": "supplier",
    // Business and Professional Services > Salvage Yard
    "63be6904847c3692a84b9b8c": "service",
    // Business and Professional Services > Scientific Equipment Supplier
    "63be6904847c3692a84b9b8d": "supplier",
    // Business and Professional Services > Search Engine Marketing and Optimization Service
    "63be6904847c3692a84b9b8e": "marketing_consultant",
    // Business and Professional Services > Security and Safety
    "63be6904847c3692a84b9b8f": "service",
    // Business and Professional Services > Shipping, Freight, and Material Transportation Service
    "52f2ab2ebcbc57f1066b8b1f": "shipping_service",
    // Business and Professional Services > Shoe Repair Service
    "52f2ab2ebcbc57f1066b8b39": "service",
    // Business and Professional Services > Storage Facility
    "4f04b1572fb6e1c99f3db0bf": "storage",
    // Business and Professional Services > Tailor
    "5032781d91d4c4b30a586d5b": "tailor",
    // Business and Professional Services > Technology Business
    "63be6904847c3692a84b9b90": "corporate_office",
    // Business and Professional Services > Telecommunication Service
    "63be6904847c3692a84b9b93": "telecommunications_service_provider",
    // Business and Professional Services > Translation Service
    "63be6904847c3692a84b9b94": "service",
    // Business and Professional Services > Tutoring Service
    "63be6904847c3692a84b9b95": "school", // Inexact
    // Business and Professional Services > TV Station
    "52e81612bcbc57f1066b7a31": "television_studio",
    // Business and Professional Services > Warehouse
    "52e81612bcbc57f1066b7a36": "warehouse_store", // Inexact
    // Business and Professional Services > Waste Management Service
    "58daa1558bbb0b01f18ec1ac": "service",
    // Business and Professional Services > Water Treatment Service
    "63be6904847c3692a84b9b96": "service",
    // Business and Professional Services > Wedding Hall
    "56aa371be4b08b9a8d5734c5": "wedding_venue",
    // Business and Professional Services > Welding Service
    "63be6904847c3692a84b9b97": "service",
    // Business and Professional Services > Wholesaler
    "63be6904847c3692a84b9b98": "wholesaler",
    // Business and Professional Services > Writing, Copywriting and Technical Writing Service
    "63be6904847c3692a84b9b99": "service",
    // Business and Professional Services > Automotive Service > Automotive Repair Shop
    "52f2ab2ebcbc57f1066b8b44": "car_repair",
    // Business and Professional Services > Automotive Service > Car Wash and Detail
    "4f04ae1f2fb6e1c99f3db0ba": "car_wash",
    // Business and Professional Services > Automotive Service > Motorcycle Repair Shop
    "63be6904847c3692a84b9b2c": "car_repair",
    // Business and Professional Services > Automotive Service > Oil Change Service
    "63be6904847c3692a84b9b2d": "car_repair",
    // Business and Professional Services > Automotive Service > Smog Check Shop
    "63be6904847c3692a84b9b2e": "car_repair",
    // Business and Professional Services > Automotive Service > Tire Repair Shop
    "63be6904847c3692a84b9b2f": "tire_shop",
    // Business and Professional Services > Automotive Service > Towing Service
    "63be6904847c3692a84b9b30": "car_repair",
    // Business and Professional Services > Automotive Service > Transmissions Shop
    "63be6904847c3692a84b9b31": "car_repair",
    // Business and Professional Services > Automotive Service > Vehicle Inspection Station
    "5f2c1e0db6d05514c70436d4": "car_repair",
    // Business and Professional Services > Child Care Service > Daycare
    "4f4532974b9074f6e4fb0104": "child_care_agency",
    // Business and Professional Services > Convention Center > Conference Room
    "4bf58dd8d48988d100941735": "convention_center",
    // Business and Professional Services > Financial Service > Accounting and Bookkeeping Service
    "63be6904847c3692a84b9b3e": "accounting",
    // Business and Professional Services > Financial Service > Banking and Finance
    "63be6904847c3692a84b9b3f": "bank",
    // Business and Professional Services > Financial Service > Business Broker
    "63be6904847c3692a84b9b40": "finance",
    // Business and Professional Services > Financial Service > Check Cashing Service
    "52f2ab2ebcbc57f1066b8b2d": "finance",
    // Business and Professional Services > Financial Service > Collections Service
    "63be6904847c3692a84b9b41": "finance",
    // Business and Professional Services > Financial Service > Credit Counseling and Bankruptcy Service
    "63be6904847c3692a84b9b42": "finance",
    // Business and Professional Services > Financial Service > Currency Exchange
    "5744ccdfe4b0c0459246b4be": "finance",
    // Business and Professional Services > Financial Service > Financial Planner
    "63be6904847c3692a84b9b43": "finance",
    // Business and Professional Services > Financial Service > Loans Agency
    "63be6904847c3692a84b9b44": "finance",
    // Business and Professional Services > Financial Service > Stock Broker
    "63be6904847c3692a84b9b45": "finance",
    // Business and Professional Services > Financial Service > Banking and Finance > ATM
    "52f2ab2ebcbc57f1066b8b56": "atm",
    // Business and Professional Services > Financial Service > Banking and Finance > Bank
    "4bf58dd8d48988d10a951735": "bank",
    // Business and Professional Services > Financial Service > Banking and Finance > Credit Union
    "5032850891d4c4b30a586d62": "bank",
    // Business and Professional Services > Food and Beverage Service > Caterer
    "63be6904847c3692a84b9b46": "catering_service",
    // Business and Professional Services > Food and Beverage Service > Food Distribution Center
    "63be6904847c3692a84b9b47": "supplier",
    // Business and Professional Services > Health and Beauty Service > Barbershop
    "63be6904847c3692a84b9b49": "barber_shop",
    // Business and Professional Services > Health and Beauty Service > Bath House
    "52e81612bcbc57f1066b7a27": "public_bath",
    // Business and Professional Services > Health and Beauty Service > Body Piercing Shop
    "52f2ab2ebcbc57f1066b8b20": "body_art_service",
    // Business and Professional Services > Health and Beauty Service > Dry Cleaner
    "52f2ab2ebcbc57f1066b8b1d": "laundry",
    // Business and Professional Services > Health and Beauty Service > Hair Removal Service
    "63be6904847c3692a84b9b4a": "beauty_salon",
    // Business and Professional Services > Health and Beauty Service > Hair Salon
    "4bf58dd8d48988d110951735": "hair_salon",
    // Business and Professional Services > Health and Beauty Service > Massage Clinic
    "52f2ab2ebcbc57f1066b8b3c": "massage",
    // Business and Professional Services > Health and Beauty Service > Nail Salon
    "4f04aa0c2fb6e1c99f3db0b8": "nail_salon",
    // Business and Professional Services > Health and Beauty Service > Skin Care Clinic
    "63be6904847c3692a84b9b4b": "skin_care_clinic",
    // Business and Professional Services > Health and Beauty Service > Spa
    "4bf58dd8d48988d1ed941735": "spa",
    // Business and Professional Services > Health and Beauty Service > Tanning Salon
    "4d1cf8421a97d635ce361c31": "tanning_studio",
    // Business and Professional Services > Health and Beauty Service > Tattoo Parlor
    "4bf58dd8d48988d1de931735": "body_art_service",
    // Business and Professional Services > Home Improvement Service > Bathroom Contractor
    "63be6904847c3692a84b9b4c": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Carpenter
    "63be6904847c3692a84b9b4d": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Carpet and Flooring Contractor
    "63be6904847c3692a84b9b4e": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Chimney Sweep
    "63be6904847c3692a84b9b4f": "service",
    // Business and Professional Services > Home Improvement Service > Deck and Patio Contractor
    "63be6904847c3692a84b9b50": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Doors and Windows Contractor
    "63be6904847c3692a84b9b51": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Electrician
    "63be6904847c3692a84b9b52": "electrician",
    // Business and Professional Services > Home Improvement Service > Fence Contractor
    "63be6904847c3692a84b9b53": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Garage Door Supplier
    "63be6904847c3692a84b9b54": "general_contractor",
    // Business and Professional Services > Home Improvement Service > General Contractor
    "63be6904847c3692a84b9b55": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Heating, Ventilating and Air Conditioning Contractor
    "63be6904847c3692a84b9b56": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Home Inspection
    "63be6904847c3692a84b9b57": "service",
    // Business and Professional Services > Home Improvement Service > Home Service
    "545419b1498ea6ccd0202f58": "service",
    // Business and Professional Services > Home Improvement Service > Interior Designer
    "63be6904847c3692a84b9b59": "consultant",
    // Business and Professional Services > Home Improvement Service > Kitchen Remodeler
    "63be6904847c3692a84b9b5a": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Landscaper and Gardener
    "63be6904847c3692a84b9b5b": "service",
    // Business and Professional Services > Home Improvement Service > Mover
    "63be6904847c3692a84b9b5c": "moving_company",
    // Business and Professional Services > Home Improvement Service > Painter
    "63be6904847c3692a84b9b5d": "painter",
    // Business and Professional Services > Home Improvement Service > Pest Control Service
    "63be6904847c3692a84b9b5e": "service",
    // Business and Professional Services > Home Improvement Service > Plumber
    "63be6904847c3692a84b9b5f": "plumber",
    // Business and Professional Services > Home Improvement Service > Professional Cleaning Service
    "63be6904847c3692a84b9b60": "service",
    // Business and Professional Services > Home Improvement Service > Roofer
    "63be6904847c3692a84b9b61": "roofing_contractor",
    // Business and Professional Services > Home Improvement Service > Sewer Contractor
    "63be6904847c3692a84b9b62": "general_contractor",
    // Business and Professional Services > Home Improvement Service > Swimming Pool Maintenance and Service
    "63be6904847c3692a84b9b63": "service",
    // Business and Professional Services > Home Improvement Service > Tree Service
    "63be6904847c3692a84b9b64": "service",
    // Business and Professional Services > Home Improvement Service > Upholstery Service
    "63be6904847c3692a84b9b65": "service",
    // Business and Professional Services > Legal Service > Immigration Attorney
    "63be6904847c3692a84b9b6c": "lawyer",
    // Business and Professional Services > Legal Service > Law Office
    "52f2ab2ebcbc57f1066b8b3f": "lawyer",
    // Business and Professional Services > Legal Service > Notary
    "5ae95d208a6f17002ce792b2": "lawyer",
    // Business and Professional Services > Office > Business and Strategy Consulting Office
    "63be6904847c3692a84b9b32": "consultant",
    // Business and Professional Services > Office > Campaign Office
    "5032764e91d4c4b30a586d5a": "corporate_office",
    // Business and Professional Services > Office > Corporate Amenity
    "5665ef1d498ec706735f0e59": "corporate_office",
    // Business and Professional Services > Office > Corporate Cafeteria
    "54f4ba06498e2cf5561da814": "cafeteria",
    // Business and Professional Services > Office > Corporate Coffee Shop
    "5665c7b9498e7d8a4f2c0f06": "coffee_shop",
    // Business and Professional Services > Office > Corporate Housing Agency
    "63be6904847c3692a84b9b75": "real_estate_agency",
    // Business and Professional Services > Office > Coworking Space
    "4bf58dd8d48988d174941735": "coworking_space",
    // Business and Professional Services > Office > Meeting Room
    "4bf58dd8d48988d127941735": "convention_center",
    // Business and Professional Services > Office > Office Building
    "63be6904847c3692a84b9b76": "corporate_office",
    // Business and Professional Services > Office > Tech Startup
    "4bf58dd8d48988d125941735": "corporate_office",
    // Business and Professional Services > Pet Service > Pet Grooming Service
    "63be6904847c3692a84b9b79": "pet_care",
    // Business and Professional Services > Pet Service > Pet Sitting and Boarding Service
    "63be6904847c3692a84b9b7a": "pet_boarding_service",
    // Business and Professional Services > Photography Service > Photographer
    "63be6904847c3692a84b9b7c": "service",
    // Business and Professional Services > Photography Service > Photography Lab
    "4eb1bdde3b7b55596b4a7490": "service",
    // Business and Professional Services > Photography Service > Photography Studio
    "554a5e17498efabeda6cc559": "art_studio",
    // Business and Professional Services > Real Estate Service > Building and Land Surveyor
    "63be6904847c3692a84b9b84": "service",
    // Business and Professional Services > Real Estate Service > Commercial Real Estate Developer
    "63be6904847c3692a84b9b85": "real_estate_agency",
    // Business and Professional Services > Real Estate Service > Property Management Office
    "63be6904847c3692a84b9b86": "real_estate_agency",
    // Business and Professional Services > Real Estate Service > Real Estate Agency
    "5032885091d4c4b30a586d66": "real_estate_agency",
    // Business and Professional Services > Real Estate Service > Real Estate Appraiser
    "63be6904847c3692a84b9b87": "real_estate_agency",
    // Business and Professional Services > Real Estate Service > Real Estate Development and Title Company
    "63be6904847c3692a84b9b88": "real_estate_agency",
    // Business and Professional Services > Technology Business > IT Service
    "52f2ab2ebcbc57f1066b8b36": "service",
    // Business and Professional Services > Technology Business > Software Company
    "63be6904847c3692a84b9b91": "corporate_office",
    // Business and Professional Services > Technology Business > Website Designer
    "63be6904847c3692a84b9b92": "service",
    // Community and Government > Addiction Treatment Center
    "63be6904847c3692a84b9b9b": "medical_clinic", // Inexact
    // Community and Government > Animal Shelter
    "4e52d2d203646f7c19daa8ae": "pet_care",
    // Community and Government > Assisted Living
    "5032891291d4c4b30a586d68": "health", // Inexact
    // Community and Government > Cemetery
    "4bf58dd8d48988d15c941735": "cemetery",
    // Community and Government > Community Center
    "52e81612bcbc57f1066b7a34": "community_center",
    // Community and Government > Cultural Center
    "52e81612bcbc57f1066b7a32": "cultural_center",
    // Community and Government > Disabled Persons Service
    "63be6904847c3692a84b9b9c": "service",
    // Community and Government > Domestic Abuse Treatment Center
    "63be6904847c3692a84b9b9d": "service", // Inexact
    // Community and Government > Dump
    "63be6904847c3692a84b9b9e": "service",
    // Community and Government > Education
    "4bf58dd8d48988d13b941735": "educational_institution",
    // Community and Government > Government Building
    "4bf58dd8d48988d126941735": "government_office",
    // Community and Government > Government Lobbyist
    "63be6904847c3692a84b9ba7": "government_office",
    // Community and Government > Homeless Shelter
    "63be6904847c3692a84b9ba8": "service", // Inexact
    // Community and Government > Housing Authority
    "63be6904847c3692a84b9ba9": "government_office",
    // Community and Government > Housing Development
    "4f2a210c4b9023bd5841ed28": "housing_complex",
    // Community and Government > Library
    "4bf58dd8d48988d12f941735": "library",
    // Community and Government > Observatory
    "5744ccdfe4b0c0459246b4d9": "planetarium", // Inexact
    // Community and Government > Organization
    "63be6904847c3692a84b9baa": "association_or_organization",
    // Community and Government > Polling Place
    "4cae28ecbf23941eb1190695": "government_office",
    // Community and Government > Prison
    "5310b8e5bcbc57f1066bcbf1": "establishment", // Inexact
    // Community and Government > Public and Social Service
    "63be6904847c3692a84b9bb1": "local_government_office",
    // Community and Government > Public Bathroom
    "5744ccdfe4b0c0459246b4c4": "public_bathroom",
    // Community and Government > Rehabilitation Center
    "56aa371be4b08b9a8d57351d": "medical_center",
    // Community and Government > Residential Building
    "4e67e38e036454776db1fb3a": "apartment_building",
    // Community and Government > Retirement Home
    "63be6904847c3692a84b9bb2": "establishment", // Inexact
    // Community and Government > Senior Citizen Service
    "63be6904847c3692a84b9bb3": "service",
    // Community and Government > Social Club
    "52e81612bcbc57f1066b7a33": "association_or_organization",
    // Community and Government > Spiritual Center
    "4bf58dd8d48988d131941735": "place_of_worship",
    // Community and Government > Summer Camp
    "52e81612bcbc57f1066b7a10": "childrens_camp",
    // Community and Government > Town Hall
    "52e81612bcbc57f1066b7a38": "city_hall",
    // Community and Government > Trailer Park
    "52f2ab2ebcbc57f1066b8b55": "mobile_home_park",
    // Community and Government > Utility Company
    "63be6904847c3692a84b9bb4": "service",
    // Community and Government > Education > Adult Education
    "56aa371ce4b08b9a8d573570": "school",
    // Community and Government > Education > Art School
    "63be6904847c3692a84b9b9f": "school",
    // Community and Government > Education > Circus School
    "52e81612bcbc57f1066b7a43": "school",
    // Community and Government > Education > College and University
    "4d4b7105d754a06372d81259": "university",
    // Community and Government > Education > Computer Training School
    "63be6904847c3692a84b9ba0": "school",
    // Community and Government > Education > Culinary School
    "58daa1558bbb0b01f18ec200": "school",
    // Community and Government > Education > Driving School
    "52e81612bcbc57f1066b7a42": "school",
    // Community and Government > Education > Flight School
    "52e81612bcbc57f1066b7a49": "school",
    // Community and Government > Education > Language School
    "52e81612bcbc57f1066b7a48": "school",
    // Community and Government > Education > Music School
    "4f04b10d2fb6e1c99f3db0be": "school",
    // Community and Government > Education > Nursery School
    "4f4533814b9074f6e4fb0107": "preschool",
    // Community and Government > Education > Preschool
    "52e81612bcbc57f1066b7a45": "preschool",
    // Community and Government > Education > Primary and Secondary School
    "63be6904847c3692a84b9ba1": "school",
    // Community and Government > Education > Private School
    "52e81612bcbc57f1066b7a46": "school",
    // Community and Government > Education > Religious School
    "52e81612bcbc57f1066b7a47": "school",
    // Community and Government > Education > Trade School
    "4bf58dd8d48988d1ad941735": "school",
    // Community and Government > Education > College and University > College Academic Building
    "4bf58dd8d48988d198941735": "university",
    // Community and Government > Education > College and University > College Administrative Building
    "4bf58dd8d48988d197941735": "university",
    // Community and Government > Education > College and University > College Arts Building
    "4bf58dd8d48988d199941735": "university",
    // Community and Government > Education > College and University > College Auditorium
    "4bf58dd8d48988d1af941735": "auditorium",
    // Community and Government > Education > College and University > College Baseball Diamond
    "4bf58dd8d48988d1bb941735": "athletic_field",
    // Community and Government > Education > College and University > College Basketball Court
    "4bf58dd8d48988d1ba941735": "sports_complex",
    // Community and Government > Education > College and University > College Bookstore
    "4bf58dd8d48988d1b1941735": "book_store",
    // Community and Government > Education > College and University > College Cafeteria
    "4bf58dd8d48988d1a1941735": "cafeteria",
    // Community and Government > Education > College and University > College Classroom
    "4bf58dd8d48988d1a0941735": "university",
    // Community and Government > Education > College and University > College Communications Building
    "4bf58dd8d48988d19a941735": "university",
    // Community and Government > Education > College and University > College Cricket Pitch
    "4bf58dd8d48988d1b9941735": "athletic_field",
    // Community and Government > Education > College and University > College Engineering Building
    "4bf58dd8d48988d19e941735": "university",
    // Community and Government > Education > College and University > College Football Field
    "4bf58dd8d48988d1b8941735": "athletic_field",
    // Community and Government > Education > College and University > College Gym
    "4bf58dd8d48988d1b2941735": "gym",
    // Community and Government > Education > College and University > College History Building
    "4bf58dd8d48988d19d941735": "university",
    // Community and Government > Education > College and University > College Hockey Rink
    "4bf58dd8d48988d1b5941735": "ice_skating_rink",
    // Community and Government > Education > College and University > College Lab
    "4bf58dd8d48988d1a5941735": "university",
    // Community and Government > Education > College and University > College Library
    "4bf58dd8d48988d1a7941735": "library",
    // Community and Government > Education > College and University > College Math Building
    "4bf58dd8d48988d19c941735": "university",
    // Community and Government > Education > College and University > College Quad
    "4bf58dd8d48988d1aa941735": "university",
    // Community and Government > Education > College and University > College Rec Center
    "4bf58dd8d48988d1a9941735": "fitness_center",
    // Community and Government > Education > College and University > College Residence Hall
    "4bf58dd8d48988d1a3941735": "university",
    // Community and Government > Education > College and University > College Science Building
    "4bf58dd8d48988d19b941735": "university",
    // Community and Government > Education > College and University > College Soccer Field
    "4bf58dd8d48988d1b7941735": "athletic_field",
    // Community and Government > Education > College and University > College Stadium
    "4bf58dd8d48988d1b4941735": "stadium",
    // Community and Government > Education > College and University > College Technology Building
    "4bf58dd8d48988d19f941735": "university",
    // Community and Government > Education > College and University > College Tennis Court
    "4e39a9cebd410d7aed40cbc4": "tennis_court",
    // Community and Government > Education > College and University > College Theater
    "4bf58dd8d48988d1ac941735": "performing_arts_theater",
    // Community and Government > Education > College and University > College Track
    "4bf58dd8d48988d1b6941735": "athletic_field",
    // Community and Government > Education > College and University > Community College
    "4bf58dd8d48988d1a2941735": "university",
    // Community and Government > Education > College and University > Fraternity House
    "4bf58dd8d48988d1b0941735": "university",
    // Community and Government > Education > College and University > Law School
    "4bf58dd8d48988d1a6941735": "university",
    // Community and Government > Education > College and University > Medical School
    "4bf58dd8d48988d1b3941735": "university",
    // Community and Government > Education > College and University > Sorority House
    "4bf58dd8d48988d141941735": "university",
    // Community and Government > Education > College and University > Student Center
    "4bf58dd8d48988d1ab941735": "university",
    // Community and Government > Education > College and University > University
    "4bf58dd8d48988d1ae941735": "university",
    // Community and Government > Education > Primary and Secondary School > Elementary School
    "4f4533804b9074f6e4fb0105": "primary_school",
    // Community and Government > Education > Primary and Secondary School > High School
    "4bf58dd8d48988d13d941735": "secondary_school",
    // Community and Government > Education > Primary and Secondary School > Middle School
    "4f4533814b9074f6e4fb0106": "primary_school",
    // Community and Government > Government Building > Capitol Building
    "4bf58dd8d48988d12a941735": "government_office",
    // Community and Government > Government Building > City Hall
    "4bf58dd8d48988d129941735": "city_hall",
    // Community and Government > Government Building > Courthouse
    "4bf58dd8d48988d12b941735": "courthouse",
    // Community and Government > Government Building > Embassy or Consulate
    "4bf58dd8d48988d12c951735": "embassy",
    // Community and Government > Government Building > Government Department
    "63be6904847c3692a84b9ba2": "government_office",
    // Community and Government > Government Building > Law Enforcement and Public Safety
    "63be6904847c3692a84b9ba3": "police",
    // Community and Government > Government Building > Military
    "63be6904847c3692a84b9ba6": "government_office",
    // Community and Government > Government Building > Post Office
    "4bf58dd8d48988d172941735": "post_office",
    // Community and Government > Government Building > Law Enforcement and Public Safety > Fire Station
    "4bf58dd8d48988d12c941735": "fire_station",
    // Community and Government > Government Building > Law Enforcement and Public Safety > Police Station
    "4bf58dd8d48988d12e941735": "police",
    // Community and Government > Government Building > Law Enforcement and Public Safety > Probation Office
    "63be6904847c3692a84b9ba4": "government_office",
    // Community and Government > Government Building > Law Enforcement and Public Safety > Rescue Service
    "63be6904847c3692a84b9ba5": "fire_station",
    // Community and Government > Government Building > Military > Military Base
    "4e52adeebd41615f56317744": "government_office",
    // Community and Government > Organization > Charity
    "63be6904847c3692a84b9bab": "non_profit_organization",
    // Community and Government > Organization > Club House
    "52e81612bcbc57f1066b7a35": "association_or_organization",
    // Community and Government > Organization > Environmental Organization
    "63be6904847c3692a84b9bac": "non_profit_organization",
    // Community and Government > Organization > Labor Union
    "63be6904847c3692a84b9bad": "association_or_organization",
    // Community and Government > Organization > LGBTQ Organization
    "63be6904847c3692a84b9bae": "non_profit_organization",
    // Community and Government > Organization > Non-Profit Organization
    "50328a8e91d4c4b30a586d6c": "non_profit_organization",
    // Community and Government > Organization > Social Services Organization
    "63be6904847c3692a84b9baf": "non_profit_organization",
    // Community and Government > Organization > Veterans' Organization
    "5f2c5de85b4c177b9a6de29c": "non_profit_organization",
    // Community and Government > Organization > Youth Organization
    "63be6904847c3692a84b9bb0": "non_profit_organization",
    // Community and Government > Residential Building > Apartment or Condo
    "4d954b06a243a5684965b473": "apartment_building",
    // Community and Government > Residential Building > Home (private)
    "4bf58dd8d48988d103941735": "premise", // Inexact. Might warrant a non-Google category
    // Community and Government > Spiritual Center > Buddhist Temple
    "52e81612bcbc57f1066b7a3e": "buddhist_temple",
    // Community and Government > Spiritual Center > Cemevi
    "58daa1558bbb0b01f18ec1eb": "place_of_worship",
    // Community and Government > Spiritual Center > Church
    "4bf58dd8d48988d132941735": "church",
    // Community and Government > Spiritual Center > Confucian Temple
    "56aa371be4b08b9a8d5734fc": "place_of_worship",
    // Community and Government > Spiritual Center > Hindu Temple
    "52e81612bcbc57f1066b7a3f": "hindu_temple",
    // Community and Government > Spiritual Center > Kingdom Hall
    "5744ccdfe4b0c0459246b4ac": "place_of_worship",
    // Community and Government > Spiritual Center > Monastery
    "52e81612bcbc57f1066b7a40": "place_of_worship",
    // Community and Government > Spiritual Center > Mosque
    "4bf58dd8d48988d138941735": "mosque",
    // Community and Government > Spiritual Center > Prayer Room
    "52e81612bcbc57f1066b7a41": "place_of_worship",
    // Community and Government > Spiritual Center > Shrine
    "4eb1d80a4b900d56c88a45ff": "shinto_shrine", // Inexact
    // Community and Government > Spiritual Center > Sikh Temple
    "5bae9231bedf3950379f89c9": "place_of_worship",
    // Community and Government > Spiritual Center > Synagogue
    "4bf58dd8d48988d139941735": "synagogue",
    // Community and Government > Spiritual Center > Temple
    "4bf58dd8d48988d13a941735": "place_of_worship",
    // Community and Government > Spiritual Center > Terreiro
    "56aa371be4b08b9a8d5734f6": "place_of_worship",
    // Dining and Drinking > Bagel Shop
    "4bf58dd8d48988d179941735": "bagel_shop",
    // Dining and Drinking > Bakery
    "4bf58dd8d48988d16a941735": "bakery",
    // Dining and Drinking > Bar
    "4bf58dd8d48988d116941735": "bar",
    // Dining and Drinking > Breakfast Spot
    "4bf58dd8d48988d143941735": "breakfast_restaurant",
    // Dining and Drinking > Brewery
    "50327c8591d4c4b30a586d5d": "brewery",
    // Dining and Drinking > Cafe, Coffee, and Tea House
    "63be6904847c3692a84b9bb6": "coffee_shop",
    // Dining and Drinking > Cafeteria
    "4bf58dd8d48988d128941735": "cafeteria",
    // Dining and Drinking > Cidery
    "5e189fd6eee47d000759bbfd": "brewery", // Inexact
    // Dining and Drinking > Creperie
    "52e81612bcbc57f1066b79f2": "restaurant", // Inexact
    // Dining and Drinking > Dessert Shop
    "4bf58dd8d48988d1d0941735": "dessert_shop",
    // Dining and Drinking > Distillery
    "4e0e22f5a56208c4ea9a85a0": "brewery", // Inexact
    // Dining and Drinking > Donut Shop
    "4bf58dd8d48988d148941735": "donut_shop",
    // Dining and Drinking > Food Court
    "4bf58dd8d48988d120951735": "food_court",
    // Dining and Drinking > Food Stand
    "56aa371be4b08b9a8d57350b": "snack_bar",
    // Dining and Drinking > Food Truck
    "4bf58dd8d48988d1cb941735": "meal_takeaway", // Inexact
    // Dining and Drinking > Juice Bar
    "4bf58dd8d48988d112941735": "juice_shop",
    // Dining and Drinking > Meadery
    "5e189d71eee47d000759b7e2": "brewery", // Inexact
    // Dining and Drinking > Night Market
    "53e510b7498ebcb1801b55d4": "market",
    // Dining and Drinking > Restaurant
    "4d4b7105d754a06374d81259": "restaurant",
    // Dining and Drinking > Smoothie Shop
    "52f2ab2ebcbc57f1066b8b41": "juice_shop",
    // Dining and Drinking > Snack Place
    "4bf58dd8d48988d1c7941735": "snack_bar",
    // Dining and Drinking > Vineyard
    "4bf58dd8d48988d1de941735": "vineyard",
    // Dining and Drinking > Winery
    "4bf58dd8d48988d14b941735": "winery",
    // Dining and Drinking > Bar > Apres Ski Bar
    "4bf58dd8d48988d1ea941735": "bar",
    // Dining and Drinking > Bar > Beach Bar
    "52e81612bcbc57f1066b7a0d": "bar",
    // Dining and Drinking > Bar > Beer Bar
    "56aa371ce4b08b9a8d57356c": "bar",
    // Dining and Drinking > Bar > Beer Garden
    "4bf58dd8d48988d117941735": "beer_garden",
    // Dining and Drinking > Bar > Champagne Bar
    "52e81612bcbc57f1066b7a0e": "wine_bar",
    // Dining and Drinking > Bar > Cocktail Bar
    "4bf58dd8d48988d11e941735": "cocktail_bar",
    // Dining and Drinking > Bar > Dive Bar
    "4bf58dd8d48988d118941735": "bar",
    // Dining and Drinking > Bar > Gay Bar
    "4bf58dd8d48988d1d8941735": "bar",
    // Dining and Drinking > Bar > Hookah Bar
    "4bf58dd8d48988d119941735": "hookah_bar",
    // Dining and Drinking > Bar > Hotel Bar
    "4bf58dd8d48988d1d5941735": "bar",
    // Dining and Drinking > Bar > Ice Bar
    "5f2c40f15b4c177b9a6dc684": "bar",
    // Dining and Drinking > Bar > Irish Pub
    "52e81612bcbc57f1066b7a06": "irish_pub",
    // Dining and Drinking > Bar > Karaoke Bar
    "4bf58dd8d48988d120941735": "karaoke",
    // Dining and Drinking > Bar > Lounge
    "4bf58dd8d48988d121941735": "lounge_bar",
    // Dining and Drinking > Bar > Piano Bar
    "4bf58dd8d48988d1e8931735": "lounge_bar",
    // Dining and Drinking > Bar > Pub
    "4bf58dd8d48988d11b941735": "pub",
    // Dining and Drinking > Bar > Rooftop Bar
    "5f2c224bb6d05514c70440a3": "bar",
    // Dining and Drinking > Bar > Sake Bar
    "4bf58dd8d48988d11c941735": "bar",
    // Dining and Drinking > Bar > Speakeasy
    "4bf58dd8d48988d1d4941735": "cocktail_bar",
    // Dining and Drinking > Bar > Sports Bar
    "4bf58dd8d48988d11d941735": "sports_bar",
    // Dining and Drinking > Bar > Tiki Bar
    "56aa371be4b08b9a8d57354d": "bar",
    // Dining and Drinking > Bar > Whisky Bar
    "4bf58dd8d48988d122941735": "bar",
    // Dining and Drinking > Bar > Wine Bar
    "4bf58dd8d48988d123941735": "wine_bar",
    // Dining and Drinking > Cafe, Coffee, and Tea House > Bubble Tea Shop
    "52e81612bcbc57f1066b7a0c": "tea_house",
    // Dining and Drinking > Cafe, Coffee, and Tea House > Café
    "4bf58dd8d48988d16d941735": "cafe",
    // Dining and Drinking > Cafe, Coffee, and Tea House > Coffee Shop
    "4bf58dd8d48988d1e0931735": "coffee_shop",
    // Dining and Drinking > Cafe, Coffee, and Tea House > Pet Café
    "56aa371be4b08b9a8d573508": "cat_cafe", // Inexact
    // Dining and Drinking > Cafe, Coffee, and Tea House > Tea Room
    "4bf58dd8d48988d1dc931735": "tea_house",
    // Dining and Drinking > Dessert Shop > Cupcake Shop
    "4bf58dd8d48988d1bc941735": "dessert_shop",
    // Dining and Drinking > Dessert Shop > Frozen Yogurt Shop
    "512e7cae91d4cbb4e5efe0af": "ice_cream_shop",
    // Dining and Drinking > Dessert Shop > Gelato Shop
    "5f2c407c5b4c177b9a6dc536": "ice_cream_shop",
    // Dining and Drinking > Dessert Shop > Ice Cream Parlor
    "4bf58dd8d48988d1c9941735": "ice_cream_shop",
    // Dining and Drinking > Dessert Shop > Pastry Shop
    "5744ccdfe4b0c0459246b4e2": "pastry_shop",
    // Dining and Drinking > Dessert Shop > Pie Shop
    "52e81612bcbc57f1066b7a0a": "dessert_shop",
    // Dining and Drinking > Dessert Shop > Waffle Shop
    "62d5af45da6648532de303ee": "dessert_shop",
    // Dining and Drinking > Restaurant > Afghan Restaurant
    "503288ae91d4c4b30a586d67": "afghani_restaurant",
    // Dining and Drinking > Restaurant > African Restaurant
    "4bf58dd8d48988d1c8941735": "african_restaurant",
    // Dining and Drinking > Restaurant > American Restaurant
    "4bf58dd8d48988d14e941735": "american_restaurant",
    // Dining and Drinking > Restaurant > Armenian Restaurant
    "5f2c2b7db6d05514c7044837": "restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant
    "4bf58dd8d48988d142941735": "asian_restaurant",
    // Dining and Drinking > Restaurant > Australian Restaurant
    "4bf58dd8d48988d169941735": "australian_restaurant",
    // Dining and Drinking > Restaurant > Austrian Restaurant
    "52e81612bcbc57f1066b7a01": "austrian_restaurant",
    // Dining and Drinking > Restaurant > Bangladeshi Restaurant
    "5e179ee74ae8e90006e9a746": "bangladeshi_restaurant",
    // Dining and Drinking > Restaurant > BBQ Joint
    "4bf58dd8d48988d1df931735": "barbecue_restaurant",
    // Dining and Drinking > Restaurant > Belgian Restaurant
    "52e81612bcbc57f1066b7a02": "belgian_restaurant",
    // Dining and Drinking > Restaurant > Bistro
    "52e81612bcbc57f1066b79f1": "bistro",
    // Dining and Drinking > Restaurant > Buffet
    "52e81612bcbc57f1066b79f4": "buffet_restaurant",
    // Dining and Drinking > Restaurant > Burger Joint
    "4bf58dd8d48988d16c941735": "hamburger_restaurant",
    // Dining and Drinking > Restaurant > Cajun and Creole Restaurant
    "4bf58dd8d48988d17a941735": "cajun_restaurant",
    // Dining and Drinking > Restaurant > Caribbean Restaurant
    "4bf58dd8d48988d144941735": "caribbean_restaurant",
    // Dining and Drinking > Restaurant > Caucasian Restaurant
    "5293a7d53cf9994f4e043a45": "restaurant",
    // Dining and Drinking > Restaurant > Comfort Food Restaurant
    "52e81612bcbc57f1066b7a00": "american_restaurant",
    // Dining and Drinking > Restaurant > Czech Restaurant
    "52f2ae52bcbc57f1066b8b81": "czech_restaurant",
    // Dining and Drinking > Restaurant > Deli
    "4bf58dd8d48988d146941735": "deli",
    // Dining and Drinking > Restaurant > Diner
    "4bf58dd8d48988d147941735": "diner",
    // Dining and Drinking > Restaurant > Dumpling Restaurant
    "4bf58dd8d48988d108941735": "dumpling_restaurant",
    // Dining and Drinking > Restaurant > Dutch Restaurant
    "5744ccdfe4b0c0459246b4d0": "dutch_restaurant",
    // Dining and Drinking > Restaurant > Eastern European Restaurant
    "4bf58dd8d48988d109941735": "eastern_european_restaurant",
    // Dining and Drinking > Restaurant > English Restaurant
    "52e81612bcbc57f1066b7a05": "british_restaurant",
    // Dining and Drinking > Restaurant > Falafel Restaurant
    "4bf58dd8d48988d10b941735": "falafel_restaurant",
    // Dining and Drinking > Restaurant > Fast Food Restaurant
    "4bf58dd8d48988d16e941735": "fast_food_restaurant",
    // Dining and Drinking > Restaurant > Fish and Chips Shop
    "4edd64a0c7ddd24ca188df1a": "fish_and_chips_restaurant",
    // Dining and Drinking > Restaurant > Fondue Restaurant
    "52e81612bcbc57f1066b7a09": "fondue_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant
    "4bf58dd8d48988d10c941735": "french_restaurant",
    // Dining and Drinking > Restaurant > Fried Chicken Joint
    "4d4ae6fc7a7b7dea34424761": "chicken_restaurant",
    // Dining and Drinking > Restaurant > Friterie
    "55d25775498e9f6a0816a37a": "fast_food_restaurant",
    // Dining and Drinking > Restaurant > Gastropub
    "4bf58dd8d48988d155941735": "gastropub",
    // Dining and Drinking > Restaurant > German Restaurant
    "4bf58dd8d48988d10d941735": "german_restaurant",
    // Dining and Drinking > Restaurant > Gluten-Free Restaurant
    "4c2cd86ed066bed06c3c5209": "restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant
    "4bf58dd8d48988d10e941735": "greek_restaurant",
    // Dining and Drinking > Restaurant > Halal Restaurant
    "52e81612bcbc57f1066b79ff": "halal_restaurant",
    // Dining and Drinking > Restaurant > Hawaiian Restaurant
    "52e81612bcbc57f1066b79fe": "hawaiian_restaurant",
    // Dining and Drinking > Restaurant > Hot Dog Joint
    "4bf58dd8d48988d16f941735": "hot_dog_restaurant",
    // Dining and Drinking > Restaurant > Hungarian Restaurant
    "52e81612bcbc57f1066b79fa": "hungarian_restaurant",
    // Dining and Drinking > Restaurant > Indian Chinese Restaurant
    "54135bf5e4b08f3d2429dfdf": "asian_fusion_restaurant", // Inexact
    // Dining and Drinking > Restaurant > Indian Restaurant
    "4bf58dd8d48988d10f941735": "indian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant
    "4bf58dd8d48988d110941735": "italian_restaurant",
    // Dining and Drinking > Restaurant > Jewish Restaurant
    "52e81612bcbc57f1066b79fd": "restaurant",
    // Dining and Drinking > Restaurant > Kebab Restaurant
    "5283c7b4e4b094cb91ec88d7": "kebab_shop",
    // Dining and Drinking > Restaurant > Latin American Restaurant
    "4bf58dd8d48988d1be941735": "latin_american_restaurant",
    // Dining and Drinking > Restaurant > Mac and Cheese Joint
    "4bf58dd8d48988d1bf941735": "american_restaurant",
    // Dining and Drinking > Restaurant > Mediterranean Restaurant
    "4bf58dd8d48988d1c0941735": "mediterranean_restaurant",
    // Dining and Drinking > Restaurant > Mexican Restaurant
    "4bf58dd8d48988d1c1941735": "mexican_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant
    "4bf58dd8d48988d115941735": "middle_eastern_restaurant",
    // Dining and Drinking > Restaurant > Modern European Restaurant
    "52e81612bcbc57f1066b79f9": "european_restaurant",
    // Dining and Drinking > Restaurant > Molecular Gastronomy Restaurant
    "4bf58dd8d48988d1c2941735": "fine_dining_restaurant",
    // Dining and Drinking > Restaurant > Moroccan Restaurant
    "4bf58dd8d48988d1c3941735": "moroccan_restaurant",
    // Dining and Drinking > Restaurant > Pakistani Restaurant
    "52e81612bcbc57f1066b79f8": "pakistani_restaurant",
    // Dining and Drinking > Restaurant > Pizzeria
    "4bf58dd8d48988d1ca941735": "pizza_restaurant",
    // Dining and Drinking > Restaurant > Polish Restaurant
    "52e81612bcbc57f1066b7a04": "polish_restaurant",
    // Dining and Drinking > Restaurant > Portuguese Restaurant
    "4def73e84765ae376e57713a": "portuguese_restaurant",
    // Dining and Drinking > Restaurant > Poutine Restaurant
    "56aa371be4b08b9a8d5734c7": "restaurant",
    // Dining and Drinking > Restaurant > Russian Restaurant
    "5293a7563cf9994f4e043a44": "russian_restaurant",
    // Dining and Drinking > Restaurant > Salad Restaurant
    "4bf58dd8d48988d1bd941735": "salad_shop",
    // Dining and Drinking > Restaurant > Sandwich Spot
    "4bf58dd8d48988d1c5941735": "sandwich_shop",
    // Dining and Drinking > Restaurant > Scandinavian Restaurant
    "4bf58dd8d48988d1c6941735": "scandinavian_restaurant",
    // Dining and Drinking > Restaurant > Scottish Restaurant
    "5744ccdde4b0c0459246b4a3": "british_restaurant",
    // Dining and Drinking > Restaurant > Seafood Restaurant
    "4bf58dd8d48988d1ce941735": "seafood_restaurant",
    // Dining and Drinking > Restaurant > Slovak Restaurant
    "56aa371be4b08b9a8d57355a": "eastern_european_restaurant",
    // Dining and Drinking > Restaurant > Soup Spot
    "4bf58dd8d48988d1dd931735": "soup_restaurant",
    // Dining and Drinking > Restaurant > Southern Food Restaurant
    "4bf58dd8d48988d14f941735": "soul_food_restaurant",
    // Dining and Drinking > Restaurant > Spanish Restaurant
    "4bf58dd8d48988d150941735": "spanish_restaurant",
    // Dining and Drinking > Restaurant > Sri Lankan Restaurant
    "5413605de4b0ae91d18581a9": "sri_lankan_restaurant",
    // Dining and Drinking > Restaurant > Steakhouse
    "4bf58dd8d48988d1cc941735": "steak_house",
    // Dining and Drinking > Restaurant > Swiss Restaurant
    "4bf58dd8d48988d158941735": "swiss_restaurant",
    // Dining and Drinking > Restaurant > Theme Restaurant
    "56aa371be4b08b9a8d573538": "restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant
    "4f04af1f2fb6e1c99f3db0bb": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Ukrainian Restaurant
    "52e928d0bcbc57f1066b7e96": "ukrainian_restaurant",
    // Dining and Drinking > Restaurant > Vegan and Vegetarian Restaurant
    "4bf58dd8d48988d1d3941735": "vegetarian_restaurant", // Inexact
    // Dining and Drinking > Restaurant > Wings Joint
    "4bf58dd8d48988d14c941735": "chicken_wings_restaurant",
    // Dining and Drinking > Restaurant > African Restaurant > Ethiopian Restaurant
    "4bf58dd8d48988d10a941735": "ethiopian_restaurant",
    // Dining and Drinking > Restaurant > African Restaurant > Mauritian Restaurant
    "5f2c344a5b4c177b9a6dc011": "african_restaurant",
    // Dining and Drinking > Restaurant > American Restaurant > New American Restaurant
    "4bf58dd8d48988d157941735": "american_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Burmese Restaurant
    "56aa371be4b08b9a8d573568": "burmese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Cambodian Restaurant
    "52e81612bcbc57f1066b7a03": "cambodian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant
    "4bf58dd8d48988d145941735": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Filipino Restaurant
    "4eb1bd1c3b7b55596b4a748f": "filipino_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Himalayan Restaurant
    "52e81612bcbc57f1066b79fb": "asian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Hotpot Restaurant
    "52af0bd33cf9994f4e043bdd": "hot_pot_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant
    "4deefc054765f83613cdba6f": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant
    "4bf58dd8d48988d111941735": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant
    "4bf58dd8d48988d113941735": "korean_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Malay Restaurant
    "4bf58dd8d48988d156941735": "malaysian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Mongolian Restaurant
    "4eb1d5724b900d56c88a45fe": "mongolian_barbecue_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Noodle Restaurant
    "4bf58dd8d48988d1d1941735": "noodle_shop",
    // Dining and Drinking > Restaurant > Asian Restaurant > Satay Restaurant
    "56aa371be4b08b9a8d57350e": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Singaporean Restaurant
    "5f2c430e5b4c177b9a6dcabd": "asian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Thai Restaurant
    "4bf58dd8d48988d149941735": "thai_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Tibetan Restaurant
    "52af39fb3cf9994f4e043be9": "tibetan_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Vietnamese Restaurant
    "4bf58dd8d48988d14a941735": "vietnamese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Anhui Restaurant
    "52af3a5e3cf9994f4e043bea": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Beijing Restaurant
    "52af3a723cf9994f4e043bec": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Cantonese Restaurant
    "52af3a7c3cf9994f4e043bed": "cantonese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Cha Chaan Teng
    "58daa1558bbb0b01f18ec1d3": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Chinese Aristocrat Restaurant
    "52af3a673cf9994f4e043beb": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Chinese Breakfast Restaurant
    "52af3a903cf9994f4e043bee": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Dim Sum Restaurant
    "4bf58dd8d48988d1f5931735": "dim_sum_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Dongbei Restaurant
    "52af3a9f3cf9994f4e043bef": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Fujian Restaurant
    "52af3aaa3cf9994f4e043bf0": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Guizhou Restaurant
    "52af3ab53cf9994f4e043bf1": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hainan Restaurant
    "52af3abe3cf9994f4e043bf2": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hakka Restaurant
    "52af3ac83cf9994f4e043bf3": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Henan Restaurant
    "52af3ad23cf9994f4e043bf4": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hong Kong Restaurant
    "52af3add3cf9994f4e043bf5": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Huaiyang Restaurant
    "52af3af23cf9994f4e043bf7": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hubei Restaurant
    "52af3ae63cf9994f4e043bf6": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Hunan Restaurant
    "52af3afc3cf9994f4e043bf8": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Imperial Restaurant
    "52af3b053cf9994f4e043bf9": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Jiangsu Restaurant
    "52af3b213cf9994f4e043bfa": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Jiangxi Restaurant
    "52af3b293cf9994f4e043bfb": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Macanese Restaurant
    "52af3b343cf9994f4e043bfc": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Manchu Restaurant
    "52af3b3b3cf9994f4e043bfd": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Peking Duck Restaurant
    "52af3b463cf9994f4e043bfe": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Shaanxi Restaurant
    "52af3b633cf9994f4e043c01": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Shandong Restaurant
    "52af3b513cf9994f4e043bff": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Shanghai Restaurant
    "52af3b593cf9994f4e043c00": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Shanxi Restaurant
    "52af3b6e3cf9994f4e043c02": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Szechuan Restaurant
    "52af3b773cf9994f4e043c03": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Taiwanese Restaurant
    "52af3b813cf9994f4e043c04": "taiwanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Tianjin Restaurant
    "52af3b893cf9994f4e043c05": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Xinjiang Restaurant
    "52af3b913cf9994f4e043c06": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Yunnan Restaurant
    "52af3b9a3cf9994f4e043c07": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Chinese Restaurant > Zhejiang Restaurant
    "52af3ba23cf9994f4e043c08": "chinese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Acehnese Restaurant
    "52960eda3cf9994f4e043ac9": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Balinese Restaurant
    "52960eda3cf9994f4e043acb": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Betawinese Restaurant
    "52960eda3cf9994f4e043aca": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Indonesian Meatball Restaurant
    "52960eda3cf9994f4e043acc": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Javanese Restaurant
    "52960eda3cf9994f4e043ac7": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Manadonese Restaurant
    "52960eda3cf9994f4e043ac8": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Padangnese Restaurant
    "52960eda3cf9994f4e043ac5": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Indonesian Restaurant > Sundanese Restaurant
    "52960eda3cf9994f4e043ac6": "indonesian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Donburi Restaurant
    "55a59bace4b013909087cb0c": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Japanese Curry Restaurant
    "55a59bace4b013909087cb30": "japanese_curry_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Japanese Family Restaurant
    "5f2c2436b6d05514c704433e": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Kaiseki Restaurant
    "55a59bace4b013909087cb21": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Kushikatsu Restaurant
    "55a59bace4b013909087cb06": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Monjayaki Restaurant
    "55a59bace4b013909087cb1b": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Nabe Restaurant
    "55a59bace4b013909087cb1e": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Okonomiyaki Restaurant
    "55a59bace4b013909087cb18": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Ramen Restaurant
    "55a59bace4b013909087cb24": "ramen_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Shabu-Shabu Restaurant
    "55a59bace4b013909087cb15": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Soba Restaurant
    "55a59bace4b013909087cb27": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Sukiyaki Restaurant
    "55a59bace4b013909087cb12": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Sushi Restaurant
    "4bf58dd8d48988d1d2941735": "sushi_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Takoyaki Place
    "55a59bace4b013909087cb2d": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Teishoku Restaurant
    "5f2c239eb6d05514c70441ee": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Tempura Restaurant
    "55a59a31e4b013909087cb00": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Tonkatsu Restaurant
    "55a59af1e4b013909087cb03": "tonkatsu_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Udon Restaurant
    "55a59bace4b013909087cb2a": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Unagi Restaurant
    "55a59bace4b013909087cb0f": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Wagashi Place
    "55a59bace4b013909087cb33": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Yakitori Restaurant
    "55a59bace4b013909087cb09": "yakitori_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Japanese Restaurant > Yoshoku Restaurant
    "55a59bace4b013909087cb36": "japanese_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Bossam/Jokbal Restaurant
    "56aa371be4b08b9a8d5734e4": "korean_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Bunsik Restaurant
    "56aa371be4b08b9a8d5734f0": "korean_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Gukbap Restaurant
    "56aa371be4b08b9a8d5734e7": "korean_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Janguh Restaurant
    "56aa371be4b08b9a8d5734ed": "korean_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Korean BBQ Restaurant
    "5f2c3f6b5b4c177b9a6dc388": "korean_barbecue_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Korean Restaurant > Samgyetang Restaurant
    "56aa371be4b08b9a8d5734ea": "korean_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Malay Restaurant > Mamak Restaurant
    "5ae9595eb77c77002c2f9f26": "malaysian_restaurant",
    // Dining and Drinking > Restaurant > Asian Restaurant > Thai Restaurant > Som Tum Restaurant
    "56aa371be4b08b9a8d573502": "thai_restaurant",
    // Dining and Drinking > Restaurant > Caribbean Restaurant > Cuban Restaurant
    "4bf58dd8d48988d154941735": "cuban_restaurant",
    // Dining and Drinking > Restaurant > Caribbean Restaurant > Puerto Rican Restaurant
    "5f2c2abab6d05514c70446e4": "caribbean_restaurant",
    // Dining and Drinking > Restaurant > Eastern European Restaurant > Belarusian Restaurant
    "52e928d0bcbc57f1066b7e97": "eastern_european_restaurant",
    // Dining and Drinking > Restaurant > Eastern European Restaurant > Bosnian Restaurant
    "58daa1558bbb0b01f18ec1ee": "eastern_european_restaurant",
    // Dining and Drinking > Restaurant > Eastern European Restaurant > Bulgarian Restaurant
    "56aa371be4b08b9a8d5734f3": "eastern_european_restaurant",
    // Dining and Drinking > Restaurant > Eastern European Restaurant > Romanian Restaurant
    "52960bac3cf9994f4e043ac4": "romanian_restaurant",
    // Dining and Drinking > Restaurant > Eastern European Restaurant > Tatar Restaurant
    "52e928d0bcbc57f1066b7e98": "eastern_european_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Alsatian Restaurant
    "57558b36e4b065ecebd306b6": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Auvergne Restaurant
    "57558b36e4b065ecebd306b8": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Basque Restaurant
    "57558b36e4b065ecebd306bc": "basque_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Brasserie
    "57558b36e4b065ecebd306b0": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Breton Restaurant
    "57558b36e4b065ecebd306c5": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Burgundian Restaurant
    "57558b36e4b065ecebd306c0": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Catalan Restaurant
    "57558b36e4b065ecebd306cb": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Ch'ti Restaurant
    "57558b36e4b065ecebd306ce": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Corsican Restaurant
    "57558b36e4b065ecebd306d1": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Estaminet
    "57558b36e4b065ecebd306b4": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Labour Canteen
    "57558b36e4b065ecebd306b2": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Lyonese Bouchon
    "57558b35e4b065ecebd306ad": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Norman Restaurant
    "57558b36e4b065ecebd306d4": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Provençal Restaurant
    "57558b36e4b065ecebd306d7": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Savoyard Restaurant
    "57558b36e4b065ecebd306da": "french_restaurant",
    // Dining and Drinking > Restaurant > French Restaurant > Southwestern French Restaurant
    "57558b36e4b065ecebd306ba": "french_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Apple Wine Pub
    "56aa371ce4b08b9a8d573583": "german_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Bavarian Restaurant
    "56aa371ce4b08b9a8d573572": "bavarian_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Bratwurst Joint
    "56aa371ce4b08b9a8d57358e": "german_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Currywurst Joint
    "56aa371ce4b08b9a8d57358b": "german_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Franconian Restaurant
    "56aa371ce4b08b9a8d573574": "german_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > German Pop-Up Restaurant
    "56aa371ce4b08b9a8d573592": "german_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Palatine Restaurant
    "56aa371ce4b08b9a8d573578": "german_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Rhenisch Restaurant
    "56aa371ce4b08b9a8d57357b": "german_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Schnitzel Restaurant
    "56aa371ce4b08b9a8d573587": "german_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Silesian Restaurant
    "56aa371ce4b08b9a8d57357f": "german_restaurant",
    // Dining and Drinking > Restaurant > German Restaurant > Swabian Restaurant
    "56aa371ce4b08b9a8d573576": "german_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Bougatsa Shop
    "53d6c1b0e4b02351e88a83e8": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Cretan Restaurant
    "53d6c1b0e4b02351e88a83e2": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Fish Taverna
    "53d6c1b0e4b02351e88a83d8": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Grilled Meat Restaurant
    "53d6c1b0e4b02351e88a83d6": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Kafenio
    "53d6c1b0e4b02351e88a83e6": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Magirio
    "53d6c1b0e4b02351e88a83e4": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Meze Restaurant
    "53d6c1b0e4b02351e88a83da": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Modern Greek Restaurant
    "53d6c1b0e4b02351e88a83d4": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Ouzeri
    "53d6c1b0e4b02351e88a83dc": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Patsa Restaurant
    "53d6c1b0e4b02351e88a83e0": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Souvlaki Shop
    "52e81612bcbc57f1066b79f3": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Taverna
    "53d6c1b0e4b02351e88a83d2": "greek_restaurant",
    // Dining and Drinking > Restaurant > Greek Restaurant > Tsipouro Restaurant
    "53d6c1b0e4b02351e88a83de": "greek_restaurant",
    // Dining and Drinking > Restaurant > Hawaiian Restaurant > Poke Restaurant
    "5bae9231bedf3950379f89d4": "hawaiian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Andhra Restaurant
    "54135bf5e4b08f3d2429dfe5": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Awadhi Restaurant
    "54135bf5e4b08f3d2429dff3": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Bengali Restaurant
    "54135bf5e4b08f3d2429dff5": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Chaat Place
    "54135bf5e4b08f3d2429dfe2": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Chettinad Restaurant
    "54135bf5e4b08f3d2429dff2": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Dhaba
    "54135bf5e4b08f3d2429dfe1": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Dosa Place
    "54135bf5e4b08f3d2429dfe3": "south_indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Goan Restaurant
    "54135bf5e4b08f3d2429dfe8": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Gujarati Restaurant
    "54135bf5e4b08f3d2429dfe9": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Hyderabadi Restaurant
    "54135bf5e4b08f3d2429dfe6": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Indian Sweet Shop
    "54135bf5e4b08f3d2429dfe4": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Irani Cafe
    "54135bf5e4b08f3d2429dfe7": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Jain Restaurant
    "54135bf5e4b08f3d2429dfea": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Karnataka Restaurant
    "54135bf5e4b08f3d2429dfeb": "south_indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Kerala Restaurant
    "54135bf5e4b08f3d2429dfed": "south_indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Maharashtrian Restaurant
    "54135bf5e4b08f3d2429dfee": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Mughlai Restaurant
    "54135bf5e4b08f3d2429dff4": "north_indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Multicuisine Indian Restaurant
    "54135bf5e4b08f3d2429dfe0": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Northeast Indian Restaurant
    "54135bf5e4b08f3d2429dff6": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > North Indian Restaurant
    "54135bf5e4b08f3d2429dfdd": "north_indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Parsi Restaurant
    "54135bf5e4b08f3d2429dfef": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Punjabi Restaurant
    "54135bf5e4b08f3d2429dff0": "north_indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Rajasthani Restaurant
    "54135bf5e4b08f3d2429dff1": "indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > South Indian Restaurant
    "54135bf5e4b08f3d2429dfde": "south_indian_restaurant",
    // Dining and Drinking > Restaurant > Indian Restaurant > Udupi Restaurant
    "54135bf5e4b08f3d2429dfec": "south_indian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Abruzzo Restaurant
    "55a5a1ebe4b013909087cbb6": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Agriturismo
    "55a5a1ebe4b013909087cb7c": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Aosta Restaurant
    "55a5a1ebe4b013909087cba7": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Basilicata Restaurant
    "55a5a1ebe4b013909087cba1": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Calabria Restaurant
    "55a5a1ebe4b013909087cba4": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Campanian Restaurant
    "55a5a1ebe4b013909087cb95": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Emilia Restaurant
    "55a5a1ebe4b013909087cb89": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Friuli Restaurant
    "55a5a1ebe4b013909087cb9b": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Ligurian Restaurant
    "55a5a1ebe4b013909087cb98": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Lombard Restaurant
    "55a5a1ebe4b013909087cbbf": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Malga
    "55a5a1ebe4b013909087cb79": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Marche Restaurant
    "55a5a1ebe4b013909087cbb0": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Molise Restaurant
    "55a5a1ebe4b013909087cbb3": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Piadineria
    "55a5a1ebe4b013909087cb74": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Piedmontese Restaurant
    "55a5a1ebe4b013909087cbaa": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Puglia Restaurant
    "55a5a1ebe4b013909087cb83": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Romagna Restaurant
    "55a5a1ebe4b013909087cb8c": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Roman Restaurant
    "55a5a1ebe4b013909087cb92": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Sardinian Restaurant
    "55a5a1ebe4b013909087cb8f": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Sicilian Restaurant
    "55a5a1ebe4b013909087cb86": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > South Tyrolean Restaurant
    "55a5a1ebe4b013909087cbb9": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Trattoria
    "55a5a1ebe4b013909087cb7f": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Trentino Restaurant
    "55a5a1ebe4b013909087cbbc": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Tuscan Restaurant
    "55a5a1ebe4b013909087cb9e": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Umbrian Restaurant
    "55a5a1ebe4b013909087cbc2": "italian_restaurant",
    // Dining and Drinking > Restaurant > Italian Restaurant > Veneto Restaurant
    "55a5a1ebe4b013909087cbad": "italian_restaurant",
    // Dining and Drinking > Restaurant > Jewish Restaurant > Kosher Restaurant
    "52e81612bcbc57f1066b79fc": "restaurant", // REVIEW
    // Dining and Drinking > Restaurant > Latin American Restaurant > Arepa Restaurant
    "4bf58dd8d48988d152941735": "latin_american_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > Empanada Restaurant
    "52939a8c3cf9994f4e043a35": "latin_american_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > Honduran Restaurant
    "5f2c32587ff30c0d7ac09638": "latin_american_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > Salvadoran Restaurant
    "5745c7ac498e5d0483112fdb": "latin_american_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant
    "4bf58dd8d48988d1cd941735": "south_american_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Argentinian Restaurant
    "4bf58dd8d48988d107941735": "argentinian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant
    "4bf58dd8d48988d16b941735": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Colombian Restaurant
    "58daa1558bbb0b01f18ec1f4": "colombian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Peruvian Restaurant
    "4eb1bfa43b7b52c0e1adc2e8": "peruvian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Venezuelan Restaurant
    "56aa371be4b08b9a8d573558": "south_american_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Acai House
    "5294c7523cf9994f4e043a62": "acai_shop",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Baiano Restaurant
    "52939ae13cf9994f4e043a3b": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Central Brazilian Restaurant
    "52939a9e3cf9994f4e043a36": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Churrascaria
    "52939a643cf9994f4e043a33": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Empada House
    "5294c55c3cf9994f4e043a61": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Goiano Restaurant
    "52939af83cf9994f4e043a3d": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Mineiro Restaurant
    "52939aed3cf9994f4e043a3c": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Northeastern Brazilian Restaurant
    "52939aae3cf9994f4e043a37": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Northern Brazilian Restaurant
    "52939ab93cf9994f4e043a38": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Pastelaria
    "5294cbda3cf9994f4e043a63": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Southeastern Brazilian Restaurant
    "52939ac53cf9994f4e043a39": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Southern Brazilian Restaurant
    "52939ad03cf9994f4e043a3a": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Brazilian Restaurant > Tapiocaria
    "52939a7d3cf9994f4e043a34": "brazilian_restaurant",
    // Dining and Drinking > Restaurant > Latin American Restaurant > South American Restaurant > Peruvian Restaurant > Peruvian Roast Chicken Joint
    "5f2c1c31b6d05514c704334c": "peruvian_restaurant",
    // Dining and Drinking > Restaurant > Mexican Restaurant > Botanero
    "58daa1558bbb0b01f18ec1d9": "mexican_restaurant",
    // Dining and Drinking > Restaurant > Mexican Restaurant > Burrito Restaurant
    "4bf58dd8d48988d153941735": "burrito_restaurant",
    // Dining and Drinking > Restaurant > Mexican Restaurant > Taco Restaurant
    "4bf58dd8d48988d151941735": "taco_restaurant",
    // Dining and Drinking > Restaurant > Mexican Restaurant > Tex-Mex Restaurant
    "56aa371ae4b08b9a8d5734ba": "tex_mex_restaurant",
    // Dining and Drinking > Restaurant > Mexican Restaurant > Yucatecan Restaurant
    "5744ccdfe4b0c0459246b4d3": "mexican_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Egyptian Restaurant
    "5bae9231bedf3950379f89e1": "middle_eastern_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Iraqi Restaurant
    "5bae9231bedf3950379f89e7": "middle_eastern_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Israeli Restaurant
    "56aa371be4b08b9a8d573529": "israeli_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Kurdish Restaurant
    "5744ccdfe4b0c0459246b4ca": "middle_eastern_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Lebanese Restaurant
    "58daa1558bbb0b01f18ec1cd": "lebanese_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant
    "52e81612bcbc57f1066b79f7": "persian_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Shawarma Restaurant
    "5bae9231bedf3950379f89e4": "shawarma_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Syrian Restaurant
    "5bae9231bedf3950379f89da": "middle_eastern_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Yemeni Restaurant
    "5bae9231bedf3950379f89ea": "middle_eastern_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Ash and Haleem Place
    "58daa1558bbb0b01f18ec1bc": "persian_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Dizi Place
    "58daa1558bbb0b01f18ec1c0": "persian_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Gilaki Restaurant
    "58daa1558bbb0b01f18ec1c4": "persian_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Jegaraki
    "58daa1558bbb0b01f18ec1c7": "persian_restaurant",
    // Dining and Drinking > Restaurant > Middle Eastern Restaurant > Persian Restaurant > Tabbakhi
    "5744ccdfe4b0c0459246b4a8": "persian_restaurant",
    // Dining and Drinking > Restaurant > Russian Restaurant > Blini House
    "52e928d0bcbc57f1066b7e9d": "russian_restaurant",
    // Dining and Drinking > Restaurant > Russian Restaurant > Pelmeni House
    "52e928d0bcbc57f1066b7e9c": "russian_restaurant",
    // Dining and Drinking > Restaurant > Spanish Restaurant > Paella Restaurant
    "4bf58dd8d48988d14d941735": "spanish_restaurant",
    // Dining and Drinking > Restaurant > Spanish Restaurant > Tapas Restaurant
    "4bf58dd8d48988d1db931735": "tapas_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Borek Place
    "530faca9bcbc57f1066bc2f3": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Cigkofte Place
    "530faca9bcbc57f1066bc2f4": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Çöp Şiş Place
    "58daa1558bbb0b01f18ec1e2": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Doner Restaurant
    "5283c7b4e4b094cb91ec88d8": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Gozleme Place
    "5283c7b4e4b094cb91ec88d9": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Kofte Place
    "5283c7b4e4b094cb91ec88db": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Kokoreç Restaurant
    "5283c7b4e4b094cb91ec88d6": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Kumpir Restaurant
    "56aa371be4b08b9a8d573535": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Kumru Restaurant
    "56aa371be4b08b9a8d5734bd": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Manti Place
    "5283c7b4e4b094cb91ec88d5": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Meyhane
    "5283c7b4e4b094cb91ec88da": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Pide Place
    "530faca9bcbc57f1066bc2f2": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Pilavcı
    "58daa1558bbb0b01f18ec1df": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Söğüş Place
    "58daa1558bbb0b01f18ec1dc": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Tantuni Restaurant
    "56aa371be4b08b9a8d5734bf": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Turkish Coffeehouse
    "56aa371be4b08b9a8d5734c1": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Turkish Restaurant > Turkish Home Cooking Restaurant
    "5283c7b4e4b094cb91ec88d4": "turkish_restaurant",
    // Dining and Drinking > Restaurant > Ukrainian Restaurant > Varenyky Restaurant
    "52e928d0bcbc57f1066b7e9a": "ukrainian_restaurant",
    // Dining and Drinking > Restaurant > Ukrainian Restaurant > West-Ukrainian Restaurant
    "52e928d0bcbc57f1066b7e9b": "ukrainian_restaurant",
    // Event > Conference
    "5267e4d9e4b0ec79466e48c6": "convention_center",
    // Event > Convention
    "5267e4d9e4b0ec79466e48c9": "convention_center",
    // Event > Entertainment Event
    "63be6904847c3692a84b9bb7": "event_venue",
    // Event > Line
    "58daa1558bbb0b01f18ec1fa": "point_of_interest", // Inexact
    // Event > Marketplace
    "63be6904847c3692a84b9bb8": "market",
    // Event > Other Event
    "5267e4d9e4b0ec79466e48c8": "event_venue",
    // Event > Entertainment Event > Festival
    "5267e4d9e4b0ec79466e48c7": "event_venue",
    // Event > Entertainment Event > Music Festival
    "5267e4d9e4b0ec79466e48d1": "event_venue",
    // Event > Entertainment Event > Parade
    "52741d85e4b0d5d1e3c6a6d9": "event_venue",
    // Event > Entertainment Event > Sporting Event
    "5bae9231bedf3950379f89c5": "event_venue",
    // Event > Entertainment Event > Festival > Beer Festival
    "62d587aeda6648532de2b88c": "event_venue",
    // Event > Marketplace > Christmas Market
    "52f2ab2ebcbc57f1066b8b3b": "market",
    // Event > Marketplace > Stoop Sale
    "52f2ab2ebcbc57f1066b8b54": "flea_market",
    // Event > Marketplace > Street Fair
    "5267e4d8e4b0ec79466e48c5": "event_venue", // Inexact
    // Event > Marketplace > Street Food Gathering
    "53e0feef498e5aac066fd8a9": "food_court", // Inexact
    // Event > Marketplace > Trade Fair
    "5bae9231bedf3950379f89c3": "convention_center",
    // Health and Medicine > Acupuncture Clinic
    "52e81612bcbc57f1066b7a3b": "wellness_center",
    // Health and Medicine > AIDS Resource
    "63be6904847c3692a84b9bba": "medical_clinic",
    // Health and Medicine > Alternative Medicine Clinic
    "52e81612bcbc57f1066b7a3c": "wellness_center",
    // Health and Medicine > Assisted Living Service
    "63be6904847c3692a84b9bbb": "service",
    // Health and Medicine > Blood Bank
    "5f2c43a65b4c177b9a6dcc62": "medical_clinic",
    // Health and Medicine > Chiropractor
    "52e81612bcbc57f1066b7a3a": "chiropractor",
    // Health and Medicine > Dentist
    "4bf58dd8d48988d178941735": "dentist",
    // Health and Medicine > Emergency Service
    "63be6904847c3692a84b9bbc": "hospital",
    // Health and Medicine > Healthcare Clinic
    "63be6904847c3692a84b9bbe": "medical_clinic",
    // Health and Medicine > Home Health Care Service
    "63be6904847c3692a84b9bbf": "service",
    // Health and Medicine > Hospice
    "5f2c5b8b5b4c177b9a6ddf0b": "medical_clinic",
    // Health and Medicine > Hospital
    "4bf58dd8d48988d196941735": "hospital",
    // Health and Medicine > Maternity Clinic
    "56aa371be4b08b9a8d5734ff": "medical_clinic",
    // Health and Medicine > Medical Center
    "4bf58dd8d48988d104941735": "medical_center",
    // Health and Medicine > Medical Lab
    "4f4531b14b9074f6e4fb0103": "medical_lab",
    // Health and Medicine > Mental Health Service
    "63be6904847c3692a84b9bc1": "doctor",
    // Health and Medicine > Nurse
    "63be6904847c3692a84b9bc3": "doctor",
    // Health and Medicine > Nursing Home
    "63be6904847c3692a84b9bc4": "health", // Inexact
    // Health and Medicine > Nutritionist
    "58daa1558bbb0b01f18ec1d0": "doctor",
    // Health and Medicine > Optometrist
    "522e32fae4b09b556e370f19": "doctor",
    // Health and Medicine > Other Healthcare Professional
    "63be6904847c3692a84b9bc5": "doctor",
    // Health and Medicine > Physical Therapy Clinic
    "5744ccdfe4b0c0459246b4af": "physiotherapist",
    // Health and Medicine > Physician
    "63be6904847c3692a84b9bc6": "doctor",
    // Health and Medicine > Podiatrist
    "63be6904847c3692a84b9bdd": "doctor",
    // Health and Medicine > Sports Medicine Clinic
    "63be6904847c3692a84b9bde": "medical_clinic",
    // Health and Medicine > Urgent Care Center
    "56aa371be4b08b9a8d573526": "medical_clinic",
    // Health and Medicine > Veterinarian
    "4d954af4a243a5684765b473": "veterinary_care",
    // Health and Medicine > Weight Loss Center
    "590a0744340a5803fd8508c3": "wellness_center",
    // Health and Medicine > Women's Health Clinic
    "63be6904847c3692a84b9bdf": "medical_clinic",
    // Health and Medicine > Emergency Service > Ambulance Service
    "63be6904847c3692a84b9bbd": "service",
    // Health and Medicine > Emergency Service > Emergency Room
    "4bf58dd8d48988d194941735": "hospital",
    // Health and Medicine > Hospital > Children's Hospital
    "63be6904847c3692a84b9bc0": "hospital",
    // Health and Medicine > Hospital > Hospital Unit
    "58daa1558bbb0b01f18ec1f7": "hospital",
    // Health and Medicine > Mental Health Service > Mental Health Clinic
    "52e81612bcbc57f1066b7a39": "medical_clinic",
    // Health and Medicine > Mental Health Service > Psychologist
    "63be6904847c3692a84b9bc2": "doctor",
    // Health and Medicine > Physician > Anesthesiologist
    "63be6904847c3692a84b9bc7": "doctor",
    // Health and Medicine > Physician > Cardiologist
    "63be6904847c3692a84b9bc8": "doctor",
    // Health and Medicine > Physician > Dermatologist
    "63be6904847c3692a84b9bc9": "doctor",
    // Health and Medicine > Physician > Doctor's Office
    "4bf58dd8d48988d177941735": "doctor",
    // Health and Medicine > Physician > Ear, Nose and Throat Doctor
    "63be6904847c3692a84b9bca": "doctor",
    // Health and Medicine > Physician > Family Medicine Doctor
    "63be6904847c3692a84b9bcb": "doctor",
    // Health and Medicine > Physician > Gastroenterologist
    "63be6904847c3692a84b9bcc": "doctor",
    // Health and Medicine > Physician > General Surgeon
    "63be6904847c3692a84b9bcd": "doctor",
    // Health and Medicine > Physician > Geriatric Doctor
    "63be6904847c3692a84b9bce": "doctor",
    // Health and Medicine > Physician > Internal Medicine Doctor
    "63be6904847c3692a84b9bcf": "doctor",
    // Health and Medicine > Physician > Neurologist
    "63be6904847c3692a84b9bd0": "doctor",
    // Health and Medicine > Physician > Obstetrician Gynecologist (Ob-gyn)
    "63be6904847c3692a84b9bd1": "doctor",
    // Health and Medicine > Physician > Oncologist
    "63be6904847c3692a84b9bd2": "doctor",
    // Health and Medicine > Physician > Ophthalmologist
    "63be6904847c3692a84b9bd3": "doctor",
    // Health and Medicine > Physician > Oral Surgeon
    "63be6904847c3692a84b9bd4": "doctor",
    // Health and Medicine > Physician > Orthopedic Surgeon
    "63be6904847c3692a84b9bd5": "doctor",
    // Health and Medicine > Physician > Pathologist
    "63be6904847c3692a84b9bd6": "doctor",
    // Health and Medicine > Physician > Pediatrician
    "63be6904847c3692a84b9bd7": "doctor",
    // Health and Medicine > Physician > Plastic Surgeon
    "63be6904847c3692a84b9bd8": "doctor",
    // Health and Medicine > Physician > Psychiatrist
    "63be6904847c3692a84b9bd9": "doctor",
    // Health and Medicine > Physician > Radiologist
    "63be6904847c3692a84b9bda": "doctor",
    // Health and Medicine > Physician > Respiratory Doctor
    "63be6904847c3692a84b9bdb": "doctor",
    // Health and Medicine > Physician > Urologist
    "63be6904847c3692a84b9bdc": "doctor",
    // Landmarks and Outdoors > Bathing Area
    "52e81612bcbc57f1066b7a28": "beach", // Inexact
    // Landmarks and Outdoors > Bay
    "56aa371be4b08b9a8d573544": "natural_feature",
    // Landmarks and Outdoors > Beach
    "4bf58dd8d48988d1e2941735": "beach",
    // Landmarks and Outdoors > Bike Trail
    "56aa371be4b08b9a8d57355e": "hiking_area", // Inexact
    // Landmarks and Outdoors > Boat Launch
    "5fabfc8099ce226e27fe6b0d": "marina",
    // Landmarks and Outdoors > Botanical Garden
    "52e81612bcbc57f1066b7a22": "botanical_garden",
    // Landmarks and Outdoors > Bridge
    "4bf58dd8d48988d1df941735": "bridge",
    // Landmarks and Outdoors > Campground
    "4bf58dd8d48988d1e4941735": "campground",
    // Landmarks and Outdoors > Canal
    "56aa371be4b08b9a8d573562": "natural_feature",
    // Landmarks and Outdoors > Canal Lock
    "56aa371be4b08b9a8d57353b": "natural_feature",
    // Landmarks and Outdoors > Castle
    "50aaa49e4b90af0d42d5de11": "castle",
    // Landmarks and Outdoors > Cave
    "56aa371be4b08b9a8d573511": "natural_feature",
    // Landmarks and Outdoors > Dam
    "5fac018b99ce226e27fe7573": "natural_feature",
    // Landmarks and Outdoors > Dive Spot
    "52e81612bcbc57f1066b7a12": "scenic_spot",
    // Landmarks and Outdoors > Farm
    "4bf58dd8d48988d15b941735": "farm",
    // Landmarks and Outdoors > Field
    "4bf58dd8d48988d15f941735": "natural_feature",
    // Landmarks and Outdoors > Forest
    "52e81612bcbc57f1066b7a23": "woods",
    // Landmarks and Outdoors > Fountain
    "56aa371be4b08b9a8d573547": "fountain",
    // Landmarks and Outdoors > Garden
    "4bf58dd8d48988d15a941735": "garden",
    // Landmarks and Outdoors > Harbor or Marina
    "4bf58dd8d48988d1e0941735": "marina",
    // Landmarks and Outdoors > Hiking Trail
    "4bf58dd8d48988d159941735": "hiking_area",
    // Landmarks and Outdoors > Hill
    "5bae9231bedf3950379f89cd": "natural_feature",
    // Landmarks and Outdoors > Historic and Protected Site
    "4deefb944765f83613cdba6e": "historical_landmark",
    // Landmarks and Outdoors > Hot Spring
    "4bf58dd8d48988d160941735": "natural_feature",
    // Landmarks and Outdoors > Island
    "50aaa4314b90af0d42d5de10": "island",
    // Landmarks and Outdoors > Lake
    "4bf58dd8d48988d161941735": "lake",
    // Landmarks and Outdoors > Lighthouse
    "4bf58dd8d48988d15d941735": "tourist_attraction", // Inexact
    // Landmarks and Outdoors > Memorial Site
    "5642206c498e4bfca532186c": "monument",
    // Landmarks and Outdoors > Monument
    "4bf58dd8d48988d12d941735": "monument",
    // Landmarks and Outdoors > Mountain
    "4eb1d4d54b900d56c88a45fc": "mountain_peak",
    // Landmarks and Outdoors > Mountain Hut
    "55a5a1ebe4b013909087cb77": "lodging",
    // Landmarks and Outdoors > Nature Preserve
    "52e81612bcbc57f1066b7a13": "nature_preserve",
    // Landmarks and Outdoors > Nudist Beach
    "52e81612bcbc57f1066b7a30": "beach",
    // Landmarks and Outdoors > Other Great Outdoors
    "4bf58dd8d48988d162941735": "natural_feature",
    // Landmarks and Outdoors > Palace
    "52e81612bcbc57f1066b7a14": "historical_landmark",
    // Landmarks and Outdoors > Park
    "4bf58dd8d48988d163941735": "park",
    // Landmarks and Outdoors > Pedestrian Plaza
    "52e81612bcbc57f1066b7a25": "plaza",
    // Landmarks and Outdoors > Picnic Shelter
    "5fac010d99ce226e27fe7467": "picnic_ground",
    // Landmarks and Outdoors > Plaza
    "4bf58dd8d48988d164941735": "plaza",
    // Landmarks and Outdoors > Reservoir
    "56aa371be4b08b9a8d573541": "lake",
    // Landmarks and Outdoors > River
    "4eb1d4dd4b900d56c88a45fd": "river",
    // Landmarks and Outdoors > Rock Climbing Spot
    "50328a4b91d4c4b30a586d6b": "adventure_sports_center", // Inexact
    // Landmarks and Outdoors > Roof Deck
    "4bf58dd8d48988d133951735": "scenic_spot", // Inexact
    // Landmarks and Outdoors > Scenic Lookout
    "4bf58dd8d48988d165941735": "scenic_spot",
    // Landmarks and Outdoors > Sculpture Garden
    "4bf58dd8d48988d166941735": "garden", // Inexact
    // Landmarks and Outdoors > Stable
    "4eb1baf03b7b2c5b1d4306ca": "stable",
    // Landmarks and Outdoors > States and Municipalities
    "530e33ccbcbc57f1066bbfe4": "locality",
    // Landmarks and Outdoors > Structure
    "4bf58dd8d48988d130941735": "point_of_interest", // Inexact
    // Landmarks and Outdoors > Surf Spot
    "4bf58dd8d48988d1e3941735": "beach", // Inexact
    // Landmarks and Outdoors > Tree
    "52e81612bcbc57f1066b7a24": "natural_feature",
    // Landmarks and Outdoors > Tunnel
    "52f2ab2ebcbc57f1066b8b4a": "landmark",
    // Landmarks and Outdoors > Volcano
    "5032848691d4c4b30a586d61": "mountain_peak",
    // Landmarks and Outdoors > Waterfall
    "56aa371be4b08b9a8d573560": "natural_feature",
    // Landmarks and Outdoors > Waterfront
    "56aa371be4b08b9a8d5734c3": "natural_feature",
    // Landmarks and Outdoors > Well
    "4fbc1be21983fc883593e321": "natural_feature",
    // Landmarks and Outdoors > Windmill
    "5bae9231bedf3950379f89c7": "tourist_attraction",
    // Landmarks and Outdoors > Park > Dog Park
    "4bf58dd8d48988d1e5941735": "dog_park",
    // Landmarks and Outdoors > Park > National Park
    "52e81612bcbc57f1066b7a21": "national_park",
    // Landmarks and Outdoors > Park > Natural Park
    "63be6904847c3692a84b9be0": "park",
    // Landmarks and Outdoors > Park > Picnic Area
    "5fabfe3599ce226e27fe709a": "picnic_ground",
    // Landmarks and Outdoors > Park > Playground
    "4bf58dd8d48988d1e7941735": "playground",
    // Landmarks and Outdoors > Park > State or Provincial Park
    "5bae9231bedf3950379f89d0": "state_park",
    // Landmarks and Outdoors > Park > Urban Park
    "63be6904847c3692a84b9be1": "city_park",
    // Landmarks and Outdoors > States and Municipalities > City
    "50aa9e094b90af0d42d5de0d": "locality",
    // Landmarks and Outdoors > States and Municipalities > Country
    "530e33ccbcbc57f1066bbff7": "country",
    // Landmarks and Outdoors > States and Municipalities > County
    "5345731ebcbc57f1066c39b2": "administrative_area_level_2",
    // Landmarks and Outdoors > States and Municipalities > Neighborhood
    "4f2a25ac4b909258e854f55f": "neighborhood",
    // Landmarks and Outdoors > States and Municipalities > State
    "530e33ccbcbc57f1066bbff8": "administrative_area_level_1",
    // Landmarks and Outdoors > States and Municipalities > Town
    "530e33ccbcbc57f1066bbff3": "locality",
    // Landmarks and Outdoors > States and Municipalities > Village
    "530e33ccbcbc57f1066bbff9": "locality",
    // Retail > Adult Store
    "5267e446e4b0ec79466e48c4": "store", // Inexact
    // Retail > Antique Store
    "4bf58dd8d48988d116951735": "store",
    // Retail > Arts and Crafts Store
    "4bf58dd8d48988d127951735": "store",
    // Retail > Auction House
    "63be6904847c3692a84b9be2": "store",
    // Retail > Automotive Retail
    "63be6904847c3692a84b9be3": "auto_parts_store",
    // Retail > Baby Store
    "52f2ab2ebcbc57f1066b8b32": "store",
    // Retail > Betting Shop
    "52f2ab2ebcbc57f1066b8b40": "store", // Inexact
    // Retail > Big Box Store
    "52f2ab2ebcbc57f1066b8b42": "warehouse_store",
    // Retail > Board Store
    "4bf58dd8d48988d1f1941735": "sporting_goods_store",
    // Retail > Bookstore
    "4bf58dd8d48988d114951735": "book_store",
    // Retail > Boutique
    "4bf58dd8d48988d104951735": "clothing_store",
    // Retail > Cannabis Store
    "63be6904847c3692a84b9be9": "store", // Inexact
    // Retail > Comic Book Store
    "52f2ab2ebcbc57f1066b8b18": "book_store",
    // Retail > Computers and Electronics Retail
    "63be6904847c3692a84b9bea": "electronics_store",
    // Retail > Construction Supplies Store
    "5454144b498ec1f095bff2f2": "building_materials_store",
    // Retail > Convenience Store
    "4d954b0ea243a5684a65b473": "convenience_store",
    // Retail > Cosmetics Store
    "4bf58dd8d48988d10c951735": "cosmetics_store",
    // Retail > Costume Store
    "52f2ab2ebcbc57f1066b8b17": "clothing_store",
    // Retail > Dance Store
    "63be6904847c3692a84b9beb": "store",
    // Retail > Department Store
    "4bf58dd8d48988d1f6941735": "department_store",
    // Retail > Discount Store
    "52dea92d3cf9994f4e043dbb": "discount_store",
    // Retail > Drugstore
    "5745c2e4498e11e7bccabdbd": "drugstore",
    // Retail > Duty-free Store
    "589ddde98ae3635c072819ee": "store",
    // Retail > Eyecare Store
    "4d954afda243a5684865b473": "store",
    // Retail > Fashion Retail
    "63be6904847c3692a84b9bec": "clothing_store",
    // Retail > Fireworks Store
    "52f2ab2ebcbc57f1066b8b3a": "store",
    // Retail > Flea Market
    "4bf58dd8d48988d1f7941735": "flea_market",
    // Retail > Floating Market
    "56aa371be4b08b9a8d573505": "market",
    // Retail > Flower Store
    "4bf58dd8d48988d11b951735": "florist",
    // Retail > Food and Beverage Retail
    "4bf58dd8d48988d1f9941735": "food_store",
    // Retail > Framing Store
    "52f2ab2ebcbc57f1066b8b24": "store",
    // Retail > Furniture and Home Store
    "4bf58dd8d48988d1f8941735": "home_goods_store",
    // Retail > Garden Center
    "4eb1c0253b7b52c0e1adc2e9": "garden_center",
    // Retail > Gift Store
    "4bf58dd8d48988d128951735": "gift_shop",
    // Retail > Hardware Store
    "4bf58dd8d48988d112951735": "hardware_store",
    // Retail > Hobby Store
    "4bf58dd8d48988d1fb941735": "store",
    // Retail > Knitting Store
    "52f2ab2ebcbc57f1066b8b25": "store",
    // Retail > Leather Goods Store
    "52f2ab2ebcbc57f1066b8b2b": "store",
    // Retail > Luggage Store
    "52f2ab2ebcbc57f1066b8b29": "store",
    // Retail > Marijuana Dispensary
    "52c71aaf3cf9994f4e043d17": "store",
    // Retail > Market
    "50be8ee891d4fa8dcc7199a7": "market",
    // Retail > Medical Supply Store
    "58daa1558bbb0b01f18ec206": "store",
    // Retail > Miscellaneous Store
    "4bf58dd8d48988d1ff941735": "store",
    // Retail > Mobility Store
    "56aa371be4b08b9a8d57354a": "store",
    // Retail > Music Store
    "4bf58dd8d48988d1fe941735": "store",
    // Retail > Newsagent
    "5f2c5a295b4c177b9a6ddd0e": "store",
    // Retail > Newsstand
    "4f04ad622fb6e1c99f3db0b9": "store",
    // Retail > Office Supply Store
    "4bf58dd8d48988d121951735": "store",
    // Retail > Outdoor Supply Store
    "52f2ab2ebcbc57f1066b8b22": "sporting_goods_store",
    // Retail > Outlet Mall
    "5744ccdfe4b0c0459246b4df": "shopping_mall",
    // Retail > Outlet Store
    "52f2ab2ebcbc57f1066b8b35": "store",
    // Retail > Packaging Supply Store
    "63be6904847c3692a84b9bf3": "store",
    // Retail > Party Supply Store
    "63be6904847c3692a84b9bf4": "store",
    // Retail > Pawn Shop
    "52f2ab2ebcbc57f1066b8b34": "store",
    // Retail > Perfume Store
    "52f2ab2ebcbc57f1066b8b23": "cosmetics_store",
    // Retail > Pet Supplies Store
    "4bf58dd8d48988d100951735": "pet_store",
    // Retail > Pharmacy
    "4bf58dd8d48988d10f951735": "pharmacy",
    // Retail > Pop-Up Store
    "52f2ab2ebcbc57f1066b8b3d": "store",
    // Retail > Print Store
    "52f2ab2ebcbc57f1066b8b28": "store",
    // Retail > Record Store
    "4bf58dd8d48988d10d951735": "store",
    // Retail > Shopping Mall
    "4bf58dd8d48988d1fd941735": "shopping_mall",
    // Retail > Shopping Plaza
    "5744ccdfe4b0c0459246b4dc": "shopping_mall",
    // Retail > Smoke Shop
    "4bf58dd8d48988d123951735": "store",
    // Retail > Souvenir Store
    "52f2ab2ebcbc57f1066b8b1b": "gift_shop",
    // Retail > Sporting Goods Retail
    "4bf58dd8d48988d1f2941735": "sporting_goods_store",
    // Retail > Stationery Store
    "52f2ab2ebcbc57f1066b8b21": "store",
    // Retail > Supplement Store
    "5744ccdfe4b0c0459246b4cd": "health_food_store",
    // Retail > Swimming Pool Supply Store
    "63be6904847c3692a84b9bfb": "store",
    // Retail > Textiles Store
    "52f2ab2ebcbc57f1066b8b26": "store",
    // Retail > Tobacco Store
    "63be6904847c3692a84b9bfc": "store",
    // Retail > Toy Store
    "4bf58dd8d48988d1f3941735": "toy_store",
    // Retail > Vape Store
    "56aa371be4b08b9a8d57355c": "store",
    // Retail > Video Store
    "4bf58dd8d48988d126951735": "store",
    // Retail > Vintage and Thrift Store
    "4bf58dd8d48988d101951735": "thrift_store",
    // Retail > Warehouse or Wholesale Store
    "52e816a6bcbc57f1066b7a54": "warehouse_store",
    // Retail > Automotive Retail > Car Dealership
    "4eb1c1623b7b52c0e1adc2ec": "car_dealer",
    // Retail > Automotive Retail > Car Parts and Accessories
    "63be6904847c3692a84b9be6": "auto_parts_store",
    // Retail > Automotive Retail > Moped Dealership
    "63be6904847c3692a84b9be7": "car_dealer",
    // Retail > Automotive Retail > Motorcycle Dealership
    "5032833091d4c4b30a586d60": "car_dealer",
    // Retail > Automotive Retail > Motor Scooter Dealership
    "63be6904847c3692a84b9be8": "car_dealer",
    // Retail > Automotive Retail > Motorsports Store
    "59d79d6b2e268052fa2a3332": "store",
    // Retail > Automotive Retail > Car Dealership > Classic and Antique Car Dealership
    "63be6904847c3692a84b9be4": "car_dealer",
    // Retail > Automotive Retail > Car Dealership > New Car Dealership
    "5e8f50bd03c7a9000c1e2fbc": "car_dealer",
    // Retail > Automotive Retail > Car Dealership > RV and Motorhome Dealership
    "63be6904847c3692a84b9be5": "car_dealer",
    // Retail > Automotive Retail > Car Dealership > Used Car Dealership
    "5e8f501a03c7a9000c1e2e88": "car_dealer",
    // Retail > Bookstore > Used Bookstore
    "52f2ab2ebcbc57f1066b8b30": "book_store",
    // Retail > Computers and Electronics Retail > Camera Store
    "4eb1bdf03b7b55596b4a7491": "electronics_store",
    // Retail > Computers and Electronics Retail > Electronics Store
    "4bf58dd8d48988d122951735": "electronics_store",
    // Retail > Computers and Electronics Retail > Mobile Phone Store
    "4f04afc02fb6e1c99f3db0bc": "cell_phone_store",
    // Retail > Computers and Electronics Retail > Video Games Store
    "4bf58dd8d48988d10b951735": "store",
    // Retail > Fashion Retail > Batik Store
    "56aa371be4b08b9a8d5734cb": "clothing_store",
    // Retail > Fashion Retail > Bridal Store
    "4bf58dd8d48988d11a951735": "clothing_store",
    // Retail > Fashion Retail > Children's Clothing Store
    "4bf58dd8d48988d105951735": "clothing_store",
    // Retail > Fashion Retail > Clothing Store
    "4bf58dd8d48988d103951735": "clothing_store",
    // Retail > Fashion Retail > Fashion Accessories Store
    "4bf58dd8d48988d102951735": "clothing_store",
    // Retail > Fashion Retail > Jewelry Store
    "4bf58dd8d48988d111951735": "jewelry_store",
    // Retail > Fashion Retail > Lingerie Store
    "4bf58dd8d48988d109951735": "clothing_store",
    // Retail > Fashion Retail > Men's Store
    "4bf58dd8d48988d106951735": "clothing_store",
    // Retail > Fashion Retail > Shoe Store
    "4bf58dd8d48988d107951735": "shoe_store",
    // Retail > Fashion Retail > Sunglasses Store
    "63be6904847c3692a84b9bed": "store",
    // Retail > Fashion Retail > Swimwear Store
    "63be6904847c3692a84b9bee": "clothing_store",
    // Retail > Fashion Retail > Watch Store
    "52f2ab2ebcbc57f1066b8b2e": "jewelry_store",
    // Retail > Fashion Retail > Women's Store
    "4bf58dd8d48988d108951735": "womens_clothing_store",
    // Retail > Food and Beverage Retail > Beer Store
    "5370f356bcbc57f1066c94c2": "liquor_store",
    // Retail > Food and Beverage Retail > Butcher
    "4bf58dd8d48988d11d951735": "butcher_shop",
    // Retail > Food and Beverage Retail > Candy Store
    "4bf58dd8d48988d117951735": "candy_store",
    // Retail > Food and Beverage Retail > Cheese Store
    "4bf58dd8d48988d11e951735": "food_store",
    // Retail > Food and Beverage Retail > Chocolate Store
    "52f2ab2ebcbc57f1066b8b31": "chocolate_shop",
    // Retail > Food and Beverage Retail > Coffee Roaster
    "5e18993feee47d000759b256": "coffee_roastery",
    // Retail > Food and Beverage Retail > Dairy Store
    "58daa1558bbb0b01f18ec1ca": "food_store",
    // Retail > Food and Beverage Retail > Farmers Market
    "4bf58dd8d48988d1fa941735": "farmers_market",
    // Retail > Food and Beverage Retail > Fish Market
    "4bf58dd8d48988d10e951735": "market",
    // Retail > Food and Beverage Retail > Fruit and Vegetable Store
    "52f2ab2ebcbc57f1066b8b1c": "food_store",
    // Retail > Food and Beverage Retail > Gourmet Store
    "4bf58dd8d48988d1f5941735": "food_store",
    // Retail > Food and Beverage Retail > Grocery Store
    "4bf58dd8d48988d118951735": "grocery_store",
    // Retail > Food and Beverage Retail > Health Food Store
    "50aa9e744b90af0d42d5de0e": "health_food_store",
    // Retail > Food and Beverage Retail > Herbs and Spices Store
    "52f2ab2ebcbc57f1066b8b2c": "food_store",
    // Retail > Food and Beverage Retail > Imported Food Store
    "5f2c41945b4c177b9a6dc7d6": "food_store",
    // Retail > Food and Beverage Retail > Kosher Store
    "63be6904847c3692a84b9bef": "food_store",
    // Retail > Food and Beverage Retail > Kuruyemişçi Shop
    "58daa1558bbb0b01f18ec1e8": "food_store",
    // Retail > Food and Beverage Retail > Liquor Store
    "4bf58dd8d48988d186941735": "liquor_store",
    // Retail > Food and Beverage Retail > Meat and Seafood Store
    "63be6904847c3692a84b9bf0": "butcher_shop",
    // Retail > Food and Beverage Retail > Sausage Store
    "56aa371be4b08b9a8d573564": "butcher_shop",
    // Retail > Food and Beverage Retail > Supermarket
    "52f2ab2ebcbc57f1066b8b46": "supermarket",
    // Retail > Food and Beverage Retail > Turşucu Shop
    "58daa1558bbb0b01f18ec1e5": "food_store",
    // Retail > Food and Beverage Retail > Wine Store
    "4bf58dd8d48988d119951735": "liquor_store",
    // Retail > Food and Beverage Retail > Grocery Store > Organic Grocery
    "52f2ab2ebcbc57f1066b8b45": "grocery_store",
    // Retail > Furniture and Home Store > Carpet Store
    "52f2ab2ebcbc57f1066b8b2a": "home_goods_store",
    // Retail > Furniture and Home Store > Home Appliance Store
    "63be6904847c3692a84b9bf1": "home_goods_store",
    // Retail > Furniture and Home Store > Housewares Store
    "63be6904847c3692a84b9bf2": "home_goods_store",
    // Retail > Furniture and Home Store > Kitchen Supply Store
    "58daa1558bbb0b01f18ec1b4": "home_goods_store",
    // Retail > Furniture and Home Store > Lighting Store
    "55888a5a498e782e3303b43a": "home_goods_store",
    // Retail > Furniture and Home Store > Mattress Store
    "52f2ab2ebcbc57f1066b8b27": "home_goods_store",
    // Retail > Sporting Goods Retail > Baseball Store
    "63be6904847c3692a84b9bf5": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Bicycle Store
    "4bf58dd8d48988d115951735": "bicycle_store",
    // Retail > Sporting Goods Retail > Dive Store
    "52f2ab2ebcbc57f1066b8b1a": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Fishing Store
    "52f2ab2ebcbc57f1066b8b16": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Golf Store
    "63be6904847c3692a84b9bf6": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Gun Store
    "52f2ab2ebcbc57f1066b8b19": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Hunting Supply Store
    "50aaa5234b90af0d42d5de12": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Running Store
    "63be6904847c3692a84b9bf7": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Skate Store
    "5bae9231bedf3950379f89d2": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Ski Store
    "56aa371be4b08b9a8d573566": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Soccer Store
    "63be6904847c3692a84b9bf8": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Surf Store
    "63be6904847c3692a84b9bf9": "sporting_goods_store",
    // Retail > Sporting Goods Retail > Tennis Store
    "63be6904847c3692a84b9bfa": "sporting_goods_store",
    // Sports and Recreation > Athletic Field
    "63be6904847c3692a84b9bfd": "athletic_field",
    // Sports and Recreation > Baseball
    "63be6904847c3692a84b9bfe": "athletic_field",
    // Sports and Recreation > Basketball
    "63be6904847c3692a84b9c01": "sports_complex",
    // Sports and Recreation > Bowling Green
    "52e81612bcbc57f1066b7a2f": "park",
    // Sports and Recreation > Cricket Ground
    "4bf58dd8d48988d18a941735": "athletic_field",
    // Sports and Recreation > Curling Ice
    "56aa371be4b08b9a8d57351a": "ice_skating_rink",
    // Sports and Recreation > Equestrian Facility
    "63be6904847c3692a84b9c04": "stable",
    // Sports and Recreation > Fishing Area
    "52e81612bcbc57f1066b7a0f": "fishing_pond",
    // Sports and Recreation > Football
    "63be6904847c3692a84b9c05": "athletic_field",
    // Sports and Recreation > Golf
    "63be6904847c3692a84b9c08": "golf_course",
    // Sports and Recreation > Gun Range
    "52e81612bcbc57f1066b7a11": "sports_activity_location",
    // Sports and Recreation > Gym and Studio
    "4bf58dd8d48988d175941735": "gym",
    // Sports and Recreation > Gymnastics
    "63be6904847c3692a84b9c0a": "sports_activity_location",
    // Sports and Recreation > Hockey
    "63be6904847c3692a84b9c0b": "ice_skating_rink",
    // Sports and Recreation > Hunting Area
    "63be6904847c3692a84b9c0d": "sports_activity_location",
    // Sports and Recreation > Indoor Play Area
    "5744ccdfe4b0c0459246b4b5": "indoor_playground",
    // Sports and Recreation > Martial Arts Dojo
    "4bf58dd8d48988d101941735": "sports_school",
    // Sports and Recreation > Paintball Field
    "5032829591d4c4b30a586d5e": "paintball_center",
    // Sports and Recreation > Personal Trainer
    "63be6904847c3692a84b9c0e": "sports_coaching",
    // Sports and Recreation > Race Track
    "4bf58dd8d48988d1f4931735": "race_course",
    // Sports and Recreation > Racquet Sports
    "63be6904847c3692a84b9c0f": "sports_complex",
    // Sports and Recreation > Recreation Center
    "52e81612bcbc57f1066b7a26": "community_center",
    // Sports and Recreation > Rugby
    "63be6904847c3692a84b9c14": "athletic_field",
    // Sports and Recreation > Running and Track
    "63be6904847c3692a84b9c15": "athletic_field",
    // Sports and Recreation > Sauna
    "58daa1558bbb0b01f18ec1ae": "sauna",
    // Sports and Recreation > Skating
    "63be6904847c3692a84b9c17": "ice_skating_rink",
    // Sports and Recreation > Skydiving Center
    "63be6904847c3692a84b9c18": "adventure_sports_center",
    // Sports and Recreation > Snow Sports
    "63be6904847c3692a84b9c19": "ski_resort",
    // Sports and Recreation > Soccer
    "63be6904847c3692a84b9c1a": "athletic_field",
    // Sports and Recreation > Sports Club
    "52e81612bcbc57f1066b7a2e": "sports_club",
    // Sports and Recreation > Volleyball Court
    "4eb1bf013b7b6f98df247e07": "athletic_field",
    // Sports and Recreation > Water Sports
    "63be6904847c3692a84b9c1c": "adventure_sports_center",
    // Sports and Recreation > Baseball > Baseball Club
    "63be6904847c3692a84b9bff": "sports_club",
    // Sports and Recreation > Baseball > Baseball Field
    "4bf58dd8d48988d1e8941735": "athletic_field",
    // Sports and Recreation > Baseball > Batting Cages
    "63be6904847c3692a84b9c00": "sports_activity_location",
    // Sports and Recreation > Basketball > Basketball Club
    "63be6904847c3692a84b9c02": "sports_club",
    // Sports and Recreation > Basketball > Basketball Court
    "4bf58dd8d48988d1e1941735": "athletic_field",
    // Sports and Recreation > Football > Football Club
    "63be6904847c3692a84b9c06": "sports_club",
    // Sports and Recreation > Football > Football Field
    "63be6904847c3692a84b9c07": "athletic_field",
    // Sports and Recreation > Golf > Golf Club
    "63be6904847c3692a84b9c09": "golf_course",
    // Sports and Recreation > Golf > Golf Course
    "4bf58dd8d48988d1e6941735": "golf_course",
    // Sports and Recreation > Golf > Golf Driving Range
    "58daa1558bbb0b01f18ec1b0": "golf_course",
    // Sports and Recreation > Gym and Studio > Boxing Gym
    "52f2ab2ebcbc57f1066b8b47": "gym",
    // Sports and Recreation > Gym and Studio > Climbing Gym
    "503289d391d4c4b30a586d6a": "gym",
    // Sports and Recreation > Gym and Studio > Cycle Studio
    "52f2ab2ebcbc57f1066b8b49": "fitness_center",
    // Sports and Recreation > Gym and Studio > Dance Studio
    "4bf58dd8d48988d134941735": "sports_school",
    // Sports and Recreation > Gym and Studio > Gym
    "4bf58dd8d48988d176941735": "gym",
    // Sports and Recreation > Gym and Studio > Gym Pool
    "4bf58dd8d48988d105941735": "swimming_pool",
    // Sports and Recreation > Gym and Studio > Outdoor Gym
    "58daa1558bbb0b01f18ec203": "gym",
    // Sports and Recreation > Gym and Studio > Pilates Studio
    "5744ccdfe4b0c0459246b4b2": "fitness_center",
    // Sports and Recreation > Gym and Studio > Yoga Studio
    "4bf58dd8d48988d102941735": "yoga_studio",
    // Sports and Recreation > Gymnastics > Gymnastics Center
    "52f2ab2ebcbc57f1066b8b48": "sports_complex",
    // Sports and Recreation > Hockey > Hockey Club
    "63be6904847c3692a84b9c0c": "sports_club",
    // Sports and Recreation > Hockey > Hockey Field
    "4f452cd44b9081a197eba860": "athletic_field",
    // Sports and Recreation > Hockey > Hockey Rink
    "56aa371be4b08b9a8d57352c": "ice_skating_rink",
    // Sports and Recreation > Race Track > Racecourse
    "56aa371be4b08b9a8d573514": "race_course",
    // Sports and Recreation > Racquet Sports > Badminton Court
    "52e81612bcbc57f1066b7a2b": "sports_complex",
    // Sports and Recreation > Racquet Sports > Racquetball Club
    "63be6904847c3692a84b9c11": "sports_club",
    // Sports and Recreation > Racquet Sports > Racquet Sport Club
    "63be6904847c3692a84b9c10": "sports_club",
    // Sports and Recreation > Racquet Sports > Squash Court
    "52e81612bcbc57f1066b7a2d": "sports_complex",
    // Sports and Recreation > Racquet Sports > Tennis
    "63be6904847c3692a84b9c12": "tennis_court",
    // Sports and Recreation > Racquet Sports > Tennis > Tennis Club
    "63be6904847c3692a84b9c13": "sports_club",
    // Sports and Recreation > Racquet Sports > Tennis > Tennis Court
    "4e39a956bd410d7aed40cbc3": "tennis_court",
    // Sports and Recreation > Rugby > Rugby Pitch
    "52e81612bcbc57f1066b7a2c": "athletic_field",
    // Sports and Recreation > Running and Track > Running Club
    "63be6904847c3692a84b9c16": "sports_club",
    // Sports and Recreation > Running and Track > Track
    "4bf58dd8d48988d106941735": "athletic_field",
    // Sports and Recreation > Skating > Skate Park
    "4bf58dd8d48988d167941735": "skateboard_park",
    // Sports and Recreation > Skating > Skating Rink
    "4bf58dd8d48988d168941735": "ice_skating_rink",
    // Sports and Recreation > Skydiving Center > Skydiving Drop Zone
    "58daa1558bbb0b01f18ec1b9": "adventure_sports_center",
    // Sports and Recreation > Snow Sports > Ski Chalet
    "4bf58dd8d48988d1ec941735": "ski_resort",
    // Sports and Recreation > Snow Sports > Ski Lodge
    "4bf58dd8d48988d1eb941735": "ski_resort",
    // Sports and Recreation > Snow Sports > Ski Resort and Area
    "4bf58dd8d48988d1e9941735": "ski_resort",
    // Sports and Recreation > Snow Sports > Ski Resort and Area > Ski Chairlift
    "4eb1c0ed3b7b52c0e1adc2ea": "ski_resort",
    // Sports and Recreation > Snow Sports > Ski Resort and Area > Ski Trail
    "4eb1c0f63b7b52c0e1adc2eb": "ski_resort",
    // Sports and Recreation > Soccer > Soccer Club
    "63be6904847c3692a84b9c1b": "sports_club",
    // Sports and Recreation > Soccer > Soccer Field
    "4cce455aebf7b749d5e191f5": "athletic_field",
    // Sports and Recreation > Water Sports > Canoe and Kayak Rental
    "63be6904847c3692a84b9c1d": "adventure_sports_center",
    // Sports and Recreation > Water Sports > Rafting Outfitter
    "63be6904847c3692a84b9c1e": "adventure_sports_center",
    // Sports and Recreation > Water Sports > Rafting Spot
    "52e81612bcbc57f1066b7a29": "adventure_sports_center",
    // Sports and Recreation > Water Sports > Sailing Club
    "63be6904847c3692a84b9c1f": "sports_club",
    // Sports and Recreation > Water Sports > Scuba Diving Instructor
    "63be6904847c3692a84b9c20": "sports_coaching",
    // Sports and Recreation > Water Sports > Surfing
    "63be6904847c3692a84b9c21": "adventure_sports_center",
    // Sports and Recreation > Water Sports > Swimming
    "63be6904847c3692a84b9c22": "swimming_pool",
    // Sports and Recreation > Water Sports > Swimming > Swimming Club
    "63be6904847c3692a84b9c23": "sports_club",
    // Sports and Recreation > Water Sports > Swimming > Swimming Pool
    "4bf58dd8d48988d15e941735": "swimming_pool",
    // Sports and Recreation > Water Sports > Swimming > Swim School
    "52e81612bcbc57f1066b7a44": "sports_school",
    // Travel and Transportation > Baggage Locker
    "5744ccdfe4b0c0459246b4e8": "storage",
    // Travel and Transportation > Bike Rental
    "4e4c9077bd41f78e849722f9": "bike_sharing_station", // Inexact
    // Travel and Transportation > Boat or Ferry
    "4bf58dd8d48988d12d951735": "ferry_terminal",
    // Travel and Transportation > Boat Rental
    "5744ccdfe4b0c0459246b4c1": "marina", // Inexact
    // Travel and Transportation > Border Crossing
    "52f2ab2ebcbc57f1066b8b4b": "transit_station",
    // Travel and Transportation > Cable Car
    "52f2ab2ebcbc57f1066b8b50": "transit_station",
    // Travel and Transportation > Cruise
    "55077a22498e5e9248869ba2": "marina", // Inexact
    // Travel and Transportation > Electric Vehicle Charging Station
    "5032872391d4c4b30a586d64": "electric_vehicle_charging_station",
    // Travel and Transportation > Fuel Station
    "4bf58dd8d48988d113951735": "gas_station",
    // Travel and Transportation > Hot Air Balloon Tour Agency
    "63be6904847c3692a84b9c24": "tour_agency",
    // Travel and Transportation > Lodging
    "63be6904847c3692a84b9c25": "lodging",
    // Travel and Transportation > Moving Target
    "4f2a23984b9023bd5841ed2c": nil, // No clear google place type
    // Travel and Transportation > Parking
    "4c38df4de52ce0d596b336e1": "parking",
    // Travel and Transportation > Pier
    "4e74f6cabd41c4836eac4c31": "point_of_interest", // Inexact
    // Travel and Transportation > Platform
    "4f4531504b9074f6e4fb0102": "transit_station",
    // Travel and Transportation > Port
    "56aa371be4b08b9a8d57353e": "ferry_terminal", // Inexact
    // Travel and Transportation > Rest Area
    "4d954b16a243a5684b65b473": "rest_stop",
    // Travel and Transportation > Road
    "4bf58dd8d48988d1f9931735": "route",
    // Travel and Transportation > RV Park
    "52f2ab2ebcbc57f1066b8b53": "rv_park",
    // Travel and Transportation > Toll Booth
    "52f2ab2ebcbc57f1066b8b4d": "toll_station",
    // Travel and Transportation > Toll Plaza
    "52f2ab2ebcbc57f1066b8b4e": "toll_station",
    // Travel and Transportation > Tourist Information and Service
    "4f4530164b9074f6e4fb00ff": "tourist_information_center",
    // Travel and Transportation > Train
    "4bf58dd8d48988d12a951735": "train_station",
    // Travel and Transportation > Transportation Service
    "54541b70498ea6ccd0204bff": "transportation_service",
    // Travel and Transportation > Transport Hub
    "63be6904847c3692a84b9c28": "transit_station",
    // Travel and Transportation > Travel Agency
    "4f04b08c2fb6e1c99f3db0bd": "travel_agency",
    // Travel and Transportation > Travel Lounge
    "4f04b25d2fb6e1c99f3db0c0": "transit_station",
    // Travel and Transportation > Truck Stop
    "57558b36e4b065ecebd306dd": "truck_stop",
    // Travel and Transportation > Lodging > Bed and Breakfast
    "4bf58dd8d48988d1f8931735": "bed_and_breakfast",
    // Travel and Transportation > Lodging > Boarding House
    "4f4530a74b9074f6e4fb0100": "guest_house",
    // Travel and Transportation > Lodging > Cabin
    "63be6904847c3692a84b9c26": "camping_cabin",
    // Travel and Transportation > Lodging > Hostel
    "4bf58dd8d48988d1ee931735": "hostel",
    // Travel and Transportation > Lodging > Hotel
    "4bf58dd8d48988d1fa931735": "hotel",
    // Travel and Transportation > Lodging > Inn
    "5bae9231bedf3950379f89cb": "inn",
    // Travel and Transportation > Lodging > Lodge
    "63be6904847c3692a84b9c27": "lodging",
    // Travel and Transportation > Lodging > Motel
    "4bf58dd8d48988d1fb931735": "motel",
    // Travel and Transportation > Lodging > Resort
    "4bf58dd8d48988d12f951735": "resort_hotel",
    // Travel and Transportation > Lodging > Vacation Rental
    "56aa371be4b08b9a8d5734e1": "lodging",
    // Travel and Transportation > Lodging > Hotel > Hotel Pool
    "4bf58dd8d48988d132951735": "swimming_pool",
    // Travel and Transportation > Road > Intersection
    "52f2ab2ebcbc57f1066b8b4c": "intersection",
    // Travel and Transportation > Tourist Information and Service > Tour Provider
    "56aa371be4b08b9a8d573520": "tour_agency",
    // Travel and Transportation > Transportation Service > Charter Bus
    "63be6904847c3692a84b9c2b": "transportation_service",
    // Travel and Transportation > Transportation Service > Limo Service
    "63be6904847c3692a84b9c2c": "chauffeur_service",
    // Travel and Transportation > Transportation Service > Public Transportation
    "63be6904847c3692a84b9c2d": "transit_station",
    // Travel and Transportation > Transportation Service > Taxi
    "4bf58dd8d48988d130951735": "taxi_service",
    // Travel and Transportation > Transportation Service > Public Transportation > Bus Line
    "4bf58dd8d48988d12b951735": "bus_station",
    // Travel and Transportation > Transport Hub > Airport
    "4bf58dd8d48988d1ed931735": "airport",
    // Travel and Transportation > Transport Hub > Bus Station
    "4bf58dd8d48988d1fe931735": "bus_station",
    // Travel and Transportation > Transport Hub > Bus Stop
    "52f2ab2ebcbc57f1066b8b4f": "bus_stop",
    // Travel and Transportation > Transport Hub > Heliport
    "56aa371ce4b08b9a8d57356e": "heliport",
    // Travel and Transportation > Transport Hub > Light Rail Station
    "4bf58dd8d48988d1fc931735": "light_rail_station",
    // Travel and Transportation > Transport Hub > Marine Terminal
    "5f2c1af1b6d05514c704319d": "ferry_terminal",
    // Travel and Transportation > Transport Hub > Metro Station
    "4bf58dd8d48988d1fd931735": "subway_station",
    // Travel and Transportation > Transport Hub > Rail Station
    "4bf58dd8d48988d129951735": "train_station",
    // Travel and Transportation > Transport Hub > Rental Car Location
    "4bf58dd8d48988d1ef941735": "car_rental",
    // Travel and Transportation > Transport Hub > Taxi Stand
    "53fca564498e1a175f32528b": "taxi_stand",
    // Travel and Transportation > Transport Hub > Tram Station
    "52f2ab2ebcbc57f1066b8b51": "tram_stop",
    // Travel and Transportation > Transport Hub > Airport > Airfield
    "5f2c42335b4c177b9a6dc927": "airstrip",
    // Travel and Transportation > Transport Hub > Airport > Airport Food Court
    "4bf58dd8d48988d1ef931735": "food_court",
    // Travel and Transportation > Transport Hub > Airport > Airport Gate
    "4bf58dd8d48988d1f0931735": "airport",
    // Travel and Transportation > Transport Hub > Airport > Airport Lounge
    "4eb1bc533b7b2c5b1d4306cb": "airport",
    // Travel and Transportation > Transport Hub > Airport > Airport Service
    "56aa371be4b08b9a8d57352f": "airport",
    // Travel and Transportation > Transport Hub > Airport > Airport Terminal
    "4bf58dd8d48988d1eb931735": "airport",
    // Travel and Transportation > Transport Hub > Airport > Airport Ticket Counter
    "60a674555c7917283bad6839": "airport",
    // Travel and Transportation > Transport Hub > Airport > Airport Tram Station
    "4bf58dd8d48988d1ec931735": "tram_stop",
    // Travel and Transportation > Transport Hub > Airport > Baggage Claim
    "5744ccdfe4b0c0459246b4e5": "airport",
    // Travel and Transportation > Transport Hub > Airport > International Airport
    "63be6904847c3692a84b9c29": "international_airport",
    // Travel and Transportation > Transport Hub > Airport > Plane
    "4bf58dd8d48988d1f7931735": "airport",
    // Travel and Transportation > Transport Hub > Airport > Private Airport
    "63be6904847c3692a84b9c2a": "airport",
    // Arts and Entertainment
    "4d4b7104d754a06370d81259": "establishment", // REVIEW: no clear google place type
    // Business and Professional Services
    "4d4b7105d754a06375d81259": "service", // REVIEW: no clear google place type
    // Community and Government
    "63be6904847c3692a84b9b9a": "service", // REVIEW: no clear google place type
    // Dining and Drinking
    "63be6904847c3692a84b9bb5": "restaurant",
    // Event
    "4d4b7105d754a06373d81259": "event_venue",
    // Health and Medicine
    "63be6904847c3692a84b9bb9": "health", // REVIEW: no clear google place type
    // Landmarks and Outdoors
    "4d4b7105d754a06377d81259": "point_of_interest", // REVIEW: no clear google place type
    // Retail
    "4d4b7105d754a06378d81259": "store",
    // Sports and Recreation
    "4f4528bc4b90abdf24c9de85": "sports_activity_location", // REVIEW: no clear google place type
    // Travel and Transportation
    "4d4b7105d754a06379d81259": "point_of_interest", // REVIEW: no clear google place type
]