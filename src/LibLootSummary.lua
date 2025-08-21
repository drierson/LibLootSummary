
--[[
LibLootSummary - ESO Addon Library

Purpose: Provides a robust API for printing item and loot summaries to chat, supporting integration with LibAddonMenu and LibChatMessage.
Features: Dynamic chat output, configurable options, localization, and developer-friendly diagnostics.
Manifest metadata (version, author, etc.) is auto-assigned by ESO at runtime.

Usage: See README.md for integration instructions and example usage.

Maintainer Notes:
- All major functions are documented inline.
- Manifest fields are available via the global LibLootSummary variable.
- Lint errors for missing ESO globals are expected in local dev, not in-game.
]]


LibLootSummary = LibLootSummary or {}
local lls = LibLootSummary

--[[ Shortcut to creating a new LibLootSumary.List instance ]]--
function lls:New(...)
    return lls.List:New(...)
end
setmetatable(lls, { __call = function(_, ...) return lls.List:New(...) end })