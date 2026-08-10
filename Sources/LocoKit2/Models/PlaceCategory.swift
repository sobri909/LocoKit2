//
//  PlaceCategory.swift
//  LocoKit2
//
//  Created by Claude on 2026-08-10
//
//  GENERATED FILE — regenerate via Scripts/placecategory/generate_placecategory.py
//  (BIG-513). Canonical taxonomy: Google Places primaryType vocabulary
//  (~514 types under 20 groups), from Yinon's prep gist, plus
//  Arc-specific private categories. rawValue IS the Google primaryType
//  string (or "arc_"-prefixed for Arc-private cases) — the same vocabulary
//  is stored in Place.userCategory and used in exports.
//

public enum PlaceCategory: String, Codable, Hashable, Sendable, CaseIterable {

    // MARK: - Automotive

    case carDealer = "car_dealer"
    case carRental = "car_rental"
    case carRepair = "car_repair"
    case carWash = "car_wash"
    case ebikeChargingStation = "ebike_charging_station"
    case electricVehicleChargingStation = "electric_vehicle_charging_station"
    case gasStation = "gas_station"
    case parking = "parking"
    case parkingGarage = "parking_garage"
    case parkingLot = "parking_lot"
    case restStop = "rest_stop"
    case tireShop = "tire_shop"
    case truckDealer = "truck_dealer"

    // MARK: - Business

    case businessCenter = "business_center"
    case corporateOffice = "corporate_office"
    case coworkingSpace = "coworking_space"
    case farm = "farm"
    case manufacturer = "manufacturer"
    case ranch = "ranch"
    case supplier = "supplier"
    case televisionStudio = "television_studio"

    // MARK: - Culture

    case artGallery = "art_gallery"
    case artMuseum = "art_museum"
    case artStudio = "art_studio"
    case auditorium = "auditorium"
    case castle = "castle"
    case culturalLandmark = "cultural_landmark"
    case fountain = "fountain"
    case historicalPlace = "historical_place"
    case historyMuseum = "history_museum"
    case monument = "monument"
    case museum = "museum"
    case performingArtsTheater = "performing_arts_theater"
    case sculpture = "sculpture"

    // MARK: - Education

    case academicDepartment = "academic_department"
    case educationalInstitution = "educational_institution"
    case library = "library"
    case preschool = "preschool"
    case primarySchool = "primary_school"
    case researchInstitute = "research_institute"
    case school = "school"
    case secondarySchool = "secondary_school"
    case university = "university"

    // MARK: - Entertainment and Recreation

    case adventureSportsCenter = "adventure_sports_center"
    case amphitheatre = "amphitheatre"
    case amusementCenter = "amusement_center"
    case amusementPark = "amusement_park"
    case aquarium = "aquarium"
    case banquetHall = "banquet_hall"
    case barbecueArea = "barbecue_area"
    case botanicalGarden = "botanical_garden"
    case bowlingAlley = "bowling_alley"
    case casino = "casino"
    case childrensCamp = "childrens_camp"
    case cityPark = "city_park"
    case comedyClub = "comedy_club"
    case communityCenter = "community_center"
    case concertHall = "concert_hall"
    case conventionCenter = "convention_center"
    case culturalCenter = "cultural_center"
    case cyclingPark = "cycling_park"
    case danceHall = "dance_hall"
    case dogPark = "dog_park"
    case eventVenue = "event_venue"
    case ferrisWheel = "ferris_wheel"
    case garden = "garden"
    case goKartingVenue = "go_karting_venue"
    case hikingArea = "hiking_area"
    case historicalLandmark = "historical_landmark"
    case indoorPlayground = "indoor_playground"
    case internetCafe = "internet_cafe"
    case karaoke = "karaoke"
    case liveMusicVenue = "live_music_venue"
    case marina = "marina"
    case miniatureGolfCourse = "miniature_golf_course"
    case movieRental = "movie_rental"
    case movieTheater = "movie_theater"
    case nationalPark = "national_park"
    case nightClub = "night_club"
    case observationDeck = "observation_deck"
    case offRoadingArea = "off_roading_area"
    case operaHouse = "opera_house"
    case paintballCenter = "paintball_center"
    case park = "park"
    case philharmonicHall = "philharmonic_hall"
    case picnicGround = "picnic_ground"
    case planetarium = "planetarium"
    case plaza = "plaza"
    case rollerCoaster = "roller_coaster"
    case skateboardPark = "skateboard_park"
    case statePark = "state_park"
    case touristAttraction = "tourist_attraction"
    case videoArcade = "video_arcade"
    case vineyard = "vineyard"
    case visitorCenter = "visitor_center"
    case waterPark = "water_park"
    case weddingVenue = "wedding_venue"
    case wildlifePark = "wildlife_park"
    case wildlifeRefuge = "wildlife_refuge"
    case zoo = "zoo"

    // MARK: - Facilities

    case publicBath = "public_bath"
    case publicBathroom = "public_bathroom"
    case stable = "stable"

    // MARK: - Finance

    case accounting = "accounting"
    case atm = "atm"
    case bank = "bank"

    // MARK: - Food and Drink

    case acaiShop = "acai_shop"
    case afghaniRestaurant = "afghani_restaurant"
    case africanRestaurant = "african_restaurant"
    case americanRestaurant = "american_restaurant"
    case argentinianRestaurant = "argentinian_restaurant"
    case asianFusionRestaurant = "asian_fusion_restaurant"
    case asianRestaurant = "asian_restaurant"
    case australianRestaurant = "australian_restaurant"
    case austrianRestaurant = "austrian_restaurant"
    case bagelShop = "bagel_shop"
    case bakery = "bakery"
    case bangladeshiRestaurant = "bangladeshi_restaurant"
    case bar = "bar"
    case barAndGrill = "bar_and_grill"
    case barbecueRestaurant = "barbecue_restaurant"
    case basqueRestaurant = "basque_restaurant"
    case bavarianRestaurant = "bavarian_restaurant"
    case beerGarden = "beer_garden"
    case belgianRestaurant = "belgian_restaurant"
    case bistro = "bistro"
    case brazilianRestaurant = "brazilian_restaurant"
    case breakfastRestaurant = "breakfast_restaurant"
    case brewery = "brewery"
    case brewpub = "brewpub"
    case britishRestaurant = "british_restaurant"
    case brunchRestaurant = "brunch_restaurant"
    case buffetRestaurant = "buffet_restaurant"
    case burmeseRestaurant = "burmese_restaurant"
    case burritoRestaurant = "burrito_restaurant"
    case cafe = "cafe"
    case cafeteria = "cafeteria"
    case cajunRestaurant = "cajun_restaurant"
    case cakeShop = "cake_shop"
    case californianRestaurant = "californian_restaurant"
    case cambodianRestaurant = "cambodian_restaurant"
    case candyStore = "candy_store"
    case cantoneseRestaurant = "cantonese_restaurant"
    case caribbeanRestaurant = "caribbean_restaurant"
    case catCafe = "cat_cafe"
    case chickenRestaurant = "chicken_restaurant"
    case chickenWingsRestaurant = "chicken_wings_restaurant"
    case chileanRestaurant = "chilean_restaurant"
    case chineseNoodleRestaurant = "chinese_noodle_restaurant"
    case chineseRestaurant = "chinese_restaurant"
    case chocolateFactory = "chocolate_factory"
    case chocolateShop = "chocolate_shop"
    case cocktailBar = "cocktail_bar"
    case coffeeRoastery = "coffee_roastery"
    case coffeeShop = "coffee_shop"
    case coffeeStand = "coffee_stand"
    case colombianRestaurant = "colombian_restaurant"
    case confectionery = "confectionery"
    case croatianRestaurant = "croatian_restaurant"
    case cubanRestaurant = "cuban_restaurant"
    case czechRestaurant = "czech_restaurant"
    case danishRestaurant = "danish_restaurant"
    case deli = "deli"
    case dessertRestaurant = "dessert_restaurant"
    case dessertShop = "dessert_shop"
    case dimSumRestaurant = "dim_sum_restaurant"
    case diner = "diner"
    case dogCafe = "dog_cafe"
    case donutShop = "donut_shop"
    case dumplingRestaurant = "dumpling_restaurant"
    case dutchRestaurant = "dutch_restaurant"
    case easternEuropeanRestaurant = "eastern_european_restaurant"
    case ethiopianRestaurant = "ethiopian_restaurant"
    case europeanRestaurant = "european_restaurant"
    case falafelRestaurant = "falafel_restaurant"
    case familyRestaurant = "family_restaurant"
    case fastFoodRestaurant = "fast_food_restaurant"
    case filipinoRestaurant = "filipino_restaurant"
    case fineDiningRestaurant = "fine_dining_restaurant"
    case fishAndChipsRestaurant = "fish_and_chips_restaurant"
    case fondueRestaurant = "fondue_restaurant"
    case foodCourt = "food_court"
    case frenchRestaurant = "french_restaurant"
    case fusionRestaurant = "fusion_restaurant"
    case gastropub = "gastropub"
    case germanRestaurant = "german_restaurant"
    case greekRestaurant = "greek_restaurant"
    case gyroRestaurant = "gyro_restaurant"
    case halalRestaurant = "halal_restaurant"
    case hamburgerRestaurant = "hamburger_restaurant"
    case hawaiianRestaurant = "hawaiian_restaurant"
    case hookahBar = "hookah_bar"
    case hotDogRestaurant = "hot_dog_restaurant"
    case hotDogStand = "hot_dog_stand"
    case hotPotRestaurant = "hot_pot_restaurant"
    case hungarianRestaurant = "hungarian_restaurant"
    case iceCreamShop = "ice_cream_shop"
    case indianRestaurant = "indian_restaurant"
    case indonesianRestaurant = "indonesian_restaurant"
    case irishPub = "irish_pub"
    case irishRestaurant = "irish_restaurant"
    case israeliRestaurant = "israeli_restaurant"
    case italianRestaurant = "italian_restaurant"
    case japaneseCurryRestaurant = "japanese_curry_restaurant"
    case japaneseIzakayaRestaurant = "japanese_izakaya_restaurant"
    case japaneseRestaurant = "japanese_restaurant"
    case juiceShop = "juice_shop"
    case kebabShop = "kebab_shop"
    case koreanBarbecueRestaurant = "korean_barbecue_restaurant"
    case koreanRestaurant = "korean_restaurant"
    case latinAmericanRestaurant = "latin_american_restaurant"
    case lebaneseRestaurant = "lebanese_restaurant"
    case loungeBar = "lounge_bar"
    case malaysianRestaurant = "malaysian_restaurant"
    case mealDelivery = "meal_delivery"
    case mealTakeaway = "meal_takeaway"
    case mediterraneanRestaurant = "mediterranean_restaurant"
    case mexicanRestaurant = "mexican_restaurant"
    case middleEasternRestaurant = "middle_eastern_restaurant"
    case mongolianBarbecueRestaurant = "mongolian_barbecue_restaurant"
    case moroccanRestaurant = "moroccan_restaurant"
    case noodleShop = "noodle_shop"
    case northIndianRestaurant = "north_indian_restaurant"
    case oysterBarRestaurant = "oyster_bar_restaurant"
    case pakistaniRestaurant = "pakistani_restaurant"
    case pastryShop = "pastry_shop"
    case persianRestaurant = "persian_restaurant"
    case peruvianRestaurant = "peruvian_restaurant"
    case pizzaDelivery = "pizza_delivery"
    case pizzaRestaurant = "pizza_restaurant"
    case polishRestaurant = "polish_restaurant"
    case portugueseRestaurant = "portuguese_restaurant"
    case pub = "pub"
    case ramenRestaurant = "ramen_restaurant"
    case restaurant = "restaurant"
    case romanianRestaurant = "romanian_restaurant"
    case russianRestaurant = "russian_restaurant"
    case saladShop = "salad_shop"
    case sandwichShop = "sandwich_shop"
    case scandinavianRestaurant = "scandinavian_restaurant"
    case seafoodRestaurant = "seafood_restaurant"
    case shawarmaRestaurant = "shawarma_restaurant"
    case snackBar = "snack_bar"
    case soulFoodRestaurant = "soul_food_restaurant"
    case soupRestaurant = "soup_restaurant"
    case southAmericanRestaurant = "south_american_restaurant"
    case southIndianRestaurant = "south_indian_restaurant"
    case southwesternUsRestaurant = "southwestern_us_restaurant"
    case spanishRestaurant = "spanish_restaurant"
    case sportsBar = "sports_bar"
    case sriLankanRestaurant = "sri_lankan_restaurant"
    case steakHouse = "steak_house"
    case sushiRestaurant = "sushi_restaurant"
    case swissRestaurant = "swiss_restaurant"
    case tacoRestaurant = "taco_restaurant"
    case taiwaneseRestaurant = "taiwanese_restaurant"
    case tapasRestaurant = "tapas_restaurant"
    case teaHouse = "tea_house"
    case texMexRestaurant = "tex_mex_restaurant"
    case thaiRestaurant = "thai_restaurant"
    case tibetanRestaurant = "tibetan_restaurant"
    case tonkatsuRestaurant = "tonkatsu_restaurant"
    case turkishRestaurant = "turkish_restaurant"
    case ukrainianRestaurant = "ukrainian_restaurant"
    case veganRestaurant = "vegan_restaurant"
    case vegetarianRestaurant = "vegetarian_restaurant"
    case vietnameseRestaurant = "vietnamese_restaurant"
    case westernRestaurant = "western_restaurant"
    case wineBar = "wine_bar"
    case winery = "winery"
    case yakinikuRestaurant = "yakiniku_restaurant"
    case yakitoriRestaurant = "yakitori_restaurant"

    // MARK: - Geographical Areas

    case administrativeAreaLevel1 = "administrative_area_level_1"
    case administrativeAreaLevel2 = "administrative_area_level_2"
    case country = "country"
    case locality = "locality"
    case postalCode = "postal_code"
    case schoolDistrict = "school_district"

    // MARK: - Government

    case cityHall = "city_hall"
    case courthouse = "courthouse"
    case embassy = "embassy"
    case fireStation = "fire_station"
    case governmentOffice = "government_office"
    case localGovernmentOffice = "local_government_office"
    case neighborhoodPoliceStation = "neighborhood_police_station"
    case police = "police"
    case postOffice = "post_office"

    // MARK: - Health and Wellness

    case chiropractor = "chiropractor"
    case dentalClinic = "dental_clinic"
    case dentist = "dentist"
    case doctor = "doctor"
    case drugstore = "drugstore"
    case generalHospital = "general_hospital"
    case hospital = "hospital"
    case massage = "massage"
    case massageSpa = "massage_spa"
    case medicalCenter = "medical_center"
    case medicalClinic = "medical_clinic"
    case medicalLab = "medical_lab"
    case pharmacy = "pharmacy"
    case physiotherapist = "physiotherapist"
    case sauna = "sauna"
    case skinCareClinic = "skin_care_clinic"
    case spa = "spa"
    case tanningStudio = "tanning_studio"
    case wellnessCenter = "wellness_center"
    case yogaStudio = "yoga_studio"

    // MARK: - Housing

    case apartmentBuilding = "apartment_building"
    case apartmentComplex = "apartment_complex"
    case condominiumComplex = "condominium_complex"
    case housingComplex = "housing_complex"

    // MARK: - Lodging

    case bedAndBreakfast = "bed_and_breakfast"
    case budgetJapaneseInn = "budget_japanese_inn"
    case campground = "campground"
    case campingCabin = "camping_cabin"
    case cottage = "cottage"
    case extendedStayHotel = "extended_stay_hotel"
    case farmstay = "farmstay"
    case guestHouse = "guest_house"
    case hostel = "hostel"
    case hotel = "hotel"
    case inn = "inn"
    case japaneseInn = "japanese_inn"
    case lodging = "lodging"
    case mobileHomePark = "mobile_home_park"
    case motel = "motel"
    case privateGuestRoom = "private_guest_room"
    case resortHotel = "resort_hotel"
    case rvPark = "rv_park"

    // MARK: - Natural Features

    case beach = "beach"
    case island = "island"
    case lake = "lake"
    case mountainPeak = "mountain_peak"
    case naturePreserve = "nature_preserve"
    case river = "river"
    case scenicSpot = "scenic_spot"
    case woods = "woods"

    // MARK: - Places of Worship

    case buddhistTemple = "buddhist_temple"
    case church = "church"
    case hinduTemple = "hindu_temple"
    case mosque = "mosque"
    case shintoShrine = "shinto_shrine"
    case synagogue = "synagogue"

    // MARK: - Services

    case aircraftRentalService = "aircraft_rental_service"
    case associationOrOrganization = "association_or_organization"
    case astrologer = "astrologer"
    case barberShop = "barber_shop"
    case beautician = "beautician"
    case beautySalon = "beauty_salon"
    case bodyArtService = "body_art_service"
    case cateringService = "catering_service"
    case cemetery = "cemetery"
    case chauffeurService = "chauffeur_service"
    case childCareAgency = "child_care_agency"
    case consultant = "consultant"
    case courierService = "courier_service"
    case electrician = "electrician"
    case employmentAgency = "employment_agency"
    case florist = "florist"
    case foodDelivery = "food_delivery"
    case footCare = "foot_care"
    case funeralHome = "funeral_home"
    case hairCare = "hair_care"
    case hairSalon = "hair_salon"
    case insuranceAgency = "insurance_agency"
    case laundry = "laundry"
    case lawyer = "lawyer"
    case locksmith = "locksmith"
    case makeupArtist = "makeup_artist"
    case marketingConsultant = "marketing_consultant"
    case movingCompany = "moving_company"
    case nailSalon = "nail_salon"
    case nonProfitOrganization = "non_profit_organization"
    case painter = "painter"
    case petBoardingService = "pet_boarding_service"
    case petCare = "pet_care"
    case plumber = "plumber"
    case psychic = "psychic"
    case realEstateAgency = "real_estate_agency"
    case roofingContractor = "roofing_contractor"
    case service = "service"
    case shippingService = "shipping_service"
    case storage = "storage"
    case summerCampOrganizer = "summer_camp_organizer"
    case tailor = "tailor"
    case telecommunicationsServiceProvider = "telecommunications_service_provider"
    case tourAgency = "tour_agency"
    case touristInformationCenter = "tourist_information_center"
    case travelAgency = "travel_agency"
    case veterinaryCare = "veterinary_care"

    // MARK: - Shopping

    case asianGroceryStore = "asian_grocery_store"
    case autoPartsStore = "auto_parts_store"
    case bicycleStore = "bicycle_store"
    case bookStore = "book_store"
    case buildingMaterialsStore = "building_materials_store"
    case butcherShop = "butcher_shop"
    case cellPhoneStore = "cell_phone_store"
    case clothingStore = "clothing_store"
    case convenienceStore = "convenience_store"
    case cosmeticsStore = "cosmetics_store"
    case departmentStore = "department_store"
    case discountStore = "discount_store"
    case discountSupermarket = "discount_supermarket"
    case electronicsStore = "electronics_store"
    case farmersMarket = "farmers_market"
    case fleaMarket = "flea_market"
    case foodStore = "food_store"
    case furnitureStore = "furniture_store"
    case gardenCenter = "garden_center"
    case generalStore = "general_store"
    case giftShop = "gift_shop"
    case groceryStore = "grocery_store"
    case hardwareStore = "hardware_store"
    case healthFoodStore = "health_food_store"
    case homeGoodsStore = "home_goods_store"
    case homeImprovementStore = "home_improvement_store"
    case hypermarket = "hypermarket"
    case jewelryStore = "jewelry_store"
    case liquorStore = "liquor_store"
    case market = "market"
    case petStore = "pet_store"
    case shoeStore = "shoe_store"
    case shoppingMall = "shopping_mall"
    case sportingGoodsStore = "sporting_goods_store"
    case sportswearStore = "sportswear_store"
    case store = "store"
    case supermarket = "supermarket"
    case teaStore = "tea_store"
    case thriftStore = "thrift_store"
    case toyStore = "toy_store"
    case warehouseStore = "warehouse_store"
    case wholesaler = "wholesaler"
    case womensClothingStore = "womens_clothing_store"

    // MARK: - Sports

    case arena = "arena"
    case athleticField = "athletic_field"
    case fishingCharter = "fishing_charter"
    case fishingPier = "fishing_pier"
    case fishingPond = "fishing_pond"
    case fitnessCenter = "fitness_center"
    case golfCourse = "golf_course"
    case gym = "gym"
    case iceSkatingRink = "ice_skating_rink"
    case indoorGolfCourse = "indoor_golf_course"
    case playground = "playground"
    case raceCourse = "race_course"
    case skiResort = "ski_resort"
    case sportsActivityLocation = "sports_activity_location"
    case sportsClub = "sports_club"
    case sportsCoaching = "sports_coaching"
    case sportsComplex = "sports_complex"
    case sportsSchool = "sports_school"
    case stadium = "stadium"
    case swimmingPool = "swimming_pool"
    case tennisCourt = "tennis_court"

    // MARK: - Transportation

    case airport = "airport"
    case airstrip = "airstrip"
    case bikeSharingStation = "bike_sharing_station"
    case bridge = "bridge"
    case busStation = "bus_station"
    case busStop = "bus_stop"
    case ferryService = "ferry_service"
    case ferryTerminal = "ferry_terminal"
    case heliport = "heliport"
    case internationalAirport = "international_airport"
    case lightRailStation = "light_rail_station"
    case parkAndRide = "park_and_ride"
    case subwayStation = "subway_station"
    case taxiService = "taxi_service"
    case taxiStand = "taxi_stand"
    case tollStation = "toll_station"
    case trainStation = "train_station"
    case trainTicketOffice = "train_ticket_office"
    case tramStop = "tram_stop"
    case transitDepot = "transit_depot"
    case transitStation = "transit_station"
    case transitStop = "transit_stop"
    case transportationService = "transportation_service"
    case truckStop = "truck_stop"

    // MARK: - Additional Place type values

    case administrativeAreaLevel3 = "administrative_area_level_3"
    case administrativeAreaLevel4 = "administrative_area_level_4"
    case administrativeAreaLevel5 = "administrative_area_level_5"
    case administrativeAreaLevel6 = "administrative_area_level_6"
    case administrativeAreaLevel7 = "administrative_area_level_7"
    case archipelago = "archipelago"
    case colloquialArea = "colloquial_area"
    case continent = "continent"
    case establishment = "establishment"
    case finance = "finance"
    case food = "food"
    case generalContractor = "general_contractor"
    case geocode = "geocode"
    case health = "health"
    case intersection = "intersection"
    case landmark = "landmark"
    case naturalFeature = "natural_feature"
    case neighborhood = "neighborhood"
    case placeOfWorship = "place_of_worship"
    case plusCode = "plus_code"
    case pointOfInterest = "point_of_interest"
    case political = "political"
    case postalCodePrefix = "postal_code_prefix"
    case postalCodeSuffix = "postal_code_suffix"
    case postalTown = "postal_town"
    case premise = "premise"
    case route = "route"
    case streetAddress = "street_address"
    case sublocality = "sublocality"
    case sublocalityLevel1 = "sublocality_level_1"
    case sublocalityLevel2 = "sublocality_level_2"
    case sublocalityLevel3 = "sublocality_level_3"
    case sublocalityLevel4 = "sublocality_level_4"
    case sublocalityLevel5 = "sublocality_level_5"
    case subpremise = "subpremise"
    case townSquare = "town_square"

    // MARK: - Arc private categories

    case home = "arc_home"
    case friendsHome = "arc_friends_home"
    case vacationRental = "arc_vacation_rental"

    // MARK: - Groups

    public enum Group: String, Codable, Hashable, Sendable, CaseIterable {
        case automotive
        case business
        case culture
        case education
        case entertainmentAndRecreation
        case facilities
        case finance
        case foodAndDrink
        case geographicalAreas
        case government
        case healthAndWellness
        case housing
        case lodging
        case naturalFeatures
        case placesOfWorship
        case services
        case shopping
        case sports
        case transportation
        case other
        case personal
    }

    public var group: Group {
        switch self {
        case .carDealer, .carRental, .carRepair, .carWash, .ebikeChargingStation, .electricVehicleChargingStation, 
             .gasStation, .parking, .parkingGarage, .parkingLot, .restStop, .tireShop, .truckDealer:
            return .automotive
        case .businessCenter, .corporateOffice, .coworkingSpace, .farm, .manufacturer, .ranch, .supplier, 
             .televisionStudio:
            return .business
        case .artGallery, .artMuseum, .artStudio, .auditorium, .castle, .culturalLandmark, .fountain, 
             .historicalPlace, .historyMuseum, .monument, .museum, .performingArtsTheater, .sculpture:
            return .culture
        case .academicDepartment, .educationalInstitution, .library, .preschool, .primarySchool, 
             .researchInstitute, .school, .secondarySchool, .university:
            return .education
        case .adventureSportsCenter, .amphitheatre, .amusementCenter, .amusementPark, .aquarium, .banquetHall, 
             .barbecueArea, .botanicalGarden, .bowlingAlley, .casino, .childrensCamp, .cityPark, .comedyClub, 
             .communityCenter, .concertHall, .conventionCenter, .culturalCenter, .cyclingPark, .danceHall, 
             .dogPark, .eventVenue, .ferrisWheel, .garden, .goKartingVenue, .hikingArea, .historicalLandmark, 
             .indoorPlayground, .internetCafe, .karaoke, .liveMusicVenue, .marina, .miniatureGolfCourse, 
             .movieRental, .movieTheater, .nationalPark, .nightClub, .observationDeck, .offRoadingArea, 
             .operaHouse, .paintballCenter, .park, .philharmonicHall, .picnicGround, .planetarium, .plaza, 
             .rollerCoaster, .skateboardPark, .statePark, .touristAttraction, .videoArcade, .vineyard, 
             .visitorCenter, .waterPark, .weddingVenue, .wildlifePark, .wildlifeRefuge, .zoo:
            return .entertainmentAndRecreation
        case .publicBath, .publicBathroom, .stable:
            return .facilities
        case .accounting, .atm, .bank:
            return .finance
        case .acaiShop, .afghaniRestaurant, .africanRestaurant, .americanRestaurant, .argentinianRestaurant, 
             .asianFusionRestaurant, .asianRestaurant, .australianRestaurant, .austrianRestaurant, .bagelShop, 
             .bakery, .bangladeshiRestaurant, .bar, .barAndGrill, .barbecueRestaurant, .basqueRestaurant, 
             .bavarianRestaurant, .beerGarden, .belgianRestaurant, .bistro, .brazilianRestaurant, 
             .breakfastRestaurant, .brewery, .brewpub, .britishRestaurant, .brunchRestaurant, .buffetRestaurant, 
             .burmeseRestaurant, .burritoRestaurant, .cafe, .cafeteria, .cajunRestaurant, .cakeShop, 
             .californianRestaurant, .cambodianRestaurant, .candyStore, .cantoneseRestaurant, .caribbeanRestaurant, 
             .catCafe, .chickenRestaurant, .chickenWingsRestaurant, .chileanRestaurant, .chineseNoodleRestaurant, 
             .chineseRestaurant, .chocolateFactory, .chocolateShop, .cocktailBar, .coffeeRoastery, .coffeeShop, 
             .coffeeStand, .colombianRestaurant, .confectionery, .croatianRestaurant, .cubanRestaurant, 
             .czechRestaurant, .danishRestaurant, .deli, .dessertRestaurant, .dessertShop, .dimSumRestaurant, 
             .diner, .dogCafe, .donutShop, .dumplingRestaurant, .dutchRestaurant, .easternEuropeanRestaurant, 
             .ethiopianRestaurant, .europeanRestaurant, .falafelRestaurant, .familyRestaurant, .fastFoodRestaurant, 
             .filipinoRestaurant, .fineDiningRestaurant, .fishAndChipsRestaurant, .fondueRestaurant, .foodCourt, 
             .frenchRestaurant, .fusionRestaurant, .gastropub, .germanRestaurant, .greekRestaurant, 
             .gyroRestaurant, .halalRestaurant, .hamburgerRestaurant, .hawaiianRestaurant, .hookahBar, 
             .hotDogRestaurant, .hotDogStand, .hotPotRestaurant, .hungarianRestaurant, .iceCreamShop, 
             .indianRestaurant, .indonesianRestaurant, .irishPub, .irishRestaurant, .israeliRestaurant, 
             .italianRestaurant, .japaneseCurryRestaurant, .japaneseIzakayaRestaurant, .japaneseRestaurant, 
             .juiceShop, .kebabShop, .koreanBarbecueRestaurant, .koreanRestaurant, .latinAmericanRestaurant, 
             .lebaneseRestaurant, .loungeBar, .malaysianRestaurant, .mealDelivery, .mealTakeaway, 
             .mediterraneanRestaurant, .mexicanRestaurant, .middleEasternRestaurant, .mongolianBarbecueRestaurant, 
             .moroccanRestaurant, .noodleShop, .northIndianRestaurant, .oysterBarRestaurant, .pakistaniRestaurant, 
             .pastryShop, .persianRestaurant, .peruvianRestaurant, .pizzaDelivery, .pizzaRestaurant, 
             .polishRestaurant, .portugueseRestaurant, .pub, .ramenRestaurant, .restaurant, .romanianRestaurant, 
             .russianRestaurant, .saladShop, .sandwichShop, .scandinavianRestaurant, .seafoodRestaurant, 
             .shawarmaRestaurant, .snackBar, .soulFoodRestaurant, .soupRestaurant, .southAmericanRestaurant, 
             .southIndianRestaurant, .southwesternUsRestaurant, .spanishRestaurant, .sportsBar, 
             .sriLankanRestaurant, .steakHouse, .sushiRestaurant, .swissRestaurant, .tacoRestaurant, 
             .taiwaneseRestaurant, .tapasRestaurant, .teaHouse, .texMexRestaurant, .thaiRestaurant, 
             .tibetanRestaurant, .tonkatsuRestaurant, .turkishRestaurant, .ukrainianRestaurant, .veganRestaurant, 
             .vegetarianRestaurant, .vietnameseRestaurant, .westernRestaurant, .wineBar, .winery, 
             .yakinikuRestaurant, .yakitoriRestaurant:
            return .foodAndDrink
        case .administrativeAreaLevel1, .administrativeAreaLevel2, .country, .locality, .postalCode, 
             .schoolDistrict:
            return .geographicalAreas
        case .cityHall, .courthouse, .embassy, .fireStation, .governmentOffice, .localGovernmentOffice, 
             .neighborhoodPoliceStation, .police, .postOffice:
            return .government
        case .chiropractor, .dentalClinic, .dentist, .doctor, .drugstore, .generalHospital, .hospital, .massage, 
             .massageSpa, .medicalCenter, .medicalClinic, .medicalLab, .pharmacy, .physiotherapist, .sauna, 
             .skinCareClinic, .spa, .tanningStudio, .wellnessCenter, .yogaStudio:
            return .healthAndWellness
        case .apartmentBuilding, .apartmentComplex, .condominiumComplex, .housingComplex:
            return .housing
        case .bedAndBreakfast, .budgetJapaneseInn, .campground, .campingCabin, .cottage, .extendedStayHotel, 
             .farmstay, .guestHouse, .hostel, .hotel, .inn, .japaneseInn, .lodging, .mobileHomePark, .motel, 
             .privateGuestRoom, .resortHotel, .rvPark:
            return .lodging
        case .beach, .island, .lake, .mountainPeak, .naturePreserve, .river, .scenicSpot, .woods:
            return .naturalFeatures
        case .buddhistTemple, .church, .hinduTemple, .mosque, .shintoShrine, .synagogue:
            return .placesOfWorship
        case .aircraftRentalService, .associationOrOrganization, .astrologer, .barberShop, .beautician, 
             .beautySalon, .bodyArtService, .cateringService, .cemetery, .chauffeurService, .childCareAgency, 
             .consultant, .courierService, .electrician, .employmentAgency, .florist, .foodDelivery, .footCare, 
             .funeralHome, .hairCare, .hairSalon, .insuranceAgency, .laundry, .lawyer, .locksmith, .makeupArtist, 
             .marketingConsultant, .movingCompany, .nailSalon, .nonProfitOrganization, .painter, 
             .petBoardingService, .petCare, .plumber, .psychic, .realEstateAgency, .roofingContractor, .service, 
             .shippingService, .storage, .summerCampOrganizer, .tailor, .telecommunicationsServiceProvider, 
             .tourAgency, .touristInformationCenter, .travelAgency, .veterinaryCare:
            return .services
        case .asianGroceryStore, .autoPartsStore, .bicycleStore, .bookStore, .buildingMaterialsStore, .butcherShop, 
             .cellPhoneStore, .clothingStore, .convenienceStore, .cosmeticsStore, .departmentStore, .discountStore, 
             .discountSupermarket, .electronicsStore, .farmersMarket, .fleaMarket, .foodStore, .furnitureStore, 
             .gardenCenter, .generalStore, .giftShop, .groceryStore, .hardwareStore, .healthFoodStore, 
             .homeGoodsStore, .homeImprovementStore, .hypermarket, .jewelryStore, .liquorStore, .market, .petStore, 
             .shoeStore, .shoppingMall, .sportingGoodsStore, .sportswearStore, .store, .supermarket, .teaStore, 
             .thriftStore, .toyStore, .warehouseStore, .wholesaler, .womensClothingStore:
            return .shopping
        case .arena, .athleticField, .fishingCharter, .fishingPier, .fishingPond, .fitnessCenter, .golfCourse, 
             .gym, .iceSkatingRink, .indoorGolfCourse, .playground, .raceCourse, .skiResort, 
             .sportsActivityLocation, .sportsClub, .sportsCoaching, .sportsComplex, .sportsSchool, .stadium, 
             .swimmingPool, .tennisCourt:
            return .sports
        case .airport, .airstrip, .bikeSharingStation, .bridge, .busStation, .busStop, .ferryService, 
             .ferryTerminal, .heliport, .internationalAirport, .lightRailStation, .parkAndRide, .subwayStation, 
             .taxiService, .taxiStand, .tollStation, .trainStation, .trainTicketOffice, .tramStop, .transitDepot, 
             .transitStation, .transitStop, .transportationService, .truckStop:
            return .transportation
        case .administrativeAreaLevel3, .administrativeAreaLevel4, .administrativeAreaLevel5, 
             .administrativeAreaLevel6, .administrativeAreaLevel7, .archipelago, .colloquialArea, .continent, 
             .establishment, .finance, .food, .generalContractor, .geocode, .health, .intersection, .landmark, 
             .naturalFeature, .neighborhood, .placeOfWorship, .plusCode, .pointOfInterest, .political, 
             .postalCodePrefix, .postalCodeSuffix, .postalTown, .premise, .route, .streetAddress, .sublocality, 
             .sublocalityLevel1, .sublocalityLevel2, .sublocalityLevel3, .sublocalityLevel4, .sublocalityLevel5, 
             .subpremise, .townSquare:
            return .other
        case .home, .friendsHome, .vacationRental:
            return .personal
        }
    }
}
