# otg-saloons

REDM saloon/restaurant script for RSG Framework with dynamic in-game creator system.

## 🎮 In-Game Creator System

This script implements an in-game creator system similar to MT Restaurants for FiveM. Saloon locations are created dynamically in-game by admins and saved to a JSON file, eliminating the need to hardcode locations in the config.

### Using the Creator Menu

Admins with `group.admin` permission can use the in-game creator:
```
/salooncreator
```

This opens a comprehensive menu where you can configure:

1. **Saloon Information** - Set ID and label
2. **Main Position** - Place the saloon at your current location  
3. **Configure Points** - Set positions for:
   - Cash Register
   - Crafting Station
   - Music Control
   - Dancer Area
4. **Zone Configuration** - Set the polyzone radius for the interaction area
5. **Blip Settings** - Configure the map blip icon, scale, and color
6. **Preview & Save** - Review settings and save the saloon

### Alternative: Quick Command

For quick saloon creation at your current position:
```
/saloon create [id] [label]
```

The saloon will be created with default station locations.

### Managing Saloons

Other admin commands:
- `/saloon list` - List all saloons
- `/saloon delete [id]` - Delete a saloon
- `/recipe list [saloon_id]` - List recipes for a saloon
- `/recipe add [saloon_id]` - Add a new recipe
- `/recipe remove [saloon_id] [recipe_name]` - Remove a recipe
- `/stock set [saloon_id] [item_name] [amount]` - Set stock for an item

### Data Persistence

Saloon locations are saved to `data/saloons_data.json` and loaded on server startup. The JSON file is automatically updated when saloons are created or deleted.

---

# otg-saloons Admin Command Documentation

This document explains the admin command system for managing saloons in the otg-saloons resource.

## Feature Toggles

The config.lua file now includes feature toggles that allow you to enable or disable specific systems:

```lua
Config.EnableAdminCommands = true      -- Enable/disable admin commands
Config.EnableRecipeManagement = true   -- Enable/disable recipe management
Config.EnableCraftingSystem = true     -- Enable/disable crafting station
Config.EnableSelfService = true        -- Enable/disable self-service mode
Config.EnableCounterSystem = true      -- Enable/disable counter item placement
Config.EnableEmployeeManagement = true -- Enable/disable employee hiring/firing
Config.EnableMusicSystem = true        -- Enable/disable music control
Config.EnableSalesTracking = true      -- Enable/disable sales history
Config.EnableOrderSystem = true        -- Enable/disable table service orders
```

## Target System Configuration

The system supports both ox_target and prompt-based interactions:

```lua
Config.UseOxTarget = true      -- Use ox_target if available, prompts otherwise
Config.TargetDistance = 2.5    -- Interaction distance
Config.TargetIcon = 'fas fa-cocktail' -- Target icon
```

## Admin Commands

### Saloon Management

**`/saloon create [id] [label]`**
Creates a new saloon at the admin's current position.
- `id`: Unique identifier for the saloon (e.g., "saloon1")
- `label`: Display name for the saloon (e.g., "Valentine Saloon")

Example: `/saloon create valentine_saloon "Valentine Saloon"`

**`/saloon delete [id]`**
Permanently deletes a saloon and all associated data.
- `id`: The saloon ID to delete

Example: `/saloon delete valentine_saloon`

**`/saloon list`**
Lists all saloons with their IDs, labels, and owners.

### Recipe Management

**`/recipe list [saloon_id]`**
Lists all recipes configured for a specific saloon.
- `saloon_id`: The ID of the saloon

**`/recipe add [saloon_id] [recipe_name]`**
Opens the recipe editor to create a new recipe for a saloon.
- `saloon_id`: The ID of the saloon
- `recipe_name`: The internal name for the recipe

**`/recipe remove [saloon_id] [recipe_name]`**
Removes a recipe from a saloon.
- `saloon_id`: The ID of the saloon
- `recipe_name`: The name of the recipe to remove

### Stock Management

**`/stock set [saloon_id] [item_name] [amount]`**
Sets the stock of a specific item in a saloon.
- `saloon_id`: The ID of the saloon
- `item_name`: The item identifier
- `amount`: The quantity to set

Example: `/stock set valentine_saloon whiskey 100`

## Permission System

Admin commands require the `group.admin` permission group. This is configured in:

```lua
Config.AdminGroup = 'group.admin'
```

The permission check works with both string and table-based group assignments.

## Owner Management

Saloon owners (players who have purchased a saloon) can manage their saloon through the in-game menu:
- Manage stock
- Manage employees
- View sales history
- Craft drinks
- Control music
- Transfer ownership
- Sell the saloon

## Integration with RSG-Core

The system integrates with RSG-Core for:
- Player permissions and groups
- Inventory management
- Money transactions
- Character data

## Client-Side Events

The following client events are available for dynamic saloon management:

- `otg-saloons:client:saloonCreated` - Fired when a saloon is created
- `otg-saloons:client:saloonDeleted` - Fired when a saloon is deleted
- `otg-saloons:client:syncInventory` - Fired for inventory updates
- `otg-saloons:client:openRecipeList` - Opens recipe list menu
- `otg-saloons:client:openRecipeEditor` - Opens recipe editor

## Configuration Reference

### Saloon Stations

Each saloon can have multiple stations:
- `counter`: Player interaction and item placement
- `crafting`: Recipe crafting interface
- `selfservice`: Self-service purchasing (when unowned)

### Recipes

Recipes define craftable items with:
- `display_name`: What shows in the UI
- `category`: Organization category
- `price`: Selling price
- `ingredients`: Required items and quantities
- `receive_item`: Output item
- `receive_amount`: Output quantity
- `craft_time`: Time in milliseconds

### Employee Roles

Defined roles with permissions:
- `owner`: Full access to all saloon features
- `manager`: Can manage employees, view sales, edit settings
- `bartender`: Can serve items, view sales