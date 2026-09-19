Config = {}

-- Language configuration
Config.Locale = 'en'

-- Draws ox_target station zones and logs every synchronized station/blip in F8.
Config.Debug = true
Config.CreatorCommand = 'saloonadmin'
Config.FreightCommand = 'freight'
Config.DefaultInteractDistance = 2.0
Config.DefaultStationRadius = 1.5
Config.MinimumTargetRadius = 1.5
Config.TargetHeight = 2.0
Config.ZoneResizeStep = 0.25
Config.DefaultStorageWeight = 500000
Config.DefaultStorageSlots = 80
-- Numeric RedM hash. The joaat hash of `blip_saloon` is BLIP_AMBIENT_CHORE,
-- not the saloon icon. 1879260108 is BLIP_SALOON.
Config.DefaultBlipSprite = 1879260108
Config.RuntimeBlipSprite = 1879260108
Config.DefaultBlipScale = 0.2
Config.ServerValidationDistance = 4.0
Config.CraftDistance = 4.0
Config.DeliveryDistance = 8.0
Config.ContractExpiryHours = 48

-- World infrastructure belongs here. Business stations are created in-game.
-- Replace/add coordinates for your map/MLO setup.
Config.SupplyDepots = {
    saintdenis_docks = {
        label = 'Saint Denis Docks',
        pickup = vector3(2673.35, -1546.85, 46.02),
        wagonSpawn = vector4(2664.73, -1540.58, 45.91, 270.0),
        freightBoard = vector3(2668.80, -1547.60, 46.00)
    },
    blackwater_docks = {
        label = 'Blackwater Docks',
        pickup = vector3(-731.10, -1252.40, 44.73),
        wagonSpawn = vector4(-738.30, -1247.40, 44.73, 90.0),
        freightBoard = vector3(-733.20, -1249.70, 44.73)
    }
}

-- Cargo is intentionally slot based instead of physics-weight based.
Config.Wagons = {
    ['wagon02x'] = { label = 'Delivery Wagon', maxCrates = 6 },
    ['wagon05x'] = { label = 'Freight Wagon', maxCrates = 12 }
}

-- Items that owners may use in recipes/orders. They must also exist in RSGShared.Items.
-- Add your server's real item names here.
Config.Ingredients = {
    { item = 'water', label = 'Water', unitPrice = 0.10 },
    { item = 'bread', label = 'Bread', unitPrice = 0.15 }
}

Config.CrateProp = `p_crate03x`
Config.CarryAnim = {
    dict = 'mech_carry_box',
    name = 'idle'
}

Config.StationTypes = {
    craft = 'Crafting Station',
    storage = 'Storage',
    manager = 'Management',
    register = 'Register',
    tray = 'Serving Tray',
    delivery = 'Delivery Point',
    piano = 'Piano',
    table = 'Customer Table',
    music = 'Music Control'
}


-- OTG Saloon V2 creator safeguards
Config.StorageLimits = {
    minWeight = 1000,
    maxWeight = 5000000,
    minSlots = 1,
    maxSlots = 500
}

-- Placement increments. The creator uses RedM-safe Cfx key mappings instead of GTA control assumptions.
Config.Placement = {
    moveStep = 0.05,
    fineStep = 0.01,
    verticalStep = 0.025,
    rotateStep = 2.5
}

-- Optional recipe/menu media. FiveManage credentials belong in server-only configuration
-- in a future provider adapter; never put secrets in this shared file.
Config.RecipeImages = {
    allowExternalHttps = true,
    fallback = ''
}


-- OTG V2.2 prop catalog.
-- RedM does not expose a reliable human-readable enumeration of every RDR3 object model.
-- Keep this catalog curated/data-driven. Custom model entry remains available in the creator.
-- Only add models you have verified in RDR3/RedM.
Config.PropCatalog = {
    { category='Storage & Freight', label='Wooden Crate 03', model='p_crate03x' },
    { category='Storage & Freight', label='Wooden Crate 04', model='p_crate04x' },
    { category='Storage & Freight', label='Wooden Box', model='p_boxmed01x' },
    { category='Storage & Freight', label='Barrel', model='p_barrel01x' },
    { category='Storage & Freight', label='Barrel 02', model='p_barrel02x' },
    { category='Furniture', label='Chair 01', model='p_chair01x' },
    { category='Furniture', label='Chair 04', model='p_chair04x' },
    { category='Furniture', label='Chair 06', model='p_chair06x' },
    { category='Furniture', label='Chair 12', model='p_chair12x' },
    { category='Furniture', label='Table 02', model='p_table02x' },
    { category='Furniture', label='Table 04', model='p_table04x' },
    { category='Furniture', label='Bench', model='p_bench01x' },
    { category='Bar & Kitchen', label='Bottle Beer', model='p_bottlebeer01x' },
    { category='Bar & Kitchen', label='Bottle Whiskey', model='p_bottleJD01x' },
    { category='Bar & Kitchen', label='Coffee Pot', model='p_coffeepot01x' },
    { category='Bar & Kitchen', label='Tin Cup', model='p_cupTin01x' },
    { category='Bar & Kitchen', label='Plate', model='p_plate01x' },
    { category='Bar & Kitchen', label='Bowl', model='p_bowl01x' },
    { category='Decor', label='Candle', model='p_candle01x' },
    { category='Decor', label='Lantern', model='p_lantern01x' },
    { category='Decor', label='Book', model='p_book01x' },
    { category='Music', label='Piano', model='p_piano02x' }
}

-- Business-scoped employee permissions layered on top of the authoritative RSG job.
Config.EmployeePermissions = {
    manage_recipes = 'Manage Recipes'
}

Config.Consumables = {
    MaxHunger = 100, MaxThirst = 100, MaxHealth = 50,
    MaxStamina = 50, MaxAlcohol = 100, MaxDurationMs = 120000
}


-- External reference catalogs are fetched server-side once per resource start.
-- If outbound HTTP is unavailable OTG falls back to Config.PropCatalog / built-in blips.
Config.ReferenceCatalogs = {
    blips = 'https://raw.githubusercontent.com/Sarbatore/RDR2-HashDatabase/master/Blips.json',
    objects = 'https://raw.githubusercontent.com/Sarbatore/RDR2-HashDatabase/master/Objects.json',
    timeoutMs = 12000,
    maxPropResults = 250
}
