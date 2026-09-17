local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------------
-- Employee Management
------------------------------------------------
RegisterNetEvent('otg-saloons:server:hireEmployee', function(saloonId, targetCitizenId, role, wage)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or manager
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local employee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    local isManager = employee and employee.role == 'manager'

    if not isOwner and not isManager then
        OTGSaloons.Notify(src, 'You do not have permission to hire', nil, 'error')
        return
    end

    -- Check employee limit
    local employeeCount = 0
    for _, _ in pairs(OTGSaloons.SaloonEmployees[saloonId] or {}) do
        employeeCount = employeeCount + 1
    end
    if employeeCount >= Config.Employees.MaxEmployees then
        OTGSaloons.Notify(src, 'Employee limit reached', nil, 'error')
        return
    end

    -- Validate role
    if not Config.Employees.Roles[role] then
        role = 'bartender'
    end

    -- Validate wage
    wage = tonumber(wage) or Config.Employees.DefaultWage
    wage = math.max(Config.Employees.MinWage, math.min(Config.Employees.MaxWage, wage))

    -- Check if already employed
    if OTGSaloons.SaloonEmployees[saloonId][targetCitizenId] then
        OTGSaloons.Notify(src, 'This player is already employed here', nil, 'error')
        return
    end

    -- Hire employee
    OTGSaloons.SaloonEmployees[saloonId][targetCitizenId] = {
        citizenid = targetCitizenId,
        role = role,
        wage = wage,
        clockedIn = false,
        clockInTime = nil,
        totalHours = 0,
    }
    MySQL.insert('INSERT INTO otg_saloon_employees (saloon_id, citizenid, role, wage) VALUES (?, ?, ?, ?)', {
        saloonId,
        targetCitizenId,
        role,
        wage,
    })

    -- Notify target player if online
    for _, p in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if p.PlayerData.citizenid == targetCitizenId then
            OTGSaloons.Notify(p.PlayerData.source, 'You have been hired!', 'You are now a ' .. Config.Employees.Roles[role].label .. ' at ' .. saloon.label, 'success')
            break
        end
    end

    OTGSaloons.Notify(src, 'Employee hired!', nil, 'success')
end)

RegisterNetEvent('otg-saloons:server:fireEmployee', function(saloonId, targetCitizenId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or manager
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local employee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    local isManager = employee and employee.role == 'manager'

    if not isOwner and not isManager then
        OTGSaloons.Notify(src, 'You do not have permission to fire', nil, 'error')
        return
    end

    -- Cannot fire the owner
    if targetCitizenId == saloon.owner then
        OTGSaloons.Notify(src, 'You cannot fire the owner', nil, 'error')
        return
    end

    -- Check if employee exists
    if not OTGSaloons.SaloonEmployees[saloonId][targetCitizenId] then
        OTGSaloons.Notify(src, 'Employee not found', nil, 'error')
        return
    end

    -- Fire employee
    OTGSaloons.SaloonEmployees[saloonId][targetCitizenId] = nil
    MySQL.prepare('DELETE FROM otg_saloon_employees WHERE saloon_id = ? AND citizenid = ?', { saloonId, targetCitizenId })

    -- Notify target player if online
    for _, p in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if p.PlayerData.citizenid == targetCitizenId then
            OTGSaloons.Notify(p.PlayerData.source, 'You have been fired!', 'You are no longer employed at ' .. saloon.label, 'error')
            break
        end
    end

    OTGSaloons.Notify(src, 'Employee fired!', nil, 'success')
end)

RegisterNetEvent('otg-saloons:server:setEmployeeRole', function(saloonId, targetCitizenId, role)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Only owner can change roles
    if saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Only the owner can change roles', nil, 'error')
        return
    end

    -- Validate role
    if not Config.Employees.Roles[role] then
        OTGSaloons.Notify(src, 'Invalid role', nil, 'error')
        return
    end

    local emp = OTGSaloons.SaloonEmployees[saloonId][targetCitizenId]
    if not emp then
        OTGSaloons.Notify(src, 'Employee not found', nil, 'error')
        return
    end

    emp.role = role
    MySQL.prepare('UPDATE otg_saloon_employees SET role = ? WHERE saloon_id = ? AND citizenid = ?', {
        role,
        saloonId,
        targetCitizenId,
    })

    OTGSaloons.Notify(src, 'Role updated!', nil, 'success')
end)

RegisterNetEvent('otg-saloons:server:setEmployeeWage', function(saloonId, targetCitizenId, wage)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Only owner can change wages
    if saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Only the owner can change wages', nil, 'error')
        return
    end

    local emp = OTGSaloons.SaloonEmployees[saloonId][targetCitizenId]
    if not emp then
        OTGSaloons.Notify(src, 'Employee not found', nil, 'error')
        return
    end

    -- Validate wage
    wage = tonumber(wage) or Config.Employees.DefaultWage
    wage = math.max(Config.Employees.MinWage, math.min(Config.Employees.MaxWage, wage))

    emp.wage = wage
    MySQL.prepare('UPDATE otg_saloon_employees SET wage = ? WHERE saloon_id = ? AND citizenid = ?', {
        wage,
        saloonId,
        targetCitizenId,
    })

    OTGSaloons.Notify(src, 'Wage updated!', nil, 'success')
end)

RegisterNetEvent('otg-saloons:server:getEmployeeStatus', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local emp = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    if not emp then
        OTGSaloons.Notify(src, 'You are not employed here', nil, 'error')
        return
    end

    TriggerClientEvent('otg-saloons:client:receiveEmployeeStatus', src, emp.clockedIn)
end)

RegisterNetEvent('otg-saloons:server:getEmployees', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local employees = {}
    for citizenid, emp in pairs(OTGSaloons.SaloonEmployees[saloonId] or {}) do
        -- Get player name
        local name = citizenid
        for _, p in pairs(RSGCore.Functions.GetRSGPlayers()) do
            if p.PlayerData.citizenid == citizenid then
                name = p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname
                break
            end
        end
        employees[#employees + 1] = {
            citizenid = citizenid,
            name = name,
            role = emp.role,
            roleLabel = Config.Employees.Roles[emp.role] and Config.Employees.Roles[emp.role].label or emp.role,
            wage = emp.wage,
            clockedIn = emp.clockedIn,
            totalHours = emp.totalHours,
        }
    end

    TriggerClientEvent('otg-saloons:client:receiveEmployees', src, employees)
end)

------------------------------------------------
-- Clock In / Out
------------------------------------------------
RegisterNetEvent('otg-saloons:server:clockIn', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local emp = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    if not emp then
        OTGSaloons.Notify(src, 'You are not employed here', nil, 'error')
        return
    end

    if emp.clockedIn then
        OTGSaloons.Notify(src, 'You are already clocked in', nil, 'error')
        return
    end

    emp.clockedIn = true
    emp.clockInTime = os.time()
    MySQL.prepare('UPDATE otg_saloon_employees SET clocked_in = 1, clock_in_time = NOW() WHERE saloon_id = ? AND citizenid = ?', {
        saloonId,
        Player.PlayerData.citizenid,
    })

    OTGSaloons.Notify(src, 'Clocked In!', 'Your wage tracking has started', 'success')
end)

RegisterNetEvent('otg-saloons:server:clockOut', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local emp = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    if not emp then
        OTGSaloons.Notify(src, 'You are not employed here', nil, 'error')
        return
    end

    if not emp.clockedIn then
        OTGSaloons.Notify(src, 'You are not clocked in', nil, 'error')
        return
    end

    -- Calculate hours worked
    local hoursWorked = 0
    if emp.clockInTime then
        hoursWorked = (os.time() - emp.clockInTime) / 3600
        emp.totalHours = emp.totalHours + hoursWorked
    end

    emp.clockedIn = false
    emp.clockInTime = nil
    MySQL.prepare('UPDATE otg_saloon_employees SET clocked_in = 0, clock_in_time = NULL, total_hours = ? WHERE saloon_id = ? AND citizenid = ?', {
        emp.totalHours,
        saloonId,
        Player.PlayerData.citizenid,
    })

    OTGSaloons.Notify(src, 'Clocked Out!', 'You worked ' .. string.format('%.1f', hoursWorked) .. ' hours', 'success')
end)

------------------------------------------------
-- Wage Payment System
------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.Employees.PayInterval * 60 * 1000)

        for saloonId, employees in pairs(OTGSaloons.SaloonEmployees) do
            local saloon = OTGSaloons.Saloons[saloonId]
            if saloon and saloon.owner then
                for citizenid, emp in pairs(employees) do
                    if emp.clockedIn and emp.wage > 0 then
                        -- Calculate hours since clock in
                        local hoursWorked = 0
                        if emp.clockInTime then
                            hoursWorked = (os.time() - emp.clockInTime) / 3600
                        end

                        local pay = emp.wage * hoursWorked

                        -- Check if saloon has enough cash
                        if saloon.cashBalance >= pay then
                            saloon.cashBalance = saloon.cashBalance - pay
                            SaveSaloonData(saloonId)

                            -- Pay the employee
                            for _, p in pairs(RSGCore.Functions.GetRSGPlayers()) do
                                if p.PlayerData.citizenid == citizenid then
                                    p.Functions.AddMoney('cash', pay, 'saloon-wage')
                                    OTGSaloons.Notify(p.PlayerData.source, 'Wage Payment', 'You received $' .. string.format('%.2f', pay) .. ' from ' .. saloon.label, 'success')
                                    break
                                end
                            end
                        else
                            -- Not enough cash, notify owner
                            for _, p in pairs(RSGCore.Functions.GetRSGPlayers()) do
                                if p.PlayerData.citizenid == saloon.owner then
                                    OTGSaloons.Notify(p.PlayerData.source, 'Insufficient Funds', 'Saloon does not have enough cash to pay wages', 'error')
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)