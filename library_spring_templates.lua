local DrawingData = require 'library_spring_drawing_data'

local Bee = {title = "Bee",actorBlueprint = {components = {AnalogStick = {disabled = false,turnFriction = 4,axes = "x and y",speed = 20},Tags = {disabled = false,tagsString = "bee player"},Body = {width = 0.98995000123978,disabled = false,angle = 0,widthScale = 0.1,layerName = "main",heightScale = 0.1,bodyType = "dynamic",fixtures = {{y = 0,x = 0,radius = 5,shapeType = "circle"}},massData = {0,-0.00063139200210571,6.5585389137268,1.8353781700134},editorBounds = {maxX = 7.1429,minY = -5.745000743866,minX = -7.1429003715515,maxY = 5.7323726654053},bullet = false,height = 0.98995000123978,visible = true},Moving = {vy = 0,disabled = false,vx = 0,density = 1,angularVelocity = 0},Slowdown = {disabled = false,motionSlowdown = 3,rotationSlowdown = 3},Bouncy = {disabled = false,bounciness = 0.8},Solid = {disabled = false},SpeedLimit = {disabled = false,maximumSpeed = 7},Rules = {disabled = false,rules = {{trigger = {params = {},name = "velocity changes",behaviorId = 7},response = {params = {nextResponse = {params = {},name = "face direction of motion",behaviorId = 1},note = "While the bee is moving, continually rotate it so that it faces the same direction that it is moving"},name = "note",behaviorId = 16},index = "43"},{trigger = {params = {},name = "analog stick ends",behaviorId = 21},response = {params = {behaviorId = 10},name = "enable behavior",behaviorId = 16},index = "44"},{trigger = {params = {},name = "analog stick begins",behaviorId = 21},response = {params = {nextResponse = {params = {behaviorId = 10,nextResponse = {params = {category = "random",seed = 2311,mutationSeed = 3555,mutationAmount = 5},name = "play sound",behaviorId = 16}},name = "disable behavior",behaviorId = 16},note = "The bee should slow to a stop when you stop controlling it, so it has the “Slow down” movement behavior. But when the analog stick is active we don’t want to be fighting against that effect, so it’s disabled temporarily."},name = "note",behaviorId = 16},index = "45"},{trigger = {params = {tag = "border"},name = "collide",behaviorId = 1},response = {params = {category = "hit",seed = 2719,mutationSeed = 0,mutationAmount = 5},name = "play sound",behaviorId = 16},index = "46"}}}}},entryType = "actorBlueprint",entryId = "ced19012-9d4d-4518-c5fb-9edccaa43001",description = "A bee that the player can control using the analog stick."}

Bee.base64Png = DrawingData.Bee.base64Png
Bee.actorBlueprint.components.Drawing2 = DrawingData.Bee.Drawing2

local Flower = {title = "Flower",actorBlueprint = {components = {Rules = {disabled = false,rules = {{trigger = {params = {comparison = "equal",frame = 4},name = "animation reaches frame",behaviorId = 20},response = {params = {nextResponse = {params = {value = "still",behaviorId = 20,propertyName = "playMode",relative = false,nextResponse = {params = {value = {params = {max = 2,min = 0,discrete = true},returnType = "number",expressionType = "random"},behaviorId = 20,propertyName = "currentFrame",relative = true,nextResponse = {params = {tag = "bloom"},name = "add tag",behaviorId = 17}},name = "set behavior property",behaviorId = 16}},name = "set behavior property",behaviorId = 16},note = "When the grow animation finishes, randomly switch to one of three art frames, corresponding to different colors, and add the tag “bloom” so that it’s ready to be “collected”"},name = "note",behaviorId = 16},index = "43"},{trigger = {params = {tag = "collected"},name = "gain tag",behaviorId = 17},response = {params = {nextResponse = {params = {behaviorId = 20,propertyName = "currentFrame",relative = false,value = 7},name = "set behavior property",behaviorId = 16},note = "When flower is marked as “collected”, switch to the art frame depicting a picked flower"},name = "note",behaviorId = 16},index = "44"},{trigger = {params = {tag = "bee"},name = "collide",behaviorId = 1},response = {params = {nextResponse = {params = {["then"] = {params = {nextResponse = {params = {nextResponse = {params = {category = "pickup",seed = 7272,mutationSeed = 0,mutationAmount = 5},name = "play sound",behaviorId = 16},tag = "collected"},name = "add tag",behaviorId = 17},tag = "bloom"},name = "remove tag",behaviorId = 17},condition = {params = {tag = "bloom"},name = "has tag",behaviorId = 17}},name = "if",behaviorId = 16},note = "If the bee collides with the flower, and the flower is finished blooming, mark the flower as having been “collected”"},name = "note",behaviorId = 16},index = "45"},{trigger = {params = {},name = "create",behaviorId = 16},response = {params = {nextResponse = {params = {duration = {params = {max = 3,min = 0,discrete = false},returnType = "number",expressionType = "random"},nextResponse = {params = {behaviorId = 20,propertyName = "playMode",relative = false,value = "play once"},name = "set behavior property",behaviorId = 16}},name = "wait",behaviorId = 16},note = "After a random delay, start playing the flower growing animation"},name = "note",behaviorId = 16},index = "46"}}},Tags = {disabled = false,tagsString = "flower"},Body = {width = 0.98995000123978,disabled = false,angle = 0,widthScale = 0.12499999523163,layerName = "main",heightScale = 0.125,bodyType = "kinematic",fixtures = {{y = -5.7142857142857,x = -0.71428571428571,radius = 3.5714285714285,shapeType = "circle"}},massData = {0,0,0,0},editorBounds = {maxX = 2.1429001331329,minY = 0.1,minX = -2.1443437576294,maxY = 10.00000038147},bullet = false,height = 0.98995000123978,visible = true},RotatingMotion = {disabled = false,vy = 0,rotationsPerSecond = 0,vx = 0}}},entryType = "actorBlueprint",entryId = "e169fa13-ec48-405f-c0f8-0d83701814c1",description = "An animated 🌻 that blooms random blossoms for Bees to collect."}

Flower.base64Png = DrawingData.Flower.base64Png
Flower.actorBlueprint.components.Drawing2 = DrawingData.Flower.Drawing2

local GrassBackground = {title = "Grass Background",actorBlueprint = {components = {Tags = {disabled = false,tagsString = ""},Body = {width = 0.98995000123978,disabled = false,angle = 0,widthScale = 0.69999997329712,layerName = "main",heightScale = 0.69999997329712,bodyType = "static",fixtures = {{points = {-5,-5,-5,5,5,5,5,-5},shapeType = "polygon"}},massData = {0,0,0,0},editorBounds = {maxX = 7.1429,minY = -10.00000038147,minX = -7.1429,maxY = 10.00000038147},bullet = false,height = 0.98995000123978,visible = true}}},entryType = "actorBlueprint",entryId = "66419ef9-adb5-418a-c1d4-fb7f8fdb5664",description = "A simple static background the same size as the card."}

GrassBackground.base64Png = DrawingData.GrassBackground.base64Png
GrassBackground.actorBlueprint.components.Drawing2 = DrawingData.GrassBackground.Drawing2

local BushBorder = {title = "Bush Border",entryType = "actorBlueprint",entryId = "7416b8c4-76e6-406e-c03d-e6707652e315",description = "Four walls of bushes that keep solid actors inside the card.",actorBlueprint = {components = {RotatingMotion = {disabled = false,vy = 0,rotationsPerSecond = 0,vx = 0},Tags = {disabled = false,tagsString = "border"},Solid = {disabled = false},Body = {width = 0.98995000123978,disabled = false,angle = 0,widthScale = 0.69999997329712,layerName = "main",heightScale = 0.69999997329712,bodyType = "kinematic",fixtures = {{points = {-7.1428571428571,-9.9999999999999,-7.1428571428571,-8.5714285714285,7.1428571428571,-8.5714285714285,7.1428571428571,-9.9999999999999},shapeType = "polygon"},{points = {-7.1428571428571,8.5714285714285,-7.1428571428571,-8.5714285714285,-6.4285714285714,-8.5714285714285,-6.4285714285714,8.5714285714285},shapeType = "polygon"},{points = {6.4285714285714,-8.5714285714285,6.4285714285714,8.5714285714285,7.1428571428571,8.5714285714285,7.1428571428571,-8.5714285714285},shapeType = "polygon"},{points = {-7.1428571428571,8.5714285714285,-7.1428571428571,9.9999999999999,7.1428571428571,9.9999999999999,7.1428571428571,8.5714285714285},shapeType = "polygon"}},massData = {0,0,0,0},editorBounds = {maxX = 7.1429003715515,minY = -10.00000038147,minX = -7.1429003715515,maxY = 10.00000038147},bullet = false,height = 0.98995000123978,visible = true}}}}

BushBorder.base64Png = DrawingData.BushBorder.base64Png
BushBorder.actorBlueprint.components.Drawing2 = DrawingData.BushBorder.Drawing2

local SPRING_TEMPLATES = {
   Bee,
   Flower,
   GrassBackground,
   BushBorder,
}

return SPRING_TEMPLATES
