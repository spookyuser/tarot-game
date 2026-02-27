-- Async API client for Claude readings and client generation
-- Uses love.thread for non-blocking HTTP requests
local json = require("src.lib.json")
local util = require("src.lib.util")

local ApiClient = {}
ApiClient.__index = ApiClient

local ENDPOINT_URL = "https://tarot-api-proxy.wenhop.workers.dev"
local READING_MODEL = "anthropic/claude-sonnet-4-6"
local CLIENT_MODEL = "anthropic/claude-opus-4-6"

local SYSTEM_PROMPT_READING = [[You are an oracle in a port town. The cards show what will happen - not metaphors, not advice, but events that are already in motion.

You'll receive a client (who they are, what brought them here) and three reading slots. Exactly one slot has a card placed but no text yet. Write one sentence for that slot.

## Voice
- Second person ("you")
- One sentence. Short enough to read at a glance.
- Concrete and specific: a person's name, a street, an object, a time of day. No abstractions, no metaphors, no poetic flourishes
- These events WILL happen. Write them as settled fact.
- Slightly oblique - the event is clear, but its full meaning may not be obvious yet

## Using the Card
A reversed card means the energy is blocked, inverted, or arrives unwanted. The event still happens - it just cuts differently.

## Slot Positions
- Slot 0: Something arrives or is discovered
- Slot 1: Something shifts or complicates
- Slot 2: Where it leads - a door opens or closes
If earlier slots have text, continue from them. Never contradict what's established.

## Echoes Across Readings
If previous readings from other clients are included, you may OCCASIONALLY reuse a specific detail from an earlier reading - the same street name, object, time of day, or person's name - woven naturally into THIS client's event. Do this rarely (at most once per full reading, and not every reading). Never explain the connection. Never call attention to it. The player notices, or they don't.

Return ONLY the sentence. No JSON. No quotes. No commentary. It should be short and direct enough to fit on a small slip of paper.]]

local SYSTEM_PROMPT_CLIENT = [[You invent people who walk into a tarot reader's tent in a small port town. Each person is real - they have a job, a home, people they care about, a specific problem they can't solve alone.

Output a JSON object:
- "name": First name and a descriptor rooted in who they are - their trade, a habit, a reputation.
- "context": [MAX 1 sentence] A short direct sentence in first person ("I"). What they say when they sit down. Raw, direct, specific. They're stuck and they need answers.

Guidelines:
- They should have problems that are human and that we all understand - not "I want to find love" but "I can't stop arguing with my partner, and I don't know if we can fix it." Not "I'm stressed about money" but "I lost my job and I have rent due in three days." The more specific, the better. The cards will be more specific in response.

Return ONLY valid JSON. No markdown. No commentary.]]

-- Thread code for async HTTP
local THREAD_CODE = [[
local request_channel = love.thread.getChannel("api_requests")
local response_channel = love.thread.getChannel("api_responses")

while true do
    local req = request_channel:demand()
    if req == "quit" then break end

    local http = require("https")
    local code, body, headers = http.request(req.url, {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
        },
        data = req.body,
    })

    response_channel:push({
        id = req.id,
        kind = req.kind,
        code = code,
        body = body,
    })
end
]]

function ApiClient.new(game)
    local self = setmetatable({}, ApiClient)
    self.game = game
    self.pending = {}  -- id -> kind
    self.thread = nil
    self.request_channel = nil
    self.response_channel = nil
    self.has_https = false

    -- Try to start the HTTP thread
    local ok = pcall(function()
        require("https")
        self.has_https = true
    end)

    if self.has_https then
        self.request_channel = love.thread.getChannel("api_requests")
        self.response_channel = love.thread.getChannel("api_responses")
        self.thread = love.thread.newThread(THREAD_CODE)
        self.thread:start()
    end

    return self
end

function ApiClient:update()
    if not self.has_https then return end

    while true do
        local resp = self.response_channel:pop()
        if not resp then break end

        local id = resp.id
        local kind = resp.kind

        if not self.pending[id] then
            -- Stale response, ignore
        elseif resp.code ~= 200 then
            self.pending[id] = nil
            self:_handle_error(id, kind, "HTTP " .. tostring(resp.code))
        else
            self.pending[id] = nil
            self:_handle_response(id, kind, resp.body)
        end
    end
end

function ApiClient:generate_reading(request_id, reading_state)
    if not self.has_https then
        -- Fallback: use a placeholder reading
        self.game.reading_cache[request_id] = "The stars remain silent tonight."
        return
    end

    local user_prompt = self:_build_reading_prompt(reading_state)
    self:_send_request(request_id, "reading", READING_MODEL, SYSTEM_PROMPT_READING, user_prompt, 150, 1.7)
end

function ApiClient:generate_client(request_id, game_state)
    if not self.has_https then
        -- Fallback: use hardcoded clients
        local fallback_clients = {
            {name = "Old Thomas the Fisherman", context = "I haven't caught anything in three weeks. My nets come up empty every morning and I don't know if the sea is punishing me or if I should just stop going out."},
            {name = "Elena the Baker's Daughter", context = "My father wants me to take over the bakery but I found a letter he was hiding - my mother didn't die, she left us, and she's living two towns over."},
            {name = "Sergeant Maren", context = "I was ordered to arrest a man I know is innocent, and if I don't do it by sunrise they'll come for me instead."},
        }
        local idx = (self.game.state.encounter_index % #fallback_clients) + 1
        self.game.pending_client_data = fallback_clients[idx]
        self.game.client_data_ready = true
        return
    end

    local user_prompt = self:_build_client_prompt(game_state)
    self:_send_request(request_id, "client", CLIENT_MODEL, SYSTEM_PROMPT_CLIENT, user_prompt, 150, 1.7)
end

function ApiClient:_send_request(id, kind, model, system_prompt, user_prompt, max_tokens, temperature)
    self.pending[id] = kind

    local body = json.encode({
        model = model,
        max_tokens = max_tokens,
        temperature = temperature,
        messages = {
            {role = "system", content = system_prompt},
            {role = "user", content = user_prompt},
        },
    })

    self.request_channel:push({
        id = id,
        kind = kind,
        url = ENDPOINT_URL,
        body = body,
    })
end

function ApiClient:_handle_response(id, kind, body_text)
    local parsed = json.decode(body_text)
    if not parsed then
        self:_handle_error(id, kind, "JSON parse error")
        return
    end

    -- Extract text from OpenAI-compatible response
    local text = ""
    if parsed.choices and parsed.choices[1] and parsed.choices[1].message then
        text = parsed.choices[1].message.content or ""
    end
    text = text:match("^%s*(.-)%s*$") or ""

    if text == "" then
        self:_handle_error(id, kind, "Empty response")
        return
    end

    if kind == "reading" then
        self.game.reading_cache[id] = text
        -- If this is for a filled slot, update the reading
        local parts = {}
        for part in id:gmatch("[^:]+") do parts[#parts+1] = part end
        if #parts == 3 then
            local slot_idx = tonumber(parts[3])
            if slot_idx and self.game.slot_filled[slot_idx] then
                self.game.slot_readings[slot_idx] = text
            end
        end
    elseif kind == "client" then
        local client_text = util.strip_markdown_fence(text)
        local client_data = json.decode(client_text)
        if not client_data then
            -- Try to extract JSON from text
            local start = client_text:find("{")
            local finish = client_text:find("}")
            if start and finish then
                client_data = json.decode(client_text:sub(start, finish))
            end
        end
        if client_data and client_data.name and client_data.context then
            self.game.pending_client_data = client_data
            self.game.client_data_ready = true
        else
            self:_handle_error(id, kind, "Invalid client response shape")
        end
    end
end

function ApiClient:_handle_error(id, kind, message)
    if kind == "reading" then
        self.game.reading_cache[id] = "The cards are silent..."
    elseif kind == "client" then
        self.game.client_request_failed = true
        self.game.client_error_message = message
    end
end

function ApiClient:_build_reading_prompt(reading_state)
    local game_state = reading_state.game_state or {}
    local active_index = reading_state.active_encounter_index or 0
    local runtime = reading_state.runtime_state or {}

    local encounters = game_state.encounters or {}
    local encounter = encounters[active_index + 1] or {}
    local client = encounter.client or {}

    local slots = {}
    local slot_cards = runtime.slot_cards or {}
    local slot_texts = runtime.slot_texts or {}
    local slot_orientations = runtime.slot_orientations or {}

    for i = 1, 3 do
        slots[i] = {
            index = i - 1,
            card = (slot_cards[i] or ""):gsub("_", " "),
            text = slot_texts[i] or "",
            orientation = slot_orientations[i] or "",
        }
    end

    local payload = {
        client = {
            name = client.name or "",
            situation = client.context or "",
        },
        slots = slots,
    }

    -- Add previous readings
    local previous = {}
    local start_idx = math.max(1, active_index - 2)
    for i = start_idx, active_index do
        local enc = encounters[i]
        if enc then
            local enc_client = enc.client or {}
            local name = enc_client.name or ""
            if name ~= "" then
                local readings = {}
                for _, slot in ipairs(enc.slots or {}) do
                    if slot.text and slot.text ~= "" then
                        readings[#readings+1] = slot.text
                    end
                end
                if #readings > 0 then
                    previous[#previous+1] = {client = name, readings = readings}
                end
            end
        end
    end
    if #previous > 0 then
        payload.previous_readings = previous
    end

    return json.encode(payload, true)
end

function ApiClient:_build_client_prompt(game_state)
    local prompt = "A new visitor walks into the tent. Create them."
    local encounters = game_state.encounters or {}
    if #encounters == 0 then return prompt end

    local lines = {}
    local start_idx = math.max(1, #encounters - 3)
    for i = start_idx, #encounters do
        local enc = encounters[i]
        if enc then
            local client = enc.client or {}
            local name = client.name or "Unknown"
            local context = client.context or ""
            lines[#lines+1] = "- " .. name .. ": " .. context
        end
    end

    if #lines > 0 then
        prompt = prompt .. "\n\nOther visitors today (avoid repeating their problems):\n"
        prompt = prompt .. table.concat(lines, "\n")
        prompt = prompt .. "\n\nMake this person distinct from the people above in age, occupation, temperament, and concern."
    end

    return prompt
end

function ApiClient:destroy()
    if self.request_channel then
        self.request_channel:push("quit")
    end
end

return ApiClient
