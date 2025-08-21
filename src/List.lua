-- Main LibLootSummary List class definition and utility functions


--[[
LibLootSummary.List - Main class for loot and currency summary logic

Purpose: Handles collection, formatting, and output of item/currency summaries to chat.
Features: Supports configurable options, integration with LibAddonMenu, and developer diagnostics.

Key Methods:
- AddCurrency, AddItem, AddItemId, AddItemLink: Add entries to summary
- Print: Output formatted summary to chat
- GenerateLam2ItemOptions/GenerateLam2LootOptions: Create LibAddonMenu controls

Maintainer Notes:
- Inline comments clarify function purpose and logic
- Lint errors for missing ESO globals are expected in local dev, not in-game
- LAM2 options are generated via a data-driven approach in lam2OptionData
]]

local lls = LibLootSummary

-- Constant for the character length of an icon in chat
local ICON_CHAT_LINK_LENGTH = 2


-- List class: Handles loot/currency summary logic and chat output
local List = ZO_Object:Subclass()
lls.List = List

local addQuantity, appendText, coalesce, defaultChat, getChildTable, mergeTables, sortByCurrencyName, sortByItemName, sortByQuality, isSetItemNotCollected, formatCount, getPlural
local qualityChoices, qualityChoicesValues, delimiterChoices, delimiterChoicesValues
local createLam2Option
local GetItemLinkFunctionalQuality, ZO_CachedStrFormat, GetCurrencyName = GetItemLinkFunctionalQuality, ZO_CachedStrFormat, GetCurrencyName
local zo_strsub, zo_strgsub, zo_strlen, zo_min, zo_strformat = zo_strsub, zo_strgsub, zo_strlen, zo_min, zo_strformat
local tostring, pairs, ipairs = tostring, pairs, ipairs
local tableInsert, stringFormat, tableSort, stringFind = table.insert, string.format, table.sort, string.find
local linkFormat = "|H%s:item:%s:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
local collectionIcon = "EsoUI/Art/treeicons/gamepad/achievement_categoryicon_collections.dds"
local CHAT_DEFAULTS, OPTIONS_DEFAULTS, RENAMED_OPTIONS, lam2OptionData


-- Create a new List instance with provided options
function lls.List:New(options)
    local instance = ZO_Object.New(self)
    instance:Initialize(options)
    return instance
end


-- Initialize List instance, set defaults and chat proxy
function lls.List:Initialize(params)
    self:Reset()
    if params == nil then
        params = {}
    end
    for chatSetting, chatDefault in pairs(CHAT_DEFAULTS) do
        self[chatSetting] = coalesce(params[chatSetting], chatDefault)
    end
    -- Ensure chat proxy has Print function
    if type(self.chat.Print) ~= "function" then
        self.chat = CHAT_DEFAULTS.chat
    end
    self.options = params
    self.defaults = {}
    self.counter = 0
end


-- Add a currency entry to the summary
function lls.List:AddCurrency(currencyType, quantity)
    assert(currencyType ~= nil, "LibLootSummary: currencyType must not be nil.")
    assert(type(quantity) == "number" and quantity >= 0, "LibLootSummary: quantity must be a non-negative number.")
    if not self:IsEnabled() then
        return
    end
    addQuantity(self.currencyList, self.currencyKeys, currencyType, quantity, self:GetOption('combineDuplicates'))
end

-- Add an item from bag/slot to the summary
function lls.List:AddItem(bagId, slotIndex, quantity)
    assert(bagId ~= nil and slotIndex ~= nil, "LibLootSummary: bagId and slotIndex must not be nil.")
    if not self:IsEnabled() then
        return
    end
    if not quantity then
        local stackSize, maxStackSize = GetSlotStackSize(bagId, slotIndex)
        quantity = zo_min(stackSize, maxStackSize)
    end
    assert(type(quantity) == "number" and quantity > 0, "LibLootSummary: quantity must be a positive number.")
    self:AddItemLink(GetItemLink(bagId, slotIndex, self:GetOption('linkStyle')), quantity, true)
end

-- Add an item by itemId to the summary
function lls.List:AddItemId(itemId, quantity)
    assert(itemId ~= nil, "LibLootSummary: itemId must not be nil.")
    assert(type(quantity) == "number" and quantity > 0, "LibLootSummary: quantity must be a positive number.")
    if not self:IsEnabled() then
        return
    end
    self:AddItemLink(stringFormat(linkFormat, self:GetOption('linkStyle'), itemId), quantity, true)
end

-- Add an item by itemLink to the summary
function lls.List:AddItemLink(itemLink, quantity, dontChangeStyle)
    assert(itemLink ~= nil, "LibLootSummary: itemLink must not be nil.")
    assert(type(quantity) == "number" and quantity > 0, "LibLootSummary: quantity must be a positive number.")
    if not self:IsEnabled() then
        return
    end
    if not dontChangeStyle then
        itemLink = zo_strgsub(itemLink, "|H[0-1]:", "|H"..tostring(self:GetOption('linkStyle')).. ":")
    end
    addQuantity(self.itemList, self.itemKeys, itemLink, quantity, self:GetOption('combineDuplicates'))
end


local function generateLam2Options(self, addonName, options, defaults, optionType, ...)
    self:SetOptions(options, defaults, ...)

    local SIs = {
        ITEM = {
            SUMMARY = SI_LLS_ITEM_SUMMARY,
            SUMMARY_TOOLTIP = SI_LLS_ITEM_SUMMARY_TOOLTIP,
            MIN_QUALITY = SI_LLS_MIN_ITEM_QUALITY,
            MIN_QUALITY_TOOLTIP = SI_LLS_MIN_ITEM_QUALITY_TOOLTIP,
            SHOW_ICONS = SI_LLS_SHOW_ITEM_ICONS,
            SHOW_ICONS_TOOLTIP = SI_LLS_SHOW_ITEM_ICONS_TOOLTIP,
            SHOW_NOT_COLLECTED = SI_LLS_SHOW_ITEM_NOT_COLLECTED,
            SHOW_NOT_COLLECTED_TOOLTIP = SI_LLS_SHOW_ITEM_NOT_COLLECTED_TOOLTIP,
            SHOW_TRAITS = SI_LLS_SHOW_ITEM_TRAITS,
            SHOW_TRAITS_TOOLTIP = SI_LLS_SHOW_ITEM_TRAITS_TOOLTIP,
            HIDE_SINGLE_QTY = SI_LLS_HIDE_ITEM_SINGLE_QTY,
            HIDE_SINGLE_QTY_TOOLTIP = SI_LLS_HIDE_ITEM_SINGLE_QTY_TOOLTIP,
        },
        LOOT = {
            SUMMARY = SI_LLS_LOOT_SUMMARY,
            SUMMARY_TOOLTIP = SI_LLS_LOOT_SUMMARY_TOOLTIP,
            MIN_QUALITY = SI_LLS_MIN_LOOT_QUALITY,
            MIN_QUALITY_TOOLTIP = SI_LLS_MIN_LOOT_QUALITY_TOOLTIP,
            SHOW_ICONS = SI_LLS_SHOW_LOOT_ICONS,
            SHOW_ICONS_TOOLTIP = SI_LLS_SHOW_LOOT_ICONS_TOOLTIP,
            SHOW_NOT_COLLECTED = SI_LLS_SHOW_LOOT_NOT_COLLECTED,
            SHOW_NOT_COLLECTED_TOOLTIP = SI_LLS_SHOW_LOOT_NOT_COLLECTED_TOOLTIP,
            SHOW_TRAITS = SI_LLS_SHOW_LOOT_TRAITS,
            SHOW_TRAITS_TOOLTIP = SI_LLS_SHOW_LOOT_TRAITS_TOOLTIP,
            HIDE_SINGLE_QTY = SI_LLS_HIDE_LOOT_SINGLE_QTY,
            HIDE_SINGLE_QTY_TOOLTIP = SI_LLS_HIDE_LOOT_SINGLE_QTY_TOOLTIP,
        },
    }

    local strings = SIs[optionType]
	local controls = {}
	for _, data in ipairs(lam2OptionData) do
		table.insert(controls, createLam2Option(self, data, addonName, strings))
	end
	return unpack(controls)
end

-- Generate LibAddonMenu option controls for item summary settings
function lls.List:GenerateLam2ItemOptions(addonName, options, defaults, ...)
    return generateLam2Options(self, addonName, options, defaults, 'ITEM', ...)
end


-- Generate LibAddonMenu option controls for loot summary settings
function lls.List:GenerateLam2LootOptions(addonName, options, defaults, ...)
    return generateLam2Options(self, addonName, options, defaults, 'LOOT', ...)
end

function lls.List:GetOption(key)
    assert(key ~= nil, "LibLootSummary: option key must not be nil.")
    assert(OPTIONS_DEFAULTS[key] ~= nil, "LibLootSummary: option key '" .. tostring(key) .. "' is not valid.")
    if self.options and self.options[key] ~= nil then
        return self.options[key]
    end
    if self.defaults then
        return self.defaults[key]
    end
end

function lls.List:IncrementCounter()
    self.counter = self.counter + 1
end

--[[ Outputs a verbose summary of all loot and currency ]]
function lls.List:Print()

    if not self:IsEnabled() then
        return
    end

    local lines = {}
    local summary = ""
    local maxLength = (self.chat.maxCharsPerLine or 1200) - ZoUTF8StringLength(self.prefix) - ZoUTF8StringLength(self.suffix)

    -- Add items summary
    if self:GetOption('sortedByQuality') then
        tableSort(self.itemKeys, sortByQuality)
    elseif self:GetOption('sorted') then
        tableSort(self.itemKeys, sortByItemName)
    end

    local quality, quantities, countString, iconStringLength
    for _, itemLink in ipairs(self.itemKeys) do
        quality = GetItemLinkFunctionalQuality(itemLink)
        if quality >= self:GetOption('minQuality') then
            quantities = self.itemList[itemLink]
            if quantities then
                for _, quantity in ipairs(quantities) do
                    local itemString = itemLink
                    iconStringLength = 0
                    if self:GetOption('showNotCollected') and isSetItemNotCollected(itemLink) then
                        local iconSize = stringFormat("%s%%", tostring(self:GetOption('iconSize')))
                        local iconString = zo_iconFormatInheritColor(collectionIcon, iconSize, iconSize)
                        if not self.chat.isDefault then
                            iconStringLength = zo_strlen(iconString)
                        end
                        itemString = itemString .. iconString
                    end
                    if self:GetOption('showTrait') and GetItemLinkEquipType(itemLink) ~= EQUIP_TYPE_INVALID then
                        local traitType = GetItemLinkTraitInfo(itemLink)
                        if traitType and traitType > 0 then
                            itemString = stringFormat("%s (%s)", itemString, GetString("SI_ITEMTRAITTYPE", traitType))
                        end
                    end
                    if not self:GetOption('hideSingularQuantities') or quantity > 1 then
                        countString = ZO_CachedStrFormat(GetString(SI_HOOK_POINT_STORE_REPAIR_KIT_COUNT), ZO_CommaDelimitNumber(quantity))
                        itemString = stringFormat("%s %s", itemString, countString)
                    end
                    if self:GetOption('showIcon') then
                        local iconSize = stringFormat("%s%%", tostring(self:GetOption('iconSize')))
                        local iconString = zo_iconFormat(GetItemLinkIcon(itemLink), iconSize, iconSize)
                        if not self.chat.isDefault then
                            iconStringLength = iconStringLength + zo_strlen(iconString)
                        end
                        itemString = iconString .. itemString
                    end
                    summary = appendText(itemString, summary, maxLength, lines, self:GetOption('delimiter'), self.prefix, iconStringLength)
                end
            else
                error("LibLootSummary: itemList missing quantities for " .. tostring(itemLink))
            end
        end
    end

    -- Add money summary
    if self:GetOption('sorted') then
        tableSort(self.currencyKeys, sortByCurrencyName)
    end

    for _, currencyType in ipairs(self.currencyKeys) do
        quantities = self.currencyList[currencyType]
        -- fix race condition for when multiple threads call Print at the same time
        if quantities then
            for _, quantity in ipairs(quantities) do
                local moneyString = GetCurrencyName(currencyType, IsCountSingularForm(quantity))
                countString = quantity > 0 and ZO_CachedStrFormat(GetString(SI_HOOK_POINT_STORE_REPAIR_KIT_COUNT), ZO_CommaDelimitNumber(quantity)) or tostring(quantity)
                moneyString = stringFormat("%s %s", moneyString, countString)
                iconStringLength = 0
                if self:GetOption('showIcon') then
                    local currencyIcon = ZO_Currency_GetPlatformFormattedCurrencyIcon(currencyType)
                    if not self.chat.isDefault then
                        iconStringLength = zo_strlen(currencyIcon)
                    end
                    moneyString = currencyIcon .. moneyString
                end
                summary = appendText(moneyString, summary, maxLength, lines, self:GetOption('delimiter'), self.prefix, iconStringLength)
            end
        else
            error("LibLootSummary: currencyList missing quantities for " .. GetCurrencyName(currencyType, false))
        end
    end
    
    -- Add counter text, if the summary is not empty and the counter is > 0
    if self:GetOption('showCounter') and self.counter > 0 then
        if self.counterText and self.counterText ~= "" and (#lines > 0 or summary ~= "") then
            local text = formatCount(self.counterText, self.counter)
            summary = appendText(text, summary, maxLength, lines, self:GetOption('delimiter'), self.prefix, iconStringLength)
        end
    end

    -- Append last line
    if ZoUTF8StringLength(summary) > ZoUTF8StringLength(self.prefix) then
        tableInsert(lines, summary)
    end

    -- Print to chat
    if #lines == 0 then
        error("LibLootSummary: Print called but no summary lines were generated.")
    end
    for i, line in ipairs(lines) do
        self.chat:Print(self.prefix .. line .. self.suffix)
    end

    self:Reset()
end

function lls.List:Reset()
    if self.itemList then
        ZO_ClearTable(self.itemList)
    end
    self.itemList = {}
    self.itemKeys = {}
    if self.currencyList then
        ZO_ClearTable(self.currencyList)
    end
    self.currencyList = {}
    self.currencyKeys = {}
    self.counter = 0
end

function lls.List:SetCombineDuplicates(combineDuplicates)
    self:SetOption('combineDuplicates', combineDuplicates)
end

function lls.List:SetCounterText(counterText)
    self.counterText = counterText
end

function lls.List:SetDelimiter(delimiter)
    self:SetOption('delimiter', delimiter)
end

function lls.List:SetEnabled(enabled)
    self:SetOption('enabled', enabled)
end

function lls.List:IsEnabled()
    return self:GetOption('enabled')
end

function lls.List:SetHideSingularQuantities(hideSingularQuantities)
    self:SetOption('hideSingularQuantities', hideSingularQuantities)
end

function lls.List:SetLinkStyle(linkStyle)
    self:SetOption('linkStyle', linkStyle)
end

function lls.List:SetMinQuality(quality)
    self:SetOption('minQuality', quality)
end

function lls.List:SetOption(key, value)
    if OPTIONS_DEFAULTS[key] ~= nil then
        self.options[key] = value
    end
end

function lls.List:SetOptions(options, defaults, ...)
    if defaults == nil then
        defaults = {}
    end
    local optionsKeys = {...}
    if #optionsKeys > 0 then
        defaults = getChildTable(defaults, optionsKeys)
        local parent = options
        options = getChildTable(parent, optionsKeys)
        options = setmetatable({}, 
            {
                __index = function(_, key)
                    local childTable = getChildTable(parent, optionsKeys)
                    return childTable[key]
                end,
                __newindex = function(_, key, value)
                    local childTable = getChildTable(parent, optionsKeys)
                    childTable[key] = value
                end,
            })
    end
    
    for oldField, newField in pairs(RENAMED_OPTIONS) do
        if defaults[oldField] ~= nil then
            defaults[newField] = defaults[oldField]
            defaults[oldField] = nil
        end
        if options[oldField] ~= nil then
            if options[newField] == nil then
                options[newField] = options[oldField]
            end
            options[oldField] = nil
        end
    end
    
    defaults = mergeTables(defaults, OPTIONS_DEFAULTS)
    
    -- Carry over options from the constructor, if any were passed there
    for field, _ in pairs(OPTIONS_DEFAULTS) do
        if options[field] == nil then
            options[field] = self.options[field]
        end
    end
    
    -- Initialize values if not yet done
    for field, defaultValue in pairs(defaults) do
        if options[field] == nil then
            options[field] = defaultValue
        end
    end
    
    self.options = options
    self.defaults = defaults
end

function lls.List:SetPrefix(prefix)
    self.prefix = prefix
end

function lls.List:SetShowCounter(showCounter)
    self:SetOption('showCounter', showCounter)
end

function lls.List:SetShowIcon(showIcon)
    self:SetOption('showIcon', showIcon)
end

function lls.List:SetIconSize(iconSize)
    self:SetOption('iconSize', iconSize)
end

function lls.List:SetShowTrait(showTrait)
    self:SetOption('showTrait', showTrait)
end

function lls.List:SetShowNotCollected(showNotCollected)
    self:SetOption('showNotCollected', showNotCollected)
end

function lls.List:SetSorted(sorted)
    self:SetOption('sorted', sorted)
end

function lls.List:SetSortedByQuality(sortedByQuality)
    self:SetOption('sortedByQuality', sortedByQuality)
end

function lls.List:SetSuffix(suffix)
    self.suffix = suffix
end

function lls.List:UseLibChatMessage(chat)
    self.chat = chat
end


-- Local functions

function addQuantity(list, keys, key, quantity, combineDuplicates)
    if list[key] then
        if combineDuplicates then
            list[key][1] = list[key][1] + quantity
        else
            tableInsert(list[key], quantity)
        end
    else
        list[key] = { [1] = quantity }
        tableInsert(keys, key)
    end
end

function appendText(text, currentText, maxLength, lines, delimiter, prefix, iconStringLength)
    iconStringLength = iconStringLength or 0
    local currentTextLength = ZoUTF8StringLength(currentText)
    local stringLength = currentTextLength + ZoUTF8StringLength(delimiter) + ZoUTF8StringLength(text)
    -- icons only take up the space of two characters
    if iconStringLength > 0 then
        stringLength = stringLength - iconStringLength + ICON_CHAT_LINK_LENGTH 
    end
    if stringLength > maxLength then
        tableInsert(lines, currentText)
        currentText = ""
    elseif currentTextLength > ZoUTF8StringLength(prefix) or stringFind(delimiter, "^\n") then
        currentText = currentText .. delimiter
    end
    currentText = currentText .. text
    return currentText
end

function coalesce(...)
    local args = {...}
    for key = 1, #args do
        local value = args[key]
        if value ~= nil then
            return value, key
        end
    end
end

defaultChat = ZO_Object:Subclass()
function defaultChat:New(...)
    local instance = ZO_Object.New(self)
    instance.isDefault = true
    instance.maxCharsPerLine = MAX_TEXT_CHAT_INPUT_CHARACTERS
    return instance
end
function defaultChat:Print(message)
    if CHAT_ROUTER then
        CHAT_ROUTER:AddDebugMessage(message)
    end
end

OPTIONS_DEFAULTS = {
    enabled = true,
    minQuality = ITEM_FUNCTIONAL_QUALITY_MIN_VALUE,
    showIcon = false,
    iconSize = 90,
    showTrait = false,
    showNotCollected = false,
    combineDuplicates = true,
    hideSingularQuantities = false,
    delimiter = " ",
    linkStyle = LINK_STYLE_DEFAULT,
    sorted = false,
    sortedByQuality = false,
    showCounter = false,
}

CHAT_DEFAULTS = {
    chat = defaultChat:New(),
    prefix = "",
    suffix = "",
}

RENAMED_OPTIONS = {
    traits = 'showTrait',
    icons = 'showIcon',
}

function formatCount(countText, count)
    -- The <<1*2>> format only prints a number when there are more than one
    if count > 1 then
        return ZO_CachedStrFormat(SI_LLS_COUNTER_FORMAT_PLURAL, count, countText)
    end
    -- Fall back on an explicit number and singular word
    return ZO_CachedStrFormat(SI_LLS_COUNTER_FORMAT_SINGLE, count, countText)
end

local numberDelimLength = zo_strlen(GetString(SI_LLS_COUNTER_FORMAT_SINGLE)) - 12
function getPlural(countText)
    -- <<m:1>> seems to be buggy and doesn't properly pluralize words, but <<1*2>> does.
    local pluralNumberAndWord = ZO_CachedStrFormat(SI_LLS_PLURAL, 2, countText)
    local plural = zo_strsub(pluralNumberAndWord, 2 + numberDelimLength)
    return plural
end

createLam2Option = function(self, optionData, addonName, strings)
    local name = strings[optionData.name] or optionData.name
    local tooltip = strings[optionData.tooltip] or optionData.tooltip
    local option = {
        type = optionData.type,
        name = GetString(name),
        tooltip = GetString(tooltip),
        default = self.defaults[optionData.option],
        disabled = function() return not self:IsEnabled() end,
    }

    if optionData.type == "checkbox" then
        option.getFunc = function() return self:GetOption(optionData.option) end
        option.setFunc = function(value) self:SetOption(optionData.option, value) end
    elseif optionData.type == "slider" then
        option.min = optionData.min
        option.max = optionData.max
        option.step = optionData.step
        option.decimals = optionData.decimals
        option.clampInput = optionData.clampInput
        option.getFunc = function() return self:GetOption(optionData.option) end
        option.setFunc = function(value) self:SetOption(optionData.option, value) end
        option.disabled = function()
            return not self:IsEnabled() or (not self:GetOption('showIcon') 
                                           and not self:GetOption('showNotCollected'))
        end
    elseif optionData.type == "dropdown" then
        option.choices = optionData.choices
        option.choicesValues = optionData.choicesValues
        option.sort = optionData.sort
        option.getFunc = optionData.getFunc and optionData.getFunc(self) or function() return self:GetOption(optionData.option) end
        option.setFunc = optionData.setFunc and optionData.setFunc(self) or function(value) self:SetOption(optionData.option, value) end
    end

    if optionData.option == 'enabled' then
        option.tooltip = zo_strformat(GetString(tooltip), addonName)
        option.disabled = nil
    elseif optionData.option == 'showNotCollected' then
        option.name = zo_strformat(GetString(name), zo_iconFormat(collectionIcon, '120%', '120%'))
    elseif optionData.option == 'showCounter' then
        if self.counterText == nil or self.counterText == '' then return end
        local language = GetCVar("Language.2")
        local pluralCounterText = getPlural(self.counterText)
        local counterTitleText = language == "en" and zo_strformat("<<t:1>>", pluralCounterText) or pluralCounterText
        option.name = zo_strformat(GetString(SI_LLS_SHOW_COUNTER), counterTitleText)
        option.tooltip = zo_strformat(GetString(SI_LLS_SHOW_COUNTER_TOOLTIP), pluralCounterText)
    end

    return option
end

function getChildTable(parent, childPath)
    local childTable = parent
    for _, key in ipairs(childPath) do
        childTable = childTable[key]
    end
    return childTable
end

function isSetItemNotCollected(itemLink)
    if not IsItemLinkSetCollectionPiece(itemLink) then return nil end
    local setId = select(6, GetItemLinkSetInfo(itemLink, false))
    local slot = GetItemLinkItemSetCollectionSlot(itemLink)
    return not IsItemSetCollectionSlotUnlocked(setId, slot)
end

function mergeTables(table1, table2)
    local merged = ZO_ShallowTableCopy(table1)
    for key, value in pairs(table2) do
        if merged[key] == nil then
            merged[key] = value
        end
    end
    return merged
end

function sortByCurrencyName(currencyType1, currencyType2)
    return GetCurrencyName(currencyType1) < GetCurrencyName(currencyType2)
end

function sortByItemName(itemLink1, itemLink2)
    return ZO_CachedStrFormat(SI_LINK_FORMAT_ITEM_NAME, GetItemLinkName(itemLink1)) < ZO_CachedStrFormat(SI_LINK_FORMAT_ITEM_NAME, GetItemLinkName(itemLink2))
end

function sortByQuality(itemLink1, itemLink2)
    local quality1 = GetItemLinkFunctionalQuality(itemLink1)
    local quality2 = GetItemLinkFunctionalQuality(itemLink2)
    if quality1 == quality2 then
        return sortByItemName(itemLink1, itemLink2)
    else
        return quality2 < quality1
    end
end

qualityChoices = {}
qualityChoicesValues = {}
for quality = ITEM_FUNCTIONAL_QUALITY_MIN_VALUE, ITEM_FUNCTIONAL_QUALITY_MAX_VALUE do
    local qualityColor = GetItemQualityColor(quality)
    local qualityString = qualityColor:Colorize(GetString("SI_ITEMQUALITY", quality))
    tableInsert(qualityChoicesValues, quality)
    tableInsert(qualityChoices, qualityString)
end


delimiterChoicesValues = {
    " ",
    "   ",
    ", ",
    " * ",
    "; ",
    "\n",
    "\n• ",
    "\n- ",
    "\n+ ",
    "\n* ",
    "、",
    "・",
}

delimiterChoices = { }
for _, delimiterChoice in ipairs(delimiterChoicesValues) do
    delimiterChoice = zo_strgsub(delimiterChoice, "\n", "\\n")
    table.insert(delimiterChoices, zo_strformat(GetString(SI_LLS_QUOTES), delimiterChoice))
end

--[[ Data for generating LAM2 option controls ]]
lam2OptionData = {
    { option = 'enabled', name = 'SUMMARY', tooltip = 'SUMMARY_TOOLTIP', type = 'checkbox' },
    { option = 'minQuality', name = 'MIN_QUALITY', tooltip = 'MIN_QUALITY_TOOLTIP', type = 'dropdown', choices = qualityChoices, choicesValues = qualityChoicesValues, sort = "numericvalue-up" },
    { option = 'showIcon', name = 'SHOW_ICONS', tooltip = 'SHOW_ICONS_TOOLTIP', type = 'checkbox' },
    { option = 'showNotCollected', name = 'SHOW_NOT_COLLECTED', tooltip = 'SHOW_NOT_COLLECTED_TOOLTIP', type = 'checkbox' },
    { option = 'iconSize', name = SI_LLS_ICON_SIZE, tooltip = SI_LLS_ICON_SIZE_TOOLTIP, type = 'slider', min = 50, max = 200, step = 10, decimals = 0, clampInput = true },
    { option = 'showTrait', name = 'SHOW_TRAITS', tooltip = 'SHOW_TRAITS_TOOLTIP', type = 'checkbox' },
    { option = 'hideSingularQuantities', name = 'HIDE_SINGLE_QTY', tooltip = 'HIDE_SINGLE_QTY_TOOLTIP', type = 'checkbox' },
    { option = 'combineDuplicates', name = SI_LLS_COMBINE_DUPLICATES, tooltip = SI_LLS_COMBINE_DUPLICATES_TOOLTIP, type = 'checkbox' },
    { option = 'sorted', name = GetString(SI_GAMEPAD_BANK_SORT_ORDER_HEADER), tooltip = GetString(SI_LLS_SORT_ORDER_TOOLTIP), type = 'dropdown',
        choices = {
            ZO_GenerateCommaSeparatedListWithoutAnd({
                GetString('SI_TRADINGHOUSEFEATURECATEGORY', TRADING_HOUSE_FEATURE_CATEGORY_QUALITY),
                GetString('SI_TRADINGHOUSELISTINGSORTTYPE', TRADING_HOUSE_LISTING_SORT_TYPE_NAME) })
            ,
            GetString('SI_TRADINGHOUSELISTINGSORTTYPE', TRADING_HOUSE_LISTING_SORT_TYPE_NAME),
            GetString(SI_ITEMTYPE0)
        },
        choicesValues = { 'quality', 'name', 'none' },
        getFunc = function(self)
            return function()
                return self:GetOption('sortedByQuality') and 'quality'
                       or self:GetOption('sorted') and 'name'
                       or 'none'
            end
        end,
        setFunc = function(self)
            return function(value)
                if value == 'quality' then
                    self:SetSortedByQuality(true)
                    self:SetSorted(false)
                elseif value == 'name' then
                    self:SetSorted(true)
                    self:SetSortedByQuality(false)
                else
                    self:SetSorted(false)
                    self:SetSortedByQuality(false)
                end
            end
        end,
    },
    { option = 'delimiter', name = SI_LLS_DELIMITER, tooltip = SI_LLS_DELIMITER_TOOLTIP, type = 'dropdown', choices = delimiterChoices, choicesValues = delimiterChoicesValues },
    { option = 'linkStyle', name = SI_LLS_LINK_STYLE, tooltip = SI_LLS_LINK_STYLE_TOOLTIP, type = 'dropdown',
        choices = {
            stringFormat(linkFormat, LINK_STYLE_BRACKETS, 54172),
            stringFormat(linkFormat, LINK_STYLE_DEFAULT, 54172),
        },
        choicesValues = { LINK_STYLE_BRACKETS, LINK_STYLE_DEFAULT }
    },
    { option = 'showCounter', name = SI_LLS_SHOW_COUNTER, tooltip = SI_LLS_SHOW_COUNTER_TOOLTIP, type = 'checkbox' },
}
