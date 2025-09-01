local mapData = {
    ObjectList = {{
        P = {           --Position
            x = "",
            y = "",
            z = ""
        },
        R = {           --Rotation
            x = "",
            y = "",
            z = ""
        },
        S = {            --Scale
            x = "",
            y = "",
            z = ""
        },
        N = "",           --Prefab Name or custom Object file name
        I = {             --Information
            IsStatic = "",
            CanCollide = "",
            IsVisible = "",
            DisplayName = "",
            CustomTexture = "",
            CustomModel = false,
            CustomWeight = 0.0
        }
    }
    },
    CameraInfo = {
        P = {
            x = 0,          --set to Player Position
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
local saveDataPath = "Map.json" --Path to export the Trailmappers file

local currentObjects = {} --List of objects spawned in World

local customTextures = {} --List of custom textures used in the world
local customMeshes = {} --List of custom meshes used in the world

local objectDataPath = "objectTable.json"
local success, objectTable = pcall(function() return json.parse(tm.os.ReadAllText_Dynamic(objectDataPath)) end)
if not success then
    objectTable = {}
    tm.os.Log("Object Table file not found -> Creating new file")
    local jsonString = json.serialize(objectTable)
    jsonString = string.gsub(jsonString, "(%d+),(%d+)", "%1.%2")
    tm.os.WriteAllText_Dynamic(objectDataPath, jsonString)
end

local playerData = {}

local function prepareObject(object)
    local objectRotation = tm.vector3.Create(0, math.random(0, 360), 0)

    local scale = {}

    local customTexture = ""
    local customObject = false

    if object.type == "Custom" then
        customObject = true
        customTexture = object.texture
        if Table_contains(customTextures, customTexture) == false then
            tm.physics.AddTexture(customTexture, customTexture)
            table.insert(customTextures, customTexture)
        end
        if Table_contains(customMeshes, object.name) == false then
            tm.physics.AddMesh(object.name, object.name)
            table.insert(customMeshes, object.name)
        end
    end

    if object.scaleMode == "uniform" then
        local scaleMultiplyier =  math.random(object.minScale * 100, object.maxScale * 100) / 100
        --multiply object scale by scale value to get a uniform scale
        scale =  {
            x = object.scale.x * scaleMultiplyier,
            y = object.scale.y * scaleMultiplyier,
            z = object.scale.z * scaleMultiplyier
        }

    elseif object.scaleMode == "seperate" then
        scale =  {
            x = math.random(object.minScale.x * 100, object.maxScale.x * 100) / 100,
            y = math.random(object.minScale.y * 100, object.maxScale.y * 100) / 100,
            z = math.random(object.minScale.z * 100, object.maxScale.z * 100) / 100
        }
    end


    local objectScale = tm.vector3.Create(scale.x, scale.y, scale.z)

    local objectOffset = tm.vector3.Create(object.offset.x, object.offset.y, object.offset.z)

    return {
        offset = objectOffset, --Vector3 Offset
        rotation = objectRotation, --Vector3 Rotation
        scale = objectScale, --Vector3 Scale
        customObject = customObject, --Prefab or Custom Object
        customTexture = customTexture --Texture for Custom Object
    }
end


local function doRaycast(playerPos, range, index)
    local xOffset = math.random(-range/2, range/2)
    local zOffset = math.random(-range/2, range/2)

    local raycastPos = playerPos + tm.vector3.Create(xOffset, 1000, zOffset)

    local raycast = tm.physics.RaycastData(raycastPos, tm.vector3.Create(0, -1, 0), 100000, true)

    tm.os.Log("Raycast started")
    if raycast.DidHit() then
        local spawnPos = raycast.GetHitPosition()
        tm.os.Log("Raycast hit at: "..spawnPos.x..", "..spawnPos.y..", "..spawnPos.z)

        local object = objectTable[math.random(1, #objectTable)]
        tm.os.Log(object.name)

        local objectData = prepareObject(object) --gets random Rotation and Scale

        local spawnedObject
        if objectData.customObject then
            spawnedObject = tm.physics.SpawnCustomObjectConcave(spawnPos + objectData.offset, object.name, objectData.customTexture)
        else
            spawnedObject = tm.physics.SpawnObject(spawnPos + objectData.offset, object.name)
        end
        spawnedObject.GetTransform().SetRotation(objectData.rotation)
        spawnedObject.GetTransform().SetScale(objectData.scale)
        tm.os.Log("Object spawned with Scale: ".. objectData.scale.ToString())
        tm.os.Log("Object spawned with Rotation: ".. objectData.rotation.ToString())
        tm.os.Log("Object spawned with Offset: ".. objectData.offset.ToString())

            currentObjects[index] = spawnedObject
            mapData.ObjectList[index] = {
                                    P = {           --Position
                                        x = spawnPos.x,
                                        y = spawnPos.y -300, --offset because of Trailmappers
                                        z = spawnPos.z
                                        },
                                    R = {           --Rotation
                                        x = objectData.rotation.x,
                                        y = objectData.rotation.y,
                                        z = objectData.rotation.z
                                        },
                                    S = {            --Scale
                                        x = objectData.scale.x,
                                        y = objectData.scale.y,
                                        z = objectData.scale.z
                                        },
                                    N = object.name,           --Name
                                    I = {             --Information
                                        IsStatic = spawnedObject.GetIsStatic(),
                                        CanCollide = true,
                                        IsVisible = spawnedObject.GetIsVisible(),
                                        DisplayName = "Sprinkle Tool Object",
                                        CustomTexture = "",
                                        CustomModel = objectData.customObject,
                                        CustomWeight = 0.0
                                        }
                                    }
            if objectData.customObject then
                mapData.ObjectList[index].N = "\\Custom Models\\"..object.name
                mapData.ObjectList[index].I.CustomTexture = "\\Custom Models\\"..objectData.customTexture
            end

        tm.os.Log("Object spawned at: ".. spawnPos.ToString())
    end
end

local function spawnObjectsOfGroup(callbackData)
    if playerData[callbackData.playerId].replaceOld then
        tm.os.Log("Despawning previous objects")
        for key, object in pairs(currentObjects) do
            object.Despawn()
            currentObjects[key] = nil
        end
        tm.os.Log("Spawning new objects")
        for index = #mapData.ObjectList, playerData[callbackData.playerId].count + #mapData.ObjectList do
            doRaycast(tm.players.GetPlayerTransform(callbackData.playerId).GetPosition(), playerData[callbackData.playerId].range, index)
        end
    else
        tm.os.Log("Spawning new objects")
        for index = 1, playerData[callbackData.playerId].count do
            doRaycast(tm.players.GetPlayerTransform(callbackData.playerId).GetPosition(), playerData[callbackData.playerId].range, index)
        end
    end
    tm.os.Log("Adding Camera Position to MapData")
    local playerPos = tm.players.GetPlayerTransform(callbackData.playerId).GetPosition()
    mapData.CameraInfo.P = {
        x = playerPos.x,
        y = playerPos.y - 300, --offset because of Trailmappers
        z = playerPos.z
    }
    tm.os.Log("Exporting MapData to: "..saveDataPath)
    local jsonString = json.serialize(mapData)
    jsonString = string.gsub(jsonString, "(%d+),(%d+)", "%1.%2")
    tm.os.WriteAllText_Dynamic(saveDataPath, jsonString)
end

local function btnSwitchMode(callbackData)
    local playerId = callbackData.playerId
    local modeList = {"spawning", "configureList"}

    for index, mode in pairs(modeList) do
        if playerData[playerId].mode == mode then
            playerData[playerId].mode = modeList[index + 1] or modeList[1]
            break
        end
    end
    if playerData[playerId].mode == "help" then
        playerData[playerId].mode = "spawning"
    end
    UpdateUI(playerId, playerData[playerId].mode)
end

local function btnToggleReplaceOld(callbackData)
    playerData[callbackData.playerId].replaceOld = not playerData[callbackData.playerId].replaceOld
    tm.os.Log("replace old: "..tostring(playerData[callbackData.playerId].replaceOld))
    tm.playerUI.SetUIValue(callbackData.playerId, "btnReplaceOld", "replace old: "..tostring(playerData[callbackData.playerId].replaceOld))
end

local function btnconfigureObject(callbackData)
    tm.os.Log("Configuring object: "..callbackData.data)
    DrawConfigureObjectUI(callbackData.playerId, callbackData.data)
end

local function btnHelp(callbackData)
    tm.os.Log("opening Help UI")
    drawHelpUI(callbackData.playerId)
end

local function btnAddObject(callbackData)
    tm.os.Log("Adding object")
    DrawAddObjectUI(callbackData.playerId)
end

local function btnEditObject(callbackData)
    tm.os.Log("Editing object: "..callbackData.data)
    DrawEditObjectUI(callbackData.playerId, callbackData.data)
end

local function btnObjectList(callbackData)
    DrawObjectListUI(callbackData.playerId)
end

local function btnDeleteObject(callbackData)
    tm.os.Log("Deleting object: "..callbackData.data)
    local objectIndex = callbackData.data
    objectTable[objectIndex] = nil
    tm.os.WriteAllText_Dynamic(objectDataPath, json.serialize(objectTable))
    DrawObjectListUI(callbackData.playerId)
end

local function btnEditValue(callbackData)
    tm.os.Log("Editing value: "..callbackData.data.type[1])
    if #callbackData.data.type == 2 then
        tm.os.Log("Editing value: "..callbackData.data.type[2])
    end
    tm.os.Log("object Index: "..callbackData.data.index)
    tm.os.Log("New value: "..callbackData.value)

    local objectIndex = callbackData.data.index
    local objectValue = callbackData.value
    if #callbackData.data.type == 1 then
        objectTable[objectIndex][callbackData.data.type[1]] = objectValue
    else
        objectTable[objectIndex][callbackData.data.type[1]][callbackData.data.type[2]] = tonumber(objectValue)
    end
end

local function btnToggleObjectType(callbackData)
    tm.os.Log("Toggling object type: "..callbackData.data)
    local objectIndex = callbackData.data
    if objectTable[objectIndex].type == "Prefab" then
        objectTable[objectIndex].type = "Custom"
        objectTable[objectIndex].name = "example.obj"
        objectTable[objectIndex].texture = "example.png"
    else
        objectTable[objectIndex].type = "Prefab"
        objectTable[objectIndex].name = "PFB_Cactus_Bush"
    end
    tm.os.Log("New object type: "..objectTable[objectIndex].type)
    UpdateUI(callbackData.playerId, "edit", {objectIndex = objectIndex})
end

local function btnToggleScaleMode(callbackData)
    tm.os.Log("Toggling scale mode: "..callbackData.data)
    local objectIndex = callbackData.data
    if objectTable[objectIndex].scaleMode == "seperate" then
        objectTable[objectIndex].scaleMode = "uniform"

        objectTable[objectIndex].minScale = 1
        objectTable[objectIndex].maxScale = 1
        objectTable[objectIndex].scale = {
            x = 1,
            y = 1,
            z = 1
        }
    else
        objectTable[objectIndex].scaleMode = "seperate"

        objectTable[objectIndex].minScale = {
            x = 1,
            y = 1,
            z = 1
        }
        objectTable[objectIndex].maxScale = {
            x = 1,
            y = 1,
            z = 1
        }
        objectTable[objectIndex].scale = nil
    end
    tm.os.Log("New scale mode: "..objectTable[objectIndex].scaleMode)
    UpdateUI(callbackData.playerId, "edit", {objectIndex = objectIndex})
end

local function saveObjectEdits(callbackData)
    tm.os.Log("Saving object edits: "..callbackData.data)
    local jsonString = json.serialize(objectTable)
    local jsonString = string.gsub(jsonString, "(%d+),(%d+)", "%1.%2")
    tm.os.WriteAllText_Dynamic(objectDataPath, jsonString)
    DrawObjectListUI(callbackData.playerId)
end

local function updateRange(callbackData)
    tm.os.Log("Range updated")
    playerData[callbackData.playerId].range = callbackData.value
end

local function updateCount(callbackData)
    tm.os.Log("Count updated")
    playerData[callbackData.playerId].count = callbackData.value
end

local function drawObjectSpawningUI(playerId)
    playerData[playerId].mode = "spawning"
    tm.playerUI.ClearUI(playerId)
    tm.playerUI.AddUIButton(playerId, "btnMode", "Mode: Spawn Objects", btnSwitchMode, playerId)

    tm.playerUI.AddUIButton(playerId, "btnHelp", "Help", btnHelp, playerId)

    tm.playerUI.AddUIButton(playerId, "btnReplaceOld", "replace old: "..tostring(playerData[playerId].replaceOld), btnToggleReplaceOld)
    tm.playerUI.AddUILabel(playerId, "lblRange", "Range:")
    tm.playerUI.AddUIText(playerId, "txtRange", playerData[playerId].range, updateRange)
    tm.playerUI.AddUILabel(playerId, "lblCount", "Count:")
    tm.playerUI.AddUIText(playerId, "txtCount", playerData[playerId].count, updateCount)
    tm.playerUI.AddUIButton(playerId, "btnSpawn", "click to spawn", spawnObjectsOfGroup, playerId)
end

function DrawObjectListUI(playerId, groupIndex)
    playerData[playerId].mode = "configureList"
    objectTable = json.parse(tm.os.ReadAllText_Dynamic(objectDataPath))
    tm.playerUI.ClearUI(playerId)
    tm.playerUI.AddUIButton(playerId, "btnMode", "Mode: Configure Objects", btnSwitchMode, playerId)

    tm.playerUI.AddUILabel(playerId, "lblObjectList", "Objects:")
    for key, object in pairs(objectTable) do
        tm.playerUI.AddUIButton(playerId, "btn"..object.name..key, object.name, btnconfigureObject, key)
    end
    tm.playerUI.AddUIButton(playerId, "btnbtnAddObject", "add object", btnAddObject, playerId)
end

function DrawConfigureObjectUI(playerId, objectIndex)
    playerData[playerId].mode = "configureObject"
    objectTable = json.parse(tm.os.ReadAllText_Dynamic(objectDataPath))
    tm.playerUI.ClearUI(playerId)

    local object = objectTable[objectIndex]

    tm.playerUI.AddUIButton(playerId, "btnMode", "back", btnObjectList)

    tm.playerUI.AddUILabel(playerId, "lblObjectName", object.name)
    tm.playerUI.AddUIButton(playerId, "btnEdit", "Edit", btnEditObject, objectIndex)
    tm.playerUI.AddUIButton(playerId, "btnDelete", "Delete", btnDeleteObject, objectIndex)
end

function DrawEditObjectUI(playerId, objectIndex)
    playerData[playerId].mode = "edit"
    tm.playerUI.ClearUI(playerId)

    local object = objectTable[objectIndex]

    tm.playerUI.AddUIButton(playerId, "btnMode", "Cancel", btnObjectList)

    tm.playerUI.AddUILabel(playerId, "lblObjectName", "Name:")
    tm.playerUI.AddUIText(playerId, "txtObjectName", object.name, btnEditValue, {type = {"name"}, index = objectIndex})
    if object.type == "Custom" then
        tm.playerUI.AddUIText(playerId, "txtObjectTexture", object.texture, btnEditValue, {type = {"texture"}, index = objectIndex})
    end

    tm.playerUI.AddUIButton(playerId, "btnObjectMode", "Object type: "..objectTable[objectIndex].type, btnToggleObjectType, objectIndex)


    tm.playerUI.AddUILabel(playerId, "lblOffset", "Offset (x, y, z) :")
    tm.playerUI.AddUIText(playerId, "txtOffsetX", object.offset.x, btnEditValue, {type = {"offset","x"}, index = objectIndex})
    tm.playerUI.AddUIText(playerId, "txtOffsetY", object.offset.y, btnEditValue, {type = {"offset","y"}, index = objectIndex})
    tm.playerUI.AddUIText(playerId, "txtOffsetZ", object.offset.z, btnEditValue, {type = {"offset","z"}, index = objectIndex})

    tm.playerUI.AddUIButton(playerId, "btnScaleMode", "Scale mode: "..object.scaleMode, btnToggleScaleMode, objectIndex)

    if object.scaleMode == "seperate" then
        tm.playerUI.AddUILabel(playerId, "lblMinScale", "Min Scale (x, y, z) :")
        tm.playerUI.AddUIText(playerId, "txtMinScaleX", object.minScale.x, btnEditValue, {type = {"minScale","x"}, index = objectIndex})
        tm.playerUI.AddUIText(playerId, "txtMinScaleY", object.minScale.y, btnEditValue, {type = {"minScale","y"}, index = objectIndex})
        tm.playerUI.AddUIText(playerId, "txtMinScaleZ", object.minScale.z, btnEditValue, {type = {"minScale","z"}, index = objectIndex})

        tm.playerUI.AddUILabel(playerId, "lblMaxScale", "Max Scale (x, y, z) :")
        tm.playerUI.AddUIText(playerId, "txtMaxScaleX", object.maxScale.x, btnEditValue, {type = {"maxScale","x"}, index = objectIndex})
        tm.playerUI.AddUIText(playerId, "txtMaxScaleY", object.maxScale.y, btnEditValue, {type = {"maxScale","y"}, index = objectIndex})
        tm.playerUI.AddUIText(playerId, "txtMaxScaleZ", object.maxScale.z, btnEditValue, {type = {"maxScale","z"}, index = objectIndex})
    elseif object.scaleMode == "uniform" then
        tm.playerUI.AddUILabel(playerId, "lblScale", "Scale multiplier (min, max) :")
        tm.playerUI.AddUIText(playerId, "txtMinScale", object.minScale, btnEditValue, {type = {"minScale"}, index = objectIndex})
        tm.playerUI.AddUIText(playerId, "txtMaxScale", object.maxScale, btnEditValue, {type = {"maxScale"}, index = objectIndex})

        tm.playerUI.AddUILabel(playerId, "lblScale", "Scale (x, y, z) :")
        tm.playerUI.AddUIText(playerId, "txtScaleX", object.scale.x, btnEditValue, {type = {"scale","x"}, index = objectIndex})
        tm.playerUI.AddUIText(playerId, "txtScaleY", object.scale.y, btnEditValue, {type = {"scale","y"}, index = objectIndex})
        tm.playerUI.AddUIText(playerId, "txtScaleZ", object.scale.z, btnEditValue, {type = {"scale","z"}, index = objectIndex})
    end

    tm.playerUI.AddUIButton(playerId, "btnSave", "Save", saveObjectEdits, objectIndex)
end

function DrawAddObjectUI(playerId)
    playerData[playerId].mode = "add"
    tm.playerUI.ClearUI(playerId)

    local objectIndex = #objectTable + 1
    objectTable[objectIndex] = {
        name = "PFB_Cactus_Bush",
        type = "Prefab",
        offset = {
            x = 0,
            y = 0,
            z = 0
        },
        scaleMode = "seperate",
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
    local object = objectTable[objectIndex]

    tm.playerUI.AddUIButton(playerId, "btnMode", "Cancel", btnObjectList)

    tm.playerUI.AddUILabel(playerId, "lblObjectName", "Name:")
    tm.playerUI.AddUIText(playerId, "txtObjectName", object.name, btnEditValue, {type = {"name"}, index = objectIndex})
    tm.playerUI.AddUIButton(playerId, "btnObjectMode", "Object type: "..objectTable[objectIndex].type, btnToggleObjectType, objectIndex)


    tm.playerUI.AddUILabel(playerId, "lblOffset", "Offset (x,y,z) :")
    tm.playerUI.AddUIText(playerId, "txtOffsetX", object.offset.x, btnEditValue, {type = {"offset","x"}, index = objectIndex})
    tm.playerUI.AddUIText(playerId, "txtOffsetY", object.offset.y, btnEditValue, {type = {"offset","y"}, index = objectIndex})
    tm.playerUI.AddUIText(playerId, "txtOffsetZ", object.offset.z, btnEditValue, {type = {"offset","z"}, index = objectIndex})

    tm.playerUI.AddUIButton(playerId, "btnScaleMode", "Scale mode: "..objectTable[objectIndex].scaleMode, btnToggleScaleMode, objectIndex)

    tm.playerUI.AddUILabel(playerId, "lblMinScale", "Min Scale (x,y,z) :")
    tm.playerUI.AddUIText(playerId, "txtMinScaleX", object.minScale.x, btnEditValue, {type = {"minScale","x"}, index = objectIndex})
    tm.playerUI.AddUIText(playerId, "txtMinScaleY", object.minScale.y, btnEditValue, {type = {"minScale","y"}, index = objectIndex})
    tm.playerUI.AddUIText(playerId, "txtMinScaleZ", object.minScale.z, btnEditValue, {type = {"minScale","z"}, index = objectIndex})

    tm.playerUI.AddUILabel(playerId, "lblMaxScale", "Max Scale (x,y,z) :")
    tm.playerUI.AddUIText(playerId, "txtMaxScaleX", object.maxScale.x, btnEditValue, {type = {"maxScale","x"}, index = objectIndex})
    tm.playerUI.AddUIText(playerId, "txtMaxScaleY", object.maxScale.y, btnEditValue, {type = {"maxScale","y"}, index = objectIndex})
    tm.playerUI.AddUIText(playerId, "txtMaxScaleZ", object.maxScale.z, btnEditValue, {type = {"maxScale","z"}, index = objectIndex})
    tm.playerUI.AddUIButton(playerId, "btnAdd", "Add object", saveObjectEdits, objectIndex)
end

function drawHelpUI(playerId)
    playerData[playerId].mode = "help"
    tm.playerUI.ClearUI(playerId)


    tm.playerUI.AddUIButton(playerId, "btnClose", "Close", btnSwitchMode)

    tm.playerUI.AddUILabel(playerId, "lblHeaderObjects", "Object declaring:")
    tm.playerUI.AddUILabel(playerId, "lblHelpText", "To sprinkle a group of objects")
    tm.playerUI.AddUILabel(playerId, "lblHelpText2", "you first need to declare a list")
    tm.playerUI.AddUILabel(playerId, "lblHelpText3", "of objects you want to spawn.")
    tm.playerUI.AddUILabel(playerId, "lblHelpText4", "You can do this via the")
    tm.playerUI.AddUILabel(playerId, "lblHelpText5", "'configure Objects' mode.")

    tm.playerUI.AddUILabel(playerId, "lblHeaderSpawning", "Spawning:")
    tm.playerUI.AddUILabel(playerId, "lblHelpText6", "Once you have configured the objects")
    tm.playerUI.AddUILabel(playerId, "lblHelpText7", "you can switch to the 'Spawn Objects'")
    tm.playerUI.AddUILabel(playerId, "lblHelpText8", "mode and spawn them.")
    tm.playerUI.AddUILabel(playerId, "lblHelpText9", "You can also edit the range and count.")

    tm.playerUI.AddUILabel(playerId, "lblHeaderExporting", "Exporting")
    tm.playerUI.AddUILabel(playerId, "lblHelpText10", "The Mode will automatically export")
    tm.playerUI.AddUILabel(playerId, "lblHelpText11", "the map data to a json file in")
    tm.playerUI.AddUILabel(playerId, "lblHelpText12", "Trailmappers format.")
    tm.playerUI.AddUILabel(playerId, "lblHelpText13", "The file will be saved in the mods")
    tm.playerUI.AddUILabel(playerId, "lblHelpText14", "data dynamic folder.")
    tm.playerUI.AddUILabel(playerId, "lblHelpText15", "You can find this folder by going to")
    tm.playerUI.AddUILabel(playerId, "lblHelpText16", "C:/Program-Files(x86)/Steam/userdata")
    tm.playerUI.AddUILabel(playerId, "lblHelpText17", "then select your steam ID and go to")
    tm.playerUI.AddUILabel(playerId, "lblHelpText18", "the folder 585420/remote/Mods then")
    tm.playerUI.AddUILabel(playerId, "lblHelpText19", "3457144914/data_dynamic/")
    tm.playerUI.AddUILabel(playerId, "lblHelpText12", "The file will be called Map.json.")

    tm.playerUI.AddUILabel(playerId, "lblHeaderCustomModels", "Custom Models:")
    tm.playerUI.AddUILabel(playerId, "lblHelpText20", "You can use custom models by")
    tm.playerUI.AddUILabel(playerId, "lblHelpText21", "putting their files into")
    tm.playerUI.AddUILabel(playerId, "lblHelpText22", "C:/Program-Files(x86)/Steam/")
    tm.playerUI.AddUILabel(playerId, "lblHelpText23", "steamapps/workshop/content/")
    tm.playerUI.AddUILabel(playerId, "lblHelpText24", "585420/3457144914/")
end

function UpdateUI(playerId, modeName, data)
    tm.os.Log("Updating UI: "..modeName)
    local mode = {
        ["spawning"] = function (playerId, data)
            drawObjectSpawningUI(playerId)
        end,
        ["configureList"] = function (playerId, data)
            DrawObjectListUI(playerId, data.groupIndex)
        end,
        ["help"] = function (playerId, data)
            drawHelpUI(playerId)
        end,
        ["add"] = function (playerId, data)
            DrawAddObjectUI(playerId)
        end,
        ["edit"] = function (playerId, data)
            DrawEditObjectUI(playerId, data.objectIndex)
        end,
        ["configureObject"] = function (playerId, data)
            DrawConfigureObjectUI(playerId, data.objectIndex)
        end
    }
    if mode[modeName] then
        mode[modeName](playerId, data)
    else
        tm.os.Log("Invalid mode: "..modeName)
    end
end

function Table_contains(tbl, x)
    for _, v in pairs(tbl) do
        if v == x then
            return true
        end
    end
    return false
end


local function main()
    playerData[0] = {
        mode = "spawning",
    }
    UpdateUI(0, playerData[0].mode)
end
main()
tm.os.Log("sprinkleTool loaded")
