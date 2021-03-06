Common:defineExpression(
   "+", {
      returnType = "number",
      category = "arithmetic",
      order = 1,
      description = "add",
      paramSpecs = {
         lhs = {
            label = "Left operand",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Right operand",
            method = "numberInput",
            initialValue = 0,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return lhs + rhs
      end,
   }
)

Common:defineExpression(
   "*", {
      returnType = "number",
      category = "arithmetic",
      order = 2,
      description = "multiply",
      paramSpecs = {
         lhs = {
            label = "Left operand",
            method = "numberInput",
            initialValue = 1,
            order = 1,
         },
         rhs = {
            label = "Right operand",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return lhs * rhs
      end,
   }
)

Common:defineExpression(
   "-", {
      returnType = "number",
      category = "arithmetic",
      order = 3,
      description = "subtract",
      paramSpecs = {
         lhs = {
            label = "Left operand",
            method = "numberInput",
            initialValue = 0,
            order = 1,
         },
         rhs = {
            label = "Right operand",
            method = "numberInput",
            initialValue = 0,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return lhs - rhs
      end,
   }
)

Common:defineExpression(
   "/", {
      returnType = "number",
      category = "arithmetic",
      order = 4,
      description = "divide",
      paramSpecs = {
         lhs = {
            label = "Numerator",
            method = "numberInput",
            initialValue = 1,
            order = 1,
         },
         rhs = {
            label = "Denominator",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         if rhs == 0 then
            return 0
         end
         return lhs / rhs
      end,
   }
)

Common:defineExpression(
   "%", {
      returnType = "number",
      category = "arithmetic",
      description = "modulo",
      paramSpecs = {
         lhs = {
            label = "Left operand",
            method = "numberInput",
            initialValue = 1,
            order = 1,
         },
         rhs = {
            label = "Right operand",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         if rhs == 0 then
            return 0
         end
         return lhs % rhs
      end,
   }
)

Common:defineExpression(
   "^", {
      returnType = "number",
      category = "arithmetic",
      description = "power",
      paramSpecs = {
         lhs = {
            label = "Base",
            method = "numberInput",
            initialValue = 1,
            order = 1,
         },
         rhs = {
            label = "Exponent",
            method = "numberInput",
            initialValue = 1,
            order = 2,
         },
      },
      eval = function(game, expression, actorId, context)
         local lhs, rhs = game:evalExpression(expression.params.lhs, actorId, context), game:evalExpression(expression.params.rhs, actorId, context)
         return lhs ^ rhs
      end,
   }
)

Common:defineExpression(
   "log", {
      returnType = "number",
      category = "arithmetic",
      description = "logarithm",
      paramSpecs = {
         base = {
            label = "Base",
            method = "numberInput",
            initialValue = 2,
         },
         number = {
            label = "Number",
            method = "numberInput",
            initialValue = 1,
         },
      },
      eval = function(game, expression, actorId, context)
         local base, x = game:evalExpression(expression.params.base, actorId, context), game:evalExpression(expression.params.number, actorId, context)
         return math.log(x) / math.log(base)
      end,
   }
)
