-- Turret Blacklist - Control Logic
-- Adds "Invert Targets" button to turret GUIs

-- ============================================================
-- Constants
-- ============================================================

local TURRET_PROTOTYPE_TYPES = {
  ["ammo-turret"] = true,
  ["electric-turret"] = true,
  ["fluid-turret"] = true,
}

-- ============================================================
-- Helper: Check if entity is a turret with priority targeting
-- ============================================================

local function is_turret(entity)
  if not entity or not entity.valid then return false end
  return TURRET_PROTOTYPE_TYPES[entity.type] ~= nil
end

-- ============================================================
-- Helper: Get all targetable entity prototype names
-- ============================================================

local function get_all_targetable_prototypes()
  local names = {}

  -- Enemy entities (biters, spitters, worms, spawners, enemy turrets)
  local enemy_types = {"unit", "unit-spawner", "turret"}
  local enemy_filters = {
    {filter = "type", type = enemy_types},
    {mode = "and", filter = "flag", flag = "placeable-enemy"},
  }
  for name, _ in pairs(prototypes.get_entity_filtered(enemy_filters)) do
    table.insert(names, name)
  end

  -- Asteroids (small/medium/big/huge × carbonic/metallic/oxide/promethium + chunks)
  for name, _ in pairs(prototypes.get_entity_filtered({
    {filter = "type", type = "asteroid"},
  })) do
    table.insert(names, name)
  end

  -- Custom types from settings
  local custom = settings.startup["turret-blacklist-additional-types"]
  if custom and custom.value ~= "" then
    local custom_types = {}
    for t in string.gmatch(custom.value, "[^,]+") do
      t = string.match(t, "^%s*(.-)%s*$")
      if t ~= "" then
        table.insert(custom_types, t)
      end
    end
    if #custom_types > 0 then
      for name, _ in pairs(prototypes.get_entity_filtered({
        {filter = "type", type = custom_types},
      })) do
        table.insert(names, name)
      end
    end
  end

  table.sort(names)
  return names
end

-- ============================================================
-- Helper: Read current priority list from entity
-- ============================================================

local function get_priority_list(entity)
  local list = {}
  local targets = entity.priority_targets
  if targets then
    for _, prototype in ipairs(targets) do
      table.insert(list, prototype.name)
    end
  end
  return list
end

-- ============================================================
-- Helper: Set priority list on entity
-- ============================================================

local function set_priority_list(entity, list)
  local current = get_priority_list(entity)
  for i = 1, #current do
    entity.set_priority_target(i, nil)
  end
  for i, name in ipairs(list) do
    entity.set_priority_target(i, name)
  end
end

-- ============================================================
-- Helper: Build inverted list
-- ============================================================

local function build_inverted_list(current_list)
  local all_targets = get_all_targetable_prototypes()

  local current_set = {}
  for _, name in ipairs(current_list) do
    current_set[name] = true
  end

  local inverted = {}
  for _, name in ipairs(all_targets) do
    if not current_set[name] then
      table.insert(inverted, name)
    end
  end

  return inverted
end

-- ============================================================
-- GUI: Create the inversion controls
-- ============================================================

local function create_inversion_gui(player)
  player.gui.relative.add({
    type = "frame",
    name = "turret-blacklist-frame",
    caption = {"turret-blacklist.gui-title"},
    direction = "vertical",
    anchor = {
      gui = defines.relative_gui_type.turret_gui,
      position = defines.relative_gui_position.bottom,
    },
  }).add({
    type = "button",
    name = "turret-blacklist-invert",
    caption = {"turret-blacklist.invert-targets"},
  })
end

-- ============================================================
-- GUI: Destroy inversion controls
-- ============================================================

local function destroy_inversion_gui(player)
  local frame = player.gui.relative["turret-blacklist-frame"]
  if frame then
    frame.destroy()
  end
end

-- ============================================================
-- Event: on_gui_opened
-- ============================================================

local function on_gui_opened(event)
  local player = game.players[event.player_index]
  if is_turret(event.entity) then
    create_inversion_gui(player)
  end
end

-- ============================================================
-- Event: on_gui_click
-- ============================================================

local function on_gui_click(event)
  local element = event.element
  if not element or not element.valid then return end
  if element.name ~= "turret-blacklist-invert" then return end

  local player = game.players[event.player_index]
  local entity = player.opened
  if not is_turret(entity) then return end

  local current_list = get_priority_list(entity)
  local inverted_list = build_inverted_list(current_list)

  if #inverted_list == 0 then
    player.print({"turret-blacklist.no-inversion-possible"})
    return
  end

  set_priority_list(entity, inverted_list)
  entity.ignore_unprioritised_targets = true
end

-- ============================================================
-- Event: on_gui_closed
-- ============================================================

local function on_gui_closed(event)
  destroy_inversion_gui(game.players[event.player_index])
end

-- ============================================================
-- Event registration
-- ============================================================

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
