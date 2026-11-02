import Foundation

enum RuleSource {
    case none      // typical value, no tag
    case piaggio   // official Piaggio schedule
    case verify    // official sources disagree: check the libretto
}

enum Need {
    case any, liquidCooling, drumRear, discRear
}

struct JobDef: Identifiable {
    let id: String
    let category: String
    let it: String
    let en: String
    var km: Int = 0
    var months: Int = 0
    var source: RuleSource = .none
    var carOnly: Bool = false
    var need: Need = .any

    func name(_ lang: String) -> String { lang == "en" ? en : it }
}

struct CategoryDef: Identifiable {
    let id: String
    let it: String
    let en: String
    let symbol: String
    func name(_ lang: String) -> String { lang == "en" ? en : it }
}

enum Catalog {
    static let categories: [CategoryDef] = [
        CategoryDef(id: "oil", it: "Oli e filtri", en: "Oils and filters", symbol: "drop"),
        CategoryDef(id: "brakes", it: "Freni", en: "Brakes", symbol: "circle.circle"),
        CategoryDef(id: "tyres", it: "Pneumatici", en: "Tyres", symbol: "circle.dashed"),
        CategoryDef(id: "transmission", it: "Trasmissione (CVT)", en: "Transmission (CVT)", symbol: "arrow.left.arrow.right"),
        CategoryDef(id: "engine", it: "Motore e alimentazione", en: "Engine and fuel", symbol: "speedometer"),
        CategoryDef(id: "electrical", it: "Impianto elettrico", en: "Electrical", symbol: "bolt"),
        CategoryDef(id: "battery", it: "Batterie", en: "Battery", symbol: "battery.100"),
        CategoryDef(id: "suspension", it: "Sospensioni", en: "Suspension", symbol: "arrow.up.and.down"),
        CategoryDef(id: "steering", it: "Sterzo", en: "Steering", symbol: "steeringwheel"),
        CategoryDef(id: "cooling", it: "Raffreddamento", en: "Cooling", symbol: "thermometer.snowflake"),
        CategoryDef(id: "exhaust", it: "Scarico ed emissioni", en: "Exhaust and emissions", symbol: "wind"),
        CategoryDef(id: "body", it: "Carrozzeria", en: "Bodywork", symbol: "paintbrush"),
        CategoryDef(id: "diag", it: "Diagnosi", en: "Diagnostics", symbol: "stethoscope"),
        CategoryDef(id: "accessories", it: "Accessori", en: "Accessories", symbol: "shippingbox"),
        CategoryDef(id: "ac", it: "Climatizzazione", en: "Air conditioning", symbol: "snowflake"),
        CategoryDef(id: "safety", it: "Sicurezza", en: "Safety", symbol: "shield")
    ]

    static let jobs: [JobDef] = [
        // Oils and filters (Piaggio: oil, oil filter every 10,000 km or 12 months; air filter 10,000 km)
        JobDef(id: "oil_engine", category: "oil", it: "Cambio olio motore", en: "Engine oil change", km: 10000, months: 12, source: .piaggio),
        JobDef(id: "oil_filter", category: "oil", it: "Cambio filtro olio", en: "Oil filter change", km: 10000, months: 12, source: .piaggio),
        JobDef(id: "air_filter", category: "oil", it: "Cambio filtro aria", en: "Air filter change", km: 10000, source: .piaggio),
        JobDef(id: "fuel_filter", category: "oil", it: "Cambio filtro carburante", en: "Fuel filter change"),
        // Brakes (Piaggio: brake fluid every 24 months)
        JobDef(id: "pads", category: "brakes", it: "Sostituzione pastiglie freni", en: "Brake pads replacement"),
        JobDef(id: "shoes", category: "brakes", it: "Sostituzione ganasce freno posteriore", en: "Rear brake shoes replacement", need: .drumRear),
        JobDef(id: "discs", category: "brakes", it: "Sostituzione dischi freni", en: "Brake discs replacement"),
        JobDef(id: "brake_fluid", category: "brakes", it: "Cambio liquido freni", en: "Brake fluid change", months: 24, source: .piaggio),
        JobDef(id: "calipers", category: "brakes", it: "Manutenzione pinze freni", en: "Brake caliper service"),
        JobDef(id: "brake_lines", category: "brakes", it: "Sostituzione tubi e cavi freno", en: "Brake lines and cables"),
        JobDef(id: "handbrake", category: "brakes", it: "Manutenzione freno a mano", en: "Handbrake service", carOnly: true),
        // Tyres (age alert at 6 years)
        JobDef(id: "tyre_front", category: "tyres", it: "Sostituzione pneumatico anteriore", en: "Front tyre replacement", months: 72),
        JobDef(id: "tyre_rear", category: "tyres", it: "Sostituzione pneumatico posteriore", en: "Rear tyre replacement", months: 72),
        JobDef(id: "balancing", category: "tyres", it: "Equilibratura ruote", en: "Wheel balancing"),
        JobDef(id: "puncture", category: "tyres", it: "Riparazione foratura", en: "Puncture repair"),
        JobDef(id: "valve", category: "tyres", it: "Sostituzione valvola", en: "Valve replacement"),
        JobDef(id: "tyre_season", category: "tyres", it: "Cambio stagionale", en: "Seasonal tyre change", carOnly: true),
        // Transmission, CVT (Piaggio: belt and rollers 20,000 km)
        JobDef(id: "belt", category: "transmission", it: "Sostituzione cinghia di trasmissione", en: "Drive belt replacement", km: 20000, source: .piaggio),
        JobDef(id: "rollers", category: "transmission", it: "Sostituzione rulli variatore", en: "Variator rollers replacement", km: 20000, source: .piaggio),
        JobDef(id: "variator", category: "transmission", it: "Sostituzione variatore", en: "Variator replacement"),
        JobDef(id: "clutch", category: "transmission", it: "Sostituzione frizione e campana", en: "Clutch and bell replacement"),
        JobDef(id: "clutch_springs", category: "transmission", it: "Sostituzione molle frizione", en: "Clutch springs replacement"),
        JobDef(id: "gear_oil", category: "transmission", it: "Cambio olio trasmissione", en: "Gear oil change", km: 30000),
        JobDef(id: "cv_joint", category: "transmission", it: "Manutenzione giunto omocinetico", en: "CV joint service", carOnly: true),
        JobDef(id: "driveshaft", category: "transmission", it: "Manutenzione semiasse", en: "Driveshaft service", carOnly: true),
        JobDef(id: "chain", category: "transmission", it: "Pulizia e regolazione catena", en: "Chain cleaning and adjustment", carOnly: true),
        // Engine and fuel
        JobDef(id: "service", category: "engine", it: "Tagliando ordinario", en: "Regular service"),
        JobDef(id: "valves", category: "engine", it: "Controllo gioco valvole", en: "Valve clearance check", km: 20000, source: .verify),
        JobDef(id: "throttle", category: "engine", it: "Pulizia corpo farfallato", en: "Throttle body cleaning"),
        JobDef(id: "fuel_pump", category: "engine", it: "Sostituzione pompa carburante", en: "Fuel pump replacement"),
        JobDef(id: "throttle_cable", category: "engine", it: "Sostituzione cavo gas", en: "Throttle cable replacement"),
        JobDef(id: "lambda", category: "engine", it: "Sostituzione sonda lambda", en: "Lambda sensor replacement"),
        // Electrical (spark plug: Piaggio sheets disagree, 10,000 vs 20,000)
        JobDef(id: "spark", category: "electrical", it: "Cambio candela", en: "Spark plug change", km: 10000, source: .verify),
        JobDef(id: "coil", category: "electrical", it: "Sostituzione bobina", en: "Ignition coil replacement"),
        JobDef(id: "regulator", category: "electrical", it: "Sostituzione regolatore di tensione", en: "Voltage regulator replacement"),
        JobDef(id: "bulbs", category: "electrical", it: "Sostituzione lampadine e frecce", en: "Bulbs and indicators"),
        JobDef(id: "fuses", category: "electrical", it: "Sostituzione fusibili e relè", en: "Fuses and relays"),
        JobDef(id: "starter", category: "electrical", it: "Sostituzione motorino d'avviamento", en: "Starter motor replacement"),
        JobDef(id: "alternator", category: "electrical", it: "Sostituzione alternatore", en: "Alternator replacement"),
        // Battery
        JobDef(id: "battery", category: "battery", it: "Sostituzione batteria 12V", en: "12V battery replacement", months: 48),
        JobDef(id: "battery_test", category: "battery", it: "Test batteria 12V", en: "12V battery test"),
        // Suspension
        JobDef(id: "shock_rear", category: "suspension", it: "Sostituzione ammortizzatore posteriore", en: "Rear shock replacement"),
        JobDef(id: "fork_oil", category: "suspension", it: "Cambio olio forcella", en: "Fork oil change", km: 40000, months: 60),
        JobDef(id: "fork_seals", category: "suspension", it: "Sostituzione paraoli forcella", en: "Fork seals replacement"),
        JobDef(id: "springs", category: "suspension", it: "Sostituzione molle", en: "Springs replacement", carOnly: true),
        JobDef(id: "arms", category: "suspension", it: "Sostituzione braccetti sospensione", en: "Suspension arms", carOnly: true),
        JobDef(id: "bushings", category: "suspension", it: "Sostituzione boccole", en: "Bushings replacement", carOnly: true),
        // Steering
        JobDef(id: "steer_bearings", category: "steering", it: "Sostituzione cuscinetti sterzo", en: "Steering bearings replacement"),
        JobDef(id: "tie_rods", category: "steering", it: "Sostituzione tiranti sterzo", en: "Tie rods replacement", carOnly: true),
        JobDef(id: "ps_oil", category: "steering", it: "Cambio olio servosterzo", en: "Power steering oil change", carOnly: true),
        JobDef(id: "steer_box", category: "steering", it: "Manutenzione scatola sterzo", en: "Steering box service", carOnly: true),
        // Cooling (liquid-cooled only)
        JobDef(id: "coolant", category: "cooling", it: "Cambio liquido refrigerante", en: "Coolant change", need: .liquidCooling),
        JobDef(id: "water_pump", category: "cooling", it: "Sostituzione pompa d'acqua", en: "Water pump replacement", need: .liquidCooling),
        JobDef(id: "thermostat", category: "cooling", it: "Sostituzione termostato", en: "Thermostat replacement", need: .liquidCooling),
        JobDef(id: "radiator", category: "cooling", it: "Manutenzione radiatore", en: "Radiator service", need: .liquidCooling),
        // Exhaust
        JobDef(id: "muffler", category: "exhaust", it: "Sostituzione marmitta", en: "Muffler replacement"),
        JobDef(id: "catalyst", category: "exhaust", it: "Manutenzione catalizzatore", en: "Catalytic converter service"),
        // Body
        JobDef(id: "paint", category: "body", it: "Riparazione verniciatura", en: "Paint repair"),
        JobDef(id: "mirrors", category: "body", it: "Sostituzione specchietti", en: "Mirrors replacement"),
        JobDef(id: "seat", category: "body", it: "Riparazione sella e serratura", en: "Seat and lock repair"),
        JobDef(id: "fairings", category: "body", it: "Sostituzione carene", en: "Fairings replacement"),
        JobDef(id: "stand", category: "body", it: "Sostituzione cavalletto", en: "Stand replacement"),
        JobDef(id: "windshield", category: "body", it: "Sostituzione parabrezza", en: "Windshield replacement", carOnly: true),
        JobDef(id: "locks", category: "body", it: "Manutenzione serrature", en: "Lock service", carOnly: true),
        // Diagnostics
        JobDef(id: "obd", category: "diag", it: "Lettura OBD", en: "OBD reading"),
        JobDef(id: "software", category: "diag", it: "Aggiornamento software", en: "Software update"),
        JobDef(id: "general", category: "diag", it: "Controllo generale", en: "General check"),
        JobDef(id: "prep_rev", category: "diag", it: "Preparazione revisione", en: "Inspection preparation"),
        // Accessories
        JobDef(id: "topcase", category: "accessories", it: "Montaggio bauletto", en: "Top case fitting"),
        JobDef(id: "windscreen", category: "accessories", it: "Montaggio paravento", en: "Windscreen fitting"),
        JobDef(id: "alarm", category: "accessories", it: "Montaggio antifurto o GPS", en: "Alarm or GPS fitting"),
        JobDef(id: "usb", category: "accessories", it: "Montaggio presa USB", en: "USB socket fitting"),
        // Car-only categories
        JobDef(id: "ac_recharge", category: "ac", it: "Ricarica clima", en: "A/C recharge", carOnly: true),
        JobDef(id: "ac_compressor", category: "ac", it: "Sostituzione compressore clima", en: "A/C compressor replacement", carOnly: true),
        JobDef(id: "cabin_fan", category: "ac", it: "Sostituzione ventola abitacolo", en: "Cabin fan replacement", carOnly: true),
        JobDef(id: "airbag", category: "safety", it: "Manutenzione airbag", en: "Airbag service", carOnly: true),
        JobDef(id: "belts", category: "safety", it: "Sostituzione cinture", en: "Seat belts replacement", carOnly: true),
        JobDef(id: "adas", category: "safety", it: "Taratura ADAS", en: "ADAS calibration", carOnly: true)
    ]

    static func job(_ id: String) -> JobDef? { jobs.first(where: { $0.id == id }) }
    static func category(_ id: String) -> CategoryDef? { categories.first(where: { $0.id == id }) }

    /// Jobs shown for a vehicle. `showAll` reveals car-only jobs and parts that do not apply.
    static func visibleJobs(for vehicle: Vehicle?, showAll: Bool) -> [JobDef] {
        if showAll { return jobs }
        return jobs.filter { j in
            if j.carOnly && !(vehicle?.isCar ?? false) { return false }
            switch j.need {
            case .any: return true
            case .liquidCooling: return vehicle?.isLiquidCooled ?? false
            case .drumRear: return vehicle?.hasDrumRear ?? true
            case .discRear: return !(vehicle?.hasDrumRear ?? true)
            }
        }
    }

    static func displayName(jobKey: String, custom: String, lang: String) -> String {
        if let j = job(jobKey) { return j.name(lang) }
        return custom
    }
}
