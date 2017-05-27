
local fs = require("filesystem")
local image = require("image")
local buffer = require("doubleBuffering")
local GUI = require("GUI")
local component = require("component")
local unicode = require("unicode")
local MineOSCore = require("MineOSCore")
if not component.isAvailable("stargate") then
	GUI.error("This program requires stargate from mod \"SGCraft\"")
	return
end
local stargate = component.stargate

---------------------------------------------------------------------------------------------

local resources = MineOSCore.getCurrentApplicationResourcesDirectory()
local pathToContacts = "MineOS/System/Stargate/Contacts3.cfg"
local contacts = {}
local Ch1Image = image.load(resources .. "Ch1.pic")
local Ch2Image = image.load(resources .. "Ch2.pic")

buffer.start()
local mainContainer = GUI.fullScreenContainer()

---------------------------------------------------------------------------------------------

local function loadContacts()
	if fs.exists(pathToContacts) then
		contacts = table.fromFile(pathToContacts)
	end
end

local function saveContacts()
	table.toFile(pathToContacts, contacts)
end

local function chevronDraw(object)
	local inactiveColor, activeColor, fadeColor = 0x332400, 0xFFDB00, 0xCC6D00
	-- buffer.square(object.x, object.y, object.width, object.height, object.isActivated and fadeColor or inactiveColor)
	-- buffer.square(object.x + 1, object.y, 3, object.height, object.isActivated and activeColor or inactiveColor)
	-- buffer.text(object.x + 2, object.y + 1, object.isActivated and 0x0 or 0xFFFFFF, object.text)
	buffer.image(object.x, object.y, object.isActivated and Ch1Image or Ch2Image)
	return object
end

local function newChevronObject(x, y)
	local object = GUI.object(x, y, 5, 3)

	object.draw = chevronDraw
	object.isActivated = false
	object.text = " "

	return object
end

local function addChevron(x, y)
	table.insert(mainContainer.chevrons, mainContainer.chevronsContainer:addChild(newChevronObject(x, y)))
end

local function updateChevrons(state)
	for i = 1, #mainContainer.chevrons do
		mainContainer.chevrons[i].isActivated = state
		if not state then mainContainer.chevrons[i].text = " " end
	end
end

local function update()
	local stargateState, irisState, imagePath = stargate.stargateState(), stargate.irisState()
	mainContainer.irisButton.text = irisState == "Closed" and "Open Iris" or "Close Iris"
	mainContainer.connectionButton.text = stargateState == "Connected" and "Disconnect" or "Connect"
	mainContainer.connectedToLabel.text = stargateState == "Connected" and "(Connected to " .. stargate.remoteAddress() .. ")" or "(Not connected)"
	
	if stargateState == "Connected" then
		mainContainer.connectContactButton.disabled = true
		mainContainer.messageContactButton.disabled = false

		if irisState == "Closed" then
			imagePath = "OnOn.pic"
		else
			imagePath = "OnOff.pic"
		end
	else
		mainContainer.connectContactButton.disabled = false
		mainContainer.messageContactButton.disabled = true

		if irisState == "Closed" then
			imagePath = "OffOn.pic"
		else
			imagePath = "OffOff.pic"
		end
	end
	mainContainer.SGImage.image = image.load(resources .. imagePath)
end

local function updateContacts()
	mainContainer.contactsComboBox.items = {}
	if #contacts == 0 then
		mainContainer.contactsComboBox:addItem("No contacts found")
	else
		for i = 1, #contacts do
			mainContainer.contactsComboBox:addItem(contacts[i].name)
		end
	end
end

local function newThing(x, y, width, height)
	local object = GUI.object(x, y, width, height)
	
	object.draw = function(object)
		local x, y = object.x + object.width - 1, math.floor(object.y + object.height / 2)
		for i = object.y, object.y + object.height - 1 do
			buffer.text(x, i, 0xEEEEEE, "│")
		end
		for i = object.x, object.x + width - 1 do
			buffer.text(i, y, 0xEEEEEE, "─")
		end
		buffer.text(x, y, 0xEEEEEE, "┤")
	end

	return object
end

local function dial(address)
	local success = stargate.dial(address)
	if success then
		mainContainer.fuelProgressBar.value = math.ceil(stargate.energyToDial(address) / stargate.energyAvailable() * 100)
		mainContainer:draw()
		buffer.draw()
	end
end

---------------------------------------------------------------------------------------------

mainContainer:addChild(GUI.panel(1, 1, mainContainer.width, mainContainer.height, 0x1E1E1E))
mainContainer.SGImage = mainContainer:addChild(GUI.image(1, 1, image.load(resources .. "OffOff.pic")))
mainContainer.chevronsContainer = mainContainer:addChild(GUI.container(mainContainer.SGImage.localPosition.x, mainContainer.SGImage.localPosition.y, mainContainer.SGImage.width, mainContainer.SGImage.height))
mainContainer.chevrons = {}
addChevron(13, 30)
addChevron(8, 17)
addChevron(21, 6)
addChevron(45, 1)
addChevron(72, 6)
addChevron(83, 17)
addChevron(79, 30)

local width, height = 32, 37
local x, y = mainContainer.width - width - 3, math.floor(mainContainer.height / 2 - height / 2)

mainContainer.SGImage.localPosition.x, mainContainer.SGImage.localPosition.y = math.floor((x - 2) / 2 - image.getWidth(mainContainer.SGImage.image) / 2), mainContainer.height - image.getHeight(mainContainer.SGImage.image) + 1
mainContainer.chevronsContainer.localPosition = mainContainer.SGImage.localPosition

mainContainer:addChild(newThing(mainContainer.SGImage.localPosition.x + mainContainer.SGImage.width, y, mainContainer.width - mainContainer.SGImage.localPosition.x - mainContainer.SGImage.width - width - 7,  height))

mainContainer:addChild(GUI.label(x, y, width, 1, 0xEEEEEE, "Stargate " .. stargate.localAddress())):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.top); y = y + 1
mainContainer.connectedToLabel = mainContainer:addChild(GUI.label(x, y, width, 1, 0x555555, "(Not connected)")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.top); y = y + 2
mainContainer.connectionButton = mainContainer:addChild(GUI.framedButton(x, y, width, 3, 0xEEEEEE, 0xEEEEEE, 0xBBBBBB, 0xBBBBBB, "Connect")); y = y + 3
mainContainer.connectionButton.onTouch = function()
	if stargate.stargateState() == "Idle" then
		local container = MineOSCore.addUniversalContainer(mainContainer, "Connect")
		local inputTextBox = container.layout:addChild(GUI.inputTextBox(1, 1, 36, 3, 0xEEEEEE, 0x666666, 0xEEEEEE, 0x262626, contacts.last, "Type address here"))
		inputTextBox.onInputFinished = function()
			if inputTextBox.text then
				dial(inputTextBox.text)
				contacts.last = inputTextBox.text
				saveContacts()
				container:delete()

				mainContainer:draw()
				buffer.draw()
			end
		end

		container.panel.eventHandler = function()
			inputTextBox.onInputFinished()
		end

		mainContainer:draw()
		buffer.draw()
	else
		stargate.disconnect()
	end
end

mainContainer.irisButton = mainContainer:addChild(GUI.framedButton(x, y, width, 3, 0xEEEEEE, 0xEEEEEE, 0xBBBBBB, 0xBBBBBB, "Open Iris")); y = y + 3
mainContainer.irisButton.onTouch = function()
	if stargate.irisState() == "Open" then
		stargate.closeIris()
	else
		stargate.openIris()
	end
end

mainContainer.messageContactButton = mainContainer:addChild(GUI.framedButton(x, y, width, 3, 0xEEEEEE, 0xEEEEEE, 0xBBBBBB, 0xBBBBBB, "Message")); y = y + 4
mainContainer.messageContactButton.onTouch = function()
	local container = MineOSCore.addUniversalContainer(mainContainer, "Message")
	local inputTextBox = container.layout:addChild(GUI.inputTextBox(1, 1, 36, 3, 0xEEEEEE, 0x666666, 0xEEEEEE, 0x262626, nil, "Type message text here"))
	inputTextBox.onInputFinished = function()
		if inputTextBox.text then
			container:delete()
			stargate.sendMessage(inputTextBox.text)

			mainContainer:draw()
			buffer.draw()
		end
	end

	container.panel.eventHandler = function()
		inputTextBox.onInputFinished()
	end

	mainContainer:draw()
	buffer.draw()
end

mainContainer:addChild(GUI.label(x, y, width, 1, 0xEEEEEE, "Contacts")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.top); y = y + 2
mainContainer.contactsComboBox = mainContainer:addChild(GUI.comboBox(x, y, width, 3, 0x3C3C3C, 0xBBBBBB, 0x555555, 0x888888)); y = y + 4

mainContainer.connectContactButton = mainContainer:addChild(GUI.framedButton(x, y, width, 3, 0xEEEEEE, 0xEEEEEE, 0xBBBBBB, 0xBBBBBB, "Connect")); y = y + 3
mainContainer.connectContactButton.onTouch = function()
	if #contacts > 0 then
		dial(contacts[mainContainer.contactsComboBox.selectedItem].address)
	end
end

mainContainer.addContactButton = mainContainer:addChild(GUI.framedButton(x, y, width, 3, 0xEEEEEE, 0xEEEEEE, 0xBBBBBB, 0xBBBBBB, "Add contact")); y = y + 3
mainContainer.addContactButton.onTouch = function()
	local container = MineOSCore.addUniversalContainer(mainContainer, "Add contact")
	local inputTextBox1 = container.layout:addChild(GUI.inputTextBox(1, 1, 36, 3, 0xEEEEEE, 0x666666, 0xEEEEEE, 0x262626, nil, "Name"))
	local inputTextBox2 = container.layout:addChild(GUI.inputTextBox(1, 1, 36, 3, 0xEEEEEE, 0x666666, 0xEEEEEE, 0x262626, contacts.last, "Address"))

	container.panel.eventHandler = function(mainContainer, object, eventData)
		if eventData[1] == "touch" then
			if inputTextBox1.text and inputTextBox2.text then
				local exists = false
				for i = 1, #contacts do
					if contacts[i].address == inputTextBox2.text then
						exists = true
						break
					end
				end
				if not exists then
					table.insert(contacts, {name = inputTextBox1.text, address = inputTextBox2.text})
					updateContacts()
					saveContacts()	
				end

				container:delete()
				mainContainer:draw()
				buffer.draw()
			end
		end
	end

	mainContainer:draw()
	buffer.draw()
end

mainContainer.removeContactButton = mainContainer:addChild(GUI.framedButton(x, y, width, 3, 0xEEEEEE, 0xEEEEEE, 0xBBBBBB, 0xBBBBBB, "Remove contact")); y = y + 4
mainContainer.removeContactButton.onTouch = function()
	if #contacts > 0 then
		table.remove(contacts, mainContainer.contactsComboBox.selectedItem)
		updateContacts()
		saveContacts()

		mainContainer:draw()
		buffer.draw()
	end
end

mainContainer:addChild(GUI.label(x, y, width, 1, 0xEEEEEE, "Energy to dial")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.top); y = y + 2
mainContainer.fuelProgressBar = mainContainer:addChild(GUI.progressBar(x, y, width, 0xBBBBBB, 0x0, 0xEEEEEE, 100, true, true, "", "%")); y = y + 3
mainContainer.exitButton = mainContainer:addChild(GUI.framedButton(x, y, width, 3, 0xEEEEEE, 0xEEEEEE, 0xBBBBBB, 0xBBBBBB, "Exit")); y = y + 4
mainContainer.exitButton.onTouch = function()
	mainContainer:stopEventHandling()
end

mainContainer.eventHandler = function(mainContainer, object, eventData)
	if eventData[1] == "sgIrisStateChange" then
		update()
		mainContainer:draw()
		buffer.draw()
	elseif eventData[1] == "sgStargateStateChange" then
		if eventData[3] == "Idle" or eventData[3] == "Connected" then
			update()
			updateChevrons(eventData[3] == "Connected")
			mainContainer:draw()
			buffer.draw()
		end
	elseif eventData[1] == "sgChevronEngaged" then
		if mainContainer.chevrons[eventData[3]] then
			mainContainer.chevrons[eventData[3]].isActivated = true
			mainContainer.chevrons[eventData[3]].text = eventData[4]
			mainContainer:draw()
			buffer.draw()
		end
	elseif eventData[1] == "sgMessageReceived" then
		GUI.error(eventData[3])
	end
end

loadContacts()
updateContacts()
update()
updateChevrons(stargate.stargateState() == "Connected")
mainContainer:draw()
buffer.draw()
mainContainer:startEventHandling()








