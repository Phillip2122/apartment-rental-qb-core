local QBCore = exports['qb-core']:GetCoreObject()

local InApartment = false
local ClosestHouse = nil
local CurrentApartment = nil
local IsOwned = false
local CurrentDoorBell = 0
local CurrentOffset = 0
local HouseObj = {}
local POIOffsets = nil
local RangDoorbell = nil

-- target variables
local InApartmentTargets = {}

-- polyzone variables
local IsInsideStashZone = false
local IsInsideOutfitsZone = false
local IsInsideLogoutZone = false


CreateThread(function()
            local blipapart = AddBlipForCoord(vector3(-669.91, -1104.15, 14.62))
            SetBlipSprite(blipapart, 374)
            SetBlipDisplay(blipapart, 4)
            SetBlipScale(blipapart, 0.70)
            SetBlipAsShortRange(blipapart, true)
            SetBlipColour(blipapart, 46)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName("Apartment")
            EndTextCommandSetBlipName(blipapart)
end)


-- polyzone integration

local function RegisterInApartmentZone(targetKey, coords, heading, text)
    if not InApartment then
        return
    end

    if InApartmentTargets[targetKey] then
        return
    end

    Wait(1000)

    local box = lib.zones.box({
        coords = coords,
        size = vec3(3, 3, 3),
        rotation = 45,
        debug = false,
        inside = function ()
         --  print(targetKey)
        end,
        onEnter = function ()
            exports['qb-core']:DrawText(text, 'left')
            if targetKey == "stashPos" then
                IsInsideStashZone = true
            end
    
            if targetKey == "outfitsPos" then
                IsInsideOutfitsZone = true
            end

        end,
        onExit = function ()
            if targetKey == "stashPos" then
                IsInsideStashZone = false
            end
    
            if targetKey == "outfitsPos" then
                IsInsideOutfitsZone = false
            end

            exports['qb-core']:HideText()
        end
    })

    InApartmentTargets[targetKey] = InApartmentTargets[targetKey] or {}
    InApartmentTargets[targetKey].zone = box
end


-- shared

local function SetInApartmentTargets()
    if not POIOffsets then
        -- do nothing
        return
    end

    local entrancePos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.exit.x, Apartments.Locations[ClosestHouse].coords.enter.y - POIOffsets.exit.y - 0.5, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.exit.z)
    local stashPos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.stash.x, Apartments.Locations[ClosestHouse].coords.enter.y - POIOffsets.stash.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.stash.z)
    local outfitsPos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.clothes.x, Apartments.Locations[ClosestHouse].coords.enter.y - POIOffsets.clothes.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.clothes.z)
    local logoutPos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.logout.x, Apartments.Locations[ClosestHouse].coords.enter.y + POIOffsets.logout.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.logout.z)

    RegisterInApartmentZone('stashPos', stashPos, 0, "[E] " .. "Open Stash")
    RegisterInApartmentZone('outfitsPos', outfitsPos, 0, "[E] " .. "Outfit")
   -- RegisterInApartmentZone('logoutPos', logoutPos, 0, "[E] " .. "Logiut")
   -- RegisterInApartmentZone('entrancePos', entrancePos, 0, "[E] Apartment Options")
end

local function DeleteApartmentsEntranceTargets()
    if Apartments.Locations and next(Apartments.Locations) then
        for _, apartment in pairs(Apartments.Locations) do
            if apartment.zone then
                apartment.zone:remove()
                apartment.zone = nil
            end
        end
    end
end

local function DeleteInApartmentTargets()
    IsInsideStashZone = false
    IsInsideOutfitsZone = false
    IsInsideLogoutZone = false

    if InApartmentTargets and next(InApartmentTargets) then
        for _, apartmentTarget in pairs(InApartmentTargets) do
            if apartmentTarget.zone then
                apartmentTarget.zone:remove()
                apartmentTarget.zone = nil
            end
        end
    end
    InApartmentTargets = {}
end


-- utility functions

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

local function openHouseAnim()
    loadAnimDict("anim@heists@keycard@")
    TaskPlayAnim( PlayerPedId(), "anim@heists@keycard@", "exit", 5.0, 1.0, -1, 16, 0, 0, 0, 0 )
    Wait(400)
    ClearPedTasks(PlayerPedId())
end

local function EnterApartment(house, apartmentId, new)
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.1)
   openHouseAnim()
    Wait(250)
    QBCore.Functions.TriggerCallback('apartments:GetApartmentOffset', function(offset)
        if offset == nil or offset == 0 then
            QBCore.Functions.TriggerCallback('apartments:GetApartmentOffsetNewOffset', function(newoffset)
                if newoffset > 230 then
                    newoffset = 210
                end
                CurrentOffset = newoffset
                TriggerServerEvent("apartments:server:AddObject", apartmentId, house, CurrentOffset)
                local coords = { x = Apartments.Locations[house].coords.enter.x, y = Apartments.Locations[house].coords.enter.y, z = Apartments.Locations[house].coords.enter.z - CurrentOffset}
                local data = exports['qb-interior']:CreateApartmentFurnished(coords)
                Wait(100)
                HouseObj = data[1]
                POIOffsets = data[2]
                InApartment = true
                CurrentApartment = apartmentId
                ClosestHouse = house
                RangDoorbell = nil
                Wait(500)
                TriggerEvent('qb-weathersync:client:DisableSync')
                Wait(100)
                TriggerServerEvent('qb-apartments:server:SetInsideMeta', house, apartmentId, true, false)
                TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_close", 0.1)
                TriggerServerEvent("apartments:server:setCurrentApartment", CurrentApartment)

            end, house)
        else
            if offset > 230 then
                offset = 210
            end
            CurrentOffset = offset
            TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.1)
            TriggerServerEvent("apartments:server:AddObject", apartmentId, house, CurrentOffset)
            local coords = { x = Apartments.Locations[ClosestHouse].coords.enter.x, y = Apartments.Locations[ClosestHouse].coords.enter.y, z = Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset}
            local data = exports['qb-interior']:CreateApartmentFurnished(coords)
            Wait(100)
            HouseObj = data[1]
            POIOffsets = data[2]
            InApartment = true
            CurrentApartment = apartmentId
            Wait(500)
            TriggerEvent('qb-weathersync:client:DisableSync')
            Wait(100)
            TriggerServerEvent('qb-apartments:server:SetInsideMeta', house, apartmentId, true, true)
            TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_close", 0.1)
            TriggerServerEvent("apartments:server:setCurrentApartment", CurrentApartment)
        end

        if new ~= nil then
            if new then
                TriggerEvent('qb-interior:client:SetNewState', true)
            else
                TriggerEvent('qb-interior:client:SetNewState', false)
            end
        else
            TriggerEvent('qb-interior:client:SetNewState', false)
        end
    end, apartmentId)
end

local function LeaveApartment(house)
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.1)
    openHouseAnim()
    TriggerServerEvent("qb-apartments:returnBucket")
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    exports['qb-interior']:DespawnInterior(HouseObj, function()
        TriggerEvent('qb-weathersync:client:EnableSync')
        SetEntityCoords(PlayerPedId(), Apartments.Locations[house].coords.enter.x, Apartments.Locations[house].coords.enter.y,Apartments.Locations[house].coords.enter.z)
        SetEntityHeading(PlayerPedId(), Apartments.Locations[house].coords.enter.w)
        Wait(1000)
        TriggerServerEvent("apartments:server:RemoveObject", CurrentApartment, house)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', CurrentApartment, false)
        CurrentApartment = nil
        InApartment = false
        CurrentOffset = 0
        DoScreenFadeIn(1000)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_close", 0.1)
        TriggerServerEvent("apartments:server:setCurrentApartment", nil)

        DeleteInApartmentTargets()
        DeleteApartmentsEntranceTargets()
    end)
end

local function SetClosestApartment()
    local pos = GetEntityCoords(PlayerPedId())
    local current = nil
    local dist = 100
    for id, _ in pairs(Apartments.Locations) do
        local distcheck = #(pos - vector3(Apartments.Locations[id].coords.enter.x, Apartments.Locations[id].coords.enter.y, Apartments.Locations[id].coords.enter.z))
        if distcheck < dist then
            current = id
        end
    end
    if current ~= ClosestHouse and LocalPlayer.state.isLoggedIn and not InApartment then
        ClosestHouse = current
        QBCore.Functions.TriggerCallback('apartments:IsOwner', function(result)
            IsOwned = result
            DeleteApartmentsEntranceTargets()
            DeleteInApartmentTargets()
        end, ClosestHouse)
    end
end

-- Event Handlers

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if HouseObj ~= nil then
            exports['qb-interior']:DespawnInterior(HouseObj, function()
                CurrentApartment = nil
                TriggerEvent('qb-weathersync:client:EnableSync')
                DoScreenFadeIn(500)
                while not IsScreenFadedOut() do
                    Wait(10)
                end
                SetEntityCoords(PlayerPedId(), Apartments.Locations[ClosestHouse].coords.enter.x, Apartments.Locations[ClosestHouse].coords.enter.y,Apartments.Locations[ClosestHouse].coords.enter.z)
                SetEntityHeading(PlayerPedId(), Apartments.Locations[ClosestHouse].coords.enter.w)
                Wait(1000)
                InApartment = false
                DoScreenFadeIn(1000)
            end)
        end

        DeleteApartmentsEntranceTargets()
        DeleteInApartmentTargets()
    end
end)


-- Events

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    CurrentApartment = nil
    InApartment = false
    CurrentOffset = 0

    DeleteApartmentsEntranceTargets()
    DeleteInApartmentTargets()
end)

RegisterNetEvent('apartments:client:setupSpawnUI', function(cData)
    QBCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result then
            TriggerEvent('qb-spawn:client:setupSpawns', cData, false, nil)
            TriggerEvent('qb-spawn:client:openUI', true)
           -- TriggerEvent("apartments:client:SetHomeBlip", result.type)
        else
            if Apartments.Starting then
                TriggerEvent('qb-spawn:client:setupSpawns', cData, true, Apartments.Locations)
                TriggerEvent('qb-spawn:client:openUI', true)
            else
                TriggerEvent('qb-spawn:client:setupSpawns', cData, false, nil)
                TriggerEvent('qb-spawn:client:openUI', true)
            end
        end
    end, cData.citizenid)
end)

RegisterNetEvent('apartments:client:SpawnInApartment', function(apartmentId, apartment)
    local pos = GetEntityCoords(PlayerPedId())
    if RangDoorbell ~= nil then
        local doorbelldist = #(pos - vector3(Apartments.Locations[RangDoorbell].coords.enter.x, Apartments.Locations[RangDoorbell].coords.enter.y,Apartments.Locations[RangDoorbell].coords.enter.z))
        if doorbelldist > 5 then
            QBCore.Functions.Notify("Terlalu Jauh Dari Pintu")
            return
        end
    end
    ClosestHouse = apartment
    EnterApartment(apartment, apartmentId, true)
    IsOwned = true
end)

RegisterNetEvent('qb-apartments:client:LastLocationHouse', function(apartmentType, apartmentId)
    ClosestHouse = apartmentType
    EnterApartment(apartmentType, apartmentId, false)
end)
RegisterNetEvent('apartments:client:RingMenu', function(data)
    RangDoorbell = ClosestHouse
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "doorbell", 0.1)
    TriggerServerEvent("apartments:server:RingDoor", data.apartmentId, ClosestHouse)
end)

RegisterNetEvent('apartments:client:RingDoor', function(player, _)
    CurrentDoorBell = player
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "doorbell", 0.1)
    QBCore.Functions.Notify("Ada Orang Di pintu")
end)

RegisterNetEvent('apartments:client:DoorbellMenu', function()
    MenuOwners()
end)

RegisterNetEvent('apartments:client:EnterApartment', function()
    QBCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result ~= nil then
            EnterApartment(ClosestHouse, result.name)
        end
    end)
end)

RegisterNetEvent('apartments:client:OpenDoor', function()
    if CurrentDoorBell == 0 then
        QBCore.Functions.Notify("Tidak Ada Orang Di pintu")
        return
    end
    TriggerServerEvent("apartments:server:OpenDoor", CurrentDoorBell, CurrentApartment, ClosestHouse)
    CurrentDoorBell = 0
end)

RegisterNetEvent('apartments:client:LeaveApartment', function()
    LeaveApartment(ClosestHouse)
end)

RegisterNetEvent('apartments:client:OpenStash', function()
    if CurrentApartment ~= nil then
        TriggerServerEvent("inventory:server:OpenInventory", "stash", CurrentApartment, {
            maxweight = Apartments.penyimpankilo,
            slots = Apartments.penyimpanslot,
        })
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "StashOpen", 0.4)
        TriggerEvent("inventory:client:SetCurrentStash", CurrentApartment)
    end
end)

RegisterNetEvent('apartments:client:ChangeOutfit', function()
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "Clothes1", 0.4)
    TriggerEvent('qb-clothing:client:openOutfitMenu')
end)

RegisterNetEvent('apartments:client:Logout', function()
    TriggerServerEvent('qb-houses:server:LogoutLocation')
end)


-- Threads

CreateThread(function ()
    local sleep = 5000
    while not LocalPlayer.state.isLoggedIn do
        -- do nothing
        Wait(sleep)
    end

    while true do
        sleep = 1000

        if not InApartment then
            SetClosestApartment()
        elseif InApartment then
            sleep = 0

            SetInApartmentTargets()

            if IsInsideStashZone then
                if IsControlJustPressed(0, 38) then
                    TriggerEvent('apartments:client:OpenStash')
                    exports['qb-core']:HideText()
                end
            end

            if IsInsideOutfitsZone then
                if IsControlJustPressed(0, 38) then
                    TriggerEvent('apartments:client:ChangeOutfit')
                    exports['qb-core']:HideText()
                end
            end
        end

        Wait(sleep)
    end
end)

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

RegisterNetEvent('open:apartmenu', function()
    --local function ShowEntranceHeaderMenu()
        local headerMenu = {}
        if IsOwned then
            headerMenu[#headerMenu+1] = {
                title = 'Masuk Apartment',
                icon = 'fa fa-mail-forward',
                event = 'apartments:client:EnterApartment',
                args = {}
            }
         elseif not IsOwned then
            headerMenu[#headerMenu+1] = {
                icon = "fas fa-house",
                title = "Beli Apartment Seharga "..Apartments.Hargabeli,
                description = "Harga Sewa Permingu "..Apartments.Hargasewa,
                event = 'client:test:buyapart',
                args = {}
                
            }
        end
    if IsOwned then
        headerMenu[#headerMenu+1] = {
            title = "Berhenti Sewa Apartment",
            icon = "fa fa-close",
            description = "Semua Barang Yang Di dalam Apartment Akan Di Buang",
            event = 'client:test:sellapart',
            args = {}
            
        }
    end
        headerMenu[#headerMenu+1] = {
            title = "Ring Door Bell",
            icon = "fa fa-bell",
            event = 'apartments:client:DoorbellMenu',
            args = {}
            
        }
        lib.registerContext({
            id = 'apart1_menu',
            title = 'Apartment',
            onExit = function()
            --    print('Hello there')
            end,
            options = headerMenu
        })
        lib.showContext('apart1_menu')
    end)
    
    
    RegisterNetEvent('close:apartmenu', function()
        local headerMenu = {}
    
        headerMenu[#headerMenu+1] = {
            title = "Buka Pintu",
            icon = "fa fa-male",
            event = 'apartments:client:OpenDoor',
            args = {}
            
        }
    
        headerMenu[#headerMenu+1] = {
            title = "Keluar Apart",
            icon = "fa fa-mail-reply",
            event = 'apartments:client:LeaveApartment',
            args = {}
            
        }
    
        lib.registerContext({
            id = 'apart2_menu',
            title = 'Apartment',
            onExit = function()
            --    print('Hello there')
            end,
            options = headerMenu
        })
        lib.showContext('apart2_menu')
    end)

function MenuOwners()
    QBCore.Functions.TriggerCallback('apartments:GetAvailableApartments', function(apartments)
        if next(apartments) == nil then
            QBCore.Functions.Notify("Tidak Ada Orang", "error", 3500)
        else
            local apartmentMenu = {}

            for k, v in pairs(apartments) do
                apartmentMenu[#apartmentMenu+1] = {
                    title = v,
                    description = "",
                    params = {
                        event = "apartments:client:RingMenu",
                        args = {
                            apartmentId = k
                        }
                    }

                }
            end

            apartmentMenu[#apartmentMenu+1] = {
                title = "Close",
                description = "",

            }
            lib.registerContext({
                id = 'apart3_menu',
                title = 'Apartment',
                onExit = function()
                --    print('Hello there')
                end,
                options = headerMenu
            })
            lib.showContext('apart3_menu')
        end
    end, ClosestHouse)
end

RegisterNetEvent('apartments:client:UpdateApartment', function()
    local apartmentType = ClosestHouse
    local apartmentLabel = Apartments.Locations[ClosestHouse].label
    TriggerServerEvent("apartments:server:UpdateApartment", apartmentType, apartmentLabel)
    IsOwned = true

    DeleteApartmentsEntranceTargets()
    DeleteInApartmentTargets()
end)


local function beliapartanim()
    loadAnimDict("timetable@jimmy@doorknock@")
    TaskPlayAnim( PlayerPedId(), "timetable@jimmy@doorknock@", "knockdoor_idle", 5.0, 1.0, -1, 16, 0, 0, 0, 0 )
    ClearPedTasks(PlayerPedId())
end


RegisterNetEvent('client:test:buyapart', function()
  --  local orang = QBCore.Functions.GetPlayerData()
    local apartmentType = ClosestHouse
    local appaYeet = Apartments.Locations[ClosestHouse].label
    --print(appaYeet)
    beliapartanim()
    Wait(4000)
    TriggerServerEvent("server:test:buyapart", apartmentType, appaYeet)
    IsOwned = true
end)

RegisterNetEvent('client:test:sellapart', function()
   -- local orang = QBCore.Functions.GetPlayerData()
    local typeapart = 'apartment1'
    TriggerServerEvent("server:test:sellapart", typeapart)
    IsOwned = false
end)

CreateThread(function()
    exports.ox_target:addSphereZone({
        coords = Apartments.entertarget,
        radius = 1,
        debug = drawZones,
        options = {
            {
                name = 'EnterApartment',
                event = "open:apartmenu",
				icon = "fa fa-house",
				label = "Apartement",
                canInteract = function(entity, distance, coords, name)
                    return true
                end
            }
        }
    })
    exports.ox_target:addSphereZone({
        coords = Apartments.outtarget,
        radius = 1,
        debug = drawZones,
        options = {
            {
                name = 'KeluarApartment',
                event = "close:apartmenu",
				icon = "fa fa-house",
				label = "Apartement",
                canInteract = function(entity, distance, coords, name)
                    return true
                end
            }
        }
    })

end)