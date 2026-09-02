import Foundation
import SwiftData

@Model
final class PackingItem {
    // Default values at the declaration site — required for SwiftData's
    // CloudKit sync.

    /// Stable, launch-independent identifier — see Trip.id's doc comment
    /// for why persistentModelID isn't safe to use for this.
    var id: UUID = UUID()
    var name: String = ""
    /// Free-form — either one of PackingCategory's rawValues, or a
    /// user-created custom category name (CustomCategory), same
    /// categoryName-string pattern ProfileItem already uses. Resolve back
    /// to a built-in case with `PackingCategory(rawValue: categoryName)`
    /// when one is specifically needed (an icon fallback, a "is this
    /// actually custom" check); nil from that means it's genuinely custom.
    var categoryName: String = PackingCategory.misc.rawValue
    var quantity: Int = 1
    var isPacked: Bool = false
    var trip: Trip?

    /// Who this item is for. Both nil means it's a shared/household item.
    var traveler: Traveler?
    var pet: Pet?

    /// Which of the trip's Luggage this item is packed in, if the user
    /// has bothered to assign one — nil just means "not sorted into a
    /// bag yet", not an error state.
    var luggage: Luggage?

    init(
        name: String,
        categoryName: String,
        quantity: Int = 1,
        isPacked: Bool = false,
        trip: Trip? = nil,
        traveler: Traveler? = nil,
        pet: Pet? = nil,
        luggage: Luggage? = nil
    ) {
        self.name = name
        self.categoryName = categoryName
        self.quantity = quantity
        self.isPacked = isPacked
        self.trip = trip
        self.traveler = traveler
        self.pet = pet
        self.luggage = luggage
    }

    /// Display label for the section this item belongs in.
    var assigneeLabel: String {
        if let traveler { return traveler.name }
        if let pet { return "\(pet.name) (pet)" }
        return "For Everyone"
    }

    /// A more specific icon based on the item's name when one matches
    /// (e.g. "Hiking boots" gets a shoe icon, not the generic clothing
    /// icon), falling back to the category's icon (or, for a custom
    /// category, a generic tag icon — mirrors ProfileItem.displaySymbol).
    var displaySymbol: IconRef {
        let categorySymbol = PackingCategory(rawValue: categoryName)?.symbol ?? "tag"
        return PackingIcon.iconRef(forName: name, fallback: categorySymbol)
    }
}

enum PackingCategory: String, Codable, CaseIterable, Identifiable {
    case clothing = "Clothing"
    case toiletries = "Toiletries"
    case electronics = "Electronics"
    case documents = "Documents"
    case gear = "Gear"
    case petSupplies = "Pet Supplies"
    case misc = "Miscellaneous"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .clothing: return "tshirt"
        case .toiletries: return "drop"
        case .electronics: return "bolt"
        case .documents: return "doc.text"
        case .gear: return "backpack"
        case .petSupplies: return "pawprint"
        case .misc: return "shippingbox"
        }
    }
}

/// Where an item's icon actually comes from. Most items get a system SF
/// Symbol; a handful that Apple's catalog has no glyph for at all (pants,
/// socks, a toothbrush, …) instead point at a small bundled icon set in
/// Assets.xcassets (see `PackingIconView`, the only place that needs to
/// know the two cases render differently).
enum IconRef: Equatable {
    case system(String)
    case custom(String)
}

/// Picks a more specific icon based on an item's name when one matches
/// (e.g. "Hiking boots" -> a shoe icon), falling back to a category's
/// default icon otherwise. A modest, high-confidence keyword set — not
/// exhaustive, but meaningfully more accurate than one icon per category
/// for clothing items in particular. Shared by `PackingItem` and
/// `ProfileItem`.
enum PackingIcon {
    static func iconRef(forName name: String, fallback: String) -> IconRef {
        let lowercased = name.lowercased()
        for rule in rules where rule.keywords.contains(where: lowercased.contains) {
            return rule.icon
        }
        return .system(fallback)
    }

    /// Legacy String-only accessor for the few call sites (a `Label`'s
    /// `systemImage:`, mainly) that can't render a bundled asset — a
    /// `.custom` match degrades to the plain category fallback there
    /// rather than showing nothing.
    static func symbol(forName name: String, fallback: String) -> String {
        if case .system(let symbolName) = iconRef(forName: name, fallback: fallback) {
            return symbolName
        }
        return fallback
    }

    private static let rules: [(keywords: [String], icon: IconRef)] = [
        (["boot", "shoe", "sneaker", "sandal", "flip-flop", "flip flop"], .system("shoe.2.fill")),
        (["swimsuit", "swim trunks", "bikini", "swim"], .system("figure.pool.swim")),
        (["sunglasses", "goggles"], .system("eyeglasses")),
        // "dress shoes" deliberately isn't listed below (unreachable —
        // "shoe" above already catches it first, correctly, since dress
        // shoes are still shoes).
        (["suit", "business attire"], .system("briefcase.fill")),
        // Split from the business-attire briefcase above — "Formal /
        // nicer outfit" reads better as an actual tie than a work bag.
        (["formal", "tie"], .custom("icon-tie")),
        // Sleepwear used to fall through to the generic tshirt icon,
        // indistinguishable from actual shirts — the most-cited example
        // of the icon-accuracy problem this rework fixes.
        (["pajama", "pyjama", "sleepwear", "nightgown"], .system("moon.zzz.fill")),
        // Split from umbrella below — a rain jacket and an umbrella are
        // different objects and shouldn't share an icon just because
        // they're both rain gear.
        (["rain jacket", "raincoat", "waterproof"], .system("cloud.rain.fill")),
        (["umbrella"], .system("umbrella.fill")),
        // Cold-weather gear — snow jacket/pants matched here before, but
        // "warm jacket" (the actual generated weather-item name) and
        // "gloves" fell through to generic tshirt; grouped together
        // since they're all the same kind of gear.
        (["thermal", "snow jacket", "snow pants", "warm jacket", "warm hat", "glove"], .system("snowflake")),
        // "hiking boots" isn't listed here (unreachable — "boot" above
        // already catches it first, and shoe.2.fill is a fine icon for
        // them too); "hiking" alone still catches other hiking gear.
        (["hiking"], .system("figure.hiking")),
        (["sunscreen"], .system("sun.max.fill")),
        (["first aid"], .system("cross.case.fill")),
        // Must precede "phone" below — "Phone charger" would otherwise
        // match that first and get the iphone icon instead.
        (["phone charger", "charging cable"], .system("cable.connector")),
        (["power adapter", "plug adapter"], .system("powerplug.fill")),
        // Must precede the generic "phone" rule right after it — was
        // previously listed AFTER "phone", so "Headphones" matched
        // "phone" (a real substring of "headphones") and got the iphone
        // icon instead of ever reaching this rule.
        (["headphone"], .system("headphones")),
        (["phone"], .system("iphone")),
        (["camera"], .system("camera.fill")),
        (["laptop"], .system("laptopcomputer")),
        (["credit card", "debit card"], .system("creditcard.fill")),
        (["wallet"], .system("wallet.pass.fill")),
        (["flight", "boarding pass"], .system("airplane")),
        // Must precede "book"/"e-reader" below — "Notebook" contains
        // "book" as a substring and would otherwise match that instead.
        (["notebook"], .system("pencil")),
        (["book", "e-reader"], .system("book.fill")),
        (["nail clipper"], .system("scissors")),
        // hand.raised.fill reads more clearly as "a hand" than the
        // sparkly variant did.
        (["hand sanitizer"], .system("hand.raised.fill")),
        (["earplug"], .system("ear.fill")),
        // Distinct from "eye mask" below despite both being eye-related
        // — an open eye for vision correction vs. a covered one for
        // sleep, rather than reusing one icon for two different items.
        (["contact lens"], .system("eye.fill")),
        (["eye mask"], .system("eye.slash.fill")),
        (["packing cube"], .system("shippingbox.fill")),
        (["toiletry bag"], .system("bag.fill")),
        // A compression bag is a bag, not a storage box — bag.fill reads
        // more accurately than the box-shaped archivebox.fill did.
        (["compression bag"], .system("bag.fill")),
        // A pillow next to sleeping bag's bed.double.fill — same family,
        // outline vs. filled, since no dedicated pillow icon exists.
        (["travel pillow"], .system("bed.double")),
        // Liquid/gel toiletries — distinct from the plain "drop" outline
        // used as toiletries' category fallback.
        (["shampoo", "conditioner", "body wash", "face wash", "moisturizer", "hair styling", "soap"], .system("drop.fill")),
        // General over-the-counter medications/supplements — distinct
        // from the toiletries category fallback, without needing a
        // separate icon per symptom (no such icons exist to pick from).
        // Bare "medication" catches the CommonProfileItems "Medications"
        // entry itself, which none of the more specific phrases below
        // it actually matched on their own.
        (["medication", "pain reliever", "antacid", "flu medicine", "cold medicine", "melatonin", "sleep aid", "digestive aid", "vitamin"], .system("pills.fill")),
        (["sleeping bag"], .system("bed.double.fill")),
        (["headlamp", "flashlight"], .system("flashlight.on.fill")),
        (["tent"], .system("tent.fill")),
        (["camp stove"], .system("flame.fill")),

        // ---- Custom icon set (Assets.xcassets/icon-*) ----
        // SF Symbols has no glyph at all for these — verified against
        // Apple's actual catalog — so these instead point at small
        // permissively-licensed icons bundled as template-tintable
        // assets (Phosphor Icons, Tabler Icons, and Google's Material
        // Symbols — all MIT/Apache-2.0). See IconRef/PackingIconView.
        (["pants", "jeans", "trousers", "shorts"], .custom("icon-pants")),
        (["sock"], .custom("icon-socks")),
        // A hoodie is the closest bundled shape to "sweater", "cardigan",
        // and a long-sleeve shirt — no dedicated icon exists for any of
        // the three, and this reads far better than the generic tshirt
        // fallback.
        (["sweater", "cardigan", "light jacket", "lightweight layers", "hoodie", "long sleeve", "long-sleeve"], .custom("icon-hoodie")),
        (["hat", "beanie"], .custom("icon-cap")),
        (["belt"], .custom("icon-belt")),
        // Shared between the two — no dedicated toothbrush icon exists
        // anywhere in the icon sets checked, but a tooth reads clearly
        // as "oral care" for both.
        (["toothbrush", "toothpaste"], .custom("icon-tooth")),
        (["portable battery", "battery pack"], .custom("icon-battery")),
        // The Venus symbol reads clearly as "women's" without needing an
        // actual garment/product illustration — no bra or feminine
        // hygiene icon exists anywhere checked, and both are clearly the
        // same "women's" concept.
        (["bra", "feminine hygiene"], .custom("icon-bra")),
        // A brush, not literally a hairbrush (none exists) — closer to
        // the object than the generic drop icon toiletries otherwise get.
        (["hairbrush"], .custom("icon-hairbrush")),

        // The following clothing/toiletry items were checked against
        // Apple's SF Symbols catalog plus four open icon sets (Lucide,
        // Phosphor, Tabler, Material Symbols) — none has a matching icon
        // for: underwear, scarves, deodorant, makeup, razors, shaving
        // cream, and reusable water bottles/wet wipes. They fall through
        // to their category's fallback icon (tshirt/drop/misc/etc.) —
        // not a bug, just the actual ceiling of icon coverage available
        // without commissioning bespoke illustration.
    ]
}
