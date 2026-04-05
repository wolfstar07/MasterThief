-- MasterThiefUI.lua
-- UI module for MasterThief addon

if not MasterThief then
    MasterThief = {}
end

-- Local reference for performance
local MT = MasterThief

----------------------------------------
-- Scroll List Functions
----------------------------------------
function MasterThief.SetupDataRow(rowControl, data, scrollList)
    rowControl:SetText(data[1])
    rowControl:SetFont("ZoFontGame")

    -- Event for mouse clicks
    rowControl:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside then
            if button == 2 then -- Delete with right mouse button
                if MasterThief:removeFromList(data[1]) then 
                    d(data[1]..GetString(MT_MISC_LOOTLIST_DELETE)) 
                    MasterThief:RefreshLootlistWindow()
                end
            end	
        end
    end)
    
    rowControl:SetHandler("OnMouseEnter", function(self)
        if not data or not data[1] then return end
        InitializeTooltip(ItemTooltip, self, RIGHT, -5, 0)
        ItemTooltip:SetLink(data[1])
    end)
    
    rowControl:SetHandler("OnMouseExit", function()
        ClearTooltip(ItemTooltip)
    end)
end

function MasterThief:CreateLootlistWindow()
    if self.lootlistWindow then return end

    local win = WINDOW_MANAGER:CreateTopLevelWindow("MasterThiefLootlistWindow")
    win:SetDimensions(700, 600)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetAnchor(CENTER, GuiRoot, CENTER)

    -- Background
    local bg = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0.05, 0.05, 0.05, 0.95)
	
	-- Disable backdrop edge safely (no border, no errors)
	bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_pixel.dds", 1, 1)
	bg:SetEdgeColor(0, 0, 0, 0)

    -- Title
    local title = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
    title:SetFont("$(PROSE_ANTIQUE_FONT)|30|soft-shadow-thin")
    title:SetText("MasterThief")
    title:SetAnchor(TOP, win, TOP, 0, 10)

    -- Close
    local close = WINDOW_MANAGER:CreateControl(nil, win, CT_BUTTON)
    close:SetDimensions(32, 32)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, 2, 5)
    close:SetNormalTexture("EsoUI/Art/Buttons/closebutton_up.dds")
    close:SetPressedTexture("EsoUI/Art/Buttons/closebutton_down.dds")
    close:SetMouseOverTexture("EsoUI/Art/Buttons/closebutton_mouseover.dds")
    close:SetHandler("OnClicked", function()
        win:SetHidden(true)
    end)

    self.lootlistWindow = win

    -- Panels (important!)
    self:CreatePanels(win)
    self:CreateTabs(win)

    -- Default tab AFTER everything exists
    self:SelectTab("loot")
end

function MasterThief:CreatePanels(win)
    -- Loot panel
    local lootPanel = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    lootPanel:SetAnchor(TOPLEFT, win, TOPLEFT, 10, 50)
    lootPanel:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -10, -60)
    lootPanel:SetHidden(false)

    -- CREATE scrollList HERE if doesn't exist
    if not scrollList then
        
        local scrollData = {
            name = "MT_ScrollListData",
            parent = lootPanel,
            width = 480,
            height = 500,
            rowHeight = 30,
            setupCallback = MasterThief.SetupDataRow,
        }
        
        scrollList = libScroll:CreateScrollList(scrollData)
        scrollList:SetAnchor(TOPLEFT, lootPanel, TOPLEFT, 5, 5)
        scrollList:SetAnchor(BOTTOMRIGHT, lootPanel, BOTTOMRIGHT, -5, -35)
        
        if scrollListData and #scrollListData > 0 then
            scrollList:Update(scrollListData)
            d("[MasterThief] Loaded " .. #scrollListData .. " items into scrollList")
        end
    else
        scrollList:SetParent(lootPanel)
        scrollList:ClearAnchors()
        scrollList:SetAnchor(TOPLEFT, lootPanel, TOPLEFT, 5, 5)
        scrollList:SetAnchor(BOTTOMRIGHT, lootPanel, BOTTOMRIGHT, -5, -35)
    end

    self.lootPanel = lootPanel
    
    -- Counter
    local counter = WINDOW_MANAGER:CreateControl(nil, lootPanel, CT_LABEL)
    counter:SetFont("$(PROSE_ANTIQUE_FONT)|18")
    counter:SetAnchor(BOTTOMLEFT, lootPanel, BOTTOMLEFT, 5, -5)
    counter:SetText("Total: " .. self:countItemsOnLootlist())
    self.lootlistCounter = counter

    -- Stats panel
    local statsPanel = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    statsPanel:SetAnchorFill(lootPanel)
    statsPanel:SetHidden(true)
    self.statsPanel = statsPanel
    
    -- CREATE STATS SUB-PANELS
    
    -- Session Stats Panel
    local sessionStatsPanel = WINDOW_MANAGER:CreateControl(nil, statsPanel, CT_CONTROL)
    sessionStatsPanel:SetAnchor(TOPLEFT, statsPanel, TOPLEFT, 10, 40)
    sessionStatsPanel:SetAnchor(BOTTOMRIGHT, statsPanel, BOTTOMRIGHT, -10, -10)
    sessionStatsPanel:SetHidden(false)  -- Show by default
    self.sessionStatsPanel = sessionStatsPanel
    
    -- Lifetime Stats Panel
    local lifetimeStatsPanel = WINDOW_MANAGER:CreateControl(nil, statsPanel, CT_CONTROL)
    lifetimeStatsPanel:SetAnchor(TOPLEFT, statsPanel, TOPLEFT, 10, 40)
    lifetimeStatsPanel:SetAnchor(BOTTOMRIGHT, statsPanel, BOTTOMRIGHT, -10, -10)
    lifetimeStatsPanel:SetHidden(true)  -- Hidden by default
    self.lifetimeStatsPanel = lifetimeStatsPanel
    
    -- Create sub-tab buttons (Session / Lifetime)
    self:CreateStatsSubTabs(statsPanel)
    
    -- Create the actual stats displays
    self:CreateSessionStatsDisplay(sessionStatsPanel)
    self:CreateLifetimeStatsDisplay(lifetimeStatsPanel)
end

function MasterThief:CreateTabs(win)
    local tabContainer = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    tabContainer:SetAnchor(BOTTOM, win, BOTTOM, 0, -10)
    tabContainer:SetHeight(40)

    self.tabs = {}

    local function CreateTab(label, id, offsetX)
        local btn = WINDOW_MANAGER:CreateControl(nil, tabContainer, CT_BUTTON)
        btn:SetDimensions(120, 30)
        btn:SetAnchor(CENTER, tabContainer, CENTER, offsetX, 0)
		
		-- Background (flat)
		local bg = WINDOW_MANAGER:CreateControl(nil, btn, CT_BACKDROP)
		bg:SetAnchorFill(btn)
		bg:SetCenterColor(0.12, 0.12, 0.12, 0.95)

        local text = WINDOW_MANAGER:CreateControl(nil, btn, CT_LABEL)
        text:SetFont("$(PROSE_ANTIQUE_FONT)|20")
        text:SetText(label)
        text:SetAnchor(CENTER)

		btn.bg = bg
        btn.label = text
		
        btn:SetHandler("OnClicked", function()
            self:SelectTab(id)
        end)

        self.tabs[id] = btn
    end

    CreateTab("Loot List", "loot", -70)
    CreateTab("Stats", "stats", 70)
end

function MasterThief:SelectTab(tabId)
    -- Update tab appearance
    for id, tab in pairs(self.tabs) do
        if id == tabId then
            -- Active tab - brighter
            tab.bg:SetCenterColor(0.25, 0.25, 0.25, 0.95)
            tab.label:SetColor(1, 0.85, 0, 1)  -- Gold
        else
            -- Inactive tab - darker
            tab.bg:SetCenterColor(0.12, 0.12, 0.12, 0.95)
            tab.label:SetColor(0.7, 0.7, 0.7, 1)  -- Gray
        end
    end
    
    -- Show/hide panels
    if tabId == "loot" then
        self.lootPanel:SetHidden(false)
        self.statsPanel:SetHidden(true)
    elseif tabId == "stats" then
        self.lootPanel:SetHidden(true)
        self.statsPanel:SetHidden(false)
        
        -- Refresh stats when showing stats tab
        self:UpdateSessionStatsDisplay()
        self:UpdateLifetimeStatsDisplay()
    end
end

function MasterThief:CreateStatsSubTabs(statsPanel)
    local buttonWidth = 100
    local buttonHeight = 30
    local spacing = 5
    
    -- Session Stats button
    local sessionBtn = WINDOW_MANAGER:CreateControl(nil, statsPanel, CT_BUTTON)
    sessionBtn:SetDimensions(buttonWidth, buttonHeight)
    -- CENTER the buttons - offset left by half button width + half spacing
    sessionBtn:SetAnchor(CENTER, statsPanel, TOP, -(buttonWidth/2 + spacing/2), 15)
    
    -- Background
    local sessionBg = WINDOW_MANAGER:CreateControl(nil, sessionBtn, CT_BACKDROP)
    sessionBg:SetAnchorFill(sessionBtn)
    sessionBg:SetCenterColor(0.25, 0.25, 0.25, 0.95)  -- Active - lighter
    sessionBg:SetEdgeColor(0.6, 0.6, 0.6, 1)
    sessionBg:SetEdgeTexture("", 8, 1, 1)
    
    -- Label
    local sessionLabel = WINDOW_MANAGER:CreateControl(nil, sessionBtn, CT_LABEL)
    sessionLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
    sessionLabel:SetText("Session")
    sessionLabel:SetAnchor(CENTER)
    sessionLabel:SetColor(1, 0.85, 0, 1)  -- Start as active (gold)
    
    sessionBtn.bg = sessionBg
    sessionBtn.label = sessionLabel
    sessionBtn:SetHandler("OnClicked", function()
        self:SelectStatsSubTab("session")
    end)
    self.sessionStatsTabButton = sessionBtn
    
    -- Lifetime Stats button
    local lifetimeBtn = WINDOW_MANAGER:CreateControl(nil, statsPanel, CT_BUTTON)
    lifetimeBtn:SetDimensions(buttonWidth, buttonHeight)
    lifetimeBtn:SetAnchor(LEFT, sessionBtn, RIGHT, spacing, 0)
    
    -- Background
    local lifetimeBg = WINDOW_MANAGER:CreateControl(nil, lifetimeBtn, CT_BACKDROP)
    lifetimeBg:SetAnchorFill(lifetimeBtn)
    lifetimeBg:SetCenterColor(0.12, 0.12, 0.12, 0.95)  -- Inactive - darker (matches main tabs)
    lifetimeBg:SetEdgeColor(0.6, 0.6, 0.6, 1)
    lifetimeBg:SetEdgeTexture("", 8, 1, 1)
    
    -- Label
    local lifetimeLabel = WINDOW_MANAGER:CreateControl(nil, lifetimeBtn, CT_LABEL)
    lifetimeLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
    lifetimeLabel:SetText("Lifetime")
    lifetimeLabel:SetAnchor(CENTER)
    lifetimeLabel:SetColor(0.7, 0.7, 0.7, 1)  -- Start as inactive (gray)
    
    lifetimeBtn.bg = lifetimeBg
    lifetimeBtn.label = lifetimeLabel
    lifetimeBtn:SetHandler("OnClicked", function()
        self:SelectStatsSubTab("lifetime")
    end)
    self.lifetimeStatsTabButton = lifetimeBtn
end

function MasterThief:SelectStatsSubTab(subTab)
    if subTab == "session" then
        self.sessionStatsPanel:SetHidden(false)
        self.lifetimeStatsPanel:SetHidden(true)
        
        -- Update button appearance
        self.sessionStatsTabButton.bg:SetCenterColor(0.25, 0.25, 0.25, 0.95)  -- Active - lighter
        self.sessionStatsTabButton.label:SetColor(1, 0.85, 0, 1)  -- Active - gold
        
        self.lifetimeStatsTabButton.bg:SetCenterColor(0.12, 0.12, 0.12, 0.95)  -- Inactive - darker
        self.lifetimeStatsTabButton.label:SetColor(0.7, 0.7, 0.7, 1)  -- Inactive - gray
    else
        self.sessionStatsPanel:SetHidden(true)
        self.lifetimeStatsPanel:SetHidden(false)
        
        -- Update button appearance
        self.sessionStatsTabButton.bg:SetCenterColor(0.12, 0.12, 0.12, 0.95)  -- Inactive - darker
        self.sessionStatsTabButton.label:SetColor(0.7, 0.7, 0.7, 1)  -- Inactive - gray
        
        self.lifetimeStatsTabButton.bg:SetCenterColor(0.25, 0.25, 0.25, 0.95)  -- Active - lighter
        self.lifetimeStatsTabButton.label:SetColor(1, 0.85, 0, 1)  -- Active - gold
    end
end

function MasterThief:CreateSessionStatsDisplay(panel)
    local yOffset = 10
    local leftCol = 10
    local leftValueCol = 240
    local rightCol = 360
    local rightValueCol = 590
    local labelHeight = 25
    
    -- Title
    local title = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    title:SetFont("$(PROSE_ANTIQUE_FONT)|24")
    title:SetText(GetString(MT_STATS_SESSION_HEADER))
    title:SetColor(1, 0.8, 0, 1)
    yOffset = yOffset + 35
    
    -- Helper function to create stat rows
    local function CreateStatRow(text, valueControlName, useRightColumn)
        local xCol = useRightColumn and rightCol or leftCol
        local xValueCol = useRightColumn and rightValueCol or leftValueCol
        
        local label = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
        label:SetAnchor(TOPLEFT, panel, TOPLEFT, xCol, yOffset)
        label:SetFont("ZoFontGame")
        label:SetText(text)
        
        local value = WINDOW_MANAGER:CreateControl(valueControlName, panel, CT_LABEL)
        value:SetAnchor(TOPLEFT, panel, TOPLEFT, xValueCol, yOffset)
        value:SetFont("ZoFontGame")
        value:SetText("0")
        value:SetColor(0.8, 0.8, 0.8, 1)
        
        yOffset = yOffset + labelHeight
        return value
    end
    
    -- Create stat labels and value controls
    -- Reset yOffset for first column
   local leftColY = yOffset
   local rightColY = yOffset
    
    self.sessionStatsLabels = {
        -- LEFT COLUMN - Looting Stats
        itemsLooted = CreateStatRow(GetString(MT_STATS_ITEMS_LOOTED), "MT_SessionStat_ItemsLooted", false),
        itemsSkipped = CreateStatRow(GetString(MT_STATS_ITEMS_SKIPPED), "MT_SessionStat_ItemsSkipped", false),
        motifsLooted = CreateStatRow(GetString(MT_STATS_MOTIFS_LOOTED), "MT_SessionStat_Motifs", false),
        recipesLooted = CreateStatRow(GetString(MT_STATS_RECIPES_LOOTED), "MT_SessionStat_Recipes", false),
        furnishingPlansLooted = CreateStatRow(GetString(MT_STATS_FURNISHING_PLANS), "MT_SessionStat_Plans", false),
        furnishingsLooted = CreateStatRow(GetString(MT_STATS_FURNISHINGS), "MT_SessionStat_Furnishings", false),
        hiddenWalletsLooted = CreateStatRow(GetString(MT_STATS_HIDDEN_WALLETS), "MT_SessionStat_Wallets", false),
        researchPortfoliosLooted = CreateStatRow(GetString(MT_STATS_RESEARCH_PORTFOLIOS), "MT_SessionStat_Portfolios", false),
		edictsLooted = CreateStatRow(GetString(MT_STATS_EDICTS), "MT_SessionStat_Edicts", false),
    }
    
    -- Reset yOffset for second column
    leftColY = yOffset  -- Save where left column ended
    yOffset = rightColY  -- Reset to start of right column
    
    local moreLabels = {
        -- RIGHT COLUMN - Justice Stats
		successfulPickpockets = CreateStatRow(GetString(MT_STATS_PICKPOCKETS), "MT_SessionStat_Pickpockets", true),
        safeboxesLockpicked = CreateStatRow(GetString(MT_STATS_SAFEBOXES), "MT_SessionStat_Safeboxes", true),
        doorsLockpicked = CreateStatRow(GetString(MT_STATS_DOORS), "MT_SessionStat_Doors", true),
		bladeOfWoeKills = CreateStatRow(GetString(MT_STATS_BOW_KILLS), "MT_SessionStat_BoW", true),
        deathsByGuards = CreateStatRow(GetString(MT_STATS_GUARD_DEATHS), "MT_SessionStat_Guards", true),
        totalFencedGold = CreateStatRow(GetString(MT_STATS_GOLD_FENCED), "MT_SessionStat_Fenced", true),
        goldSpentLaundering = CreateStatRow(GetString(MT_STATS_GOLD_LAUNDERED), "MT_SessionStat_Laundered", true),
        highestBounty = CreateStatRow(GetString(MT_STATS_HIGHEST_BOUNTY), "MT_SessionStat_Bounty", true),
    }
	
	rightColY = yOffset  -- Save where right column ended
    
    -- Merge the two tables
    for k, v in pairs(moreLabels) do
        self.sessionStatsLabels[k] = v
    end
    
    -- Use the taller column for subsequent elements
    yOffset = math.max(leftColY, rightColY)
    
    yOffset = yOffset + 15
    
    -- Highest value item
    local highestLabel = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
    highestLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    highestLabel:SetFont("ZoFontGame")
    highestLabel:SetText(GetString(MT_STATS_HIGHEST_VALUE))
    
    local highestValue = WINDOW_MANAGER:CreateControl("MT_SessionStat_Highest", panel, CT_LABEL)
    highestValue:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset + labelHeight)
    highestValue:SetFont("ZoFontGame")
    highestValue:SetText("None")
    highestValue:SetColor(0.8, 0.8, 0.8, 1)
    self.sessionStatsLabels.highestValue = highestValue
    
    yOffset = yOffset + labelHeight * 2 + 20
    
    -- Reset button
    local resetBtn = WINDOW_MANAGER:CreateControl(nil, panel, CT_BUTTON)
    resetBtn:SetDimensions(150, 30)
    resetBtn:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    
    -- Background with border
    local resetBg = WINDOW_MANAGER:CreateControl(nil, resetBtn, CT_BACKDROP)
    resetBg:SetAnchorFill(resetBtn)
    resetBg:SetCenterColor(0.2, 0.2, 0.2, 0.9)
    resetBg:SetEdgeColor(0.6, 0.6, 0.6, 1)
    resetBg:SetEdgeTexture("", 8, 1, 1)
    
    -- Label
    local resetLabel = WINDOW_MANAGER:CreateControl(nil, resetBtn, CT_LABEL)
    resetLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
    resetLabel:SetText(GetString(MT_STATS_RESET_SESSION))
    resetLabel:SetAnchor(CENTER)
    resetLabel:SetColor(1, 0.85, 0, 1)
    
    resetBtn:SetHandler("OnClicked", function()
        self:ResetSessionStats()
    end)
end

function MasterThief:CreateLifetimeStatsDisplay(panel)
    local leftCol = 10
    local leftValueCol = 240
    local rightCol = 360
    local rightValueCol = 590
    local labelHeight = 25
    
    -- Title
    local yOffset = 10
    local title = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    title:SetFont("$(PROSE_ANTIQUE_FONT)|24")
    title:SetText(GetString(MT_STATS_LIFETIME_HEADER))
    title:SetColor(1, 0.8, 0, 1)
    yOffset = yOffset + 35
    
    -- Separate Y positions for each column
    local leftColY = yOffset
    local rightColY = yOffset
    
    -- Helper function to create stat rows
    local function CreateStatRow(text, valueControlName, useRightColumn)
        local xCol = useRightColumn and rightCol or leftCol
        local xValueCol = useRightColumn and rightValueCol or leftValueCol
        
        -- Use the appropriate column's Y position
        local currentY = useRightColumn and rightColY or leftColY
        
        local label = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
        label:SetAnchor(TOPLEFT, panel, TOPLEFT, xCol, currentY)
        label:SetFont("ZoFontGame")
        label:SetText(text)
        
        local value = WINDOW_MANAGER:CreateControl(valueControlName, panel, CT_LABEL)
        value:SetAnchor(TOPLEFT, panel, TOPLEFT, xValueCol, currentY)
        value:SetFont("ZoFontGame")
        value:SetText("0")
        value:SetColor(0.8, 0.8, 0.8, 1)
        
        -- Increment the appropriate column's Y position
        if useRightColumn then
            rightColY = rightColY + labelHeight
        else
            leftColY = leftColY + labelHeight
        end
        
        return value
    end
    
    -- Reset yOffset for first column
    local firstColY = yOffset
    
    self.lifetimeStatsLabels = {
        -- LEFT COLUMN - Looting Stats
        itemsLooted = CreateStatRow(GetString(MT_STATS_ITEMS_LOOTED), "MT_LifetimeStat_ItemsLooted", false),
        itemsSkipped = CreateStatRow(GetString(MT_STATS_ITEMS_SKIPPED), "MT_LifetimeStat_ItemsSkipped", false),
        motifsLooted = CreateStatRow(GetString(MT_STATS_MOTIFS_LOOTED), "MT_LifetimeStat_Motifs", false),
        recipesLooted = CreateStatRow(GetString(MT_STATS_RECIPES_LOOTED), "MT_LifetimeStat_Recipes", false),
        furnishingPlansLooted = CreateStatRow(GetString(MT_STATS_FURNISHING_PLANS), "MT_LifetimeStat_Plans", false),
        furnishingsLooted = CreateStatRow(GetString(MT_STATS_FURNISHINGS), "MT_LifetimeStat_Furnishings", false),
        hiddenWalletsLooted = CreateStatRow(GetString(MT_STATS_HIDDEN_WALLETS), "MT_LifetimeStat_Wallets", false),
        researchPortfoliosLooted = CreateStatRow(GetString(MT_STATS_RESEARCH_PORTFOLIOS), "MT_LifetimeStat_Portfolios", false),
		edictsLooted = CreateStatRow(GetString(MT_STATS_EDICTS), "MT_LifetimeStat_Edicts", false),
    }
    
    -- Reset yOffset for second column
    yOffset = firstColY
    
    local moreLabels = {
        -- RIGHT COLUMN - Justice Stats
		successfulPickpockets = CreateStatRow(GetString(MT_STATS_PICKPOCKETS), "MT_LifetimeStat_Pickpockets", true),
        safeboxesLockpicked = CreateStatRow(GetString(MT_STATS_SAFEBOXES), "MT_LifetimeStat_Safeboxes", true),
        doorsLockpicked = CreateStatRow(GetString(MT_STATS_DOORS), "MT_LifetimeStat_Doors", true),
		bladeOfWoeKills = CreateStatRow(GetString(MT_STATS_BOW_KILLS), "MT_LifetimeStat_BoW", true),
        deathsByGuards = CreateStatRow(GetString(MT_STATS_GUARD_DEATHS), "MT_LifetimeStat_Guards", true),
		thievesTrovesLooted = CreateStatRow(GetString(MT_STATS_TROVES), "MT_LifetimeStat_Troves", true),
        totalFencedGold = CreateStatRow(GetString(MT_STATS_GOLD_FENCED), "MT_LifetimeStat_Fenced", true),
        goldSpentLaundering = CreateStatRow(GetString(MT_STATS_GOLD_LAUNDERED), "MT_LifetimeStat_Laundered", true),
        highestBounty = CreateStatRow(GetString(MT_STATS_HIGHEST_BOUNTY), "MT_LifetimeStat_Bounty", true),
		paidBountyTotal = CreateStatRow(GetString(MT_STATS_LIFETIME_BOUNTY_PAID), "MT_LifetimeStat_Paid", true),
    }
    
    -- Merge the two tables
    for k, v in pairs(moreLabels) do
        self.lifetimeStatsLabels[k] = v
    end
    
    -- Use the taller column for subsequent elements
    yOffset = math.max(leftColY, rightColY)
    
    yOffset = yOffset + 15
    
    -- Highest value item
    local highestLabel = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
    highestLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    highestLabel:SetFont("ZoFontGame")
    highestLabel:SetText(GetString(MT_STATS_HIGHEST_VALUE))
    
    local highestValue = WINDOW_MANAGER:CreateControl("MT_LifetimeStat_Highest", panel, CT_LABEL)
    highestValue:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset + labelHeight)
    highestValue:SetFont("ZoFontGame")
    highestValue:SetText("None")
    highestValue:SetColor(0.8, 0.8, 0.8, 1)
    self.lifetimeStatsLabels.highestValue = highestValue
    
    yOffset = yOffset + labelHeight * 2 + 20
    
    -- Reset button (with confirmation)
    local resetBtn = WINDOW_MANAGER:CreateControl(nil, panel, CT_BUTTON)
    resetBtn:SetDimensions(150, 30)
    resetBtn:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    
    -- Background with border
    local resetBg = WINDOW_MANAGER:CreateControl(nil, resetBtn, CT_BACKDROP)
    resetBg:SetAnchorFill(resetBtn)
    resetBg:SetCenterColor(0.2, 0.2, 0.2, 0.9)
    resetBg:SetEdgeColor(0.6, 0.6, 0.6, 1)
    resetBg:SetEdgeTexture("", 8, 1, 1)
    
    -- Label
    local resetLabel = WINDOW_MANAGER:CreateControl(nil, resetBtn, CT_LABEL)
    resetLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
    resetLabel:SetText(GetString(MT_STATS_RESET_LIFETIME))
    resetLabel:SetAnchor(CENTER)
    resetLabel:SetColor(1, 0.85, 0, 1)
    
    resetBtn:SetHandler("OnClicked", function()
        -- Show confirmation dialog
        ZO_Dialogs_ShowDialog("MT_CONFIRM_RESET_LIFETIME")
    end)
end

local TAB_INACTIVE_BG = { 0.15, 0.15, 0.15, 0.9 }
local TAB_ACTIVE_BG   = { 0.22, 0.24, 0.25, 0.95 }

local TAB_GLOW_COLOR  = { 0.45, 0.65, 0.70, 1 } -- muted teal-silver

function MasterThief:RefreshLootlistWindow()
    if not scrollList then return end

    -- Rebuild data from saved vars
    scrollListData = {}
    for _, obj in ipairs(self.SavedVarsLoots.Worthful or {}) do
        table.insert(scrollListData, { obj[1] })
    end

    -- Update scroll list
    scrollList:Update(scrollListData)

    -- Update counter
    if self.lootlistCounter then
        self.lootlistCounter:SetText(
            "Total: " .. self:countItemsOnLootlist()
        )
    end
end

function MasterThief:UpdateSessionStatsDisplay()
    if not self.sessionStatsLabels then return end
    
    local stats = MasterThief.SessionStats
    
    self.sessionStatsLabels.itemsLooted:SetText(tostring(stats.itemsLooted))
    self.sessionStatsLabels.itemsSkipped:SetText(tostring(stats.itemsSkipped))
    self.sessionStatsLabels.motifsLooted:SetText(tostring(stats.motifsLooted))
    self.sessionStatsLabels.recipesLooted:SetText(tostring(stats.recipesLooted))
    self.sessionStatsLabels.furnishingPlansLooted:SetText(tostring(stats.furnishingPlansLooted))
    self.sessionStatsLabels.furnishingsLooted:SetText(tostring(stats.furnishingsLooted))
    self.sessionStatsLabels.hiddenWalletsLooted:SetText(tostring(stats.hiddenWalletsLooted or 0))
    self.sessionStatsLabels.researchPortfoliosLooted:SetText(tostring(stats.researchPortfoliosLooted or 0))
	self.sessionStatsLabels.edictsLooted:SetText(tostring(stats.edictsLooted or 0))
	self.sessionStatsLabels.safeboxesLockpicked:SetText(tostring(MasterThief.SessionStats.safeboxesLockpicked or 0))
	self.sessionStatsLabels.doorsLockpicked:SetText(tostring(MasterThief.SessionStats.doorsLockpicked or 0))
	self.sessionStatsLabels.deathsByGuards:SetText(tostring(MasterThief.SessionStats.deathsByGuards or 0))
	self.sessionStatsLabels.totalFencedGold:SetText(tostring(MasterThief.SessionStats.totalFencedGold or 0) .. "g")
	self.sessionStatsLabels.goldSpentLaundering:SetText(tostring(MasterThief.SessionStats.goldSpentLaundering or 0) .. "g")
	self.sessionStatsLabels.highestBounty:SetText(tostring(MasterThief.SessionStats.highestBounty or 0) .. "g")
	self.sessionStatsLabels.bladeOfWoeKills:SetText(tostring(MasterThief.SessionStats.bladeOfWoeKills or 0))
	self.sessionStatsLabels.successfulPickpockets:SetText(tostring(MasterThief.SessionStats.successfulPickpockets or 0))
    
    if stats.highestValueItemLooted.value > 0 then
        self.sessionStatsLabels.highestValue:SetText(
            stats.highestValueItemLooted.link .. " (" .. stats.highestValueItemLooted.value .. "g)"
        )
    else
        self.sessionStatsLabels.highestValue:SetText("None")
    end
end

function MasterThief:UpdateLifetimeStatsDisplay()
    if not self.lifetimeStatsLabels then return end
    
    local stats = MasterThief.SavedVarsLifetimeStats
    
    self.lifetimeStatsLabels.itemsLooted:SetText(tostring(stats.itemsLooted))
    self.lifetimeStatsLabels.itemsSkipped:SetText(tostring(stats.itemsSkipped))
    self.lifetimeStatsLabels.motifsLooted:SetText(tostring(stats.motifsLooted))
    self.lifetimeStatsLabels.recipesLooted:SetText(tostring(stats.recipesLooted))
    self.lifetimeStatsLabels.furnishingPlansLooted:SetText(tostring(stats.furnishingPlansLooted))
    self.lifetimeStatsLabels.furnishingsLooted:SetText(tostring(stats.furnishingsLooted))
    self.lifetimeStatsLabels.hiddenWalletsLooted:SetText(tostring(stats.hiddenWalletsLooted or 0))
    self.lifetimeStatsLabels.researchPortfoliosLooted:SetText(tostring(stats.researchPortfoliosLooted or 0))
	self.lifetimeStatsLabels.safeboxesLockpicked:SetText(tostring(stats.safeboxesLockpicked or 0))
	self.lifetimeStatsLabels.doorsLockpicked:SetText(tostring(stats.doorsLockpicked or 0))
	self.lifetimeStatsLabels.edictsLooted:SetText(tostring(stats.edictsLooted or 0))
	self.lifetimeStatsLabels.thievesTrovesLooted:SetText(tostring(stats.thievesTrovesLooted or 0))
	self.lifetimeStatsLabels.deathsByGuards:SetText(tostring(stats.deathsByGuards or 0))
	self.lifetimeStatsLabels.totalFencedGold:SetText(tostring(stats.totalFencedGold or 0) .. "g")
	self.lifetimeStatsLabels.goldSpentLaundering:SetText(tostring(stats.goldSpentLaundering or 0) .. "g")
	self.lifetimeStatsLabels.highestBounty:SetText(tostring(stats.highestBounty or 0) .. "g")
	self.lifetimeStatsLabels.successfulPickpockets:SetText(tostring(stats.successfulPickpockets or 0))
	self.lifetimeStatsLabels.bladeOfWoeKills:SetText(tostring(stats.bladeOfWoeKills or 0))
	self.lifetimeStatsLabels.paidBountyTotal:SetText(tostring(stats.paidBountyTotal or 0) .. "g")

    if stats.highestValueItemLooted and stats.highestValueItemLooted.value > 0 then
        self.lifetimeStatsLabels.highestValue:SetText(
            stats.highestValueItemLooted.link .. " (" .. stats.highestValueItemLooted.value .. "g)"
        )
    else
        self.lifetimeStatsLabels.highestValue:SetText("None")
    end
end

function MasterThief:ToggleLootlistWindow()
    if not self.lootlistWindow then
        self:CreateLootlistWindow()
    end
    
    local win = self.lootlistWindow
    local isHidden = win:IsHidden()
    
    win:SetHidden(not isHidden)

        -- Refresh the appropriate panel based on which is visible
        if self.statsPanel and not self.statsPanel:IsHidden() then
            -- Stats panel is active, refresh it
            self:UpdateSessionStatsDisplay()
            self:UpdateLifetimeStatsDisplay()
        elseif self.lootPanel and not self.lootPanel:IsHidden() then
            -- Loot panel is active, refresh loot list
            self:RefreshLootlistWindow()
        end
end

----------------------------------------
-- Create On-Screen Message Box
----------------------------------------
function MasterThief:CreateMessageBox()
	-- Only create once - prevents duplicate control errors on reload/zone change
	if ctlMasterThief then 
		return 
	end
	local msgBox = WINDOW_MANAGER:CreateTopLevelWindow("ctlMasterThief")
	msgBox:SetDimensions(1800, 50)
	msgBox:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
	msgBox:SetMouseEnabled(true)
	msgBox:SetMovable(true)
	msgBox:SetClampedToScreen(true)
	msgBox:SetHandler("OnMoveStop", function() MasterThief.WinMoveStop() end)
	
	local label = WINDOW_MANAGER:CreateControl("ctlMasterThiefLabel", msgBox, CT_LABEL)
	label:SetDimensions(1800, 50)
	label:SetAnchor(LEFT, msgBox, LEFT, 0, 0)
	label:SetFont("ZoFontWinH1")
	label:SetColor(1, 0.8, 0.67, 1)
	label:SetText("")
	label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	label:SetVerticalAlignment(TEXT_ALIGN_TOP)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	
	_G["ctlMasterThief"] = msgBox
	_G["ctlMasterThiefLabel"] = label
end