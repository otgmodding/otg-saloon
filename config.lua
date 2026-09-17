Config = {}

------------------------------------------------
-- Feature Toggles - Enable/disable specific features
------------------------------------------------
Config.EnableAdminCommands = true
Config.EnableRecipeManagement = true
Config.EnableCraftingSystem = true
Config.EnableSelfService = true
Config.EnableCounterSystem = true
Config.EnableEmployeeManagement = true
Config.EnableMusicSystem = true
Config.EnableSalesTracking = true
Config.EnableOrderSystem = true

------------------------------------------------
-- Target System Configuration
------------------------------------------------
Config.UseOxTarget = true -- Set to false to use prompts/keybinds instead
Config.TargetDistance = 2.5 -- Distance for target interactions
Config.TargetIcon = 'fas fa-cocktail' -- Icon for targets (if using ox_target)

------------------------------------------------
-- Creator System Configuration
------------------------------------------------
Config.EnableCreator = true -- Enable/disable the saloon creator system
Config.CreatorCommand = 'salooncreator' -- Command to open the creator menu
Config.CreatorPermission = 'group.admin' -- Permission group required to use the creator

------------------------------------------------
-- General Settings
------------------------------------------------
Config.Debug = false -- Enable debug prints
Config.Keybind = 'E' -- Keybind for prompts
Config.PromptDistance = 2.5 -- Distance for prompts

------------------------------------------------
-- Saloon Locations
------------------------------------------------
-- Saloon locations are now loaded from a JSON file (data/saloons_data.json)
-- created via the in-game admin creator (/saloon create).
-- This allows for dynamic creation without modifying this config file.
-- Default saloon template for new creations can be defined below:
Config.Saloons = {}

-- Path to JSON file containing dynamically created saloons
-- The server loads saloons from this file on startup
Config.SaloonDataDir = 'data/saloons_data.json'

------------------------------------------------
-- Default saloon template for new creations
-- This template is used when creating new saloons in-game
------------------------------------------------
Config.DefaultSaloonTemplate = {
    label = 'New Saloon',
    coords = vector3(0.0, 0.0, 0.0),
    counterCoords = vector3(0.0, 0.0, 0.0),
    cashRegisterCoords = vector3(0.0, 0.0, 0.0),
    craftingCoords = vector3(0.0, 0.0, 0.0),
    musicCoords = vector3(0.0, 0.0, 0.0),
    dancerCoords = vector3(0.0, 0.0, 0.0),
    blip = {
        enabled = true,
        sprite = 'blip_shop_store',
        scale = 0.2,
        color = 'BLIP_MODIFIER_MP_COLOR_6',
    },
    defaultStock = {
        beer = 50,
        whiskey = 30,
        bread = 25,
        stew = 20,
        coffee = 30,
    },
}

------------------------------------------------
-- Ownership System
------------------------------------------------
Config.Ownership = {
    PurchasePrice = 5000, -- Cost to purchase an unowned saloon
    SellPrice = 3000, -- Amount received when selling a saloon
    MaxOwnedSaloons = 1, -- Max saloons a player can own
    AllowTransfer = true, -- Allow transferring ownership to another player
    PurchaseCooldown = 60, -- Seconds between purchase attempts
}

------------------------------------------------
-- Employee Management
------------------------------------------------
Config.Employees = {
    MaxEmployees = 10, -- Max employees per saloon
    DefaultWage = 25, -- Default hourly wage
    MinWage = 5, -- Minimum wage allowed
    MaxWage = 200, -- Maximum wage allowed
    PayInterval = 30, -- Minutes between wage payments
    ClockInDistance = 5.0, -- Max distance to clock in/out
    Roles = {
        ['bartender'] = {
            label = 'Bartender',
            canServe = true,
            canCraft = true,
            canManageStock = true,
            canControlMusic = true,
            canAccessCashRegister = false,
            canManageEmployees = false,
        },
        ['manager'] = {
            label = 'Manager',
            canServe = true,
            canCraft = true,
            canManageStock = true,
            canControlMusic = true,
            canAccessCashRegister = true,
            canManageEmployees = true,
        },
    },
}

------------------------------------------------
-- Stock & Inventory
------------------------------------------------
Config.Stock = {
    MaxStockPerItem = 100, -- Max stock of a single item
    RestockTime = 300, -- Seconds between automatic restocks
    RestockAmount = 5, -- Amount restocked per cycle
    RestockEnabled = true, -- Enable automatic restocking
    StashIdentifier = 'otg_saloon_stash_', -- Prefix for stash identifiers
    StashSlots = 50, -- Number of stash slots
    StashWeight = 100000, -- Max stash weight
}

------------------------------------------------
-- Cash Register
------------------------------------------------
Config.CashRegister = {
    MaxBalance = 100000, -- Max cash that can be stored
    WithdrawCooldown = 10, -- Seconds between withdrawals
    DepositCooldown = 5, -- Seconds between deposits
    TaxRate = 0.05, -- 5% tax on sales
}

------------------------------------------------
-- Drink Crafting
------------------------------------------------
Config.Crafting = {
    CraftTime = 5000, -- Base craft time in ms
    CraftingAnimDict = 'amb_rest_drunk@world_human_drinking@male_a@idle_a',
    CraftingAnimName = 'idle_a',
    CraftingProp = 'p_cs_canteen_hercule',
}

-- Recipes for crafting drinks
-- ingredients: items required to craft
-- receive: item received
-- price: cost to craft (taken from saloon cash register if owned, or player if self-service)
Config.Recipes = {
    ['beer'] = {
        name = 'Beer',
        label = 'Beer',
        crafttime = 5000,
        category = 'Beers',
        ingredients = {
            [1] = { item = 'corn', amount = 2 },
            [2] = { item = 'water', amount = 1 },
        },
        receive = 'beer',
        price = 1.00,
    },
    ['whiskey'] = {
        name = 'Whiskey',
        label = 'Whiskey',
        crafttime = 5000,
        category = 'Shorts',
        ingredients = {
            [1] = { item = 'potato', amount = 2 },
            [2] = { item = 'water', amount = 1 },
        },
        receive = 'whiskey',
        price = 2.00,
    },
    ['wine'] = {
        name = 'Wine',
        label = 'Wine',
        crafttime = 5000,
        category = 'Wines',
        ingredients = {
            [1] = { item = 'berry', amount = 2 },
            [2] = { item = 'water', amount = 1 },
        },
        receive = 'wine',
        price = 2.50,
    },
    ['tequila'] = {
        name = 'Tequila',
        label = 'Tequila',
        crafttime = 5000,
        category = 'Shorts',
        ingredients = {
            [1] = { item = 'corn', amount = 2 },
            [2] = { item = 'water', amount = 1 },
        },
        receive = 'tequila',
        price = 2.00,
    },
    ['coffee'] = {
        name = 'Coffee',
        label = 'Coffee',
        crafttime = 3000,
        category = 'Hot Drinks',
        ingredients = {
            [1] = { item = 'coffeebeans', amount = 1 },
            [2] = { item = 'water', amount = 1 },
        },
        receive = 'coffee',
        price = 0.50,
    },
    ['stew'] = {
        name = 'Stew',
        label = 'Stew',
        crafttime = 8000,
        category = 'Food',
        ingredients = {
            [1] = { item = 'meat', amount = 1 },
            [2] = { item = 'potato', amount = 1 },
            [3] = { item = 'water', amount = 1 },
        },
        receive = 'stew',
        price = 1.50,
    },
    ['bread'] = {
        name = 'Bread',
        label = 'Bread',
        crafttime = 5000,
        category = 'Food',
        ingredients = {
            [1] = { item = 'wheat', amount = 2 },
            [2] = { item = 'water', amount = 1 },
        },
        receive = 'bread',
        price = 0.50,
    },
    ['oldfashioned'] = {
        name = 'Old Fashioned',
        label = 'Old Fashioned',
        crafttime = 6000,
        category = 'Cocktails',
        ingredients = {
            [1] = { item = 'whiskey', amount = 1 },
            [2] = { item = 'sugar', amount = 1 },
            [3] = { item = 'lemon', amount = 1 },
        },
        receive = 'oldfashioned',
        price = 3.00,
    },
    ['moonshine'] = {
        name = 'Moonshine',
        label = 'Moonshine',
        crafttime = 10000,
        category = 'Moonshine',
        ingredients = {
            [1] = { item = 'corn', amount = 2 },
            [2] = { item = 'water', amount = 2 },
            [3] = { item = 'sugar', amount = 1 },
        },
        receive = 'moonshine',
        price = 4.00,
    },
}

------------------------------------------------
-- Customer Ordering
------------------------------------------------
Config.Orders = {
    OrderTimeout = 60, -- Seconds before an order expires
    MaxActiveOrders = 5, -- Max active orders per saloon
    OrderCooldown = 30, -- Seconds between customer orders
    TipChance = 0.3, -- 30% chance of a tip
    TipMin = 1, -- Minimum tip amount
    TipMax = 10, -- Maximum tip amount
    OrderItems = {
        'beer',
        'whiskey',
        'wine',
        'tequila',
        'coffee',
        'stew',
        'bread',
        'oldfashioned',
        'moonshine',
    },
}

------------------------------------------------
-- Music Control
------------------------------------------------
Config.Music = {
    Enabled = true, -- Enable music system
    DefaultVolume = 0.5, -- Default music volume
    MaxVolume = 1.0, -- Maximum volume
    MinVolume = 0.0, -- Minimum volume
    -- Available music tracks (xsound compatible)
    Tracks = {
        [1] = {
            name = 'Saloon Piano',
            url = 'https://example.com/saloon_piano.ogg',
            volume = 0.5,
        },
        [2] = {
            name = 'Western Ballad',
            url = 'https://example.com/western_ballad.ogg',
            volume = 0.5,
        },
        [3] = {
            name = 'Fiddle Tune',
            url = 'https://example.com/fiddle_tune.ogg',
            volume = 0.5,
        },
        [4] = {
            name = 'Banjo Blues',
            url = 'https://example.com/banjo_blues.ogg',
            volume = 0.5,
        },
    },
}

------------------------------------------------
-- Dancer System
------------------------------------------------
Config.Dancers = {
    Enabled = true, -- Enable dancer system
    MaxDancers = 3, -- Max dancers per saloon
    DanceAnimDict = 'amb_rest_drunk@world_human_drinking@male_a@idle_a',
    DanceAnimName = 'idle_a',
    DanceDuration = 30, -- Seconds per dance session
    DanceCooldown = 60, -- Seconds between dance sessions
    TipChance = 0.2, -- 20% chance of a tip
    TipMin = 1,
    TipMax = 5,
}

------------------------------------------------
-- Drunk Effects
------------------------------------------------
Config.DrunkEffects = {
    Enabled = true, -- Enable drunk effects
    -- Each drink has a drunk level. Higher = more drunk
    DrunkLevels = {
        ['beer'] = 10,
        ['whiskey'] = 25,
        ['wine'] = 15,
        ['tequila'] = 30,
        ['oldfashioned'] = 35,
        ['moonshine'] = 50,
    },
    MaxDrunkLevel = 100, -- Maximum drunk level
    DrunkDecayRate = 2, -- Drunk level decay per second
    DrunkThreshold = 30, -- Level at which visual effects start
    SevereDrunkThreshold = 60, -- Level at which severe effects start
    -- Camera sway intensity at different levels
    SwayMin = 0.01,
    SwayMax = 0.05,
    -- Screen effects
    EnableBlur = true,
    EnableColorShift = true,
    EnableCameraSway = true,
    EnableMovementImpairment = true,
    MovementImpairmentChance = 0.3, -- Chance of stumbling
}

------------------------------------------------
-- Self-Service Mode
------------------------------------------------
Config.SelfService = {
    Enabled = true, -- Enable self-service for unowned saloons
    -- Items available for purchase in self-service mode
    Items = {
        { name = 'beer', price = 1.00 },
        { name = 'whiskey', price = 2.00 },
        { name = 'wine', price = 2.50 },
        { name = 'tequila', price = 2.00 },
        { name = 'coffee', price = 0.50 },
        { name = 'stew', price = 1.50 },
        { name = 'bread', price = 0.50 },
    },
    -- Money type used for purchases
    MoneyType = 'cash',
}

------------------------------------------------
-- Counter Placement
------------------------------------------------
Config.Counter = {
    MaxItemsOnCounter = 10, -- Max items that can be placed on counter
    ItemLifetime = 300, -- Seconds before placed items expire
    PlaceDistance = 1.5, -- Distance from counter to place items
    -- Props used for placed items (fallback if item has no prop)
    DefaultProp = 'p_cs_canteen_hercule',
    -- Item prop mappings (item name -> prop model)
    ItemProps = {
        ['beer'] = 'p_cs_canteen_hercule',
        ['whiskey'] = 'p_cs_canteen_hercule',
        ['wine'] = 'p_cs_canteen_hercule',
        ['tequila'] = 'p_cs_canteen_hercule',
        ['coffee'] = 'p_cs_canteen_hercule',
        ['stew'] = 'p_cs_canteen_hercule',
        ['bread'] = 'p_cs_canteen_hercule',
        ['oldfashioned'] = 'p_cs_canteen_hercule',
        ['moonshine'] = 'p_cs_canteen_hercule',
    },
}

------------------------------------------------
-- Crafting (Owner-Managed)
------------------------------------------------
-- Recipes are managed by the saloon owner in-game (Manage Crafting menu).
-- DefaultRecipes below are only SEEDS: they are copied into a saloon's
-- crafting menu on first load, after which the owner can add/remove them.
-- ingredients: item name -> amount required (taken from the saloon stock)
Config.Crafting = {
    Enabled = true,
    Time = 5000,        -- ms it takes to craft one item
    MaxRecipes = 25,    -- max recipes per saloon
    DefaultRecipes = {
        { name = 'oldfashioned', label = 'Old Fashioned', receive = 'oldfashioned', amount = 1, price = 4.00, ingredients = { whiskey = 2 } },
        { name = 'moonshine',    label = 'Moonshine',    receive = 'moonshine',    amount = 1, price = 5.00, ingredients = { whiskey = 1, coffee = 1 } },
        { name = 'stew',         label = 'Hearty Stew',  receive = 'stew',         amount = 1, price = 2.50, ingredients = { bread = 1, coffee = 1 } },
    },
}

------------------------------------------------
-- Table Service
------------------------------------------------
-- Customers can call service to their table; employees/owner pick up
-- the call, see what the customer wants and deliver it.
Config.TableService = {
    Enabled = true,
    CallDistance = 30.0,    -- max distance from the saloon point to call service
    NotifyDistance = 60.0,  -- distance at which staff receive the call blip/notification
    OrderTimeout = 300,     -- seconds before an unanswered table order expires
    MaxActiveOrders = 10,   -- max active table orders per saloon
}

------------------------------------------------
-- Shop (rsg-inventory shop UI)
------------------------------------------------
-- Customers buy directly from the saloon stock through the inventory
-- shop UI instead of the context menu. Optional per-saloon `shopCoords`
-- in Config.Saloons falls back to the counter coords when not set.
Config.Shop = {
    Enabled = true,
}

------------------------------------------------
-- Notifications
------------------------------------------------
------------------------------------------------
-- Notifications
------------------------------------------------
Config.Notifications = {
    UseOxLib = false, -- Use ox_lib notifications
    UseRNotify = false, -- Use rNotify notifications
    UseBlnNotify = true, -- Use bln_notify notifications
}

------------------------------------------------
-- Shared Utility Functions
------------------------------------------------
-- Moved here from shared/main.lua (which has been removed).
-- config.lua is loaded as a shared script, so these are available
-- to both client and server at runtime.
OTGSaloons = OTGSaloons or {}

function OTGSaloons.GetRecipeByName(name)
    for _, recipe in pairs(Config.Recipes) do
        if recipe.name == name or recipe.receive == name then
            return recipe
        end
    end
    return nil
end

function OTGSaloons.GetItemLabel(itemName)
    if RSGCore and RSGCore.Shared and RSGCore.Shared.Items and RSGCore.Shared.Items[itemName] then
        return RSGCore.Shared.Items[itemName].label
    end
    return itemName
end

function OTGSaloons.GetItemPrice(itemName)
    -- Check self-service items first
    for _, item in pairs(Config.SelfService.Items) do
        if item.name == itemName then
            return item.price
        end
    end
    -- Check recipes
    local recipe = OTGSaloons.GetRecipeByName(itemName)
    if recipe then
        return recipe.price
    end
    return 0
end

-- The `os` library is not exposed to CfxLua client scripts (the client sandbox
-- strips the standard libraries), so `os.time()` throws
-- "attempt to index a nil value (global 'os')" on the client.
-- This helper returns a Unix timestamp in seconds on both client and server,
-- falling back to the game timer when cloud time is not available.
function OTGSaloons.GetTimestamp()
    if os and os.time then
        return os.time()
    end

    if GetCloudTimeAsInt then
        local cloudTime = GetCloudTimeAsInt()
        if cloudTime and cloudTime > 0 then
            return cloudTime
        end
    end

    -- Client fallback: the game timer is monotonic milliseconds, so convert to seconds.
    return math.floor(GetGameTimer() / 1000)
end

function OTGSaloons.DebugPrint(...)
    if Config.Debug then
        print('[otg-saloons]', ...)
    end
end

------------------------------------------------
-- Admin and Owner Management
------------------------------------------------
Config.AdminGroup = 'group.admin' -- The group that can create and manage saloons
Config.OwnerManagement = true -- Whether saloon owners can manage their own saloons

------------------------------------------------
-- UI Configuration
------------------------------------------------
Config.UI = {
    -- Menu settings
    menuTitle = 'Saloon Management',
    menuSubtitle = 'Manage your saloon operations',
    
    -- Crafting UI settings
    craftingTitle = 'Crafting Station',
    craftingSubtitle = 'Create new items',
    
    -- Self-service UI settings
    selfServiceTitle = 'Self Service',
    selfServiceSubtitle = 'Purchase items'
}

------------------------------------------------
-- Notification Settings
------------------------------------------------
Config.Notifications = {
    UseOxLib = false,
    UseRNotify = false,
    UseBlnNotify = true
}

------------------------------------------------
-- New Restaurant Configuration Section
------------------------------------------------
-- This section allows for configuring restaurant-style operations
-- similar to MT Restaurants FiveM implementation
Config.Restaurants = {
    -- Example restaurant configuration
    ['restaurant1'] = {
        name = 'Restaurant',
        label = 'Restaurant',
        coords = vector3(250.0, -800.0, 25.0),
        heading = 180.0,
        blip = {
            enabled = true,
            sprite = 'blip_shop_store',
            scale = 0.2,
            color = 'BLIP_MODIFIER_MP_COLOR_6'
        }
    }
}

------------------------------------------------
-- Integration Settings with RSG-Core
------------------------------------------------
Config.RSGCoreIntegration = {
    enabled = true,
    inventoryEvent = 'rsg-core:inventory:update',
    playerLoadedEvent = 'rsg-core:client:playerLoaded',
    onPlayerLogout = 'rsg-core:client:playerLogout'
}

