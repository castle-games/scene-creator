-- Constants

local BELT_HEIGHT = 200

local ELEM_SIZE = 170
local ELEM_GAP = 20

local DECEL_X = 2400

local SNAP_THRESHOLD_VX = 200

-- Start / stop

function Common:startBelt()
    self.beltDirty = true

    self.beltElems = {}

    self.beltCursorX = 0
    self.beltCursorVX = 0
end

-- Update

function Common:markBeltDirty()
    -- Mark belt as needing synchronization
    self.beltDirty = true
end

function Common:syncBelt()
    -- Synchronize belt data with library entries

    -- Collect set of ids the current belt data covers
    local currElemIds = {}
    for _, beltElem in ipairs(self.beltElems) do
        currElemIds[beltElem.entryId] = true
    end

    -- Prepare list of new elements
    local newElems = {}
    for entryId, entry in pairs(self.library) do
        if not currElemIds[entryId] then
            local newElem = {}
            newElem.entryId = entry.entryId
            newElem.title = entry.title
            newElem.order = entry.beltOrder
            if newElem.order == nil then
                newElem.order = 0
            end
            if entry.base64Png then
                local decoded = love.data.decode("data", "base64", entry.base64Png)
                local imgData = love.image.newImageData(decoded)
                newElem.image = love.graphics.newImage(imgData)
            end
            table.insert(newElems, newElem)
        end
    end

    -- Save new elements
    for _, newElem in ipairs(newElems) do
        table.insert(self.beltElems, newElem)
    end

    -- Sort belt
    table.sort(self.beltElems, function(a, b)
        return a.order < b.order
    end)

    -- Calculate positions
    for i, elem in ipairs(self.beltElems) do
        elem.x = (ELEM_SIZE + ELEM_GAP) * (i - 1)
    end

    self.beltDirty = false
end

function Common:updateBelt(dt)
    if self.beltDirty then
        self:syncBelt()
    end

    local skipApplyVel = false

    local dragScrolling = false
    if self.numTouches == 1 and self.maxNumTouches == 1 then -- Single touch
        local windowWidth, windowHeight = love.graphics.getDimensions()

        local touchId, touch = next(self.touches)

        if touch.screenY > windowHeight - BELT_HEIGHT then -- Drag to scroll
            touch.used = true
            self.beltCursorX = self.beltCursorX - touch.screenDX
            skipApplyVel = true
            dragScrolling = true
            self.beltCursorVX = -touch.screenDX / dt
        end
    end

    -- Strong rubber band on ends
    local rubberBanded = false
    if not dragScrolling then
        if self.beltCursorX < 0 then
            self.beltCursorVX = 0.5 * self.beltCursorVX
            self.beltCursorX = 0.85 * self.beltCursorX
            rubberBanded = true
        end
        local maxX = self.beltElems[#self.beltElems].x
        if self.beltCursorX > maxX then
            self.beltCursorVX = 0.5 * self.beltCursorVX
            self.beltCursorX = 0.85 * self.beltCursorX + 0.15 * maxX
            rubberBanded = true
        end
    end

    -- Snap cursor to nearest elem
    if not rubberBanded and not dragScrolling then
        if math.abs(self.beltCursorVX) <= SNAP_THRESHOLD_VX then
            local i = math.floor(self.beltCursorX / (ELEM_SIZE + ELEM_GAP) + 0.5)

            local beforeX = (i - 0.5) * (ELEM_SIZE + ELEM_GAP)
            local afterX = (i + 0.5) * (ELEM_SIZE + ELEM_GAP)
            local beforeDX = self.beltCursorX - beforeX
            local afterDX = afterX - self.beltCursorX

            local accel = 0
            accel = accel - 0.7 * SNAP_THRESHOLD_VX * beforeDX
            accel = accel + 0.7 * SNAP_THRESHOLD_VX * afterDX
            self.beltCursorVX = self.beltCursorVX + accel * dt
        end
    end

    -- Velocity application
    if not skipApplyVel then
        self.beltCursorX = self.beltCursorX + self.beltCursorVX * dt
    end

    -- Deceleration
    if self.beltCursorVX ~= 0 then
        if self.beltCursorVX > 0 then
            self.beltCursorVX = self.beltCursorVX - DECEL_X * dt
            if self.beltCursorVX < 0 then
                self.beltCursorVX = 0
            end
        elseif self.beltCursorVX < 0 then
            self.beltCursorVX = self.beltCursorVX + DECEL_X * dt
            if self.beltCursorVX > 0 then
                self.beltCursorVX = 0
            end
        end
    end
end

-- Draw

function Common:drawBelt()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    love.graphics.push("all")

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill",
        0, windowHeight - BELT_HEIGHT,
        windowWidth, BELT_HEIGHT)

    local y = windowHeight - 0.5 * BELT_HEIGHT

    love.graphics.setColor(1, 1, 1)
    for i, elem in ipairs(self.beltElems) do
        if elem.image then
            local imgW, imgH = elem.image:getDimensions()
            local scale = math.min(ELEM_SIZE / imgW, ELEM_SIZE / imgH)
            love.graphics.draw(elem.image,
                0.5 * windowWidth + elem.x - self.beltCursorX, y,
                0, scale, scale, 0.5 * imgW, 0.5 * imgH)
        end
    end

    love.graphics.pop()
end