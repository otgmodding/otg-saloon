------------------------------------------------
-- Owner Menu
------------------------------------------------
function OpenOwnerMenu(data)
    local options = {
        {
            title = 'Manage Stock',
            description = 'View and manage saloon stock',
            icon = 'fa-solid fa-boxes-stacked',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:getStock', data.id)
            end,
        },
        {
            title = 'Manage Employees',
            description = 'Hire, fire, and manage employees',
            icon = 'fa-solid fa-users',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:getEmployees', data.id)
            end,
        },
        {
            title = 'Cash Register',
            description = 'View balance: $' .. string.format('%.2f', data.cashBalance or 0),
            icon = 'fa-solid fa-cash-register',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:getCashRegister', data.id)
            end,
        },
        {
            title = 'Sales History',
            description = 'View recent sales',
            icon = 'fa-solid fa-chart-line',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:getSalesHistory', data.id)
            end,
        },
        {
            title = 'Open Stash',
            description = 'Access the saloon storage',
            icon = 'fa-solid fa-box-open',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:openStash', data.id)
            end,
        },
        {
            title = 'Music Control',
            description = 'Control the saloon music',
            icon = 'fa-solid fa-music',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:getMusicState', data.id)
            end,
        },
        {
            title = 'Manage Crafting',
            description = 'Create and manage drink/food recipes',
            icon = 'fa-solid fa-martini-glass-citrus',
            onSelect = function()
                OpenCraftingMenu(data.id)
            end,
        },
        {
            title = 'Transfer Ownership',
            description = 'Transfer saloon to another player',
            icon = 'fa-solid fa-arrow-right-arrow-left',
            onSelect = function()
                local input = lib.inputDialog('Transfer Saloon', {
                    { type = 'input', label = 'Target Citizen ID', required = true },
                })
                if input and input[1] then
                    TriggerServerEvent('otg-saloons:server:transferSaloon', data.id, input[1])
                end
            end,
        },
        {
            title = 'Sell Saloon',
            description = 'Sell the saloon for $' .. Config.Ownership.SellPrice,
            icon = 'fa-solid fa-hand-holding-dollar',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Sell Saloon',
                    content = 'Are you sure you want to sell this saloon for $' .. Config.Ownership.SellPrice .. '?',
                    centered = true,
                    cancel = true,
                })
                if confirm == 'confirm' then
                    TriggerServerEvent('otg-saloons:server:sellSaloon', data.id)
                end
            end,
        },
    }

    lib.registerContext({
        id = 'otg_saloon_owner_menu',
        title = data.label .. ' - Owner Menu',
        options = options,
    })
    lib.showContext('otg_saloon_owner_menu')
end

------------------------------------------------
-- Employee Menu
------------------------------------------------
function OpenEmployeeMenu(data)
    local options = {
        {
            title = 'Clock In / Out',
            description = 'Track your work hours',
            icon = 'fa-solid fa-clock',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:getEmployeeStatus', data.id)
            end,
        },
        {
            title = 'Serve Customers',
            description = 'View and manage customer orders',
            icon = 'fa-solid fa-bell-concierge',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:getOrders', data.id)
            end,
        },
        {
            title = 'Craft Drinks',
            description = 'Craft drinks using recipes',
            icon = 'fa-solid fa-martini-glass-citrus',
            onSelect = function()
                OpenCraftingMenu(data.id)
            end,
        },
        {
            title = 'Manage Stock',
            description = 'View and manage saloon stock',
            icon = 'fa-solid fa-boxes-stacked',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:getStock', data.id)
            end,
        },
        {
            title = 'Music Control',
            description = 'Control the saloon music',
            icon = 'fa-solid fa-music',
            onSelect = function()
                TriggerServerEvent('otg-saloons:server:getMusicState', data.id)
            end,
        },
    }

    lib.registerContext({
        id = 'otg_saloon_employee_menu',
        title = data.label .. ' - Employee Menu',
        options = options,
    })
    lib.showContext('otg_saloon_employee_menu')
end

------------------------------------------------
-- Customer Menu
------------------------------------------------
function OpenCustomerMenu(data)
    local options = {
        {
            title = 'Place Order',
            description = 'Order drinks and food from the bar',
            icon = 'fa-solid fa-bell-concierge',
            onSelect = function()
                OpenOrderMenu(data.id)
            end,
        },
        {
            title = 'View Menu',
            description = 'See what is available',
            icon = 'fa-solid fa-book',
            onSelect = function()
                OpenMenuView(data.id)
            end,
        },
    }

    lib.registerContext({
        id = 'otg_saloon_customer_menu',
        title = data.label,
        options = options,
    })
    lib.showContext('otg_saloon_customer_menu')
end

------------------------------------------------
-- Self-Service Menu
------------------------------------------------
function OpenSelfServiceMenu(data)
    local options = {}
    for _, item in pairs(Config.SelfService.Items) do
        local label = OTGSaloons.GetItemLabel(item.name)
        options[#options + 1] = {
            title = label,
            description = '$' .. string.format('%.2f', item.price),
            icon = 'fa-solid fa-martini-glass',
            onSelect = function()
                local input = lib.inputDialog('Purchase ' .. label, {
                    { type = 'number', label = 'Quantity', default = 1, min = 1, max = 10 },
                })
                if input and input[1] then
                    TriggerServerEvent('otg-saloons:server:selfServicePurchase', data.id, item.name, tonumber(input[1]))
                end
            end,
        }
    end

    -- Add purchase option for unowned saloons
    options[#options + 1] = {
        title = 'Purchase Saloon',
        description = 'Buy this saloon for $' .. Config.Ownership.PurchasePrice,
        icon = 'fa-solid fa-store',
        onSelect = function()
            local confirm = lib.alertDialog({
                header = 'Purchase Saloon',
                content = 'Are you sure you want to purchase this saloon for $' .. Config.Ownership.PurchasePrice .. '?',
                centered = true,
                cancel = true,
            })
            if confirm == 'confirm' then
                TriggerServerEvent('otg-saloons:server:purchaseSaloon', data.id)
            end
        end,
    }

    lib.registerContext({
        id = 'otg_saloon_selfservice_menu',
        title = data.label .. ' - Self Service',
        options = options,
    })
    lib.showContext('otg_saloon_selfservice_menu')
end

------------------------------------------------
-- Menu View (Customer)
------------------------------------------------
function OpenMenuView(saloonId)
    local options = {}
    for _, item in pairs(Config.SelfService.Items) do
        local label = OTGSaloons.GetItemLabel(item.name)
        options[#options + 1] = {
            title = label,
            description = '$' .. string.format('%.2f', item.price),
            icon = 'fa-solid fa-martini-glass',
            disabled = true,
        }
    end

    lib.registerContext({
        id = 'otg_saloon_menu_view',
        title = 'Saloon Menu',
        options = options,
    })
    lib.showContext('otg_saloon_menu_view')
end

------------------------------------------------
-- Crafting Management (Owner)
------------------------------------------------
function OpenCraftingMenu(saloonId)
    -- Request the saloon's recipes from the server
    TriggerServerEvent('otg-saloons:server:getRecipes', saloonId)

    -- Show a loading message while we wait for the response
    lib.showTextUI('Loading recipes...')

    -- Set a timeout to hide the loading message if server doesn't respond
    SetTimeout(5000, function()
        lib.hideTextUI()
    end)
end

function ShowCraftingManagementMenu(recipes, isEmptyState)
    local options = {}

    if isEmptyState then
        options[#options + 1] = {
            title = 'No recipes yet',
            description = 'Add your first recipe to get started',
            icon = 'fa-solid fa-list',
            disabled = true,
        }
    else
        -- Add existing recipes
        for recipeName, recipe in pairs(recipes) do
            options[#options + 1] = {
                title = recipe.display_name or recipeName,
                description = 'Category: ' .. (recipe.category or 'Other') .. ' | Price: $' .. string.format('%.2f', recipe.price or 0),
                icon = 'fa-solid fa-martini-glass-citrus',
                onSelect = function()
                    -- Show recipe details and options to edit/delete
                    ShowRecipeDetailsMenu(recipeName, recipe)
                end,
                args = { recipeName = recipeName, recipe = recipe }
            }
        end
    end

    -- Add button to create new recipe
    options[#options + 1] = {
        title = 'Add New Recipe',
        description = 'Create a new drink or food recipe',
        icon = 'fa-solid fa-plus',
        onSelect = function()
            ShowCreateRecipeMenu()
        end,
    }

    -- Add back button
    options[#options + 1] = {
        title = 'Back',
        description = 'Return to owner menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            if saloonData and saloonData.isOwner then
                OpenOwnerMenu(saloonData)
            end
        end,
    }

    lib.registerContext({
        id = 'otg_saloon_crafting_management',
        title = 'Crafting Management',
        options = options,
    })
    lib.showContext('otg_saloon_crafting_management')
end

function ShowRecipeDetailsMenu(recipeName, recipe)
    local options = {}

    options[#options + 1] = {
        title = 'Edit Recipe',
        description = 'Modify this recipe',
        icon = 'fa-solid fa-pen',
        onSelect = function()
            ShowEditRecipeMenu(recipeName, recipe)
        end,
    }

    options[#options + 1] = {
        title = 'Delete Recipe',
        description = 'Remove this recipe permanently',
        icon = 'fa-solid fa-trash',
        onSelect = function()
            local confirm = lib.alertDialog({
                header = 'Delete Recipe',
                content = 'Are you sure you want to delete the recipe "' .. (recipe.display_name or recipeName) .. '"? This action cannot be undone.',
                centered = true,
                cancel = true,
            })
            if confirm == 'confirm' then
                TriggerServerEvent('otg-saloons:server:deleteRecipe', saloonData.id, recipeName)
            end
        end,
    }

    options[#options + 1] = {
        title = 'Back',
        description = 'Return to recipe list',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            ShowCraftingManagementMenu(recipes, false)
        end,
    }

    lib.registerContext({
        id = 'otg_saloon_recipe_details_' .. recipeName,
        title = recipe.display_name or recipeName,
        options = options,
    })
    lib.showContext('otg_saloon_recipe_details_' .. recipeName)
end

function ShowCreateRecipeMenu()
    local inputs = lib.inputDialog('Create New Recipe', {
        { type = 'input', label = 'Recipe Name (internal)', placeholder = 'e.g., apple_pie', required = true },
        { type = 'input', label = 'Display Name', placeholder = 'e.g., Apple Pie', required = true },
        { type = 'input', label = 'Category', placeholder = 'e.g., Desserts, Drinks, etc.', default = 'Other' },
        { type = 'number', label = 'Craft Time (ms)', default = 5000, min = 1000 },
        { type = 'number', label = 'Price ($)', default = 0.0, min = 0.0, step = 0.01 },
        { type = 'input', label = 'Ingredients (JSON)', description = 'Format: [{"item": "apple", "amount": 2}, {"item": "sugar", "amount": 1}]', default = '[{"item": "apple", "amount": 2}]', required = true },
        { type = 'input', label = 'Receive Item', placeholder = 'e.g., apple_pie', required = true },
        { type = 'number', label = 'Receive Amount', default = 1, min = 1 },
    })

    if inputs then
        local recipeName, displayName, category, craftTime, price, ingredientsJson, receiveItem, receiveAmount =
            inputs[1], inputs[2], inputs[3], inputs[4], inputs[5], inputs[6], inputs[7], inputs[8]

        -- Validate JSON
        local ingredients
        pcall(function() ingredients = json.decode(ingredientsJson) end)
        if not ingredients or type(ingredients) ~= 'table' then
            OTGSaloonsNotify('Invalid Input', 'Ingredients must be valid JSON array', 'error', 5000)
            return
        end

        TriggerServerEvent('otg-saloons:server:addRecipe', saloonData.id, {
            recipe_name = recipeName,
            display_name = displayName,
            category = category,
            craft_time = craftTime,
            price = price,
            ingredients = ingredients,
            receive_item = receiveItem,
            receive_amount = receiveAmount
        })
    end
end

function ShowEditRecipeMenu(recipeName, recipe)
    local inputs = lib.inputDialog('Edit Recipe: ' .. (recipe.display_name or recipeName), {
        { type = 'input', label = 'Display Name', default = recipe.display_name or '' },
        { type = 'input', label = 'Category', default = recipe.category or 'Other' },
        { type = 'number', label = 'Craft Time (ms)', default = recipe.craft_time or 5000, min = 1000 },
        { type = 'number', label = 'Price ($)', default = recipe.price or 0.0, min = 0.0, step = 0.01 },
        { type = 'input', label = 'Ingredients (JSON)', default = json.encode(recipe.ingredients) },
        { type = 'input', label = 'Receive Item', default = recipe.receive_item or '' },
        { type = 'number', label = 'Receive Amount', default = recipe.receive_amount or 1, min = 1 },
    })

    if inputs then
        local displayName, category, craftTime, price, ingredientsJson, receiveItem, receiveAmount =
            inputs[1], inputs[2], inputs[3], inputs[4], inputs[5], inputs[6], inputs[7], inputs[8]

        -- Validate JSON
        local ingredients
        pcall(function() ingredients = json.decode(ingredientsJson) end)
        if not ingredients or type(ingredients) ~= 'table' then
            OTGSaloonsNotify('Invalid Input', 'Ingredients must be valid JSON array', 'error', 5000)
            return
        end

        TriggerServerEvent('otg-saloons:server:updateRecipe', saloonData.id, recipeName, {
            display_name = displayName,
            category = category,
            craft_time = craftTime,
            price = price,
            ingredients = ingredients,
            receive_item = receiveItem,
            receive_amount = receiveAmount
        })
    end
end

------------------------------------------------
-- Employee Status
------------------------------------------------
RegisterNetEvent('otg-saloons:client:receiveEmployeeStatus', function(clockedIn)
    local data = saloonData
    if not data then return end

    if clockedIn then
        TriggerServerEvent('otg-saloons:server:clockOut', data.id)
    else
        TriggerServerEvent('otg-saloons:server:clockIn', data.id)
    end
end)

------------------------------------------------
-- Receive Employees
------------------------------------------------
RegisterNetEvent('otg-saloons:client:receiveEmployees', function(employees)
    local data = saloonData
    if not data then return end

    local options = {}
    for _, emp in pairs(employees) do
        options[#options + 1] = {
            title = emp.name,
            description = emp.roleLabel .. ' | Wage: $' .. string.format('%.2f', emp.wage) .. '/hr' .. (emp.clockedIn and ' | Clocked In' or ''),
            icon = 'fa-solid fa-user',
            onSelect = function()
                local actions = {
                    {
                        title = 'Change Role',
                        description = 'Set employee role',
                        icon = 'fa-solid fa-user-tag',
                        onSelect = function()
                            local roleOptions = {}
                            for roleName, roleData in pairs(Config.Employees.Roles) do
                                roleOptions[#roleOptions + 1] = {
                                    title = roleData.label,
                                    onSelect = function()
                                        TriggerServerEvent('otg-saloons:server:setEmployeeRole', data.id, emp.citizenid, roleName)
                                    end,
                                }
                            end
                            lib.registerContext({
                                id = 'otg_saloon_employee_role',
                                title = 'Set Role - ' .. emp.name,
                                options = roleOptions,
                            })
                            lib.showContext('otg_saloon_employee_role')
                        end,
                    },
                    {
                        title = 'Change Wage',
                        description = 'Set employee wage',
                        icon = 'fa-solid fa-dollar-sign',
                        onSelect = function()
                            local input = lib.inputDialog('Set Wage', {
                                { type = 'number', label = 'Wage per hour', default = emp.wage, min = Config.Employees.MinWage, max = Config.Employees.MaxWage },
                            })
                            if input and input[1] then
                                TriggerServerEvent('otg-saloons:server:setEmployeeWage', data.id, emp.citizenid, tonumber(input[1]))
                            end
                        end,
                    },
                    {
                        title = 'Fire Employee',
                        description = 'Remove employee from saloon',
                        icon = 'fa-solid fa-user-xmark',
                        onSelect = function()
                            local confirm = lib.alertDialog({
                                header = 'Fire Employee',
                                content = 'Are you sure you want to fire ' .. emp.name .. '?',
                                centered = true,
                                cancel = true,
                            })
                            if confirm == 'confirm' then
                                TriggerServerEvent('otg-saloons:server:fireEmployee', data.id, emp.citizenid)
                            end
                        end,
                    },
                }
                lib.registerContext({
                    id = 'otg_saloon_employee_actions',
                    title = 'Manage - ' .. emp.name,
                    options = actions,
                })
                lib.showContext('otg_saloon_employee_actions')
            end,
        }
    end

    -- Add hire option at the end
    options[#options + 1] = {
        title = 'Hire Employee',
        description = 'Hire a new employee',
        icon = 'fa-solid fa-user-plus',
        onSelect = function()
            local input = lib.inputDialog('Hire Employee', {
                { type = 'input', label = 'Target Citizen ID', required = true },
                { type = 'select', label = 'Role', options = {
                    { value = 'bartender', label = 'Bartender' },
                    { value = 'manager', label = 'Manager' },
                }},
                { type = 'number', label = 'Wage per hour', default = Config.Employees.DefaultWage, min = Config.Employees.MinWage, max = Config.Employees.MaxWage },
            })
            if input and input[1] and input[2] and input[3] then
                TriggerServerEvent('otg-saloons:server:hireEmployee', data.id, input[1], input[2], tonumber(input[3]))
            end
        end,
    }

    lib.registerContext({
        id = 'otg_saloon_employees_menu',
        title = 'Employees - ' .. data.label,
        options = options,
    })
    lib.showContext('otg_saloon_employees_menu')
end)

------------------------------------------------
-- Open Cash Register
------------------------------------------------
RegisterNetEvent('otg-saloons:client:openCashRegister', function(saloonId)
    -- The server validates owner/employee register access and notifies on failure
    TriggerServerEvent('otg-saloons:server:getCashRegister', saloonId)
end)

------------------------------------------------
-- Cash Register Menu
------------------------------------------------
RegisterNetEvent('otg-saloons:client:receiveCashRegister', function(cashData)
    -- The register has its own prompt, so fall back to the saloon id sent by the
    -- server instead of requiring the player to open the saloon menu first.
    local data = saloonData
    if not data or data.id ~= cashData.id then
        data = { id = cashData.id }
    end
    if not data.id then return end

    local options = {
        {
            title = 'Back',
            description = 'Return to the previous menu',
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                if saloonData and saloonData.isOwner then
                    OpenOwnerMenu(saloonData)
                end
            end,
        },
        {
            title = 'Deposit Cash',
            description = 'Add cash to the register',
            icon = 'fa-solid fa-money-bill-transfer',
            onSelect = function()
                local input = lib.inputDialog('Deposit Cash', {
                    { type = 'number', label = 'Amount', default = 100, min = 1, max = cashData.maxBalance },
                })
                if input and input[1] then
                    TriggerServerEvent('otg-saloons:server:depositCash', data.id, tonumber(input[1]))
                end
            end,
        },
        {
            title = 'Withdraw Cash',
            description = 'Take cash from the register',
            icon = 'fa-solid fa-hand-holding-dollar',
            onSelect = function()
                local input = lib.inputDialog('Withdraw Cash', {
                    { type = 'number', label = 'Amount', default = 100, min = 1, max = cashData.balance },
                })
                if input and input[1] then
                    TriggerServerEvent('otg-saloons:server:withdrawCash', data.id, tonumber(input[1]))
                end
            end,
        },
    }

    lib.registerContext({
        id = 'otg_saloon_cash_menu',
        title = 'Cash Register - $' .. string.format('%.2f', cashData.balance),
        options = options,
    })
    lib.showContext('otg_saloon_cash_menu')
end)

------------------------------------------------
-- Receive Sales History
------------------------------------------------
RegisterNetEvent('otg-saloons:client:receiveSalesHistory', function(sales)
    local options = {}
    for _, sale in pairs(sales) do
        options[#options + 1] = {
            title = sale.item .. ' x' .. sale.amount,
            description = '$' .. string.format('%.2f', sale.price) .. ' | ' .. (sale.buyer or 'Unknown') .. ' | ' .. sale.sale_type,
            icon = 'fa-solid fa-receipt',
            disabled = true,
        }
    end

    options[#options + 1] = {
        title = 'Back',
        description = 'Return to the previous menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            if saloonData and saloonData.isOwner then
                OpenOwnerMenu(saloonData)
            end
        end,
    }

    if #options == 0 then
        options[1] = {
            title = 'No sales yet',
            icon = 'fa-solid fa-circle-info',
            disabled = true,
        }
    end

    lib.registerContext({
        id = 'otg_saloon_sales_history',
        title = 'Sales History',
        options = options,
    })
    lib.showContext('otg_saloon_sales_history')
end)