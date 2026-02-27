-- Top-level game controller: owns FSM, systems, and all state
local CardData = require("src.cards.card_data")
local Card = require("src.cards.card")
local Hand = require("src.cards.hand")
local Slot = require("src.cards.slot")
local DragManager = require("src.cards.drag_manager")
local Deck = require("src.systems.deck")
local Portraits = require("src.systems.portraits")
local SoundManager = require("src.systems.sound_manager")
local ApiClient = require("src.systems.api_client")
local Vignette = require("src.fx.vignette")
local Tween = require("src.fx.tween")
local FSM = require("src.states.fsm")
local Button = require("src.ui.button")
local NinePatch = require("src.ui.ninepatch")
local Sidebar = require("src.ui.sidebar")
local StoryPanel = require("src.ui.story_panel")
local HoverPanel = require("src.ui.hover_panel")
local EndScreen = require("src.ui.end_screen")
local RichText = require("src.ui.richtext")
local util = require("src.lib.util")

local Game = {}
Game.__index = Game

-- Layout constants (matching Godot scene)
local SIDEBAR_X, SIDEBAR_Y, SIDEBAR_W = 0, 0, 280
local STORY_X, STORY_W = 830, 450
local SLOT_START_X, SLOT_Y = 292, 100
local SLOT_W, SLOT_H = 150, 200
local SLOT_GAP = 183
local HAND_CENTER_X, HAND_CENTER_Y = 555, 570

function Game.new()
    local self = setmetatable({}, Game)

    -- Load fonts
    self.font_bold = love.graphics.newFont("assets/fonts/spectral/Spectral-Bold.ttf", 20)
    self.font_small = love.graphics.newFont("assets/fonts/spectral/Spectral-Bold.ttf", 14)
    self.font_tiny = love.graphics.newFont("assets/fonts/spectral/Spectral-Bold.ttf", 10)
    self.font_title = love.graphics.newFont("assets/fonts/spectral/Spectral-Bold.ttf", 24)

    local italic_path = "assets/fonts/spectral/Spectral-BoldItalic.ttf"
    if love.filesystem.getInfo(italic_path) then
        self.font_italic = love.graphics.newFont(italic_path, 14)
    else
        self.font_italic = self.font_small
    end

    love.graphics.setFont(self.font_small)

    -- Load UI textures
    self.panel_textures = {}
    local panel_files = {gold = "assets/ui/panels/gold_panel.png", silver = "assets/ui/panels/silver_panel.png", wood = "assets/ui/panels/wood_panel.png"}
    for name, path in pairs(panel_files) do
        if love.filesystem.getInfo(path) then
            local tex = love.graphics.newImage(path)
            tex:setFilter("nearest", "nearest")
            self.panel_textures[name] = tex
        end
    end

    -- Load button textures
    self.btn_normal = nil
    self.btn_pressed = nil
    if love.filesystem.getInfo("assets/ui/buttons/wood_button_normal.png") then
        self.btn_normal = love.graphics.newImage("assets/ui/buttons/wood_button_normal.png")
        self.btn_normal:setFilter("nearest", "nearest")
    end
    if love.filesystem.getInfo("assets/ui/buttons/wood_button_pressed.png") then
        self.btn_pressed = love.graphics.newImage("assets/ui/buttons/wood_button_pressed.png")
        self.btn_pressed:setFilter("nearest", "nearest")
    end

    -- Nine-patch panels
    self.wood_np = self.panel_textures.wood and NinePatch.new(self.panel_textures.wood, 8) or nil
    self.silver_np = self.panel_textures.silver and NinePatch.new(self.panel_textures.silver, 8) or nil

    -- Core systems
    self.card_data = CardData.new()
    self.card_data:load_all()

    self.deck = Deck.new()
    self.portraits = Portraits.new()
    self.portraits:load_all()
    self.sound = SoundManager.new()
    self.sound:load()
    self.vignette = Vignette.new()
    self.richtext = RichText.new(self.font_small, self.font_italic)

    -- Card interaction
    self.hand = Hand.new(HAND_CENTER_X, HAND_CENTER_Y)
    self.hand.max_hand_size = 9
    self.hand.max_spread = 700
    self.slots = {}
    for i = 1, 3 do
        local sx = SLOT_START_X + (i - 1) * SLOT_GAP
        self.slots[i] = Slot.new(sx, SLOT_Y, SLOT_W, SLOT_H, i)
    end
    self.drag_manager = DragManager.new()
    self.drag_manager:set_containers({self.slots[1], self.slots[2], self.slots[3], self.hand})

    -- UI components
    self.sidebar = Sidebar.new(SIDEBAR_X, 0, SIDEBAR_W, 720)
    self.story_panel = StoryPanel.new(STORY_X, 0, STORY_W, 720)
    self.hover_panel = HoverPanel.new(self.panel_textures.silver)
    self.end_screen = EndScreen.new()

    -- Buttons
    self.intro_button = Button.new(470, 420, 200, 40, "Begin Reading", self.btn_normal, self.btn_pressed)
    self.next_button = Button.new(520, 520, 200, 40, "Next Client", self.btn_normal, self.btn_pressed)
    self.play_again_button = Button.new(540, 540, 200, 40, "Play Again", self.btn_normal, self.btn_pressed)
    self.restart_button = Button.new(80, 680, 120, 30, "Restart", self.btn_normal, self.btn_pressed)

    -- API client
    self.api_client = ApiClient.new(self)

    -- Game state
    self:_init_state()

    -- FSM
    local states = {
        init = require("src.states.init"),
        client_loading = require("src.states.client_loading"),
        intro = require("src.states.intro"),
        reading_active = require("src.states.reading_active"),
        resolution = require("src.states.resolution"),
        game_end = require("src.states.game_end"),
    }
    self.fsm = FSM.new(states)
    self.fsm.game = self

    -- Start
    self.fsm:transition("init")

    return self
end

function Game:_init_state()
    self.state = {encounters = {}, encounter_index = 0, client_count = 0}
    self.current_encounter = nil
    self.show_cards = false
    self.show_loading = false
    self.show_intro = false
    self.show_resolution = false
    self.show_end = false
    self.active_slot = 1
    self.all_slots_filled = false
    self.slot_filled = {false, false, false}
    self.slot_readings = {"", "", ""}
    self.slot_labels = {"", "", ""}
    self.hover_slot = -1
    self.hover_card = nil
    self.hover_preview_text = ""
    self.hover_info_card = nil
    self.loading_slots = {}
    self.reading_cache = {}
    self.pending_reading_requests = {}
    self.begin_pressed = false
    self.next_pressed = false
    self.play_again_pressed = false
    self.resolution_timer = 0
    self.resolution_shown = false
    self.resolution_title = ""
    self.resolution_readings = {}
    self.client_data_ready = false
    self.client_request_failed = false
    self.client_error_message = ""
    self.pending_client_data = nil
    self.client_error = nil

    Card.hovering_count = 0
    Card.holding_count = 0
end

function Game:reset()
    self:destroy_all_cards()
    self.hand:clear()
    for i = 1, 3 do
        self.slots[i]:clear()
        self.slots[i].enabled = false
    end
    self.vignette:clear()
    self.hover_panel:hide()
    self:_init_state()
end

function Game:setup_client_ui()
    self.show_cards = true
    self.show_intro = false
    self.show_loading = false
    self.show_resolution = false

    self.state.client_count = self.state.client_count + 1
    local enc = self.current_encounter or {}
    local client = enc.client or {}
    local client_name = client.name or "Unknown"

    -- Reset slots
    self.active_slot = 1
    self.all_slots_filled = false
    for i = 1, 3 do
        self.slot_filled[i] = false
        self.slot_readings[i] = ""
        self.slot_labels[i] = ""
        self.slots[i]:clear()
        self.slots[i].enabled = (i == 1)
    end
    self.reading_cache = {}
    self.pending_reading_requests = {}
    self.hover_slot = -1
    self.hover_card = nil
    self.hover_preview_text = ""

    -- Update sidebar
    self.sidebar:update_client(client_name, self.state.client_count, self.portraits:get_portrait(client_name))
    self.sidebar:update_progress(self.slot_filled)

    -- Update story panel
    self.story_panel.title = client_name
    self.story_panel.context = client.context or ""

    -- Deal hand
    self:_deal_hand()

    self.sidebar:update_deck_count(self.hand:get_card_count())
end

function Game:_deal_hand()
    local available = #self.deck.cards
    if available <= 0 then return end

    local drawn = self.deck:draw(available)
    for _, card_name in ipairs(drawn) do
        local card = Card.new(card_name, self.card_data)
        card.is_reversed = math.random() < 0.5
        self.hand:add_card(card)
    end
end

function Game:destroy_all_cards()
    self.hover_panel:hide()
    self.vignette:clear()

    for i = 1, 3 do
        self.slots[i]:clear()
    end
    self.hand:clear()
    Card.hovering_count = 0
    Card.holding_count = 0
end

function Game:update(dt)
    Tween.update_all(dt)
    self.richtext:update(dt)
    self.fsm:update(dt)

    -- Poll API responses
    self.api_client:update()
end

function Game:draw()
    -- Background
    love.graphics.setColor(0.08, 0.04, 0.14, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Column dividers
    love.graphics.setColor(0.85, 0.7, 0.4, 0.25)
    love.graphics.rectangle("fill", 279, 0, 1, 720)
    love.graphics.rectangle("fill", 830, 0, 1, 720)

    -- Story panel background (wood nine-patch)
    if self.wood_np then
        self.wood_np:draw(STORY_X, 0, STORY_W, 720)
    end

    -- Story panel content
    self.story_panel:draw(self.font_bold, self.font_small, self.richtext,
        self.slot_filled, self.slot_readings, self.active_slot,
        self.hover_slot, self.hover_preview_text)

    -- Sidebar
    self.sidebar:draw(self.font_small, self.font_tiny)

    -- Restart button
    self.restart_button:draw(self.font_tiny)

    -- Cards and slots
    if self.show_cards then
        -- Draw slot backgrounds
        for i = 1, 3 do
            local slot = self.slots[i]
            if self.slot_filled[i] then
                love.graphics.setColor(1, 1, 1, 0.15)
            elseif i == self.active_slot then
                love.graphics.setColor(0.85, 0.7, 0.4, 0.3)
            else
                love.graphics.setColor(1, 1, 1, 0.08)
            end
            love.graphics.rectangle("fill", slot.x, slot.y, slot.w, slot.h, 4, 4)
            love.graphics.setColor(0.85, 0.7, 0.4, 0.3)
            love.graphics.rectangle("line", slot.x, slot.y, slot.w, slot.h, 4, 4)
        end

        -- Slot labels
        love.graphics.setFont(self.font_tiny)
        for i = 1, 3 do
            local slot = self.slots[i]
            local label = self.slot_labels[i]
            if label and label ~= "" then
                love.graphics.setColor(0.85, 0.7, 0.4, 1)
                love.graphics.printf(label, slot.x, slot.y - 16, slot.w, "center")
            elseif i == self.active_slot and not self.slot_filled[i] then
                love.graphics.setColor(0.85, 0.7, 0.4, 0.7)
                love.graphics.printf("Place a card", slot.x, slot.y - 16, slot.w, "center")
            end
        end

        -- Reading labels under slots
        love.graphics.setFont(self.font_tiny)
        for i = 1, 3 do
            local slot = self.slots[i]
            local reading = self.slot_readings[i]
            if reading and reading ~= "" then
                local color
                if self.slot_filled[i] then
                    color = StoryPanel.SLOT_COLORS[i]
                else
                    color = StoryPanel.HOVER_COLORS[i]
                end
                love.graphics.setColor(color)
                love.graphics.printf(reading, slot.x - 10, slot.y + slot.h + 8, slot.w + 20, "center")
            end
        end

        -- Phase-specific drawing
        self.fsm:draw()

        -- Draw all cards sorted by z-index
        local all_cards = {}
        for _, card in ipairs(self.hand.cards) do all_cards[#all_cards + 1] = card end
        for i = 1, 3 do
            if self.slots[i].card then all_cards[#all_cards + 1] = self.slots[i].card end
        end
        table.sort(all_cards, function(a, b) return a.z_index < b.z_index end)
        for _, card in ipairs(all_cards) do
            card:draw()
        end

        -- Hover info panel
        self.hover_panel:update(self.hover_info_card, self.font_tiny)
        self.hover_panel:draw(self.font_tiny)
    end

    -- Vignette overlay (always on top of gameplay)
    self.vignette:draw()

    -- Overlay panels
    if self.show_loading then
        self:_draw_loading_panel()
    end

    if self.show_intro then
        self:_draw_intro_panel()
    end

    if self.show_resolution then
        self:_draw_resolution_panel()
    end

    if self.show_end then
        self.end_screen:populate(self.state.encounters, self.card_data, self.portraits)
        self.end_screen:draw(self.font_title, self.font_small)
        self.play_again_button:draw(self.font_small)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function Game:_draw_loading_panel()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    love.graphics.setColor(0.06, 0.03, 0.12, 0.92)
    love.graphics.rectangle("fill", 440, 280, 400, 160, 4, 4)
    love.graphics.setColor(0.85, 0.7, 0.4, 0.4)
    love.graphics.rectangle("line", 440, 280, 400, 160, 4, 4)

    love.graphics.setFont(self.font_bold)
    love.graphics.setColor(0.85, 0.7, 0.4, 1)
    love.graphics.printf("A visitor approaches...", 440, 340, 400, "center")
end

function Game:_draw_intro_panel()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local px, py, pw, ph = 340, 150, 600, 380
    love.graphics.setColor(0.06, 0.03, 0.12, 0.92)
    love.graphics.rectangle("fill", px + 8, py + 8, pw - 16, ph - 16, 4, 4)
    love.graphics.setColor(0.85, 0.7, 0.4, 0.4)
    love.graphics.rectangle("line", px, py, pw, ph, 4, 4)

    local enc = self.current_encounter or {}
    local client = enc.client or {}

    -- Portrait
    local portrait = self.portraits:get_portrait(client.name or "")
    if portrait then
        local ppw, pph = portrait:getDimensions()
        local scale = math.min(80 / ppw, 80 / pph)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(portrait, px + pw * 0.5 - (ppw * scale) * 0.5, py + 30, 0, scale, scale)
    end

    -- Name
    love.graphics.setFont(self.font_bold)
    love.graphics.setColor(0.85, 0.7, 0.4, 1)
    love.graphics.printf(client.name or "Unknown", px, py + 130, pw, "center")

    -- Context
    love.graphics.setFont(self.font_small)
    love.graphics.setColor(0.8, 0.75, 0.9, 1)
    love.graphics.printf(client.context or "", px + 40, py + 170, pw - 80, "center")

    -- Begin button
    self.intro_button.x = px + (pw - 200) * 0.5
    self.intro_button.y = py + ph - 60
    self.intro_button:draw(self.font_small)
end

function Game:_draw_resolution_panel()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local px, py, pw, ph = 290, 100, 700, 500
    love.graphics.setColor(0.06, 0.03, 0.12, 0.92)
    love.graphics.rectangle("fill", px + 8, py + 8, pw - 16, ph - 16, 4, 4)
    love.graphics.setColor(0.85, 0.7, 0.4, 0.4)
    love.graphics.rectangle("line", px, py, pw, ph, 4, 4)

    -- Title
    love.graphics.setFont(self.font_bold)
    love.graphics.setColor(0.85, 0.7, 0.4, 1)
    love.graphics.printf(self.resolution_title or "", px, py + 30, pw, "center")

    -- Divider
    love.graphics.setColor(0.85, 0.7, 0.4, 0.3)
    love.graphics.rectangle("fill", px + 40, py + 65, pw - 80, 1)

    -- Readings
    love.graphics.setFont(self.font_small)
    local ry = py + 90
    for i = 1, 3 do
        local reading = self.resolution_readings[i] or ""
        local color = StoryPanel.SLOT_COLORS[i] or {1, 1, 1, 1}
        love.graphics.setColor(color)
        love.graphics.printf(reading, px + 40, ry, pw - 80, "left")
        ry = ry + 100
    end

    -- Next button
    self.next_button.x = px + (pw - 200) * 0.5
    self.next_button.y = py + ph - 60
    self.next_button:draw(self.font_small)
end

function Game:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Restart button
    if self.restart_button:contains(x, y) then
        self:reset()
        self.fsm:transition("init")
        return
    end

    -- Play again
    if self.show_end and self.play_again_button:contains(x, y) then
        self.play_again_pressed = true
    end

    self.fsm:mousepressed(x, y, button)
end

function Game:mousereleased(x, y, button)
    self.fsm:mousereleased(x, y, button)
end

function Game:wheelmoved(x, y)
    if self.show_end then
        self.end_screen:wheelmoved(x, y)
    end
end

function Game:destroy()
    self.api_client:destroy()
end

return Game
