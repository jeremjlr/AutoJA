--AutoJA addon for ffxi Ashita
--Copyright (C) 2022 Lumlum

--This program is free software: you can redistribute it and/or modify
--it under the terms of the GNU Affero General Public License as published
--by the Free Software Foundation, either version 3 of the License, or
--(at your option) any later version.

--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU Affero General Public License for more details.

--You should have received a copy of the GNU Affero General Public License
--along with this program.  If not, see <https://www.gnu.org/licenses/>.

_addon.name = 'AutoJA'
_addon.version = '0.1'
_addon.author = 'Lumlum'

require 'common'
require 'ffxi.recast'

timer_started = false;
active_abilities = {},{"en", "recast_id", "tp_cost", "engaged_only", "use_if_paralyzed"};

function AutoJAMessage(message)
  print("\31\200[\31\05AutoJA\31\200]\31\207 " .. message)
end

local function Print_Help(cmd, help)
  print("\31\200[\31\05" .. _addon.name .. "\31\200]\30\01 " .. "\30\68Command:\30\02 " .. cmd .. "\30\71 -- " .. help);
end

ashita.register_event('load', function()
    ashita.timer.adjust_timer("autoja", 3, 0, UseAbilities);
  end);

ashita.register_event('command', function(command, ntype)
    local args = command:args();
    if args[1] ~= "/autoja" then
      return false;
    end

    if args[2] == "help" then
      Print_Help("add", "Adds the ability to the active list. Only accepts self-targeting abilities. /autoja add [ability] [engaged_only=off] [use_if_paralyzed=off]. ie: /autoja add berserk on on");
      Print_Help("remove", "Removes the ability from the active list.");
      Print_Help("clear", "Clears the active list.");
      Print_Help("list", "Lists the active list.");
      Print_Help("proc", "Uses an ability from the active list.");
      Print_Help("start", "Starts automatically using abilities.");
      Print_Help("stop", "Stops automatically using abilities.");
    elseif args[2] == "add" and args[3] ~= nil then
      --Checks if ability is already in the list, if yes returns
      for i,v in pairs(active_abilities) do
        if args[3]:lower() == v.en:lower() then
          AutoJAMessage(args[3] .. " is already an active JA.");
          return true;
        end
      end
      --Only accepts self-targeting JAs ie: Berserk, Hasso...
      tocheck_name = args[3]:lower();
      tocheck_ability = AshitaCore:GetResourceManager():GetAbilityByName(tocheck_name, 0);
      if tocheck_ability ~= nil and tocheck_ability.ValidTargets == 1 then
        if args[4] ~= nil and args[4] == "on" then
          if args[5] ~= nil and args[5] == "on" then
            temp = {en=tocheck_name, recast_id=tocheck_ability.TimerId, tp_cost=tocheck_ability.TP, engaged_only=true, use_if_paralyzed=true};
          else
            temp = {en=tocheck_name, recast_id=tocheck_ability.TimerId, tp_cost=tocheck_ability.TP, engaged_only=true, use_if_paralyzed=false};
          end
        else
          if args[5] ~= nil and args[5] == "on" then
            temp = {en=tocheck_name, recast_id=tocheck_ability.TimerId, tp_cost=tocheck_ability.TP, engaged_only=false, use_if_paralyzed=true};
          else
            temp = {en=tocheck_name, recast_id=tocheck_ability.TimerId, tp_cost=tocheck_ability.TP, engaged_only=false, use_if_paralyzed=false};
          end
        end
        table.insert(active_abilities, temp);
        AutoJAMessage(args[3] .. " was added. Engaged only: "..tostring(temp.engaged_only).." || Use if paralyzed: "..tostring(temp.use_if_paralyzed));
        return true;
      end
      AutoJAMessage(args[3] .. " is not a valid JA and could not be added.");
      return true;
    elseif args[2] == "remove" and args[3] ~= nil then
      for i,v in pairs(active_abilities) do
        if args[3]:lower() == v.en:lower() then
          table.remove(active_abilities, i);
          AutoJAMessage(args[3] .. " was removed.");
          return true;
        end
      end
      AutoJAMessage(args[3] .. " is not an active ability.");
      return true;
    elseif args[2] == "clear" then
      active_abilities = {},{"en", "recast_id", "tp_cost", "engaged_only", "use_if_paralyzed"};
      AutoJAMessage("Active abilities cleared.");
      return true;
    elseif args[2] == "list" then
      AutoJAMessage("Active abilities :");
      for i,v in pairs(active_abilities) do
        AutoJAMessage(i..": "..v.en..". Engaged only: "..tostring(v.engaged_only).." || Use if paralyzed: "..tostring(v.use_if_paralyzed));
      end
      return true;
    elseif args[2] == "proc" then
      UseAbilities();
      return true;
    elseif args[2] == "start" then
      ashita.timer.start_timer("autoja");
      timer_started = true;
      AutoJAMessage("AutoJA started.");
      return true;
    elseif args[2] == "stop" then
      ashita.timer.stop("autoja");
      timer_started = false;
      AutoJAMessage("AutoJA stopped.");
      return true;
    end
    return false;
  end);

function HaveBuff(buff_name)
  local buffs = AshitaCore:GetDataManager():GetPlayer():GetBuffs();
  for i,v in pairs(buffs) do
    if buff_name:lower() == AshitaCore:GetResourceManager():GetString("statusnames", v):lower() then
      return true;
    end
  end
  return false;
end

-- Checks if the player has the JAs' buffs already, if not, tries to use them if his job can
function UseAbilities()
  for i,v in pairs(active_abilities) do
    if not HaveBuff(v.en) then
      -- ashita.ffxi.recast.get_ability_recast_by_id(v.recast_id) is equal to -1 if the player's job doesn't have the JA at all
      -- Also checks if it the player has enough tp if it's a dnc ability, and if the player is not dead
      if ashita.ffxi.recast.get_ability_recast_by_id(v.recast_id) == 0 and AshitaCore:GetDataManager():GetParty():GetMemberCurrentTP(0) >= v.tp_cost and AshitaCore:GetDataManager():GetParty():GetMemberCurrentHP(0) > 0 then
        if not v.engaged_only or (v.engaged_only and GetPlayerEntity().Status==1) then
          -- Doesn't try to use JA if you can't
          if not HaveBuff("amnesia") and not HaveBuff("impairment") and (not HaveBuff("Paralysis") or v.use_if_paralyzed) then
            AutoJAMessage("USING : "..v.en);
            AshitaCore:GetChatManager():QueueCommand('/ja "'..v.en..'" <me>', 1);
            return;
          end
        end
      end
    end
  end
end

ashita.register_event('incoming_packet', function(id, size, packet, packet_modified, blocked)
    if (id == 0xB) and timer_started then
      ashita.timer.stop("autoja");
      timer_started = false;
      AutoJAMessage("AutoJA stopped after zoning.");
    end
    return false;
  end);