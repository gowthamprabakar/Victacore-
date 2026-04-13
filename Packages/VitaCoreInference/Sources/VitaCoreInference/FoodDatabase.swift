// FoodDatabase.swift
// VitaCoreInference — Sprint 1 F-01: Real food database.
//
// Replaces the 15-item hardcoded lookup in analyzeFood() with a
// SQLite-backed search across a curated food database. The DB is
// built from USDA FoodData Central (public domain) + common South
// Asian, Mediterranean, and international foods.
//
// Architecture: The database ships as a bundled .sqlite file inside
// the VitaCoreInference package's resources. On first access it's
// copied to Application Support for read-only queries. No network
// access required — fully on-device per Principle I.

import Foundation
import GRDB
import VitaCoreContracts

// MARK: - FoodItem (DB row)

public struct FoodItem: Codable, FetchableRecord, Sendable, Hashable {
    public let fdcId: Int
    public let name: String
    public let calories: Double     // per 100g
    public let carbsG: Double       // per 100g
    public let proteinG: Double     // per 100g
    public let fatG: Double         // per 100g
    public let servingG: Double     // typical serving in grams
    public let category: String
}

// MARK: - FoodDatabase

public actor FoodDatabase {

    private let writer: any DatabaseWriter

    private init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    // -------------------------------------------------------------------------
    // MARK: Factory
    // -------------------------------------------------------------------------

    /// Cached singleton instance to prevent multiple DatabaseQueue
    /// instances opening the same file (causes SQLite lock contention).
    private static var _shared: FoodDatabase?

    /// Opens the bundled food database. Singleton — only one instance
    /// exists per process lifetime.
    public static func shared() throws -> FoodDatabase {
        if let cached = _shared { return cached }
        let instance = try _createShared()
        _shared = instance
        return instance
    }

    private static func _createShared() throws -> FoodDatabase {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("VitaCore", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let dbPath = dir.appendingPathComponent("vitacore_food.sqlite")

        // Copy the bundled pre-built USDA database on first access.
        // 7,873 foods from USDA SR Legacy + 86 South Asian + International.
        if !fm.fileExists(atPath: dbPath.path) {
            if let bundled = Bundle.module.url(forResource: "vitacore_food", withExtension: "sqlite") {
                try fm.copyItem(at: bundled, to: dbPath)
            } else {
                // Fallback: create and seed from code if bundle missing.
                try Self.createAndSeed(at: dbPath.path)
            }
        }

        let queue = try DatabaseQueue(path: dbPath.path)
        return FoodDatabase(writer: queue)
    }

    /// Test-safe database using a unique temp file per call.
    public static func forTesting() throws -> FoodDatabase {
        let tmp = NSTemporaryDirectory() + "vitacore_food_\(UUID().uuidString).sqlite"
        try Self.createAndSeed(at: tmp)
        let queue = try DatabaseQueue(path: tmp)
        return FoodDatabase(writer: queue)
    }

    // -------------------------------------------------------------------------
    // MARK: Search
    // -------------------------------------------------------------------------

    /// Searches for foods matching the query. Returns up to `limit`
    /// results ranked by relevance (exact prefix match > contains).
    public func search(_ query: String, limit: Int = 20) async throws -> [FoodItem] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return [] }

        return try await writer.read { db in
            let pattern = "%\(cleaned)%"
            return try FoodItem.fetchAll(db, sql: """
                SELECT * FROM foods
                WHERE LOWER(name) LIKE ?
                ORDER BY
                    CASE WHEN LOWER(name) LIKE ? THEN 0 ELSE 1 END,
                    LENGTH(name)
                LIMIT ?
                """,
                arguments: [pattern, cleaned + "%", limit]
            )
        }
    }

    /// Converts a list of FoodItems into a FoodAnalysisResult with
    /// portion-scaled macros. Nonisolated because it's a pure function
    /// on the input data — no actor state accessed.
    public nonisolated func buildAnalysisResult(
        items: [FoodItem],
        portionScale: Double = 1.0
    ) -> FoodAnalysisResult {
        var entries: [FoodEntry] = []
        var totalCal: Double = 0
        var totalCarbs: Double = 0
        var totalProtein: Double = 0
        var totalFat: Double = 0

        for item in items {
            let scale = (item.servingG / 100.0) * portionScale
            let cal = item.calories * scale
            let carbs = item.carbsG * scale
            let protein = item.proteinG * scale
            let fat = item.fatG * scale

            entries.append(FoodEntry(
                name: item.name,
                portionGrams: item.servingG * portionScale,
                calories: cal,
                carbsG: carbs,
                proteinG: protein,
                fatG: fat,
                sourceSkillId: "skill.foodDatabase",
                timestamp: Date()
            ))

            totalCal += cal
            totalCarbs += carbs
            totalProtein += protein
            totalFat += fat
        }

        return FoodAnalysisResult(
            recognisedItems: entries,
            totalCalories: totalCal,
            totalCarbsG: totalCarbs,
            totalProteinG: totalProtein,
            totalFatG: totalFat,
            confidence: items.isEmpty ? 0.3 : 0.85,
            analysedAt: Date()
        )
    }

    // -------------------------------------------------------------------------
    // MARK: DB Creation + Seeding
    // -------------------------------------------------------------------------

    private static func createAndSeed(at path: String) throws {
        let queue = try DatabaseQueue(path: path)
        try seedDatabase(queue)
    }

    private static func seedDatabase(_ writer: any DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "foods", ifNotExists: true) { t in
                t.column("fdcId", .integer).primaryKey()
                t.column("name", .text).notNull()
                t.column("calories", .double).notNull()
                t.column("carbsG", .double).notNull()
                t.column("proteinG", .double).notNull()
                t.column("fatG", .double).notNull()
                t.column("servingG", .double).notNull()
                t.column("category", .text).notNull()
            }

            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_foods_name ON foods(name COLLATE NOCASE)")

            // Seed with curated food database.
            // Values per 100g unless servingG overrides the typical portion.
            let foods: [(Int, String, Double, Double, Double, Double, Double, String)] = [
                // === GRAINS & CEREALS ===
                (1001, "White Rice (cooked)", 130, 28.2, 2.7, 0.3, 200, "Grains"),
                (1002, "Brown Rice (cooked)", 123, 25.6, 2.7, 1.0, 200, "Grains"),
                (1003, "Basmati Rice (cooked)", 121, 25.2, 3.5, 0.4, 200, "Grains"),
                (1004, "Pasta (cooked)", 131, 25.0, 5.0, 1.1, 200, "Grains"),
                (1005, "Whole Wheat Bread", 247, 41.3, 13.0, 3.4, 60, "Grains"),
                (1006, "White Bread", 265, 49.0, 9.0, 3.2, 60, "Grains"),
                (1007, "Oatmeal (cooked)", 71, 12.0, 2.5, 1.5, 250, "Grains"),
                (1008, "Quinoa (cooked)", 120, 21.3, 4.4, 1.9, 185, "Grains"),
                (1009, "Corn Tortilla", 218, 44.6, 5.7, 2.8, 30, "Grains"),
                (1010, "Naan Bread", 290, 50.0, 8.0, 6.0, 90, "Grains"),

                // === SOUTH ASIAN FOODS ===
                (2001, "Dal (cooked lentils)", 116, 20.1, 9.0, 0.4, 200, "South Asian"),
                (2002, "Roti / Chapati", 297, 52.0, 9.8, 5.0, 40, "South Asian"),
                (2003, "Idli (steamed rice cake)", 130, 25.8, 3.9, 0.4, 80, "South Asian"),
                (2004, "Dosa (rice crepe)", 168, 28.0, 4.0, 4.5, 100, "South Asian"),
                (2005, "Biryani (chicken)", 180, 22.0, 10.0, 6.0, 350, "South Asian"),
                (2006, "Sambar", 65, 9.0, 3.5, 1.5, 200, "South Asian"),
                (2007, "Rasam", 30, 5.0, 1.5, 0.5, 200, "South Asian"),
                (2008, "Upma (semolina)", 168, 26.0, 4.5, 5.0, 200, "South Asian"),
                (2009, "Poha (flattened rice)", 130, 24.0, 2.5, 2.0, 200, "South Asian"),
                (2010, "Paneer (cottage cheese)", 265, 1.2, 18.3, 20.8, 100, "South Asian"),
                (2011, "Curd / Yogurt (plain)", 61, 3.4, 3.5, 3.3, 150, "South Asian"),
                (2012, "Paratha", 326, 42.0, 7.0, 14.0, 80, "South Asian"),
                (2013, "Puri (fried bread)", 420, 46.0, 7.0, 23.0, 40, "South Asian"),
                (2014, "Aloo Gobi", 95, 13.0, 3.0, 4.0, 200, "South Asian"),
                (2015, "Palak Paneer", 170, 8.0, 10.0, 12.0, 200, "South Asian"),
                (2016, "Butter Chicken", 148, 6.0, 14.0, 8.0, 250, "South Asian"),
                (2017, "Chole (chickpea curry)", 143, 22.0, 7.5, 3.0, 200, "South Asian"),
                (2018, "Rajma (kidney bean curry)", 127, 22.0, 8.7, 0.5, 200, "South Asian"),
                (2019, "Masala Dosa", 200, 30.0, 5.0, 7.0, 150, "South Asian"),
                (2020, "Vada (fried lentil donut)", 340, 33.0, 13.0, 18.0, 60, "South Asian"),
                (2021, "Khichdi (rice + lentil)", 105, 17.0, 4.5, 2.0, 250, "South Asian"),
                (2022, "Pongal", 140, 23.0, 4.0, 4.0, 200, "South Asian"),
                (2023, "Uttapam", 155, 26.0, 4.5, 3.5, 120, "South Asian"),
                (2024, "Appam", 120, 22.0, 2.5, 2.0, 80, "South Asian"),
                (2025, "Puttu", 180, 35.0, 3.5, 3.0, 150, "South Asian"),

                // === PROTEINS ===
                (3001, "Chicken Breast (grilled)", 165, 0, 31.0, 3.6, 120, "Protein"),
                (3002, "Chicken Thigh (cooked)", 209, 0, 26.0, 10.9, 120, "Protein"),
                (3003, "Salmon (baked)", 208, 0, 20.4, 13.4, 150, "Protein"),
                (3004, "Tuna (canned in water)", 116, 0, 25.5, 0.8, 100, "Protein"),
                (3005, "Eggs (boiled)", 155, 1.1, 12.6, 10.6, 100, "Protein"),
                (3006, "Egg White", 52, 0.7, 10.9, 0.2, 66, "Protein"),
                (3007, "Tofu (firm)", 144, 2.8, 17.3, 8.7, 120, "Protein"),
                (3008, "Beef (lean ground)", 250, 0, 26.0, 15.0, 120, "Protein"),
                (3009, "Lamb (cooked)", 258, 0, 25.5, 16.5, 120, "Protein"),
                (3010, "Shrimp (cooked)", 99, 0.2, 24.0, 0.3, 100, "Protein"),
                (3011, "Fish Fillet (white)", 96, 0, 20.8, 1.0, 120, "Protein"),
                (3012, "Turkey Breast", 135, 0, 30.0, 0.7, 120, "Protein"),

                // === FRUITS ===
                (4001, "Banana", 89, 22.8, 1.1, 0.3, 120, "Fruit"),
                (4002, "Apple", 52, 13.8, 0.3, 0.2, 180, "Fruit"),
                (4003, "Orange", 47, 11.8, 0.9, 0.1, 150, "Fruit"),
                (4004, "Mango", 60, 15.0, 0.8, 0.4, 200, "Fruit"),
                (4005, "Grapes", 69, 18.1, 0.7, 0.2, 150, "Fruit"),
                (4006, "Watermelon", 30, 7.6, 0.6, 0.2, 300, "Fruit"),
                (4007, "Strawberries", 32, 7.7, 0.7, 0.3, 150, "Fruit"),
                (4008, "Blueberries", 57, 14.5, 0.7, 0.3, 150, "Fruit"),
                (4009, "Papaya", 43, 10.8, 0.5, 0.3, 200, "Fruit"),
                (4010, "Pineapple", 50, 13.1, 0.5, 0.1, 200, "Fruit"),
                (4011, "Guava", 68, 14.3, 2.6, 1.0, 100, "Fruit"),
                (4012, "Pomegranate", 83, 18.7, 1.7, 1.2, 150, "Fruit"),

                // === VEGETABLES ===
                (5001, "Broccoli (cooked)", 35, 7.2, 2.4, 0.4, 150, "Vegetable"),
                (5002, "Spinach (cooked)", 23, 3.6, 2.9, 0.4, 150, "Vegetable"),
                (5003, "Carrot (raw)", 41, 9.6, 0.9, 0.2, 100, "Vegetable"),
                (5004, "Potato (baked)", 93, 21.2, 2.5, 0.1, 200, "Vegetable"),
                (5005, "Sweet Potato (baked)", 90, 20.7, 2.0, 0.1, 200, "Vegetable"),
                (5006, "Tomato", 18, 3.9, 0.9, 0.2, 150, "Vegetable"),
                (5007, "Cucumber", 15, 3.6, 0.7, 0.1, 150, "Vegetable"),
                (5008, "Mixed Salad", 20, 3.5, 1.5, 0.3, 200, "Vegetable"),
                (5009, "Cauliflower (cooked)", 23, 4.1, 1.8, 0.5, 150, "Vegetable"),
                (5010, "Green Beans (cooked)", 35, 7.1, 1.8, 0.1, 150, "Vegetable"),
                (5011, "Okra / Bhindi (cooked)", 33, 7.0, 1.9, 0.2, 100, "Vegetable"),
                (5012, "Bitter Gourd (cooked)", 17, 3.7, 1.0, 0.2, 100, "Vegetable"),

                // === DAIRY ===
                (6001, "Milk (whole)", 61, 4.8, 3.2, 3.3, 250, "Dairy"),
                (6002, "Milk (skim)", 34, 5.0, 3.4, 0.1, 250, "Dairy"),
                (6003, "Cheese (cheddar)", 403, 1.3, 25.0, 33.1, 30, "Dairy"),
                (6004, "Greek Yogurt (plain)", 73, 3.6, 10.2, 2.0, 150, "Dairy"),
                (6005, "Butter", 717, 0.1, 0.9, 81.1, 14, "Dairy"),
                (6006, "Ghee", 900, 0, 0, 100.0, 14, "Dairy"),

                // === LEGUMES & NUTS ===
                (7001, "Chickpeas (cooked)", 164, 27.4, 8.9, 2.6, 160, "Legumes"),
                (7002, "Black Beans (cooked)", 132, 23.7, 8.9, 0.5, 170, "Legumes"),
                (7003, "Almonds", 579, 21.6, 21.2, 49.9, 30, "Nuts"),
                (7004, "Peanuts", 567, 16.1, 25.8, 49.2, 30, "Nuts"),
                (7005, "Walnuts", 654, 13.7, 15.2, 65.2, 30, "Nuts"),
                (7006, "Cashews", 553, 30.2, 18.2, 43.9, 30, "Nuts"),
                (7007, "Peanut Butter", 588, 20.0, 25.1, 50.4, 32, "Nuts"),
                (7008, "Moong Dal (green gram)", 105, 18.3, 7.0, 0.4, 200, "Legumes"),
                (7009, "Toor Dal (pigeon pea)", 343, 62.8, 22.3, 1.5, 200, "Legumes"),

                // === BEVERAGES ===
                (8001, "Orange Juice", 45, 10.4, 0.7, 0.2, 250, "Beverage"),
                (8002, "Coffee (black)", 2, 0, 0.3, 0, 240, "Beverage"),
                (8003, "Tea (no milk)", 1, 0.3, 0, 0, 240, "Beverage"),
                (8004, "Coconut Water", 19, 3.7, 0.7, 0.2, 250, "Beverage"),
                (8005, "Lassi (sweet)", 72, 12.0, 3.0, 1.5, 250, "Beverage"),
                (8006, "Chai (milk tea)", 50, 7.0, 2.0, 1.5, 200, "Beverage"),

                // === SNACKS & SWEETS ===
                (9001, "Dark Chocolate (70%)", 598, 45.9, 7.8, 42.6, 30, "Snack"),
                (9002, "Popcorn (plain)", 387, 77.8, 12.9, 4.5, 30, "Snack"),
                (9003, "Protein Bar", 350, 35.0, 20.0, 12.0, 60, "Snack"),
                (9004, "Glucose Tablets (4)", 60, 15.0, 0, 0, 16, "Medical"),
                (9005, "Jalebi", 380, 52.0, 3.0, 18.0, 50, "South Asian"),
                (9006, "Gulab Jamun", 330, 40.0, 5.0, 17.0, 50, "South Asian"),
                (9007, "Laddu", 490, 55.0, 8.0, 27.0, 40, "South Asian"),
                (9008, "Halwa (semolina)", 350, 45.0, 4.0, 18.0, 100, "South Asian"),

                // === COMMON PREPARED MEALS ===
                (10001, "Pizza (1 slice)", 266, 33.0, 11.0, 10.0, 110, "Prepared"),
                (10002, "Burger (beef)", 295, 24.0, 17.0, 14.0, 200, "Prepared"),
                (10003, "French Fries", 312, 41.4, 3.4, 15.0, 120, "Prepared"),
                (10004, "Fried Rice", 163, 24.0, 4.5, 5.5, 250, "Prepared"),
                (10005, "Noodles (stir-fried)", 138, 22.0, 4.0, 4.0, 250, "Prepared"),
                (10006, "Sushi Roll (6 pcs)", 180, 30.0, 8.0, 3.0, 180, "Prepared"),
                (10007, "Sandwich (chicken)", 280, 28.0, 18.0, 10.0, 200, "Prepared"),
                (10008, "Wrap (veggie)", 220, 32.0, 8.0, 7.0, 200, "Prepared"),
                (10009, "Soup (vegetable)", 50, 8.0, 2.5, 1.0, 300, "Prepared"),
                (10010, "Salad (Caesar)", 170, 8.0, 7.0, 13.0, 250, "Prepared"),
            ]

            for f in foods {
                try db.execute(
                    sql: "INSERT OR REPLACE INTO foods (fdcId, name, calories, carbsG, proteinG, fatG, servingG, category) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    arguments: [f.0, f.1, f.2, f.3, f.4, f.5, f.6, f.7]
                )
            }
        }
    }
}
