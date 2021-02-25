local CounterBehavior =
    defineCoreBehavior {
    name = "Counter",
    displayName = "Counter",
    dependencies = {},
    propertySpecs = {
       value = {
          method = 'numberInput',
          label = 'Value',
          props = { step = 1 }, -- TODO: dynamic min and max
          rules = { get = true },
       },
       minValue = {
          method = 'numberInput',
          label = 'minimum value',
          props = { step = 1 },
       },
       maxValue = {
          method = 'numberInput',
          label = 'maximum value',
          props = { step = 1 },
       },
    },
}

-- Component management

function CounterBehavior.handlers:addComponent(component, bp, opts)
    component.properties.value = bp.value or bp.minValue or bp.maxValue or 0
    component.properties.minValue = bp.minValue or 0
    component.properties.maxValue = bp.maxValue or 100
end

function CounterBehavior.handlers:blueprintComponent(component, bp)
    bp.minValue = component.properties.minValue
    bp.maxValue = component.properties.maxValue
    bp.value = component.properties.value
end

-- Setters

function CounterBehavior.setters:value(component, newValue, opts)
    local newValue = math.max(component.properties.minValue, math.min(newValue, component.properties.maxValue))
    if component.properties.value ~= newValue then
        component.properties.value = newValue
        if self.game.performing and opts.isOrigin then
            self:fireTrigger(
                "counter reaches value",
                component.actorId,
                {
                    counterValue = newValue
                },
                {
                    filter = function(params)
                        local compareTo = self.game:evalExpression(params.value, component.actorId)
                        return self.game:compare(params.comparison, newValue, compareTo)
                    end
                }
            )

            self:fireTrigger("counter changes", component.actorId)
        end
    end
end

-- Triggers

CounterBehavior.triggers["counter reaches value"] = {
    description = "When this actor's counter reaches a value",
    category = "state",
    paramSpecs = {
       comparison = {
          label = "comparison",
          method = "dropdown",
          initialValue = "equal",
          props = {
             items = COMPARISON_OPERATORS,
          },
       },
       value = {
          label = "value",
          method = "numberInput",
          initialValue = 0,
       },
    },
}

CounterBehavior.triggers["counter changes"] = {
    description = "When the actor's counter changes",
    category = "state"
}

-- Responses

CounterBehavior.responses["change counter"] = {
    description = "Adjust the actor's counter (legacy)",
    isDeprecated = true,
    migrate = function(self, actorId, response)
       response.name = "set counter"

       response.params.relative = true
       response.params.setToValue = response.params.changeBy
       response.params.changeBy = nil
    end,
    run = function(self, actorId, params, context)
        if context.isOwner then -- Only owning host should fire counter updates
            local component = self.components[actorId]
            local changeBy = self.game:evalExpression(params.changeBy, actorId, context)
            if component then
                self:sendSetProperties(actorId, "value", component.properties.value + changeBy)
            end
        end
    end
}

CounterBehavior.responses["set counter"] = {
    description = "Modify the actor's counter",
    category = "state",
    paramSpecs = {
       setToValue = {
          label = "set to value",
          method = "numberInput",
          initialValue = 0,
       },
       relative = {
          method = "toggle",
          label = "relative",
          initialValue = false,
       },
    },
    run = function(self, actorId, params, context)
        if context.isOwner then -- Only owning host should fire counter updates
            local component = self.components[actorId]
            local setToValue = self.game:evalExpression(params.setToValue, actorId, context)
            if component then
                if params.relative then
                    self:sendSetProperties(actorId, "value", component.properties.value + setToValue)
                else
                    self:sendSetProperties(actorId, "value", setToValue)
                end
            end
        end
    end
}

-- TODO: convert to boolean expression
-- if comparison(counter expression, value expression)
CounterBehavior.responses["counter meets condition"] = {
    description = "If the actor's counter meets a condition",
    category = "state",
    returnType = "boolean",
    paramSpecs = {
       comparison = {
          method = "dropdown",
          initialValue = "equal",
          props = {
             items = COMPARISON_OPERATORS,
          },
       },
       value = {
          method = "numberInput",
          initialValue = 0,
       },
    },
    run = function(self, actorId, params, context)
        local component = self.components[actorId]
        if not component then
            return false
        end
        local value = component.properties.value
        local compareTo = self.game:evalExpression(params.value, actorId, context)
        return self.game:compare(params.comparison, value, compareTo)
    end
}
