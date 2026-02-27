local CardData = require("src.cards.card_data")
local Card = require("src.cards.card")
local Hand = require("src.cards.hand")
local Slot = require("src.cards.slot")
local DragManager = require("src.cards.drag_manager")
local Deck = require("src.systems.deck")
local FSM = require("src.states.fsm")
local GameState = require("src.systems.game_state")
local ReadingManager = require("src.systems.reading_manager")

local InitState = require("src.states.init")
local ClientLoadingState = require("src.states.client_loading")
local IntroState = require("src.states.intro")
local ReadingActiveState = require("src.states.reading_active")
local ResolutionState = require("src.states.resolution")
local GameEndState = require("src.states.game_end")

local clients = {
  { name = "Elsa the Miller", context = "The harvest failed, and my family needs hope before winter closes in." },
  { name = "Gregor the Guard", context = "I was offered coin to look away. Should I protect my honor or my purse?" },
  { name = "Mara the Scholar", context = "A letter arrived from my estranged sister after ten years of silence." },
}

local Game = {}
Game.__index = Game

function Game.new()
  local self = setmetatable({}, Game)
  CardData.load_all()
  self.state = GameState.new()
  self.hand = Hand.new()
  self.reading_manager = ReadingManager.new()
  self.deck = Deck.new(CardData.build_deck_names())
  self.cards_in_play = {}
  self.slots = {
    Slot.new(1, 420, 180),
    Slot.new(2, 570, 180),
    Slot.new(3, 720, 180),
  }
  self.drag_manager = DragManager.new(function() return self.cards_in_play end, self.slots, self.hand)
  self.fsm = FSM.new(self)
  self.fsm:register("init", InitState(self))
  self.fsm:register("client_loading", ClientLoadingState(self))
  self.fsm:register("intro", IntroState(self))
  self.fsm:register("reading_active", ReadingActiveState(self))
  self.fsm:register("resolution", ResolutionState(self))
  self.fsm:register("game_end", GameEndState(self))
  self.fsm:transition_to("init")
  return self
end

function Game:reset_run_data()
  self.state = GameState.new()
  self.deck = Deck.new(CardData.build_deck_names())
  self.hand.cards = {}
  self.cards_in_play = {}
  self.state.session.encounter_index = 0
end

function Game:prepare_next_client()
  self.state.session.encounter_index = self.state.session.encounter_index + 1
  local idx = ((self.state.session.encounter_index - 1) % #clients) + 1
  self.state.encounter.client = clients[idx]
  for i, slot in ipairs(self.slots) do
    slot.card = nil
    slot.reading = ""
    slot.enabled = i == 1
  end
  self.hand.cards = {}
  self.cards_in_play = {}
  for _, card_name in ipairs(self.deck:draw_many(9)) do
    local card = Card.new(card_name, CardData)
    self.hand:add_card(card)
    self.cards_in_play[#self.cards_in_play + 1] = card
  end
end

function Game:on_slot_filled(slot_index)
  local slot = self.slots[slot_index]
  slot.reading = self.reading_manager:generate(slot.card, slot_index)
  if slot_index < #self.slots then
    self.slots[slot_index + 1].enabled = true
  end
end

function Game:all_slots_filled()
  for _, slot in ipairs(self.slots) do
    if not slot.card then return false end
  end
  return true
end

function Game:is_run_complete()
  return #self.deck.remaining < 9
end

function Game:record_encounter()
  local readings = {}
  for _, slot in ipairs(self.slots) do
    readings[#readings + 1] = slot.reading
  end
  self.state.session.encounters[#self.state.session.encounters + 1] = {
    client = self.state.encounter.client.name,
    readings = readings,
  }
end

function Game:update(dt)
  for _, card in ipairs(self.cards_in_play) do
    card:update(dt)
  end
  if self.fsm.current and self.fsm.current.update then self.fsm.current:update(dt) end
end

function Game:draw_board()
  love.graphics.setColor(0.2, 0.16, 0.14)
  love.graphics.rectangle("fill", 20, 20, 260, 680, 12, 12)
  love.graphics.setColor(0.9, 0.85, 0.74)
  love.graphics.printf(self.state.encounter.client and self.state.encounter.client.name or "", 40, 40, 220, "left")
  love.graphics.printf(string.format("Deck: %d", #self.deck.remaining), 40, 90, 220, "left")

  for _, slot in ipairs(self.slots) do slot:draw() end

  table.sort(self.cards_in_play, function(a, b) return a.z_index < b.z_index end)
  for _, card in ipairs(self.cards_in_play) do card:draw(true) end
end

function Game:draw()
  if self.fsm.current and self.fsm.current.draw then
    self.fsm.current:draw()
  else
    self:draw_board()
  end
end

function Game:mousemoved(x, y)
  if self.fsm.current and self.fsm.current.mousemoved then self.fsm.current:mousemoved(x, y) end
end

function Game:mousepressed(x, y, button)
  if self.fsm.current and self.fsm.current.mousepressed then self.fsm.current:mousepressed(x, y, button) end
end

function Game:mousereleased(x, y, button)
  if self.fsm.current and self.fsm.current.mousereleased then self.fsm.current:mousereleased(x, y, button) end
end

function Game:wheelmoved(y)
  if self.fsm.current and self.fsm.current.wheelmoved then self.fsm.current:wheelmoved(y) end
end

return Game
