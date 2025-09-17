VERSION = "1.3"

local MAP_DATA = {
    ObjectList = {},
    CameraInfo = {
        P = {
            x = 0, --set to Player Position
            y = 0,
            z = 0
        },
        R = {
            x = 0,
            y = 0,
            z = 0
        },
        S = {
            x = 0.0,
            y = 0.0,
            z = 0.0
        },
        N = "",
        I = {
            IsStatic = false,
            CanCollide = false,
            IsVisible = false,
            DisplayName = "",
            CustomTexture = "",
            CustomModel = false,
            CustomWeight = 0.0
        }
    },
    SpawnpointInfo = {
        P = {
            x = 0.0,
            y = 0.0,
            z = 0.0
        },
        R = {
            x = 0.0,
            y = 0.0,
            z = 0.0
        },
        S = {
            x = 1.0,
            y = 1.0,
            z = 1.0
        },
        N = "",
        I = {
            IsStatic = false,
            CanCollide = false,
            IsVisible = false,
            DisplayName = "",
            CustomTexture = "",
            CustomModel = false,
            CustomWeight = 0.0
        }
    },
    Name = "sprinkleTool",
    PrettyPrint = false,
    Version = "1.3"
}

local spawnedGroups = {
    --"groupId" = {obj1, obj2, obj3...},
    --"groupId2" = {obj1, obj2, ....}, ...
}

local customTextures = {}
local customMeshes = {}

local success, settings = pcall(function() return json.parse(tm.os.ReadAllText_Dynamic("settings.json")) end)
if not success then
    settings = {
        spawnsPerUpdate = 100,
        defaultObject = "PFB_PalmFern_Medium",
    }
    tm.os.Log("Settings file not found -> Creating new file")
    local jsonString = json.serialize(settings)
    jsonString = string.gsub(jsonString, "(%d+),(%d+)", "%1.%2")
    tm.os.WriteAllText_Dynamic("settings.json", jsonString)
end

local success, objectGroups = pcall(function() return json.parse(tm.os.ReadAllText_Dynamic("objectGroups.json")) end)
if not success then
    objectGroups = {}
    tm.os.Log("Object Table file not found -> Creating new file")
    local jsonString = json.serialize(objectGroups)
    jsonString = string.gsub(jsonString, "(%d+),(%d+)", "%1.%2")
    tm.os.WriteAllText_Dynamic("objectGroups.json", jsonString)
end

local newObjectTemplate = {
    name = settings.defaultObject,
    prefab = true, -- true = prefab, false = custom object
    likeliness = 1,
    offset = {
        x = 0,
        y = 0,
        z = 0
    },
    scaleSeperate = true, -- true = seperate scale, false = uniform scale
    minScale = {
        x = 1,
        y = 1,
        z = 1
    },
    maxScale = {
        x = 1,
        y = 1,
        z = 1
    }
}

local playerUIData = {}
---------Common UI Elements---------
local btnReturn = "<b><color=#69d9d8>↩️ Return </color></b>"
local colors = {
    dark_green = "<color=" .. "#113537" .. ">",
    blue = "<color=" .. "#8CA0D7" .. ">",
    orange = "<color=" .. "#E87461" .. ">",
    yellow = "<color=" .. "#D0D38F" .. ">",
    teal = "<color=" .. "#B4EDD2" .. ">",
    purple = "<color=" .. "#A06CD5" .. ">",
}

--#region Functions
---------------------------------------------------- Functions ---------------------------------------------------

local function exportAllGroups(playerId)
    local mapData = {
        ObjectList = {},
        CameraInfo = MAP_DATA.CameraInfo,
        SpawnpointInfo = MAP_DATA.SpawnpointInfo,
        Name = MAP_DATA.Name,
        PrettyPrint = MAP_DATA.PrettyPrint,
        Version = MAP_DATA.Version
    }
    if not next(spawnedGroups) then
        tm.playerUI.AddSubtleMessageForPlayer(playerId, "No objects to export", "Spawn some objects first", 5)
        return
    end
    for i, group in pairs(spawnedGroups) do
        for j, object in ipairs(group) do
            tm.os.Log("adding: " .. object.name .. " to export data.")

            local objReference = object.objectReference

            local objTransform = objReference.GetTransform()
            local objPos = objTransform.GetPosition()
            local objRotation = objTransform.GetRotation()
            local objScale = objTransform.GetScale()

            table.insert(mapData.ObjectList, {
                P = {
                    x = objPos.x,
                    y = objPos.y - 300, --offset because of Trailmappers
                    z = objPos.z
                },
                R = {
                    x = objRotation.x,
                    y = objRotation.y,
                    z = objRotation.z
                },
                S = {
                    x = objScale.x,
                    y = objScale.y,
                    z = objScale.z
                },
                N = object.name,
                I = {
                    IsStatic = objReference.GetIsStatic(),
                    CanCollide = true,
                    IsVisible = objReference.GetIsVisible(),
                    DisplayName = "Sprinkle Tool Object",
                    CustomTexture = object.prefab and "" or "\\Custom Models\\" .. object.texture,
                    CustomModel = object.prefab and object.name or "\\Custom Models\\" .. object.name,
                    CustomWeight = 0.0
                }
            })
        end
    end
    local jsonString = json.serialize(mapData)
    jsonString = string.gsub(jsonString, "(%d+),(%d+)", "%1.%2")

    local timeStamp = os.date("%d-%m-%Y_%H%M%S")

    tm.os.WriteAllText_Dynamic("exportedMap" .. timeStamp .. ".json", jsonString)
    tm.playerUI.AddSubtleMessageForPlayer(playerId, "Exported Map as:",
        "exportedMap" .. timeStamp .. ".json", 10)
    tm.os.Log("Exported as exportedMap" .. timeStamp .. ".json")
end

local function prepareWeightedTable(objects)
    local cumulative = {}
    local total = 0
    for i, obj in ipairs(objects) do
        total = total + obj.likeliness
        cumulative[i] = total
    end
    return cumulative, total
end

-- Binary search to find index
local function binarySearch(cumulative, value)
    local low, high = 1, #cumulative
    while low < high do
        local mid = math.floor((low + high) / 2)
        if value <= cumulative[mid] then
            high = mid
        else
            low = mid + 1
        end
    end
    return low
end

local function weightedRandom(objects, cumulative, total)
    local r = math.random() * total
    local index = binarySearch(cumulative, r)
    return objects[index]
end

local function loadHeatmap(path)
    if path == nil or path == "" then
        tm.os.Log("No heatmap path provided")
        return nil
    end

    local success, parsedData = pcall(function() return json.parse(tm.os.ReadAllText_Static(path)) end)
    if not success then
        tm.os.Log("Failed to read heatmap file: " .. path)
        return nil
    end
    tm.os.Log("Heatmap file read successfully: " .. path)
    return parsedData
end

local function prepareObject(object) --returns scale and rotation
    local scale
    if object.scaleSeperate then
        scale = tm.vector3.Create(
            math.random(object.minScale.x * 100, object.maxScale.x * 100) / 100,
            math.random(object.minScale.y * 100, object.maxScale.y * 100) / 100,
            math.random(object.minScale.z * 100, object.maxScale.z * 100) / 100
        )
    else
        local scaleMultiplyier = math.random(object.minScale * 100, object.maxScale * 100) / 100
        --multiply object scale by scale value to get a uniform scale
        scale = tm.vector3.Create(
            object.scale.x * scaleMultiplyier,
            object.scale.y * scaleMultiplyier,
            object.scale.z * scaleMultiplyier
        )
    end

    local rotation = tm.vector3.Create(0, math.random(0, 360), 0)

    if not object.prefab then
        if not Table_contains(customTextures, object.texture) then
            tm.physics.AddTexture(object.texture, object.texture)
            table.insert(customTextures, object.texture)
        end
        if not Table_contains(customMeshes, object.name) then
            tm.physics.AddMesh(object.name, object.name)
            table.insert(customMeshes, object.name)
        end
    end

    return scale, rotation
end

local function spawnObject(object, position)
    local scale, rotation = prepareObject(object)
    local objectReference

    if object.prefab then
        objectReference = tm.physics.SpawnObject(position, object.name)
    else
        objectReference = tm.physics.SpawnCustomObjectConcave(position, object.name, object.texture)
    end

    local objectTransform = objectReference.GetTransform()
    objectTransform.SetRotation(rotation)
    objectTransform.SetScale(scale)
    tm.os.Log("Spawned Object: " .. object.name)
    return { objectReference = objectReference, name = object.name, prefab = object.prefab }
end

local function spawnGroup(group, amount)
    tm.os.Log("amount to spawn: " .. amount)
    local objects = group.objects
    local groupPos = group.position
    local groupSize = group.size

    local maxSpawnPosX, minSpawnPosX = groupPos.x + (groupSize.x / 2), groupPos.x - (groupSize.x / 2)
    local maxSpawnPosZ, minSpawnPosZ = groupPos.z + (groupSize.z / 2), groupPos.z - (groupSize.z / 2)

    local cumulative, total = prepareWeightedTable(objects)

    local heatmap = loadHeatmap(group.heatmapPath)
    tm.os.Log("using heatmap: " .. tostring(heatmap ~= nil))

    if spawnedGroups[group.groupId] == nil then
        spawnedGroups[group.groupId] = {}
    end

    local i = 0
    while i < amount do
        local raycastPos = tm.vector3.Create(
            math.random(minSpawnPosX, maxSpawnPosX),
            groupPos.y,
            math.random(minSpawnPosZ, maxSpawnPosZ)
        )

        local raycast = tm.physics.RaycastData(raycastPos, tm.vector3.Down(), 1000, true)

        if raycast.DidHit() then
            local hitPos = raycast.GetHitPosition()
            if heatmap ~= nil then
                local hitIndex_X = math.max(1,
                    math.min(heatmap.width, math.floor(((hitPos.x - minSpawnPosX) / groupSize.x) * heatmap.width)))
                local hitIndex_Y = math.max(1,
                    math.min(heatmap.height, math.floor(((hitPos.z - minSpawnPosZ) / groupSize.z) * heatmap.height)))

                local randomValue = math.random()

                tm.os.Log("hitIndex_X: " .. hitIndex_X .. ", hitIndex_Y: " .. hitIndex_Y .. ", heatmap value: " ..
                    heatmap.data[hitIndex_X][hitIndex_Y] .. ", randomValue: " .. randomValue)

                if heatmap.data[hitIndex_X][hitIndex_Y] < randomValue then
                    tm.os.Log("hitpos rejected by heatmap")
                    goto continue
                end
            end

            i = i + 1
            local randomObj = weightedRandom(objects, cumulative, total)
            table.insert(spawnedGroups[group.groupId], spawnObject(randomObj, hitPos))
            tm.os.Log(i)
            if i % settings.spawnsPerUpdate == 0 then
                tm.os.Log("yielding spawning")
                coroutine.yield(i)
            end
        end
        ::continue::
    end
end

local function despawnGroup(groupId)
    local spawnedGroupsGroup = spawnedGroups[groupId] or {}
    tm.os.Log("amount to despawn: " .. #spawnedGroupsGroup)
    for i, obj in ipairs(spawnedGroupsGroup) do
        local objectReference = obj.objectReference
        local success, err = pcall(function() return objectReference.Despawn() end)
        if not success then
            tm.os.Log("Failed to despawn object: " .. err)
        end
        obj = nil
        tm.os.Log(i)
        if i % settings.spawnsPerUpdate == 0 then
            tm.os.Log("yielding despawn")
            coroutine.yield(i)
        end
    end
    spawnedGroups[groupId] = {}
end

local function showGroupPreview(playerId, group)
    local data = playerUIData[playerId]

    if data.groupVisualization ~= nil then
        data.groupVisualization.Despawn()
    end
    --spawn TriggerBox to visualize Group Area
    local groupPos = tm.vector3.Create(group.position.x, group.position.y, group.position.z)
    local groupScale = tm.vector3.Create(group.size.x, 5, group.size.z)
    data.groupVisualization = tm.physics.SpawnBoxTrigger(groupPos, groupScale)
    data.groupVisualization.SetIsVisible(true)
end


function Table_contains(tbl, x)
    for key, value in pairs(tbl) do
        if value == x then
            return true
        end
    end
    return false
end

--#endregion Functions

--#region UI
------------------------------------------------------- UI -------------------------------------------------------

local function drawUI_StartMenu(playerId)
    tm.playerUI.AddUILabel(playerId, "lbldividerSmall1", "~- Main Menu -~")
    tm.playerUI.AddUIButton(playerId, "btnGroupList", colors.yellow .. "Group List" .. "</color>",
        function() UpdateUI(playerId, "groupList") end)

    local hasSpawnedGroups = next(spawnedGroups) ~= nil
    local color = hasSpawnedGroups and colors.dark_green or colors.orange
    tm.playerUI.AddUIButton(playerId, "btnExportAll", color .. "Export All Groups" .. "</color>",
        function() exportAllGroups(playerId) end)

    tm.playerUI.AddUIButton(playerId, "btnSettings", colors.teal .. "Settings" .. "</color>",
        function() UpdateUI(playerId, "settings") end)

    tm.playerUI.AddUILabel(playerId, "lbldividerSmall1", "~- * -~")

    tm.playerUI.AddUIButton(playerId, "btnAbout", colors.purple .. "About" .. "</color>",
        function() UpdateUI(playerId, "about") end)
    tm.playerUI.AddUILabel(playerId, "lblCredit", "<color=#BEAED5>by Blockhampter</color>")
end

local function drawUI_About(playerId)
    tm.playerUI.AddUIButton(playerId, "btnReturn", btnReturn, function() UpdateUI(playerId, "startMenu") end)

    tm.playerUI.AddUILabel(playerId, "lblAbout1", "Sprinkle Tool ".. VERSION)
    tm.playerUI.AddUILabel(playerId, "lblAbout3", "This mod is in 'active'")
    tm.playerUI.AddUILabel(playerId, "lblAbout4", "development. Please feel")
    tm.playerUI.AddUILabel(playerId, "lblAbout5", "invited to give me feedback")
    tm.playerUI.AddUILabel(playerId, "lblAbout6", "and suggestions for new features.")
    tm.playerUI.AddUILabel(playerId, "lblAbout7", "You can reach me on Discord")
    tm.playerUI.AddUILabel(playerId, "lblAbout8", "under the username:")
    tm.playerUI.AddUILabel(playerId, "lblAbout9", "<color=#BEAED5><i>blockhampter</i></color>")
    tm.playerUI.AddUILabel(playerId, "lblAbout10", "I hope you enjoy using this mod!")
    tm.playerUI.AddUILabel(playerId, "lblCredit", ":D")


end

local function drawUI_Settings(playerId)
    tm.playerUI.AddUIButton(playerId, "btnReturn", btnReturn, function()
        UpdateUI(playerId, "startMenu")
    end)

    tm.playerUI.AddUILabel(playerId, "lblSpawnsPerUpdate", "Spawns/Despawns per update")
    tm.playerUI.AddUIText(playerId, "txtSpawnsPerUpdate", settings.spawnsPerUpdate, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil or tonumber(UICallbackData.value) < 1 then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Value must be a number > 0", 5)
            return
        end
        settings.spawnsPerUpdate = tonumber(UICallbackData.value)
        tm.os.Log("Spawns/Despawns per update set to: " .. settings.spawnsPerUpdate)
    end)

    tm.playerUI.AddUILabel(playerId, "lblDefaultObject", "Default Object for new objects")
    tm.playerUI.AddUIText(playerId, "txtDefaultObject", settings.defaultObject, function(UICallbackData)
        if tostring(UICallbackData.value) == "" or UICallbackData.value == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Name", "Name cannot be empty", 5)
            return
        end
        settings.defaultObject = UICallbackData.value
        newObjectTemplate.name = settings.defaultObject
        tm.os.Log("Default Object set to: " .. settings.defaultObject)
    end)
    tm.playerUI.AddUIButton(playerId, "btnSaveSettings", "Save Settings", function()
        tm.os.Log("Saving settings")
        local jsonString = json.serialize(settings)
        jsonString = string.gsub(jsonString, "(%d+),(%d+)", "%1.%2")
        tm.os.WriteAllText_Dynamic("settings.json", jsonString)
        tm.playerUI.AddSubtleMessageForPlayer(playerId, "Settings saved", "settings.json", 5)
    end)
end

local function drawUI_GroupList(playerId, data)
    local focusedGroupElement = data.focusedGroupElement or nil

    tm.playerUI.AddUIButton(playerId, "btnReturn", btnReturn, function()
        data.focusedGroupElement = nil
        data.focusedObjectElement = nil
        UpdateUI(playerId, "startMenu")
    end)

    tm.playerUI.AddUILabel(playerId, "lbldividerSmall1", "~- Groups -~")

    for i, group in ipairs(objectGroups) do
        tm.playerUI.AddUIButton(playerId, "btnGroup_" .. i, colors.yellow .. group.name .. "</color>",
            function()
                data.focusedGroupElement = i ~= focusedGroupElement and i or nil
                tm.os.Log("Focused group element: " .. tostring(data.focusedGroupElement))
                UpdateUI(playerId, "groupList")
            end)
        if i == focusedGroupElement then
            -- Btn Object List
            tm.playerUI.AddUIButton(playerId, "btnObjectList", "Object List", function()
                UpdateUI(playerId, "objectList")
            end)
            --Btn Spawn Group
            tm.playerUI.AddUIButton(playerId, "btnSpawnGroup_" .. i, "Spawn", function()
                UpdateUI(playerId, "spawnGroup")
            end)
            --Btn Edit Group
            tm.playerUI.AddUIButton(playerId, "btnEditGroup_" .. i, "Edit",
                function() UpdateUI(playerId, "editGroup") end)
            --Btn Delete Group
            tm.playerUI.AddUIButton(playerId, "btnDeleteGroup_" .. i, "Delete", function()
                table.remove(objectGroups, i) --to be changed out with a call to a function that deletes the group and all objects in it
                UpdateUI(playerId, "groupList")
            end)
        end
    end

    tm.playerUI.AddUILabel(playerId, "lbldividerSmall2", "~- * -~")

    tm.playerUI.AddUIButton(playerId, "btnAddGroup", "Add Group", function()
        local newGroupName = "New Group" .. " " .. (#objectGroups + 1)
        local groupId = tostring(tm.os.GetRealtimeSinceStartup()) .. "_" .. tostring(math.random(1000, 9999))
        local playerPos = tm.players.GetPlayerTransform(playerId).GetPosition()
        table.insert(objectGroups, {
            name = newGroupName,
            groupId = groupId,
            position = {
                x = playerPos.x,
                y = playerPos.y,
                z = playerPos.z
            },
            size = {
                x = 100,
                z = 100
            },
            objects = {}
        })
        UpdateUI(playerId, "groupList")
    end)
end

local function drawUI_EditGroup(playerId, data)
    local focusedGroupElement = data.focusedGroupElement or nil
    local group = objectGroups[focusedGroupElement]

    if focusedGroupElement == nil then
        UpdateUI(playerId, "groupList")
        return
    end


    tm.playerUI.AddUIButton(playerId, "btnReturn", "Save", function()
        UpdateUI(playerId, "groupList")
        tm.os.Log("Saving groups")
        tm.os.WriteAllText_Dynamic("objectGroups.json", json.serialize(objectGroups))
    end)

    tm.playerUI.AddUIText(playerId, "txtGroupName", group.name, function(UICallbackData)
        if tostring(UICallbackData.value) == "" or UICallbackData.value == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Name", "Name cannot be empty", 5)
            return
        end
        group.name = UICallbackData.value
    end)

    tm.playerUI.AddUILabel(playerId, "lblHeatmap", "Heatmap Path (optional)")
    tm.playerUI.AddUIText(playerId, "txtHeatmapPath", group.heatmapPath or "", function(UICallbackData)
        if tostring(UICallbackData.value) == "" or UICallbackData.value == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Heatmap disabled", "Heatmap field is empty", 5)
        end
        group.heatmapPath = UICallbackData.value
    end)

    tm.playerUI.AddUILabel(playerId, "lblPosition", "Position (x, y, z)")

    tm.playerUI.AddUIButton(playerId, "btnSetPosToPlayer", "Set to Player Position", function()
        local playerPos = tm.players.GetPlayerTransform(playerId).GetPosition()
        group.position.x = playerPos.x
        group.position.y = playerPos.y
        group.position.z = playerPos.z
        UpdateUI(playerId, "editGroup")
    end)

    tm.playerUI.AddUIText(playerId, "txtPosX", group.position.x, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Position must be a number", 5)
            return
        end
        group.position.x = tonumber(UICallbackData.value)
        showGroupPreview(playerId, group)
    end)
    tm.playerUI.AddUIText(playerId, "txtPosY", group.position.y, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Position must be a number", 5)
            return
        end
        group.position.y = tonumber(UICallbackData.value) or group.position.y
        showGroupPreview(playerId, group)
    end)
    tm.playerUI.AddUIText(playerId, "txtPosZ", group.position.z, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Position must be a number", 5)
            return
        end
        group.position.z = tonumber(UICallbackData.value) or group.position.z
        showGroupPreview(playerId, group)
    end)

    tm.playerUI.AddUILabel(playerId, "lblSize", "Size (x, z)")
    tm.playerUI.AddUIText(playerId, "txtSizeX", group.size.x or 1, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Size must be a number", 5)
            return
        end
        group.size.x = tonumber(UICallbackData.value)
        showGroupPreview(playerId, group)
    end)
    tm.playerUI.AddUIText(playerId, "txtSizeZ", group.size.z or 1, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Size must be a number", 5)
            return
        end
        group.size.z = tonumber(UICallbackData.value)
        showGroupPreview(playerId, group)
    end)
end


local function drawUI_ObjectList(playerId, data)
    tm.playerUI.AddUIButton(playerId, "btnReturn", btnReturn, function() UpdateUI(playerId, "groupList") end)

    local focusedGroupElement = data.focusedGroupElement or nil
    local focusedObjectElement = data.focusedObjectElement or nil
    if focusedGroupElement == nil then
        tm.os.Log("No group selected")
        UpdateUI(playerId, "groupList")
        return
    end
    local group = objectGroups[focusedGroupElement]

    tm.playerUI.AddUIButton(playerId, "btnHideShowGroupObjects" .. focusedGroupElement,
        (group.visible == true and "Hide" or "Show") .. " Objects", function()
            group.visible = not group
                .visible --to be changed out with a call to a function that toggles visibility and hides all objects in the group
            UpdateUI(playerId, "objectList")
        end)

    tm.playerUI.AddUILabel(playerId, "lbldividerSmall1", "~- Objects -~")

    for i, object in ipairs(group.objects) do
        tm.playerUI.AddUIButton(playerId, "btnObject_" .. i, colors.teal .. object.name .. "</color>",
            function()
                data.focusedObjectElement = i ~= focusedObjectElement and i or nil
                tm.os.Log("Focused group element: " .. tostring(data.focusedGroupElement))
                UpdateUI(playerId, "objectList")
            end)
        if i == focusedObjectElement then
            --Btn Edit Object
            tm.playerUI.AddUIButton(playerId, "btnEditObject_" .. i, "Edit",
                function() UpdateUI(playerId, "editObject") end)
            --Btn Delete Object
            tm.playerUI.AddUIButton(playerId, "btnDeleteObject_" .. i, "Delete", function()
                table.remove(group.objects, i) --to be changed out with a call to a function that deletes the group and all objects in it
                UpdateUI(playerId, "objectList")
            end)
        end
    end

    tm.playerUI.AddUILabel(playerId, "lbldividerSmall2", "~- * -~")

    -- Btn Add Object
    tm.playerUI.AddUIButton(playerId, "btnAddObject", "Add Object", function()
        local newObject = {
            name = newObjectTemplate.name,
            likeliness = newObjectTemplate.likeliness,
            prefab = newObjectTemplate.prefab,
            offset = {
                x = newObjectTemplate.offset.x,
                y = newObjectTemplate.offset.y,
                z = newObjectTemplate.offset.z
            },
            scaleSeperate = newObjectTemplate.scaleSeperate,
            minScale = {
                x = newObjectTemplate.minScale.x,
                y = newObjectTemplate.minScale.y,
                z = newObjectTemplate.minScale.z
            },
            maxScale = {
                x = newObjectTemplate.maxScale.x,
                y = newObjectTemplate.maxScale.y,
                z = newObjectTemplate.maxScale.z
            }
        }
        table.insert(group.objects, newObject)
        data.focusedObjectElement = #group.objects
        UpdateUI(playerId, "editObject")
    end)
end


local function drawUI_EditObject(playerId, data)
    local focusedGroupElement = data.focusedGroupElement or nil
    local focusedObjectElement = data.focusedObjectElement or nil

    if focusedGroupElement == nil or focusedObjectElement == nil then
        tm.os.Log("No group or object selected")
        UpdateUI(playerId, "objectList")
        return
    end

    tm.os.Log("Focused group element: " ..
        tostring(focusedGroupElement) .. ", focused object element: " .. tostring(focusedObjectElement))

    local group = objectGroups[focusedGroupElement]
    local object = group.objects[focusedObjectElement]

    tm.playerUI.AddUIButton(playerId, "btnReturn", "Save", function()
        UpdateUI(playerId, "objectList")
        tm.os.Log("Saving objects")
        tm.os.WriteAllText_Dynamic("objectGroups.json", json.serialize(objectGroups))
    end)

    tm.playerUI.AddUILabel(playerId, "lblObjectName", "Name:")
    tm.playerUI.AddUIText(playerId, "txtObjectName", object.name, function(UICallbackData)
        if tostring(UICallbackData.value) == "" or UICallbackData.value == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Name", "Name cannot be empty", 5)
            return
        end
        object.name = UICallbackData.value
    end)

    if not object.prefab then
        tm.playerUI.AddUIText(playerId, "txtObjectTexture", object.texture or "Texture.png", function(UICallbackData)
            if tostring(UICallbackData.value) == "" or UICallbackData.value == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Texture", "Texture cannot be empty", 5)
                return
            end
            object.texture = UICallbackData.value
        end)
    end

    tm.playerUI.AddUIButton(playerId, "btnObjectMode", "Object type: " ..
        (object.prefab == true and "Prefab" or "Custom"), function()
            object.prefab = not object.prefab
            UpdateUI(playerId, "editObject")
        end)

    tm.playerUI.AddUILabel(playerId, "lblLikeliness", "Likeliness")
    tm.playerUI.AddUILabel(playerId, "lblLikeliness2", "<size=10>how likely the object is to be spawned</size>")
    tm.playerUI.AddUIText(playerId, "txtLikeliness", object.likeliness, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Likeliness must be a number", 5)
            return
        end
        object.likeliness = tonumber(UICallbackData.value)
    end)

    tm.playerUI.AddUILabel(playerId, "lblOffset", "Offset (x, y, z):")
    tm.playerUI.AddUIText(playerId, "txtOffsetX", object.offset.x, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Offset must be a number", 5)
            return
        end
        object.offset.x = tonumber(UICallbackData.value)
    end)
    tm.playerUI.AddUIText(playerId, "txtOffsetY", object.offset.y, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Offset must be a number", 5)
            return
        end
        object.offset.y = tonumber(UICallbackData.value)
    end)
    tm.playerUI.AddUIText(playerId, "txtOffsetZ", object.offset.z, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Offset must be a number", 5)
            return
        end
        object.offset.z = tonumber(UICallbackData.value)
    end)

    tm.playerUI.AddUIButton(playerId, "btnScaleMode",
        "Scale mode: " .. (object.scaleSeperate == true and "Seperate" or "Uniform"), function(UICallbackData)
            object.scaleSeperate = not object.scaleSeperate
            if object.scaleSeperate then
                object.minScale = { x = 1, y = 1, z = 1 }
                object.maxScale = { x = 1, y = 1, z = 1 }
            else
                object.minScale = 1
                object.maxScale = 1
                object.scale = { x = 1, y = 1, z = 1 }
            end
            UpdateUI(playerId, "editObject")
        end)

    if object.scaleSeperate then
        tm.playerUI.AddUILabel(playerId, "lblMinScale", "Min Scale (x, y, z):")
        tm.playerUI.AddUIText(playerId, "txtMinScaleX", object.minScale.x, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.minScale.x = tonumber(UICallbackData.value)
        end)
        tm.playerUI.AddUIText(playerId, "txtMinScaleY", object.minScale.y, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.minScale.y = tonumber(UICallbackData.value)
        end)
        tm.playerUI.AddUIText(playerId, "txtMinScaleZ", object.minScale.z, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.minScale.z = tonumber(UICallbackData.value)
        end)

        tm.playerUI.AddUILabel(playerId, "lblMaxScale", "Max Scale (x, y, z):")
        tm.playerUI.AddUIText(playerId, "txtMaxScaleX", object.maxScale.x, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.maxScale.x = tonumber(UICallbackData.value)
        end)
        tm.playerUI.AddUIText(playerId, "txtMaxScaleY", object.maxScale.y, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.maxScale.y = tonumber(UICallbackData.value)
        end)
        tm.playerUI.AddUIText(playerId, "txtMaxScaleZ", object.maxScale.z, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.maxScale.z = tonumber(UICallbackData.value)
        end)
    else
        tm.playerUI.AddUILabel(playerId, "lblScale", "Scale multiplier (min, max):")
        tm.playerUI.AddUIText(playerId, "txtMinScale", object.minScale, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.minScale = tonumber(UICallbackData.value)
        end)
        tm.playerUI.AddUIText(playerId, "txtMaxScale", object.maxScale, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.maxScale = tonumber(UICallbackData.value)
        end)

        tm.playerUI.AddUILabel(playerId, "lblScale", "Scale (x, y, z):")
        tm.playerUI.AddUIText(playerId, "txtScaleX", object.scale.x, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.scale.x = tonumber(UICallbackData.value)
        end)
        tm.playerUI.AddUIText(playerId, "txtScaleY", object.scale.y, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.scale.y = tonumber(UICallbackData.value)
        end)
        tm.playerUI.AddUIText(playerId, "txtScaleZ", object.scale.z, function(UICallbackData)
            if tonumber(UICallbackData.value) == nil then
                tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Scale must be a number", 5)
                return
            end
            object.scale.z = tonumber(UICallbackData.value)
        end)
    end
end

local function drawUI_SpawnGroup(playerId, data)
    local focusedGroupElement = data.focusedGroupElement or nil

    if focusedGroupElement == nil then
        tm.os.Log("No group selected")
        UpdateUI(playerId, "groupList")
        return
    end

    local group = objectGroups[focusedGroupElement]

    tm.playerUI.AddUIButton(playerId, "btnReturn", btnReturn, function() UpdateUI(playerId, "groupList") end)

    tm.playerUI.AddUILabel(playerId, "lblSpawnGroup", "Spawn Group: " .. group.name)

    tm.playerUI.AddUILabel(playerId, "lblObjectsToSpawn", "Objects to spawn:")
    tm.playerUI.AddUIText(playerId, "txtObjectsToSpawn", data.amountToSpawn, function(UICallbackData)
        if tonumber(UICallbackData.value) == nil then
            tm.playerUI.AddSubtleMessageForPlayer(playerId, "Invalid Value", "Amount must be a number", 5)
            return
        end
        data.amountToSpawn = tonumber(UICallbackData.value)
    end)
    tm.playerUI.AddUIButton(playerId, "btnSpawnObjects", "Spawn Objects", function()
        local sprinkleGen = {
            action = "Spawning",
            amount = data.amountToSpawn,
            coroutine = coroutine.create(function()
                spawnGroup(group, data.amountToSpawn)
            end)
        }

        data.spawnMessageId = tm.playerUI.AddSubtleMessageForPlayer(playerId, "Spawning: " .. group.name,
            "0% of objects spawned", 1000000000)
        data.sprinkleGen = sprinkleGen
    end)
    tm.playerUI.AddUIButton(playerId, "btnDespawnObjects", "Despawn Objects", function()
        tm.os.Log("Despawning objects in group: " .. group.name)
        tm.os.Log("Amount of objects to despawn: " .. (#spawnedGroups[group.groupId] or 0))
        local sprinkleGen = {
            action = "Despawning",
            amount = #spawnedGroups[group.groupId],
            coroutine = coroutine.create(function()
                despawnGroup(group.groupId)
            end)
        }
        data.spawnMessageId = tm.playerUI.AddSubtleMessageForPlayer(playerId, "Despawning: " .. group.name,
            "0% of objects despawned", 1000000000)
        data.sprinkleGen = sprinkleGen
    end)
end

function UpdateUI(playerId, modeName)
    tm.os.Log("Updating UI: " .. modeName)
    local mode = {
        ["startMenu"] = function(playerId, data)
            drawUI_StartMenu(playerId)
        end,
        ["settings"] = function(playerId, data)
            drawUI_Settings(playerId)
        end,
        ["groupList"] = function(playerId, data)
            drawUI_GroupList(playerId, data)
        end,
        ["editGroup"] = function(playerId, data)
            drawUI_EditGroup(playerId, data)
        end,
        ["objectList"] = function(playerId, data)
            drawUI_ObjectList(playerId, data)
        end,
        ["editObject"] = function(playerId, data)
            drawUI_EditObject(playerId, data)
        end,
        ["spawnGroup"] = function(playerId, data)
            drawUI_SpawnGroup(playerId, data)
        end,
        ["about"] = function(playerId, data)
            drawUI_About(playerId)
        end
    }
    local uiData = playerUIData[playerId]

    if uiData.focusedGroupElement ~= nil then
        showGroupPreview(playerId, objectGroups[uiData.focusedGroupElement])
    else
        if uiData.groupVisualization ~= nil then
            uiData.groupVisualization.Despawn()
            uiData.groupVisualization = nil
        end
    end

    if mode[modeName] then
        playerUIData[playerId].uiMenu = modeName
        tm.playerUI.ClearUI(playerId)
        mode[modeName](playerId, uiData)
    else
        tm.os.Log("Invalid mode: " .. modeName)
    end
end

--#endregion UI

------------------------------------------------------- INIT -------------------------------------------------------


function update()
    for i, player in ipairs(tm.players.CurrentPlayers()) do
        local playerId = player.playerId
        local playerData = playerUIData[playerId]

        if playerData.sprinkleGen then
            --player is either spawning or despawning something
            local sprinkleGen = playerData.sprinkleGen

            local action = sprinkleGen.action -- "Spawning" or "Despawning"

            if coroutine.status(sprinkleGen.coroutine) ~= "dead" then
                local ok, index = coroutine.resume(sprinkleGen.coroutine)
                if ok then
                    if index == nil then
                        tm.os.Log("Fatal Flaw in coroutine")
                        break
                    end
                    tm.os.Log(action .. " progress: " .. index .. "/" .. sprinkleGen.amount)
                    tm.playerUI.SubtleMessageUpdateMessageForPlayer(playerId, playerData.spawnMessageId,
                        math.ceil((index / sprinkleGen.amount) * 100) .. "%")
                else
                    tm.os.Log("reached end or fatal Flaw")
                    tm.os.Log("Error: " .. index)
                end
            else
                tm.playerUI.RemoveSubtleMessageForPlayer(playerId, playerData.spawnMessageId)
                tm.playerUI.AddSubtleMessageForPlayer(playerId,
                    action .. " " .. objectGroups[playerData.focusedGroupElement].name .. " complete", "100%", 5)
                playerData.sprinkleGen = nil
                playerData.spawnMessageId = nil
            end
        end
    end
end

local function main()
    playerUIData[0] = {
        amountToSpawn = 100,
        uiMenu = "startMenu"
    }
    UpdateUI(0, "startMenu")
end
main()