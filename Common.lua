local Physics = require 'multi.physics'


local resource_loader = require 'resource_loader'


love.physics.setMeter(64)


MAIN_RELIABLE_CHANNEL = 0
SECONDARY_RELIABLE_CHANNEL = 99


-- Behavior base

local Behavior = {}

function Behavior:callHandler(handlerName, ...)
    local handler = self.handlers[handlerName]
    if handler then
        return handler(self, ...)
    end
end

function Behavior:sendSetProperties(opts, ...)
    local actorId, sendOpts
    if type(opts) == 'table' then
        actorId = opts.actorId
        sendOpts = setmetatable({ kind = 'setProperties' }, { __index = opts })
    else
        actorId = opts
        sendOpts = 'setProperties'
    end

    local function propertyNamesToIds(name, value, ...)
        if name ~= nil then
            local id = self.propertyIds[name]
            if not id then
                error("behavior '" .. self.name .. "' has no property named '" .. name .. "'")
            end
            return id, value, propertyNamesToIds(...)
        end
    end

    self.game:send(sendOpts, actorId, self.behaviorId, propertyNamesToIds(...))
end


-- Body behavior

local BodyBehavior = {
    name = 'Body',
    propertyNames = {
        'worldId',
        'bodyId',
        'fixtureId',
    },
    handlers = {},
}

function BodyBehavior.handlers:addBehavior(opts)
    self._physics = Physics.new({
        game = self.game,
        updateRate = 120,
        reliableChannel = MAIN_RELIABLE_CHANNEL,
    })

    if self.game.server then
        self:sendSetProperties(nil, 'worldId', self._physics:newWorld(0, 1, true))
    end
end

function BodyBehavior.handlers:removeBehavior(opts)
    self:getWorld():destroy()
end

function BodyBehavior.handlers:preSyncClient(clientId)
    self._physics:syncNewClient({
        clientId = clientId,
        channel = MAIN_RELIABLE_CHANNEL,
    })
end

function BodyBehavior.handlers:addComponent(component, bp, opts)
    if opts.isOrigin then
        local bodyId = self._physics:newBody(self.globals.worldId,
            bp.x or 0, bp.y or 0,
            bp.bodyType or 'static')
        if bp.massData then
            self._physics:setMassData(bodyId, unpack(bp.massData))
        end
        if bp.fixedRotation ~= nil then
            self._physics:setFixedRotation(bodyId, bp.fixedRotation)
        end
        if bp.angle ~= nil then
            self._physics:setAngle(bodyId, bp.angle)
        end
        if bp.linearVelocity ~= nil then
            self._physics:setLinearVelocity(bodyId, unpack(bp.linearVelocity))
        end
        if bp.angularVelocity ~= nil then
            self._physics:setAngularVelocity(bodyId, unpack(bp.angularVelocity))
        end
        if bp.linearDamping ~= nil then
            self._physics:setLinearDamping(bodyId, bp.linearDamping)
        end
        if bp.angularDamping ~= nil then
            self._physics:setAngularDamping(bodyId, bp.angularDamping)
        end
        if bp.bullet ~= nil then
            self._physics:setBullet(bodyId, bp.bullet)
        end
        if bp.gravityScale ~= nil then
            self._physics:setGravityScale(bodyId, bp.gravityScale)
        end

        local fixtureBps = bp.fixture and { bp.fixture } or bp.fixtures
        if fixtureBps then
            for _, fixtureBp in ipairs(fixtureBps) do
                local shapeId
                local shapeType = fixtureBp.shapeType

                if shapeType == 'circle' then
                    shapeId = self._physics:newCircleShape(fixtureBp.x or 0, fixtureBp.y or 0, fixtureBp.radius or 0)
                elseif shapeType == 'polygon' then
                    shapeId = self._physics:newPolygonShape(unpack(assert(fixtureBp.points)))
                elseif shapeType == 'edge' then
                    shapeId = self._physics:newEdgeShape(unpack(assert(fixtureBp.points)))
                    self._physics:setPreviousVertex(unpack(assert(fixtureBp.previousVertex)))
                    self._physics:setNextVertex(unpack(assert(fixtureBp.nextVertex)))
                elseif shapeType == 'chain' then
                    shapeId = self._physics:newChainShape(unpack(assert(fixtureBp.points)))
                    self._physics:setPreviousVertex(unpack(assert(fixtureBp.previousVertex)))
                    self._physics:setNextVertex(unpack(assert(fixtureBp.nextVertex)))
                end

                local fixtureId = self._physics:newFixture(bodyId, shapeId, fixtureBp.density or 1)
                if fixtureBp.friction ~= nil then
                    self._physics:setFriction(fixtureId, fixtureBp.friction)
                end
                if fixtureBp.restitution ~= nil then
                    self._physics:setRestitution(fixtureId, fixtureBp.restitution)
                end
                if fixtureBp.sensor ~= nil then
                    self._physics:setSensor(fixtureId, fixtureBp.sensor)
                end

                self._physics:destroyObject(shapeId)
            end
        else -- Default shape
            local shapeId = self._physics:newRectangleShape(32, 32)
            local fixtureId = self._physics:newFixture(bodyId, shapeId, 1)
            self._physics:destroyObject(shapeId)
        end

        self._physics:setUserData(bodyId, component.actorId)
        self:sendSetProperties(component.actorId, 'bodyId', bodyId)
    end
end

function BodyBehavior.handlers:removeComponent(component, opts)
    if opts.isOrigin then
        self._physics:destroyObject(component.properties.bodyId)
    end
end

function BodyBehavior.handlers:blueprintComponent(component, bp)
    local body = self:getBody()
    bp.x = body:getX()
    bp.y = body:getY()
    bp.bodyType = body:getType()
    bp.massData = { body:getMassData() }
    bp.fixedRotation = body:isFixedRotation()
    bp.angle = body:getAngle()
    bp.linearVelocity = { body:getLinearVelocity() }
    bp.angularVelocity = body:getAngularVelocity()
    bp.linearDamping = body:getLinearDamping()
    bp.angularDamping = body:getAngularDamping()
    bp.bullet = body:isBullet()
    bp.gravityScale = body:getGravityScale()

    bp.fixtures = {}
    for _, fixture in ipairs(body:getFixtures()) do
        local fixtureBp = {}

        local shape = fixture:getShape()
        local shapeType = shape:getType()
        fixtureBp.shapeType = shapeType
        if shapeType == 'circle' then
            fixtureBp.x, fixtureBp.y = shape:getPoint()
            fixtureBp.radius = shape:getRadius()
        elseif shapeType == 'polygon' then
            fixtureBp.points = { shape:getPoints() }
        elseif shapeType == 'edge' then
            fixtureBp.points = { shape:getPoints() }
            fixtureBp.previousVertex = { shape:getPreviousVertex() }
            fixtureBp.nextVertex = { shape:getNextVertex() }
        elseif shapeType == 'chain' then
            fixtureBp.points = { shape:getPoints() }
            fixtureBp.previousVertex = { shape:getPreviousVertex() }
            fixtureBp.nextVertex = { shape:getNextVertex() }
        end

        fixtureBp.density = fixture:getDensity()
        fixtureBp.friction = fixture:getFriction()
        fixtureBp.restitution = fixture:getRestitution()
        fixtureBp.sensor = fixture:isSensor()

        table.insert(bp.fixtures, fixtureBp)
    end
end

function BodyBehavior.handlers:perform(dt)
    self._physics:updateWorld(self.globals.worldId, dt)
    self._physics:sendSyncs(self.globals.worldId)
end

function BodyBehavior.handlers:draw(order)
    local world = self:getWorld()
    if world then
        table.insert(order, {
            depth = 100,
            draw = function()
                love.graphics.push('all')
                love.graphics.setColor(0, 1, 0)
                for _, body in ipairs(world:getBodies()) do
                    for _, fixture in ipairs(body:getFixtures()) do
                        local shape = fixture:getShape()
                        local ty = shape:getType()
                        if ty == 'circle' then
                            love.graphics.circle('line', body:getX(), body:getY(), shape:getRadius())
                        elseif ty == 'polygon' then
                            love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                        elseif ty == 'edge' then
                            love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                        elseif ty == 'chain' then
                            love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                        end
                    end
                end
                love.graphics.pop()
            end,
        })
    end
end

function BodyBehavior:getWorld()
    return self._physics:objectForId(self.globals.worldId)
end

function BodyBehavior:getBody(actorId)
    return self._physics:objectForId(self.components[actorId].properties.bodyId)
end

function BodyBehavior:getActorForBody(body)
    return body:getUserData()
end


-- Image behavior

local ImageBehavior = {
    name = 'Image',
    propertyNames = {
        'url',
        'depth',
        'filter',
    },
    dependencies = {
        'Body',
    },
    handlers = {},
}

function ImageBehavior.handlers:addComponent(component, blueprint, opts)
    component.properties.url = 'https://raw.githubusercontent.com/nikki93/edit-world/4c9d0d6f92b3a67879c7a5714e6608530093b45a/assets/checkerboard.png'
    component.properties.depth = 0
    component.properties.filter = 'nearest'
end

function ImageBehavior.handlers:removeComponent(component, opts)
end

function ImageBehavior.handlers:draw(order)
    for actorId, component in pairs(self.components) do
        table.insert(order, {
            depth = component.properties.depth,
            draw = function()
                component._imageHolder = resource_loader.loadImage(component.properties.url, component.properties.filter)
                local image = component._imageHolder.image
                local width, height = image:getDimensions()

                local body = self.dependencies.Body:getBody(actorId)

                love.graphics.draw(
                    image,
                    body:getX(), body:getY(),
                    body:getAngle(),
                    32 / width, 32 / height,
                    0.5 * width, 0.5 * height)
            end,
        })
    end
end


-- Core behavior list

CORE_BEHAVIORS = {
    BodyBehavior,
    ImageBehavior,
}


-- Define

function Common:define()
    -- Users
    self:defineMessageKind('me', {
        reliable = true,
        channel = SECONDARY_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
    })

    -- Actors / behaviors
    local reliableToAll = {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
        rate = 20,
    }
    self:defineMessageKind('addActor', reliableToAll)
    self:defineMessageKind('removeActor', reliableToAll)
    self:defineMessageKind('addBehavior', reliableToAll)
    self:defineMessageKind('removeBehavior', reliableToAll)
    self:defineMessageKind('addComponent', reliableToAll)
    self:defineMessageKind('removeComponent', reliableToAll)
    self:defineMessageKind('setProperties', reliableToAll)
end


-- Start / stop

function Common:start()
    -- Users

    self.mes = {}


    -- Actors / behaviors

    self.actors = {} -- `actorId` -> actor
    self.behaviors = {} -- `behaviorId` -> behavior
    self.behaviorsByName = {} -- `behaviorName` -> behavior
    self.behaviorsByHandler = {} -- `handlerName` -> `behaviorId` -> behavior

    for behaviorId, behaviorSpec in pairs(CORE_BEHAVIORS) do
        self.receivers.addBehavior(self, 0, self.clientId, behaviorId, behaviorSpec)
    end
end

function Common:stop()
    for behaviorId, behavior in pairs(self.behaviors) do
        self.receivers.removeBehavior(self, 0, self.clientId, behaviorId)
    end
end


-- Users

function Common.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end


-- Actors / behaviors

function Common.receivers:addActor(time, clientId, actorId)
    assert(not self.actors[actorId], 'addActor: this `actorId` is already used')

    local actor = {}
    actor.actorId = {}
    actor.components = {}

    self.actors[actorId] = actor
end

function Common.receivers:removeActor(time, clientId, actorId)
    local actor = assert(self.actors[actorId], 'removeActor: no such actor')

    for behaviorId, component in pairs(actor.components) do
        local behavior = self.behaviors[behaviorId]
        behavior:callHandler('removeComponent', component, {
            isOrigin = self.clientId == clientId,
        })
        behavior.components[actorId] = nil
    end

    self.actors[actorId] = nil
end

function Common.receivers:addBehavior(time, clientId, behaviorId, behaviorSpec)
    assert(not self.behaviors[behaviorId], 'addBehavior: this `behaviorId` is already used')
    assert(behaviorSpec, 'addBehavior: need a `behaviorSpec`')

    -- Basics
    local behavior = setmetatable({}, { __index = Behavior })
    behavior.behaviorId = behaviorId
    behavior.behaviorSpec = behaviorSpec
    behavior.name = behaviorSpec.name
    behavior.game = self
    behavior.globals = {}
    behavior.components = {}

    -- Copy property names
    behavior.propertyIds = {}
    behavior.propertyNames = {}
    for propertyId, propertyName in ipairs(behaviorSpec.propertyNames) do
        behavior.propertyIds[propertyName] = propertyId
        behavior.propertyNames[propertyId] = propertyName
    end

    -- Copy methods
    for methodName, method in pairs(behaviorSpec) do
        if type(method) == 'function' then
            behavior[methodName] = method
        end
    end

    -- Copy handlers and setters
    behavior.handlers = {}
    for handlerName, handler in pairs(behaviorSpec.handlers or {}) do
        behavior.handlers[handlerName] = handler
    end
    behavior.setters = {}
    for setterName, setter in pairs(behaviorSpec.setters or {}) do
        behavior.setters[setterName] = setter
    end

    -- Reference dependencies
    behavior.dependencies = {}
    for _, dependencyName in pairs(behaviorSpec.dependencies or {}) do
        behavior.dependencies[dependencyName] = assert(self.behaviorsByName[dependencyName],
            "dependency '" .. dependencyName .. "' not resolved")
    end

    -- Set in maps
    self.behaviors[behaviorId] = behavior
    self.behaviorsByName[behavior.name] = behavior
    for handlerName in pairs(behavior.handlers) do
        if not self.behaviorsByHandler[handlerName] then
            self.behaviorsByHandler[handlerName] = {}
        end
        self.behaviorsByHandler[handlerName][behaviorId] = behavior
    end

    -- Notify `addBehavior`
    behavior:callHandler('addBehavior', {
        isOrigin = self.clientId == clientId,
    })
end

function Common.receivers:removeBehavior(time, clientId, behaviorId)
    local behavior = assert(self.behaviors[behaviorId], 'removeBehavior: no such behavior')

    -- Notify `removeBehavior`
    behavior:callHandler('removeBehavior', {
        isOrigin = self.clientId == clientId,
    })

    -- Unset in maps
    for actorId in pairs(behavior.components) do
        self.actors[actorId].components[behaviorId] = nil
    end
    for handlerName in pairs(behavior.handlers) do
        self.behaviorsByHandler[handlerName][behaviorId] = nil
        if not next(self.behaviorsByHandler[handlerName]) then
            self.behaviorsByHandler[handlerName] = nil
        end
    end
    self.behaviorsByName[behavior.name] = nil
    self.behaviors[behaviorId] = nil
end

function Common.receivers:addComponent(time, clientId, actorId, behaviorId, blueprint)
    local actor = assert(self.actors[actorId], 'addComponent: no such actor')
    local behavior = assert(self.behaviors[behaviorId], 'addComponent: no such behavior')

    local component = {}
    component.actorId = actorId
    component.behaviorId = behaviorId
    component.properties = {}

    actor.components[behaviorId] = component
    behavior.components[actorId] = component

    behavior:callHandler('addComponent', component, blueprint or {}, {
        isOrigin = self.clientId == clientId,
    })
end

function Common.receivers:removeComponent(time, clientId, actorId, behaviorId)
    local actor = assert(self.actors[actorId], 'removeComponent: no such actor')
    local behavior = assert(self.behaviors[behaviorId], 'removeComponent: no such behavior')

    behavior:callHandler('removeComponent', actor.components[behaviorId], {
        isOrigin = self.clientId == clientId,
    })

    actor.components[behaviorId] = nil
    behavior.components[actorId] = nil
end

function Common.receivers:setProperties(time, actorId, behaviorId, ...)
    local behavior = assert(self.behaviors[behaviorId], 'setProperties: no such behavior')

    local component
    if actorId then
        local actor = assert(self.actors[actorId], 'setProperties: no such actor')
        component = actor.components[behaviorId]
    end

    for i = 1, select('#', ...), 2 do
        local id, value = select(i, ...)
        local name = behavior.propertyNames[id]
        if not name then
            error('setProperties: bad property id')
        end
        local setter = behavior.setters[name]
        if actorId then
            if setter then
                setter(behavior, component, value)
            else
                component.properties[name] = value
            end
        else
            if setter then
                setter(behavior, value)
            else
                behavior.globals[name] = value
            end
        end
    end
end

function Common:callHandlers(handlerName, ...)
    local behaviors = self.behaviorsByHandler[handlerName]
    if behaviors then
        for behaviorId, behavior in pairs(behaviors) do
            behavior:callHandler(handlerName, ...)
        end
    end
end


-- Update

function Common:update(dt)
    self:callHandlers('perform', dt)
end
