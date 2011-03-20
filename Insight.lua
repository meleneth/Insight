function p_pretty(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
                if type(k) ~= 'number' then k = '"'..k..'"' end
                s = s .. '['..k..'] = ' .. p_pretty(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

-- INSIGHT START


SLASH_INSIGHT1 = '/insight';

InsightReport = {}
InsightReport.__index = InsightReport

function table_keys_sorted(t)
    local result = {};
    local i, d
    for i, d in pairs(t) do
        table.insert(result, i)
    end
    table.sort(result)
    return result
end

function InsightReport:render()
  local name, i
  local sorted_names = table_keys_sorted(self.items_by_name)
  local overall_total = 0
  local overall_qty = 0

  for i, name in pairs(sorted_names) do
    local d = self.items_by_name[name]
    local output_line = self.links_by_name[name] .. ": "
    local price, qty
    local sorted_prices = {}

    for price, qty in pairs(d) do
        table.insert(sorted_prices, price)
        overall_total = overall_total + (price * qty)
        overall_qty = overall_qty + qty
    end

    table.sort(sorted_prices)

    for i, price in pairs(sorted_prices) do
        local color_override = "none"

        if self:is_being_undercut(name, price) then
            color_override = "FF0000"
        else
            if(self.my_items_by_name[name][price]) then
                color_override = "00FFFF"
            end
        end

        if(self.good_prices[name]) then
            if(self.good_prices[name]  > price) then
                color_override = "FFFF00"
            end
        end

        if(color_override  == "none") then
            output_line = output_line .. d[price] .. "@" .. price .. " "
        else
            output_line = output_line .. "|cff" .. color_override .. d[price] .. "@" .. price .. "|r "
        end
    end

    print(output_line)
  end
  --print("player name: |cffFFAAFF" .. self.player_name .. "|rnormal text")
  print("Market total: " .. overall_qty .. " items, " .. overall_total .. "g" .. " (" .. (overall_total / overall_qty).. " average)")
end

function InsightReport:setup_good_prices()
    self.good_prices = {
        ["Volatile Life"] = 12,
        ["Eternal Earth"] =  7,
        ["Eternal Fire"] =  35,
        ["Eternal Life"] =  15,
        ["Eternal Shadow"] = 10,

        ["Majestic Zircon"] = 150,
        ["Ametrine"] = 150,
        ["King's Amber"] = 150,
        ["Cardinal Ruby "] = 150,
        ["Dreadstone"] = 150,
        
        ["Saronite Ore"] =  15,
        ["Dragon's Eye"] = 100,
        ["Arctic Fur"]   = 100

    }
end

function InsightReport:is_being_undercut(name, price)
    if(self.undercuts_by_name[name]) then
        if(self.undercuts_by_name[name][price]) then 
            return 1
        end
    end
    return nil
end

function InsightReport:show_sales_report()
    local settings = {["selectbox"] = {"1", "server"}, ["auction"] = true}
    local result = BeanCounter.API.search("Runed Cardinal Ruby", settings, true)
    local i, d
    for i, d in pairs(result) do 
        --print("Market total: " .. overall_qty .. " items, " .. overall_total .. "g" .. " (" .. (overall_total / overall_qty).. " average)")
        --print(p_pretty( d))
        when_sold = date("%m/%d/%Y", d[12])
        print(d[1] .. " sold on " .. when_sold .. " for " .. d[4])
    end
end

local function is_my_seller(n)
    local sellers = {
        ["Bartender"] = 1,
        ["Dustwynch"] = 1,
        ["Goodstuffz"] = 1,
        ["Varkesh"] = 1,
        ["Goldmaker"] = 1,
    }
    if(not n) then
        print("Seller was nil :/")
        return nil
    end
    return sellers[n]
end

function InsightReport:scan_my_lowest_posted(data)
  local i, d
  for i, d in pairs(data) do
    -- 17 = buyout, 1 = link, 9 = name, 11 = count
    local price_each = d[17] / d[11]
    local price_in_gold = math.floor(price_each / 10000)
    local name = d[9]
    local seller = d[20]

    if(is_my_seller(seller)) then
      if not self.my_lowest_posted_by_name[name] then
        self.my_lowest_posted_by_name[name] = price_each
      end
    end

  end
end

function InsightReport:add_data(data)
  self:scan_my_lowest_posted(data)

  local i, d
  for i, d in pairs(data) do
    -- 17 = buyout, 1 = link, 9 = name, 11 = count
    local price_each = d[17] / d[11]
    local price_in_gold = math.floor(price_each / 10000)
    local name = d[9]
    local seller = d[20]

    if not self.items_by_name[name] then 
        self.items_by_name[name]    = {}
        self.my_items_by_name[name] = {}
    end
   
    if not self.items_by_name[name][price_in_gold] then
    	self.items_by_name[name][price_in_gold]    = 0
    	self.my_items_by_name[name][price_in_gold] = nil
    end
 
    self.links_by_name[name] = d[1]
    self.items_by_name[name][price_in_gold] = d[11] + self.items_by_name[name][price_in_gold]; 

    if(is_my_seller(seller)) then
        if(price_each) then 
            self.my_items_by_name[name][price_in_gold] = 1
        end
    else
      if self.my_lowest_posted_by_name[name] then
        if price_each < self.my_lowest_posted_by_name[name] then
          if not self.undercuts_by_name[name] then
            self.undercuts_by_name[name] = {}
          end
          self.undercuts_by_name[name][price_in_gold] = 1
        end
      end
    end
  end
end

function InsightReport.create(n)
    local report = { 
        name = n,
        player_name = UnitName("player"),
        item_names = {},
        items_by_name = {},
        links_by_name =  {},
        my_items_by_name = {},
        my_lowest_posted_by_name = {},
        undercuts_by_name = {},
        lowest_posted_by_name = {}
    }
    setmetatable(report, InsightReport)
    return report
end

local function is_uncut_gem(item_info)
    local raw_gem_names = { 
        ["Inferno Ruby"] = 1, 
        ["Demonseye"] = 1, 
        ["Ember Topaz"] = 1, 
        ["Amberjewel"] = 1,
        ["Ocean Sapphire"] = 1,
        ["Dream Emerald"] = 1
    }

    return not raw_gem_names[item_info[9]]
end

local function is_uncut_epic_gem(item_info)
    local raw_epic_gem_names = { 
        ["Cardinal Ruby"] = 1, 
        ["Dreadstone"] = 1, 
        ["Ametrine"] = 1, 
        ["King's Amber"] = 1,
        ["Majestic Zircon"] = 1,
        ["Eye of Zul"] = 1,
        ["Dragon's Eye"] = 1,
        ["Nightmare Tear"] = 1
    }

    return not raw_epic_gem_names[item_info[9]]
end

local function is_uncut_green_gem(item_info)
    local raw_green_gem_names = { 
        ["Carnelian"] = 1, 
        ["Nightstone"] = 1, 
        ["Hessonite"] = 1, 
        ["Alicite"] = 1,
        ["Zephyrite"] = 1,
        ["Jasper"] = 1
    }

    return not raw_green_gem_names[item_info[9]]
end

local function is_pipeline_item(item_info)
    local pipeline_names = { 
        ["Scarlet Ruby"] = 1,
        ["Saronite Ore"] = 1,
        ["Saronite Bar"] = 1,
        ["Frost Lotus"] = 1,
        ["Titanium Bar"] = 1,
        ["Titanium Ore"] = 1,
        ["Dragon's Eye"] = 1,
        ["Lichbloom"] = 1
    }

    return not pipeline_names[item_info[9]]
end

local function is_product_item(item_info)
    local product_names = { 
        ["Eternal Belt Buckle"] = 1,
        ["Nightmare Tear"] = 1,
        ["Nobles Deck"] = 1,
        ["Spellweave"] = 1,
        ["Ebonweave"] = 1,
        ["Moonshroud"] = 1
    }

    return not product_names[item_info[9]]
end

local function is_eternal_item(item_info)
    local eternal_names = { 
        ["Eternal Earth"] = 1,
        ["Eternal Air"] = 1,
        ["Eternal Fire"] = 1,
        ["Eternal Shadow"] = 1,
        ["Eternal Life"] = 1,
        ["Eternal Water"] = 1
    }

    return not eternal_names[item_info[9]]
end

local function is_argent_pet_item(item_info)
    local pet_names = { 
        ["Ammen Vale Lashling"] = 1,
        ["Dun Morogh Cub"] = 1,
        ["Durotar Scorpion"] = 1,
        ["Elwynn Lamb"] = 1,
        ["Enchanted Broom"] = 1,
        ["Teldrassil Sproutling"] = 1,
        ["Tirisfal Batling"] = 1,
        ["Mechanopeep"] = 1,
        ["Mulgore Hatchling"] = 1,
        ["Sen'jin Fetish"] = 1
    }
    return not pet_names[item_info[9]]
end

local function is_toc_item(item_info)
    local toc_names = { 
        ["Band of the Traitor King"] = 1,
        ["Signet of the Traitor King"] = 1,
        ["Circle of the Darkmender"] = 1,
        ["Ring of the Darkmender"] = 1,
        ["Cloak of Displacement"] = 1,
        ["Shroud of Displacement"] = 1,
        ["Cloak of the Untamed Predator"] = 1,
        ["Drape of the Untamed Predator"] = 1,
        ["The Executioner's Vice"] = 1,
        ["Plans: Sunforged Bracers"] = 1,
        ["Plans: Sunforged Breastplate"] = 1,
        ["Plans: Titanium Razorplate"] = 1,
        ["Plans: Titanium Spikeguards"] = 1,
        ["Plans: Breastplate of the White Knight"] = 1,
        ["Plans: Saronite Swordbreakers"] = 1,
        ["Pattern: Royal Moonshroud Robe"] = 1,
        ["Pattern: Royal Moonshroud Bracers"] = 1,
        ["Pattern: Merlin's Robe"] = 1,
        ["Pattern: Bejeweled Wizard's Bracers"] = 1
    }

    return not toc_names[item_info[9]]
end

local function is_icc_item(item_info)
    local icc_names = { 
        ["Belt of the Blood Nova"] = 1,
        ["Belt of the Lonely Noble"] = 1,
        ["Blood Queen's Crimson Choker"] = 1,
        ["Carapace of Forgotten Kings"] = 1,
        ["Crypt Keeper's Bracers"] = 1,
        ["Harbinger's Bone Band"] = 1,
        ["Ikfirus's Sack of Wonder"] = 1,
        ["Leggings of Dubious Charms"] = 1,
        ["Marrowgar's Frigid Eye"] = 1,
        ["Nightmare Ender"] = 1,
        ["Professor's Bloodied Smock"] = 1,
        ["Raging Behemoth's Shoulderplates"] = 1,
        ["Ring of Rotting Sinew"] = 1,
        ["Rowan's Rifle of Silver Bullets"] = 1,
        ["Stiffened Corpse Shoulderpads"] = 1,
        ["Wodin's Lucky Necklace"] = 1,
    }

    return not icc_names[item_info[9]]
end

local function is_lw_item(item_info)
    local lw_names = { 
        ["Borean Leather"] = 1,
        ["Heavy Borean Leather"] = 1,
        ["Icy Dragonscale"] = 1,
        ["Nerubian Chitin"] = 1,
        ["Jormungar Scale"] = 1,
        ["Frozen Orb"] = 1,
    }

    return not lw_names[item_info[9]]
end

local function is_legarmor_item(item_info)
    local legarmor_names = { 
        ["Earthen Leg Armor"] = 1,
        ["Frosthide Leg Armor"] = 1,
        ["Icescale Leg Armor"] = 1,
    }

    return not legarmor_names[item_info[9]]
end

local function is_my_auctioned_item(item_info)
    print "Functionality not yet available: show market status of all items I have posted"
    return nil
end

local function insight_cmd_handler(msg, editbox)
  print("--- Results for " .. msg .. " --")
  local extracted = {}
  local links_by_name = {}

  report = InsightReport.create("Flibbity")
  report:setup_good_prices()

  local query_data
  if msg == "gems" then
    query_data = AucAdvanced.API.QueryImage({filter = is_uncut_gem})
  elseif msg == "greengems" then
    query_data = AucAdvanced.API.QueryImage({filter = is_uncut_green_gem})
  elseif msg == "epicgems" then
    query_data = AucAdvanced.API.QueryImage({filter = is_uncut_epic_gem})
  elseif msg == "pipeline" then
    query_data = AucAdvanced.API.QueryImage({filter = is_pipeline_item})
  elseif msg == "products" then
    query_data = AucAdvanced.API.QueryImage({filter = is_product_item})
  elseif msg == "eternals" then
    query_data = AucAdvanced.API.QueryImage({filter = is_eternal_item})
  elseif msg == "argentpets" then
    query_data = AucAdvanced.API.QueryImage({filter = is_argent_pet_item})
  elseif msg == "toc" then
    query_data = AucAdvanced.API.QueryImage({filter = is_toc_item})
  elseif msg == "icc" then
    query_data = AucAdvanced.API.QueryImage({filter = is_icc_item})
  elseif msg == "lw" then
    query_data = AucAdvanced.API.QueryImage({filter = is_lw_item})
  elseif msg == "legarmor" then
    query_data = AucAdvanced.API.QueryImage({filter = is_legarmor_item})
  elseif msg == "auctions" then
    report:find_my_auctions()
    query_data = AucAdvanced.API.QueryImage({filter = is_my_auctioned_item})
  elseif msg == "sales" then
      report:show_sales_report()
      return
  elseif msg == "" then
    print "Usage: /insight name - name is what to search for, or one of specials"
    print "       'gems', 'greengems', 'epicgems', 'pipeline', 'products', "
    print "       'eternals', 'toc', 'auctions', 'argentpets', 'icc', 'lw', 'legarmor'"
    return
  else
    query_data = AucAdvanced.API.QueryImage({name = msg})
  end

  report:add_data(query_data)
  report:render()
 
end

SlashCmdList["INSIGHT"] = insight_cmd_handler
