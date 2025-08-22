local SPAWNS_PER_UPDATE = 100


local spawnedObjects = {}

local customTextures = {}
local customMeshes = {}

local success, objectGroups = pcall(function() return json.parse(tm.os.ReadAllText_Dynamic("objectGroups.json")) end)
if not success then
    objectGroups = {}
    tm.os.Log("Object Table file not found -> Creating new file")
    local jsonString = json.serialize(objectGroups)
    jsonString = string.gsub(jsonString, "(%d+),(%d+)", "%1.%2")
    tm.os.WriteAllText_Dynamic("objectGroups.json", jsonString)
end

local newObjectTemplate = {
    name = "PFB_PalmFern_Medium",
    prefab = true, -- true = prefab, false = custom object
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
    tm.os.Log("Spawned Object: "..object.name)
    return objectReference
end

local function spawnGroup(group, amount)
    tm.os.Log("amount to spawn: ".. amount)
    local objects = group.objects
    for i = 1, amount do

        table.insert(spawnedObjects, spawnObject(objects[math.random(1, #objects)], tm.vector3.Create(math.random(-1000, 1000), 300, math.random(-1000, 1000))))
        if i % SPAWNS_PER_UPDATE == 0 then
            tm.os.Log("yielding")
            coroutine.yield(i)
        end
    end
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
    tm.playerUI.AddUIButton(playerId, "btnGroupList", "Group List", function() UpdateUI(playerId, "groupList") end)
    tm.playerUI.AddUILabel(playerId, "lblCredit", "<color=#BEAED5>by Blockhampter</color>")
end

local function drawUI_GroupList(playerId, data)
    local focusedGroupElement = data.focusedGroupElement or nil

    tm.playerUI.AddUIButton(playerId, "btnReturn", btnReturn, function() UpdateUI(playerId, "startMenu") end)

    tm.playerUI.AddUILabel(playerId, "lbldividerSmall1", "~- Groups -~")

    for i, group in ipairs(objectGroups) do
        tm.playerUI.AddUIButton(playerId, "btnGroup_" .. i, colors.yellow .. group.name .. "</color>",
            function()
                data.focusedGroupElement = i ~= focusedGroupElement and i or nil
                tm.os.Log("Focused group element: " .. tostring(data.focusedGroupElement))
                UpdateUI(playerId, "groupList")
            end)
        if i == focusedGroupElement then
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
        table.insert(objectGroups, { name = newGroupName, objects = {} })
        UpdateUI(playerId, "groupList")
    end)
end

local function drawUI_EditGroup(playerId, data)
    local focusedGroupElement = data.focusedGroupElement or nil
    local group = objectGroups[focusedGroupElement]

    tm.playerUI.AddUIButton(playerId, "btnReturn", btnReturn, function() UpdateUI(playerId, "groupList") end)

    tm.playerUI.AddUIText(playerId, "txtGroupName", group.name, function(CallbackData)
        group.name = CallbackData.value
        UpdateUI(playerId, "editGroup")
    end)

    tm.playerUI.AddUIButton(playerId, "btnEnableDisabletHeatMap",
        (group.heatmapActive == true and "Disable" or "Enable") .. " Heatmap", function()
            group.heatmapActive = not group.heatmapActive
            UpdateUI(playerId, "editGroup")
        end)
    -- Btn Object List
    tm.playerUI.AddUIButton(playerId, "btnObjectList", "Objects", function()
        UpdateUI(playerId, "objectList")
    end)
end


local function drawUI_ObjectList(playerId, data)
    tm.playerUI.AddUIButton(playerId, "btnReturn", btnReturn, function() UpdateUI(playerId, "editGroup") end)

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
    tm.playerUI.AddUIText(playerId, "txtObjectName", object.name, function(CallbackData)
        object.name = CallbackData.value
        UpdateUI(playerId, "editObject")
    end)

    if not object.prefab then
        tm.playerUI.AddUIText(playerId, "txtObjectTexture", object.texture or "Texture.png", function(CallbackData)
            object.texture = CallbackData.value
            UpdateUI(playerId, "editObject")
        end)
    end

    tm.playerUI.AddUIButton(playerId, "btnObjectMode", "Object type: " ..
        (object.prefab == true and "Prefab" or "Custom"), function()
            object.prefab = not object.prefab
            UpdateUI(playerId, "editObject")
        end)


    tm.playerUI.AddUILabel(playerId, "lblOffset", "Offset (x, y, z) :")
    tm.playerUI.AddUIText(playerId, "txtOffsetX", object.offset.x, function(UICallbackData)
        object.offset.x = tonumber(UICallbackData.value) or 0
        UpdateUI(playerId, "editObject")
    end)
    tm.playerUI.AddUIText(playerId, "txtOffsetY", object.offset.y, function(UICallbackData)
        object.offset.y = tonumber(UICallbackData.value) or 0
        UpdateUI(playerId, "editObject")
    end)
    tm.playerUI.AddUIText(playerId, "txtOffsetZ", object.offset.z, function(UICallbackData)
        object.offset.z = tonumber(UICallbackData.value) or 0
        UpdateUI(playerId, "editObject")
    end)

    tm.playerUI.AddUIButton(playerId, "btnScaleMode",
        "Scale mode: " .. (object.scaleSeperate == true and "Seperate" or "Uniform"), function(CallbackData)
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
        tm.playerUI.AddUILabel(playerId, "lblMinScale", "Min Scale (x, y, z) :")
        tm.playerUI.AddUIText(playerId, "txtMinScaleX", object.minScale.x, function(UICallbackData)
            object.minScale.x = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)
        tm.playerUI.AddUIText(playerId, "txtMinScaleY", object.minScale.y, function(UICallbackData)
            object.minScale.y = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)
        tm.playerUI.AddUIText(playerId, "txtMinScaleZ", object.minScale.z, function(UICallbackData)
            object.minScale.z = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)

        tm.playerUI.AddUILabel(playerId, "lblMaxScale", "Max Scale (x, y, z) :")
        tm.playerUI.AddUIText(playerId, "txtMaxScaleX", object.maxScale.x, function(UICallbackData)
            object.maxScale.x = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)
        tm.playerUI.AddUIText(playerId, "txtMaxScaleY", object.maxScale.y, function(UICallbackData)
            object.maxScale.y = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)
        tm.playerUI.AddUIText(playerId, "txtMaxScaleZ", object.maxScale.z, function(UICallbackData)
            object.maxScale.z = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)
    else
        tm.playerUI.AddUILabel(playerId, "lblScale", "Scale multiplier (min, max) :")
        tm.playerUI.AddUIText(playerId, "txtMinScale", object.minScale, function(UICallbackData)
            object.minScale = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)
        tm.playerUI.AddUIText(playerId, "txtMaxScale", object.maxScale, function(UICallbackData)
            object.maxScale = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)

        tm.playerUI.AddUILabel(playerId, "lblScale", "Scale (x, y, z) :")
        tm.playerUI.AddUIText(playerId, "txtScaleX", object.scale.x, function(UICallbackData)
            object.scale.x = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)
        tm.playerUI.AddUIText(playerId, "txtScaleY", object.scale.y, function(UICallbackData)
            object.scale.y = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
        end)
        tm.playerUI.AddUIText(playerId, "txtScaleZ", object.scale.z, function(UICallbackData)
            object.scale.z = tonumber(UICallbackData.value) or 0
            UpdateUI(playerId, "editObject")
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
    tm.playerUI.AddUIText(playerId, "txtObjectsToSpawn", data.amountToSpawn or 100, function(CallbackData)
        data.amountToSpawn = tonumber(CallbackData.value) or 100
        UpdateUI(playerId, "spawnGroup")
    end)
    tm.playerUI.AddUIButton(playerId, "btnSpawnObjects", "Spawn Objects", function()
        -- create coroutine and save at data.sprinkleGen
        data.spawnMessageId = tm.playerUI.AddSubtleMessageForPlayer(playerId, "Spawning: " .. group.name,
            "0% of objects spawned", 1000000000)
        data.sprinkleGen = coroutine.create(function()
            spawnGroup(group, data.amountToSpawn)
        end)
    end)
end

function UpdateUI(playerId, modeName)
    tm.os.Log("Updating UI: " .. modeName)
    local mode = {
        ["startMenu"] = function(playerId, data)
            drawUI_StartMenu(playerId)
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
        end
    }
    local uiData = playerUIData[playerId]

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
            local sprinkleGen = playerData.sprinkleGen
            if coroutine.status(sprinkleGen) ~= "dead" then
                local ok, index = coroutine.resume(sprinkleGen)
                if ok then
                    tm.playerUI.SubtleMessageUpdateMessageForPlayer(playerId, playerData.spawnMessageId,
                        math.ceil((index / playerData.amountToSpawn) * 100) .. "%")
                else
                    tm.os.Log("reached end or fatal Flaw")
                    tm.os.Log("Error: ".. index)
                end
            else
                tm.playerUI.RemoveSubtleMessageForPlayer(playerId, playerData.spawnMessageId)
                tm.playerUI.AddSubtleMessageForPlayer(playerId,
                    "Spawning " .. objectGroups[playerData.focusedGroupElement].name .. " complete", "100%", 5)
                playerData.sprinkleGen = nil
                playerData.spawnMessageId = nil
            end
        end
    end
end

local function main()
    playerUIData[0] = {
        uiMenu = "startMenu"
    }
    UpdateUI(0, "startMenu")
    --[[     local ascii = ""
    local data = tm.os.ReadAllText_Static("image.png")
    for i = 1, #data do
        local b = string.byte(data, i)
        ascii = ascii .. tostring(b)
    end
    tm.os.Log(ascii) ]]
end
main()

function OnPlayerJoined(player)
    UpdateUI(player.playerId, "startMenu")
end
