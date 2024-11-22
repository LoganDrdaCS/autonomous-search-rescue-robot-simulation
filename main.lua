sim=require'sim'
simUI=require'simUI'

local hasFoundTarget = false
local BACKUP_TIME = 2.25 -- Time in seconds to back up before resuming forward motion

-- Define speed range constants
local MIN_SPEED = 3.5
local MAX_SPEED = 18

function sysCall_init()
    -- Proximity sensor handle to detect the target (victim)
    targetDetectionSensor = sim.getObject("../sensingNose_To_Detect") 
    -- Handle of the robot base (body)
    bubbleRobBase = sim.getObject('..') 
    -- Handle of the left and right motors for movement control
    leftMotor = sim.getObject("../leftMotor") 
    rightMotor = sim.getObject("../rightMotor") 
    -- Handle of the main proximity sensor for obstacle detection
    obstacleSensor = sim.getObject("../sensingNose") 
    -- Set the speed range for the motors
    minMaxSpeed = {MIN_SPEED, MAX_SPEED} 
    -- Time tracking for backward motion
    backUntilTime = -1 
    -- Create a collection for the robot base and add it to the collection
    robotBaseCollection = sim.createCollection(0)
    sim.addItemToCollection(robotBaseCollection, sim.handle_tree, bubbleRobBase, 0)
    -- Drawing objects for visualization
    distanceSegment = sim.addDrawingObject(sim.drawing_lines, 4, 0, -1, 1, {0,1,0})
    robotTrace = sim.addDrawingObject(sim.drawing_linestrip + sim.drawing_cyclic, 2, 0, -1, 200, {1,1,0}, nil, nil, {1,1,0})
    -- Set the sensor color to blue
    sim.setObjectColor(targetDetectionSensor, 0, sim.colorcomponent_ambient_diffuse, {0,0,1}) 
    -- Create the custom UI with a slider for speed control
    xml = '<ui title="Speed Control Slider" closeable="false" resizeable="false" activate="false" position="1350,300" placement="absolute">'..[[
                <hslider minimum="0" maximum="100" on-change="speedChange_callback" id="1"/>
            <label text="" style="* {margin-left: 300px;}"/>
        </ui>
        ]] 
    ui = simUI.create(xml)
    -- Default speed set to midpoint of min and max speeds
    speed = (minMaxSpeed[1] + minMaxSpeed[2]) * 0.5
    -- Set the initial value of the slider to reflect the default speed
    simUI.setSliderValue(ui, 1, 100 * (speed - minMaxSpeed[1])/(minMaxSpeed[2] - minMaxSpeed[1]))

end

function sysCall_sensing()
    -- Check for obstacles in the robot's environment using obstacle sensor
    local result, distData = sim.checkDistance(robotBaseCollection, sim.handle_all)
    if result > 0 then
        -- Add the obstacle data to the drawing object for visualization
        sim.addDrawingObjectItem(distanceSegment, nil)
        sim.addDrawingObjectItem(distanceSegment, distData)
    end
    -- Track and visualize the robot's position
    local p = sim.getObjectPosition(bubbleRobBase)
    sim.addDrawingObjectItem(robotTrace, p)
end

function speedChange_callback(ui, id, newVal)
    -- Maps the slider value (0-100) to the motor speed range (minMaxSpeed[1] - minMaxSpeed[2])
    -- Normalize the slider value to a range of 0.0 to 1.0:
    local normalizedValue = newVal / 100
    -- Scale the normalized value to the speed range (minMaxSpeed[1] - minMaxSpeed[2]):
    local scaledValue = normalizedValue * (minMaxSpeed[2] - minMaxSpeed[1])
    -- Add the minimum speed to get the final motor speed:
    speed = minMaxSpeed[1] + scaledValue
end

function stopRobot()
    -- Disable the UI slider when the robot has completed the task
    simUI.setEnabled(ui, 1, false)
    -- Stop the motors
    sim.setJointTargetVelocity(leftMotor, 0)
    sim.setJointTargetVelocity(rightMotor, 0)
    hasFoundTarget = true -- Mark that the task is completed
    print("Robot stopped.")
end

function sysCall_actuation()
    if not hasFoundTarget then
        -- Check if the robot is near any obstacles using obstacle sensor
        local result = sim.readProximitySensor(obstacleSensor)
        if result > 0 then
            -- Set the time to start backing up if an obstacle is detected
            backUntilTime = sim.getSimulationTime() + BACKUP_TIME -- Initiating backup mode
        end

        -- Control robot movement based on the current time and obstacle proximity
        if backUntilTime < sim.getSimulationTime() then
            -- Move forward if no obstacles are detected or after backing up
            sim.setJointTargetVelocity(leftMotor, speed)
            sim.setJointTargetVelocity(rightMotor, speed)
        else
            -- Move backward if the robot is in backup mode
            sim.setJointTargetVelocity(leftMotor, -speed / 2)
            sim.setJointTargetVelocity(rightMotor, -speed / 8)
        end

        -- Check if the target (victim) is detected
        local result_To_Detect, _, _, detectedObjectHandle = sim.readProximitySensor(targetDetectionSensor)
        if result_To_Detect > 0 and detectedObjectHandle then
            -- If the detected object is the victim (identified by 'lowerLegs')
            if sim.getObjectAlias(detectedObjectHandle) == 'lowerLegs' then
                print("Victim detected! Mission accomplished.")
                local victimPosition = sim.getObjectPosition(bubbleRobBase, -1)
                -- Print the coordinates of the victim
                print(string.format("Victim's coordinates: %.3f, %.3f", victimPosition[1], victimPosition[2]))
                -- Change the sensor color to green to indicate success
                sim.setObjectColor(targetDetectionSensor, 0, sim.colorcomponent_ambient_diffuse, {0,1,0})
                stopRobot() -- Stop the robot after successful detection
            end
        end
    end
end

function sysCall_cleanup() 
    -- Clean up the custom UI when the simulation ends
    simUI.destroy(ui)
end
