
GRID_HORIZONTAL_PADDING = 0.05 * DEFAULT_VIEW_WIDTH
GRID_TOP_PADDING = 0.1 * DEFAULT_VIEW_WIDTH
GRID_WIDTH = DEFAULT_VIEW_WIDTH - GRID_HORIZONTAL_PADDING * 2.0

DRAW_DATA_SCALE = 10.0

BACKGROUND_COLOR = {r = 0.0, g = 0.0, b = 0.0}

local HANDLE_TOUCH_RADIUS = 30
local HANDLE_DRAW_RADIUS = 12

require('tools.draw_algorithms')
require('tools.draw_data')

local DrawTool =
    defineCoreBehavior {
    name = "Draw2",
    propertyNames = {},
    dependencies = {
        "Body",
        "Drawing2"
    },
    tool = {
        icon = "pencil-alt",
        iconFamily = "FontAwesome5",
        needsPerformingOff = true,
        isFullScreen = true,
    }
}

--[[

tove's coordinate system for angles looks like this

             270


180 deg      (0,0)     0 deg


             90 deg

we use the same system but in radians

]]--


-- TODO: don't allow completely overlapping lines


-- Behavior management

local TEST_POINT = nil

local _viewTransform = love.math.newTransform()
local _drawData
local _physicsBodyData

local _initialCoord
local _currentPathData

local _tempGraphics
local _tool
local _subtool
local _physicsBodySubtool
local _grabbedPaths
local _isUsingBendPoint

local _didChange

function DrawTool.handlers:addBehavior(opts)
    
end

-- Methods

local function addPathData(pathData)
    if pathData.points[1].x ~= pathData.points[2].x or pathData.points[1].y ~= pathData.points[2].y then
        if not pathData.color then
            pathData.color = util.deepCopyTable(_drawData.color)
        end
        table.insert(_drawData.pathDataList, pathData)
    end
end

local function addTempPathData(pathData)
    if not pathData.color then
        pathData.color = util.deepCopyTable(_drawData.color)
    end
    _drawData:updatePathDataRendering(pathData)
    _tempGraphics:addPath(pathData.tovePath)
end

local function removePathData(pathData)
    for i = #_drawData.pathDataList, 1, -1 do
        if _drawData.pathDataList[i] == pathData then
            table.remove(_drawData.pathDataList, i)
        end
    end
end

local function resetTempGraphics()
    _tempGraphics = tove.newGraphics()
    _tempGraphics:setDisplay("mesh", 1024)
end

function DrawTool:saveDrawing(commandDescription, c)
    local actorId = c.actorId
    local newDrawData = _drawData:serialize()
    local newPhysicsBodyData = _physicsBodyData:serialize()
    local newHash = self.dependencies.Drawing2:hash(newDrawData, newPhysicsBodyData) -- Prevent reloading since we're already in sync
    c._lastHash = newHash
    local oldDrawData = self.dependencies.Drawing2:get(actorId).properties.drawData
    local oldPhysicsBodyData = self.dependencies.Drawing2:get(actorId).properties.physicsBodyData
    local oldHash = self.dependencies.Drawing2:get(actorId).properties.hash

    self.dependencies.Drawing2:command(
        commandDescription,
        {
            params = {"oldDrawData", "newDrawData", "oldPhysicsBodyData", "newPhysicsBodyData", "oldHash", "newHash"}
        },
        function()
            self:sendSetProperties(actorId, "drawData", newDrawData)
            self:sendSetProperties(actorId, "physicsBodyData", newPhysicsBodyData)
            self:sendSetProperties(actorId, "hash", newHash)
        end,
        function()
            self:sendSetProperties(actorId, "drawData", oldDrawData)
            self:sendSetProperties(actorId, "physicsBodyData", oldPhysicsBodyData)
            self:sendSetProperties(actorId, "hash", oldHash)
        end
    )
end

function DrawTool:getSingleComponent()
    local singleComponent
    for actorId, component in pairs(self.components) do
        if self.game.clientId == component.clientId then
            if singleComponent then
                return nil
            end
            singleComponent = component
        end
    end
    return singleComponent
end

-- Update

function DrawTool.handlers:onSetActive()
    _drawData = DrawData:new()
    _physicsBodyData = PhysicsBodyData:new()
    _grabbedPaths = nil
    _initialCoord = nil
    _tempGraphics = nil
    _didChange = false
    _tool = 'draw'
    _subtool = 'pencil'
    _physicsBodySubtool = 'rectangle'
end

function DrawTool.handlers:preUpdate(dt)
    if not self:isActive() then
        return
    end

    -- Steal all touches
    local touchData = self:getTouchData()
    for touchId, touch in pairs(touchData.touches) do
        touch.used = true
    end
end

local _scaleRotateData = {}

local function bind(t, k)
    return function(...) return t[k](t, ...) end
end

function DrawTool:updatePhysicsBodyTool(c, touch)
    local touchX, touchY = _viewTransform:inverseTransformPoint(touch.x, touch.y)

    local roundedX, roundedY = _drawData:roundGlobalCoordinatesToGrid(touchX, touchY)
    local roundedCoord = {x = roundedX, y = roundedY}

    if _physicsBodySubtool == 'rectangle' or _physicsBodySubtool == 'circle' or _physicsBodySubtool == 'triangle' then
        if _initialCoord == nil then
            _initialCoord = roundedCoord
        end

        local shape
        if _physicsBodySubtool == 'rectangle' then
            shape = _physicsBodyData:getRectangleShape(_initialCoord, roundedCoord)
        elseif _physicsBodySubtool == 'circle' then
            local roundDx = floatUnit(_initialCoord.x - touchX)
            local roundDy = floatUnit(_initialCoord.y - touchY)

            shape = _physicsBodyData:getCircleShape(_initialCoord, roundedCoord, bind(_drawData, 'roundGlobalCoordinatesToGrid'), bind(_drawData, 'roundGlobalDistanceToGrid'), roundDx, roundDy)
        elseif _physicsBodySubtool == 'triangle' then
            shape = _physicsBodyData:getTriangleShape(_initialCoord, roundedCoord)
        end

        if shape then
            _physicsBodyData.tempShape = shape
        end

        if touch.released then
            if _physicsBodyData:commitTempShape() then
                self:saveDrawing('add ' .. _physicsBodySubtool, c)
            end

            _initialCoord = nil
        end
    elseif _physicsBodySubtool == 'move' then
        if _initialCoord == nil then
            _initialCoord = {
                x = touchX,
                y = touchY
            }
            local idx = _physicsBodyData:getShapeIdxAtPoint(_initialCoord)
            if idx then
                _grabbedShape = _physicsBodyData:removeShapeAtIndex(idx)
            end
        end

        if _grabbedShape then
            local diffX, diffY = _drawData:roundGlobalDiffCoordinatesToGrid(touchX - _initialCoord.x, touchY - _initialCoord.y)

            _physicsBodyData.tempShape = _physicsBodyData:moveShapeBy(_grabbedShape, diffX, diffY, _drawData:gridCellSize())
        end

        if touch.released then
            if _physicsBodyData:commitTempShape() then
                self:saveDrawing("move", c)
            end

            _initialCoord = nil
            _grabbedShape = nil
        end
    elseif _physicsBodySubtool == 'scale-rotate' then
        if _initialCoord == nil then
            _initialCoord = {
                x = touchX,
                y = touchY
            }

            if _scaleRotateData.index then
                local handleTouchRadius = HANDLE_TOUCH_RADIUS * self.game:getPixelScale()
                local scaleRotateShape = _physicsBodyData:getShapeAtIndex(_scaleRotateData.index)
            
                local handles = _physicsBodyData:getHandlesForShape(scaleRotateShape)
                for i = 1, #handles do
                    local handle = handles[i]
                    local distance = math.sqrt(math.pow(touchX - handle.x, 2.0) + math.pow(touchY - handle.y, 2.0))
                    if distance < handleTouchRadius then
                        _scaleRotateData.handle = handle

                        if scaleRotateShape.type == 'triangle' then
                            _scaleRotateData.otherPoints = {}
                            for j = 1, #handles do
                                if j ~= i then
                                    table.insert(_scaleRotateData.otherPoints, {
                                        x = handles[j].x,
                                        y = handles[j].y,
                                    })
                                end
                            end
                        end
                        break
                    end
                end
            end

            -- only allow choosing a new shape if we didn't find a handle
            if _scaleRotateData.handle == nil then
                local index = _physicsBodyData:getShapeIdxAtPoint(_initialCoord)

                if index then
                    _scaleRotateData.index = index
                end
            end
        end

        if _scaleRotateData.index and _scaleRotateData.handle then
            local otherCoord = {
                x = _scaleRotateData.handle.oppositeX,
                y = _scaleRotateData.handle.oppositeY,
            }

            local scaleRotateShape = _physicsBodyData:getShapeAtIndex(_scaleRotateData.index)
            local type = scaleRotateShape.type
            local shape

            if type == 'rectangle' then
                shape = _physicsBodyData:getRectangleShape(otherCoord, roundedCoord)
            elseif type == 'circle' then
                local roundDx = floatUnit(_scaleRotateData.handle.oppositeX - touchX)
                local roundDy = floatUnit(_scaleRotateData.handle.oppositeY - touchY)

                shape = _physicsBodyData:getCircleShape(otherCoord, roundedCoord, bind(_drawData, 'roundGlobalCoordinatesToGrid'), bind(_drawData, 'roundGlobalDistanceToGrid'), roundDx, roundDy)
            elseif type == 'triangle' then
                shape = _physicsBodyData:getTriangleShape(roundedCoord, _scaleRotateData.otherPoints[1], _scaleRotateData.otherPoints[2])
            end

            if shape then
                _physicsBodyData:updateShapeAtIdx(_scaleRotateData.index, shape)
            end
        end

        if touch.released then
            if _scaleRotateData.handle then
                self:saveDrawing("scale", c)
            end

            _initialCoord = nil
            _scaleRotateData.handle = nil
        end
    elseif _physicsBodySubtool == 'erase' then
        if _initialCoord == nil then
            _initialCoord = roundedCoord

            local idx = _physicsBodyData:getShapeIdxAtPoint(_initialCoord)
            if idx then
                _physicsBodyData:removeShapeAtIndex(idx)
                self:saveDrawing("erase", c)
            end
        end

        if touch.released then
            _initialCoord = nil
        end
    end
end

function DrawTool:updateDrawTool(c, touch)
    local touchX, touchY = _viewTransform:inverseTransformPoint(touch.x, touch.y)

    local roundedX, roundedY = _drawData:roundGlobalCoordinatesToGrid(touchX, touchY)
    local roundedCoord = {x = roundedX, y = roundedY}

    if _subtool == 'rectangle' or _subtool == 'circle' or _subtool == 'triangle' then
        if _initialCoord == nil then
            _initialCoord = roundedCoord
            _currentPathDataList = {}
        end

        local shape
        if _subtool == 'rectangle' then
            shape = _drawData:getRectangleShape(_initialCoord, roundedCoord)
        elseif _subtool == 'circle' then
            local roundDx = floatUnit(_initialCoord.x - touchX)
            local roundDy = floatUnit(_initialCoord.y - touchY)

            shape = _drawData:getCircleShape(_initialCoord, roundedCoord, bind(_drawData, 'roundGlobalCoordinatesToGrid'), bind(_drawData, 'roundGlobalDistanceToGrid'), roundDx, roundDy)
        elseif _subtool == 'triangle' then
            shape = _drawData:getTriangleShape(_initialCoord, roundedCoord)
        end

        if shape then
            _currentPathDataList = shape
        end

        if touch.released then
            for i = 1, #_currentPathDataList do
                _currentPathDataList[i].tovePath = nil
                addPathData(_currentPathDataList[i])
            end

            _drawData:resetGraphics()
            _drawData:resetFill()
            self:saveDrawing('add ' .. _subtool, c)

            _initialCoord = nil
            _currentPathDataList = {}
            _tempGraphics = nil
        else
            resetTempGraphics()
            for i = 1, #_currentPathDataList do
                addTempPathData(_currentPathDataList[i])
            end
        end
    elseif _subtool == 'pencil_no_grid' then
        local clampedX, clampedY = _drawData:clampGlobalCoordinates(touchX, touchY)

        if _initialCoord == nil then
            _initialCoord = {
                x = clampedX,
                y = clampedY,
            }
            _currentPathData = nil
            _currentPathDataList = {}
        end

        local newCoord = {
            x = clampedX,
            y = clampedY,
        }

        _currentPathData = {}
        _currentPathData.points = {_initialCoord, newCoord}
        _currentPathData.style = 1
        _currentPathData.isFreehand = true

        local dist = math.sqrt(math.pow(_initialCoord.x - clampedX, 2.0) + math.pow(_initialCoord.y - clampedY, 2.0))
        if dist > 0.2 then
            _initialCoord = newCoord
            table.insert(_currentPathDataList, _currentPathData)
            _currentPathData = nil
        end

        if touch.released then
            if _currentPathData ~= nil and (_currentPathData.points[1].x ~= _currentPathData.points[2].x or _currentPathData.points[1].y ~= _currentPathData.points[2].y) then
                table.insert(_currentPathDataList, _currentPathData)
            end

            for i = 1, #_currentPathDataList do
                _currentPathDataList[i].tovePath = nil
                addPathData(_currentPathDataList[i])
            end
            _drawData:resetGraphics()
            _drawData:resetFill()
            self:saveDrawing("freehand pencil", c)

            _initialCoord = nil
            _currentPathData = nil
            _currentPathDataList = {}
            _tempGraphics = nil
        else
            resetTempGraphics()
            for i = 1, #_currentPathDataList do
                addTempPathData(_currentPathDataList[i])
            end

            if _currentPathData ~= nil then
                addTempPathData(_currentPathData)
            end
        end
    elseif _subtool == 'line' then
        if _initialCoord == nil then
            _initialCoord = roundedCoord
        end

        local pathData = {}
        pathData.points = {_initialCoord, roundedCoord}
        pathData.style = 1

        if touch.released then
            addPathData(pathData)
            _drawData:resetGraphics()
            _drawData:resetFill()
            self:saveDrawing("line", c)

            _initialCoord = nil
            _tempGraphics = nil
        else
            resetTempGraphics()
            addTempPathData(pathData)
        end
    elseif _subtool == 'pencil' then
        if _initialCoord == nil then
            _initialCoord = roundedCoord
            _currentPathData = nil
            _currentPathDataList = {}
        end

        local angle = math.atan2(touchY - _initialCoord.y, touchX - _initialCoord.x)
        if angle < 0.0 then
            angle = angle + math.pi * 2.0
        end
        local angleRoundedTo8Directions = math.floor((angle + (math.pi * 2.0) / (8.0 * 2.0)) * 8.0 / (math.pi * 2.0))
        if angleRoundedTo8Directions > 7 then
            angleRoundedTo8Directions = 0
        end
        local distFromOriginalPoint = math.sqrt(math.pow(touchX - _initialCoord.x, 2.0) + math.pow(touchY - _initialCoord.y, 2.0))
        local newAngle = (angleRoundedTo8Directions * (math.pi * 2.0) / 8.0)
        local direction = {x = math.cos(newAngle), y = math.sin(newAngle)}

        local cellSize = _drawData.scale / _drawData.gridSize

        if distFromOriginalPoint > cellSize then
            if _currentPathData ~= nil and (_currentPathData.points[1].x ~= _currentPathData.points[2].x or _currentPathData.points[1].y ~= _currentPathData.points[2].y) then
                table.insert(_currentPathDataList, _currentPathData)

                _initialCoord = _currentPathData.points[2]
            end
        end

        distFromOriginalPoint = math.sqrt(math.pow(touchX - _initialCoord.x, 2.0) + math.pow(touchY - _initialCoord.y, 2.0)) - cellSize * 0.5
        local newRoundedX, newRoundedY = _drawData:roundGlobalCoordinatesToGrid(_initialCoord.x + direction.x * distFromOriginalPoint, _initialCoord.y + direction.y * distFromOriginalPoint)
            
        _currentPathData = {}
        _currentPathData.points = {_initialCoord, {
            x = newRoundedX,
            y = newRoundedY,
        }}
        _currentPathData.style = 1

        if touch.released then
            if _currentPathData ~= nil and (_currentPathData.points[1].x ~= _currentPathData.points[2].x or _currentPathData.points[1].y ~= _currentPathData.points[2].y) then
                table.insert(_currentPathDataList, _currentPathData)
            end

            local newPathDataList = simplifyPathDataList(_currentPathDataList)

            for i = 1, #newPathDataList do
                newPathDataList[i].tovePath = nil
                addPathData(newPathDataList[i])
            end
            _drawData:resetGraphics()
            _drawData:resetFill()
            self:saveDrawing("pencil", c)

            _initialCoord = nil
            _currentPathData = nil
            _currentPathDataList = {}
            _tempGraphics = nil
        else
            resetTempGraphics()
            for i = 1, #_currentPathDataList do
                addTempPathData(_currentPathDataList[i])
            end
            addTempPathData(_currentPathData)
        end
    elseif _subtool == 'move' then
        if _grabbedPaths == nil then
            _grabbedPaths = {}

            for i = 1, #_drawData.pathDataList do
                if not _drawData.pathDataList[i].isFreehand then
                    for p = 1, 2 do
                        local distance = math.sqrt(math.pow(touchX - _drawData.pathDataList[i].points[p].x, 2.0) + math.pow(touchY - _drawData.pathDataList[i].points[p].y, 2.0))

                        if distance < _drawData.scale * 0.05 then
                            _drawData.pathDataList[i].grabPointIndex = p
                            table.insert(_grabbedPaths, _drawData.pathDataList[i])
                            break
                        end
                    end
                end
            end

            for i = 1, #_grabbedPaths do
                removePathData(_grabbedPaths[i])
            end

            if #_grabbedPaths == 0 then
                for i = 1, #_drawData.pathDataList do
                    if not _drawData.pathDataList[i].isFreehand then
                        local pathData = _drawData.pathDataList[i]
                        local distance, t, subpath = pathData.tovePath:nearest(touchX, touchY, 0.5)
                        if subpath then
                            local pointX, pointY = subpath:position(t)
                            removePathData(pathData)
                            local touchPoint = {x = touchX, y = touchY}

                            -- todo: figure out path ids here
                            local newPathData1 = {
                                points = {
                                    pathData.points[1],
                                    touchPoint
                                },
                                style = pathData.style,
                                color = pathData.color,
                                grabPointIndex = 2
                            }

                            local newPathData2 = {
                                points = {
                                    touchPoint,
                                    pathData.points[2]
                                },
                                style = pathData.style,
                                color = pathData.color,
                                grabPointIndex = 1
                            }

                            table.insert(_grabbedPaths, newPathData1)
                            table.insert(_grabbedPaths, newPathData2)

                            break
                        end
                    end
                end
            end

            if #_grabbedPaths > 0 then
                _drawData:resetGraphics()
            end
        end

        for i = 1, #_grabbedPaths do
            _grabbedPaths[i].points[_grabbedPaths[i].grabPointIndex].x = roundedX
            _grabbedPaths[i].points[_grabbedPaths[i].grabPointIndex].y = roundedY

            _grabbedPaths[i].tovePath = nil
        end

        if touch.released then
            if _grabbedPaths and #_grabbedPaths > 0 then
                for i = 1, #_grabbedPaths do
                    addPathData(_grabbedPaths[i])
                end

                _drawData:resetGraphics()
                _drawData:resetFill()
                self:saveDrawing("move", c)
            end

            _grabbedPaths = nil
            _tempGraphics = nil
        else
            resetTempGraphics()

            for i = 1, #_grabbedPaths do
                addTempPathData(_grabbedPaths[i])
            end
        end
    elseif _subtool == 'bend' then
        if _grabbedPaths == nil then
            _grabbedPaths = {}
            _initialCoord = {
                x = touchX,
                y = touchY,
            }
            _isUsingBendPoint = false

            for i = 1, #_drawData.pathDataList do
                if not _drawData.pathDataList[i].isFreehand and _drawData.pathDataList[i].tovePath:nearest(touchX, touchY, 0.5) then
                    table.insert(_grabbedPaths, _drawData.pathDataList[i])
                    removePathData(_drawData.pathDataList[i])
                    _drawData:resetGraphics()
                    break
                end
            end
        end

        local distance = math.sqrt(math.pow(_initialCoord.x - touchX, 2.0) + math.pow(_initialCoord.y - touchY, 2.0))
        if distance > 0.1 then
            _isUsingBendPoint = true
        end

        if #_grabbedPaths > 0 then
            if _isUsingBendPoint then
                _grabbedPaths[1].style = 1
                _grabbedPaths[1].bendPoint = {
                    x = touchX,
                    y = touchY,
                }
            end
            _grabbedPaths[1].tovePath = nil
        end

        if touch.released then
            if #_grabbedPaths > 0 then
                if not _isUsingBendPoint then
                    if _grabbedPaths[1].bendPoint then
                        _grabbedPaths[1].style = 1
                        _grabbedPaths[1].bendPoint = nil
                    else
                        _grabbedPaths[1].style = _grabbedPaths[1].style + 1
                        if _grabbedPaths[1].style > 3 then
                            _grabbedPaths[1].style = 1
                        end
                    end
                end

                addPathData(_grabbedPaths[1])

                _drawData:resetFill()
                _drawData:resetGraphics()
                self:saveDrawing("bend", c)
            end

            _grabbedPaths = nil
            _tempGraphics = nil
        else
            if #_grabbedPaths > 0 then
                resetTempGraphics()
                addTempPathData(_grabbedPaths[1])
            end
        end
    elseif _subtool == 'fill' then
        if _drawData:floodFill(touchX, touchY) then
            _didChange = true
        end

        if touch.released then
            if _didChange then
                self:saveDrawing("fill", c)
            end
            _didChange = false
        end
    elseif _subtool == 'erase' then
        for i = 1, #_drawData.pathDataList do
            if _drawData.pathDataList[i].tovePath:nearest(touchX, touchY, 0.5) then
                removePathData(_drawData.pathDataList[i])
                _drawData:resetGraphics()
                _didChange = true
                break
            end
        end

        if _drawData:floodClear(touchX, touchY) then
            _didChange = true
        end

        if touch.released then
            if _didChange then
                _drawData:resetGraphics()
                _drawData:resetFill()
                self:saveDrawing("erase", c)
            end
            _didChange = false
        end
    end
end

function DrawTool.handlers:update(dt)
    if not self:isActive() then
        return
    end

    -- Make sure we have exactly one actor active
    local c = self:getSingleComponent()
    if not c then
        return
    end

    local drawingComponent = self.dependencies.Drawing2:get(c.actorId)
    if c._lastHash ~= drawingComponent.properties.hash then
        local data = self.dependencies.Drawing2:cacheDrawing(drawingComponent.properties)

        c._lastHash = drawingComponent.properties.hash
        _drawData = data.drawData:clone()
        _physicsBodyData = data.physicsBodyData:clone()

        if _scaleRotateData and _scaleRotateData.index and _scaleRotateData.index > _physicsBodyData:getNumShapes() then
            _scaleRotateData.index = _physicsBodyData:getNumShapes()
        end
    end


    local touchData = self:getTouchData()
    if touchData.numTouches == 1 and touchData.maxNumTouches == 1 then
        -- Get the single touch
        local touchId, touch = next(touchData.touches)

        if _tool == "draw" then
            self:updateDrawTool(c, touch)
        else
            self:updatePhysicsBodyTool(c, touch)
        end
    end
end

-- Draw

local function drawShapes()
    love.graphics.setColor(1, 1, 1, 1)

    _drawData:graphics():draw()

    if _tempGraphics ~= nil then
        _tempGraphics:draw()
    end
end

local function drawPoints(points, radius)
    if radius == nil then
        radius = 0.07
    end

    for i = 1, #points, 2 do
        love.graphics.circle("fill", points[i], points[i + 1], radius)
    end
end

function DrawTool.handlers:drawOverlay()
    if not self:isActive() then
        return
    end


    love.graphics.push()

    _viewTransform:reset()
    _viewTransform:translate(GRID_HORIZONTAL_PADDING, GRID_TOP_PADDING)
    _viewTransform:scale(GRID_WIDTH / _drawData.scale)
    love.graphics.applyTransform(_viewTransform)

    love.graphics.clear(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b)

    love.graphics.setColor(1, 1, 1, 1)

    if _tool == 'draw' then
        _physicsBodyData:draw()
        _drawData:renderFill()
    else
        _drawData:renderFill()
        drawShapes()

        love.graphics.setColor(0, 0, 0, 0.5)
        local padding = 0.1
        love.graphics.rectangle('fill', -padding, -padding, _drawData.scale + padding * 2.0, _drawData.scale + padding * 2.0)
    end

    -- grid
    if _tool ~= 'draw' or (_subtool == 'line' or _subtool == 'pencil' or _subtool == 'move' or _subtool == 'rectangle' or _subtool == 'circle' or _subtool == 'triangle') then
        love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
        --love.graphics.setPointSize(10.0)

        local points = {}

        for x = 1, _drawData.gridSize do
            for y = 1, _drawData.gridSize do
                local globalX, globalY = _drawData:gridToGlobalCoordinates(x, y)
                table.insert(points, globalX)
                table.insert(points, globalY)
            end
        end

        drawPoints(points)
    end

    if _tool == 'draw' then
        drawShapes()
    end

    love.graphics.setColor(1, 1, 1, 1)

    if _tool == "draw" and _subtool == "move" then
        local movePoints = {}

        for i = 1, #_drawData.pathDataList do
            if not _drawData.pathDataList[i].isFreehand then
                for p = 1, 2 do
                    table.insert(movePoints, _drawData.pathDataList[i].points[p].x)
                    table.insert(movePoints, _drawData.pathDataList[i].points[p].y)
                end
            end
        end

        love.graphics.setColor(1.0, 0.6, 0.6, 1.0)
        love.graphics.setPointSize(30.0)
        love.graphics.points(movePoints)
    end

    if _tool == 'physics_body' then
        _physicsBodyData:draw()

        if _physicsBodySubtool == 'scale-rotate' and _scaleRotateData.index then
            love.graphics.setColor(1.0, 0.0, 0.0, 1.0)
            love.graphics.setPointSize(30.0)
            --love.graphics.points()

            local handleDrawRadius = HANDLE_DRAW_RADIUS * self.game:getPixelScale()
            local scaleRotateShape = _physicsBodyData:getShapeAtIndex(_scaleRotateData.index)
            for _, handle in ipairs(_physicsBodyData:getHandlesForShape(scaleRotateShape)) do
                love.graphics.circle("fill", handle.x, handle.y, handleDrawRadius)
                if handle.endX and handle.endY then
                    love.graphics.line(handle.x, handle.y, handle.endX, handle.endY)
                end
            end
        end
    end

    if TEST_POINT ~= nil then
        love.graphics.setColor(0.0, 1.0, 0.0, 1.0)
        love.graphics.setPointSize(30.0)

        love.graphics.points(TEST_POINT.x, TEST_POINT.y)
    end

    love.graphics.pop()
end

-- UI

function DrawTool.handlers:uiData()
    if not self:isActive() then
        return
    end

    local c = self:getSingleComponent()
    if not c then
        return
    end

    local actions = {}
    actions['onSelectArtwork'] = function()
        _tool = 'draw'
    end

    actions['onSelectCollision'] = function()
        _tool = 'physics_body'
    end

    actions['onSelectArtworkSubtool'] = function(name)
        _subtool = name

        if _subtool == 'fill' or _subtool == 'erase' then
            _drawData:updatePathsCanvas()
        end
    end

    actions['onSelectCollisionSubtool'] = function(name)
        _physicsBodySubtool = name

        if _physicsBodySubtool == 'scale-rotate' then
            if _physicsBodyData:getNumShapes() > 0 then
                _scaleRotateData.index = _physicsBodyData:getNumShapes()
            end
        end
    end

    actions['updateColor'] = function(opts)
        _drawData:updateColor(opts.r, opts.g, opts.b)
        self:saveDrawing("update color", c)
    end

    ui.data({
        currentMode = (_tool == 'draw' and 'artwork' or 'collision'),
        color = _drawData.color,
        artworkSubtool = _subtool,
        collisionSubtool = _physicsBodySubtool,
    }, {
        actions = actions,
    })
end
