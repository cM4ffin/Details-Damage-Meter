--> customized display script

	local _detalhes = 		_G._detalhes
	local gump = 			_detalhes.gump
	local _
	
	_detalhes.custom_function_cache = {}
	
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> local pointers

	local _cstr = string.format --lua local
	local _math_floor = math.floor --lua local
	local _table_sort = table.sort --lua local
	local _table_insert = table.insert --lua local
	local _table_size = table.getn --lua local
	local _setmetatable = setmetatable --lua local
	local _ipairs = ipairs --lua local
	local _pairs = pairs --lua local
	local _rawget= rawget --lua local
	local _math_min = math.min --lua local
	local _math_max = math.max --lua local
	local _bit_band = bit.band --lua local
	local _unpack = unpack --lua local
	local _type = type --lua local
	local _pcall = pcall -- lua local
	
	local _GetSpellInfo = _detalhes.getspellinfo -- api local
	local _IsInRaid = IsInRaid -- api local
	local _IsInGroup = IsInGroup -- api local
	local _GetNumGroupMembers = GetNumGroupMembers -- api local
	local _GetNumPartyMembers = GetNumPartyMembers or GetNumSubgroupMembers -- api local
	local _GetNumRaidMembers = GetNumRaidMembers or GetNumGroupMembers -- api local
	local _GetUnitName = GetUnitName -- api local
	
	local _string_replace = _detalhes.string.replace --details api
	local Loc = LibStub ("AceLocale-3.0"):GetLocale ( "Details" )
	
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> constants

	local atributo_custom = _detalhes.atributo_custom
	atributo_custom.mt = {__index = atributo_custom}
	
	local combat_containers = {
		["damagedone"] = 1,
		["healdone"] = 2,
	}
	
	--> hold the mini custom objects
	atributo_custom._InstanceActorContainer = {}
	atributo_custom._InstanceLastCustomShown = {}
	atributo_custom._InstanceLastCombatShown = {}
	atributo_custom._TargetActorsProcessed = {}
	
	local ToKFunctions = _detalhes.ToKFunctions
	local SelectedToKFunction = ToKFunctions [1]
	local FormatTooltipNumber = ToKFunctions [8]
	local TooltipMaximizedMethod = 1
	local UsingCustomRightText = false
	local UsingCustomLeftText = false
	
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> core

	function atributo_custom:GetCombatContainerIndex (attribute)
		return combat_containers [attribute]
	end

	function atributo_custom:RefreshWindow (instance, combat, force, export)

		--> get the custom object
		local custom_object = instance:GetCustomObject()

		if (not custom_object) then
			return instance:ResetAttribute()
		end

		--> save the custom name in the instance
		instance.customName = custom_object:GetName()
		
		--> get the container holding the custom actor objects for this instance
		local instance_container = atributo_custom:GetInstanceCustomActorContainer (instance)
		
		local last_shown = atributo_custom._InstanceLastCustomShown [instance:GetId()]
		if (last_shown and last_shown ~= custom_object:GetName()) then
			instance_container:WipeCustomActorContainer()
		end
		atributo_custom._InstanceLastCustomShown [instance:GetId()] = custom_object:GetName()
		
		local last_combat_shown = atributo_custom._InstanceLastCombatShown [instance:GetId()]
		if (last_combat_shown and last_combat_shown ~= combat) then
			instance_container:WipeCustomActorContainer()
		end
		atributo_custom._InstanceLastCombatShown [instance:GetId()] = combat
		
		--> declare the main locals
		local total = 0
		local top = 0
		local amount = 0
		
		--> check if is a custom script
		if (custom_object:IsScripted()) then

			--> be save reseting the values on every refresh
			instance_container:ResetCustomActorContainer()
		
			local func
			
			if (_detalhes.custom_function_cache [instance.customName]) then
				func = _detalhes.custom_function_cache [instance.customName]
			else
				func = loadstring (custom_object.script)
				if (func) then
					_detalhes.custom_function_cache [instance.customName] = func
				end

				local tooltip_script  = custom_object.tooltip and loadstring (custom_object.tooltip)
				if (tooltip_script) then
					_detalhes.custom_function_cache [instance.customName .. "Tooltip"] = tooltip_script
				end
				local total_script = custom_object.total_script and loadstring (custom_object.total_script)
				if (total_script) then
					_detalhes.custom_function_cache [instance.customName .. "Total"] = total_script
				end
				local percent_script = custom_object.percent_script and loadstring (custom_object.percent_script)
				if (percent_script) then
					_detalhes.custom_function_cache [instance.customName .. "Percent"] = percent_script
				end
			end
			
			if (not func) then
				_detalhes:Msg (Loc ["STRING_CUSTOM_FUNC_INVALID"], func)
				_detalhes:EndRefresh (instance, 0, combat, combat [1])
			end
			
			--> call the loop function
			--total, top, amount = func (combat, instance_container, instance)
			
			okey, total, top, amount = _pcall (func, combat, instance_container, instance)
			if (not okey) then
				_detalhes:Msg ("|cFFFF9900error on custom display function|r:", total)
				return _detalhes:EndRefresh (instance, 0, combat, combat [1])
			end
			
			total = total or 0
			top = top or 0
			amount = amount or 0
			
		else
			--> get the attribute
			local attribute = custom_object:GetAttribute()
			
			--> get the custom function (actor, source, target, spellid)
			local func = atributo_custom [attribute]
			
			--> get the combat container
			local container_index = self:GetCombatContainerIndex (attribute)
			local combat_container = combat [container_index]._ActorTable

			--> build container
			total, top, amount = atributo_custom:BuildActorList (func, custom_object.source, custom_object.target, custom_object.spellid, combat, combat_container, container_index, instance_container, instance, custom_object)

		end

		if (custom_object:IsSpellTarget()) then
			amount = atributo_custom._TargetActorsProcessedAmt
			total = atributo_custom._TargetActorsProcessedTotal
			top = atributo_custom._TargetActorsProcessedTop
		end

		if (amount == 0) then
			if (force) then
				if (instance:IsGroupMode()) then
					for i = 1, instance.rows_fit_in_window  do
						gump:Fade (instance.barras [i], "in", 0.3)
					end
				end
			end
			instance:EsconderScrollBar()
			return _detalhes:EndRefresh (instance, total, combat, combat [container_index])
		end
		
		if (amount > #instance_container._ActorTable) then
			amount = #instance_container._ActorTable
		end

		combat.totals [custom_object:GetName()] = total
		
		instance_container:Sort()
		instance_container:Remap()
		
		if (export) then
		
			-- key name value need to be formated
			if (custom_object) then
			
				local percent_script = _detalhes.custom_function_cache [instance.customName .. "Percent"]
				local total_script = _detalhes.custom_function_cache [instance.customName .. "Total"]
				
				for index, actor in _ipairs (instance_container._ActorTable) do 	
					local percent, ptotal
					if (percent_script) then
						percent = percent_script (_math_floor (actor.value), top, total, combat, instance)
					else
						percent = _cstr ("%.1f", _math_floor (actor.value) / total * 100)
					end
					
					if (total_script) then
						local value = total_script (_math_floor (actor.value), top, total, combat, instance)
						if (type (value) == "number") then
							ptotal = SelectedToKFunction (_, value)
						else
							ptotal = value
						end
					else
						ptotal = SelectedToKFunction (_, _math_floor (actor.value))
					end
					
					actor.report_value = ptotal .. " (" .. percent .. "%)"
					
					if (actor.id) then
						if (actor.id == 1) then
							actor.report_name = GetSpellLink (6603)
						elseif (actor.id > 10) then
							actor.report_name = GetSpellLink (actor.id)
						else
							actor.report_name = actor.nome
						end
					else
						actor.report_name = actor.nome
					end
				end

			end
			
			return total, instance_container._ActorTable, top, amount, "report_name"
		end
		
		instance:AtualizarScrollBar (amount)

		atributo_custom:Refresh (instance, instance_container, combat, force, total, top, custom_object)
		
		return _detalhes:EndRefresh (instance, total, combat, combat [container_index])

	end

	function atributo_custom:BuildActorList (func, source, target, spellid, combat, combat_container, container_index, instance_container, instance, custom_object)

		--> do the loop
		
		local total = 0
		local top = 0
		local amount = 0
		
		--> check if is a spell target custom
		if (custom_object:IsSpellTarget()) then
			table.wipe (atributo_custom._TargetActorsProcessed)
			atributo_custom._TargetActorsProcessedAmt = 0
			atributo_custom._TargetActorsProcessedTotal = 0
			atributo_custom._TargetActorsProcessedTop = 0
			instance_container:ResetCustomActorContainer()
		end
		
		if (source == "[all]") then
			
			for _, actor in _ipairs (combat_container) do 
				local actortotal = func (_, actor, source, target, spellid, combat, instance_container)
				if (actortotal > 0) then
					total = total + actortotal
					amount = amount + 1
					
					if (actortotal > top) then
						top = actortotal
					end
					
					instance_container:SetValue (actor, actortotal)
				end
			end
			
		elseif (source == "[raid]") then
		
			if (_detalhes.in_combat and instance.segmento == 0 and not export) then
				if (container_index == 1) then
					combat_container = _detalhes.cache_damage_group
				elseif (container_index == 2) then
					combat_container = _detalhes.cache_healing_group
				end
			end

			for _, actor in _ipairs (combat_container) do 
				if (actor.grupo) then
					local actortotal = func (_, actor, source, target, spellid, combat, instance_container)

					if (actortotal > 0) then
						total = total + actortotal
						amount = amount + 1
						
						if (actortotal > top) then
							top = actortotal
						end
						
						instance_container:SetValue (actor, actortotal)
					end
					
				end
			end
			
		elseif (source == "[player]") then
			local pindex = combat [container_index]._NameIndexTable [_detalhes.playername]
			if (pindex) then
				local actor = combat [container_index]._ActorTable [pindex]
				local actortotal = func (_, actor, source, target, spellid, combat, instance_container)
				
				if (actortotal > 0) then
					total = total + actortotal
					amount = amount + 1
					
					if (actortotal > top) then
						top = actortotal
					end
					
					instance_container:SetValue (actor, actortotal)
				end
			end
		else

			local pindex = combat [container_index]._NameIndexTable [source]
			if (pindex) then
				local actor = combat [container_index]._ActorTable [pindex]
				local actortotal = func (_, actor, source, target, spellid, combat, instance_container)
				
				if (actortotal > 0) then
					total = total + actortotal
					amount = amount + 1
					
					if (actortotal > top) then
						top = actortotal
					end
					
					instance_container:SetValue (actor, actortotal)
				end
			end
		end
		
		return total, top, amount
	end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> refresh functions

	function atributo_custom:Refresh (instance, instance_container, combat, force, total, top, custom_object)
		local qual_barra = 1
		local barras_container = instance.barras
		local percentage_type = instance.row_info.percent_type
		
		local combat_time = combat:GetCombatTime()
		UsingCustomLeftText = instance.row_info.textL_enable_custom_text
		UsingCustomRightText = instance.row_info.textR_enable_custom_text
		
		--> total bar
		local use_total_bar = false
		if (instance.total_bar.enabled) then
			use_total_bar = true
			if (instance.total_bar.only_in_group and (not _IsInGroup() and not _IsInRaid())) then
				use_total_bar = false
			end
		end

		local percent_script = _detalhes.custom_function_cache [instance.customName .. "Percent"]
		local total_script = _detalhes.custom_function_cache [instance.customName .. "Total"]
		
		local bars_show_data = instance.row_info.textR_show_data
		local bars_brackets = instance:GetBarBracket()
		local bars_separator = instance:GetBarSeparator()

		if (instance.bars_sort_direction == 1) then --top to bottom
			
			if (use_total_bar and instance.barraS[1] == 1) then
			
				qual_barra = 2
				local iter_last = instance.barraS[2]
				if (iter_last == instance.rows_fit_in_window) then
					iter_last = iter_last - 1
				end
				
				local row1 = barras_container [1]
				row1.minha_tabela = nil
				row1.texto_esquerdo:SetText (Loc ["STRING_TOTAL"])
				row1.texto_direita:SetText (_detalhes:ToK2 (total) .. " (" .. _detalhes:ToK (total / combat_time) .. ")")
				
				row1.statusbar:SetValue (100)
				local r, b, g = unpack (instance.total_bar.color)
				row1.textura:SetVertexColor (r, b, g)
				
				row1.icone_classe:SetTexture (instance.total_bar.icon)
				row1.icone_classe:SetTexCoord (0.0625, 0.9375, 0.0625, 0.9375)
				
				gump:Fade (row1, "out")
				
				for i = instance.barraS[1], iter_last, 1 do
					instance_container._ActorTable[i]:UpdateBar (barras_container, qual_barra, percentage_type, i, total, top, instance, force, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
					qual_barra = qual_barra+1
				end
			
			else
				for i = instance.barraS[1], instance.barraS[2], 1 do
					instance_container._ActorTable[i]:UpdateBar (barras_container, qual_barra, percentage_type, i, total, top, instance, force, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
					qual_barra = qual_barra+1
				end
			end
			
		elseif (instance.bars_sort_direction == 2) then --bottom to top
		
			if (use_total_bar and instance.barraS[1] == 1) then
			
				qual_barra = 2
				local iter_last = instance.barraS[2]
				if (iter_last == instance.rows_fit_in_window) then
					iter_last = iter_last - 1
				end
				
				local row1 = barras_container [1]
				row1.minha_tabela = nil
				row1.texto_esquerdo:SetText (Loc ["STRING_TOTAL"])
				row1.texto_direita:SetText (_detalhes:ToK2 (total) .. " (" .. _detalhes:ToK (total / combat_time) .. ")")
				
				row1.statusbar:SetValue (100)
				local r, b, g = unpack (instance.total_bar.color)
				row1.textura:SetVertexColor (r, b, g)
				
				row1.icone_classe:SetTexture (instance.total_bar.icon)
				row1.icone_classe:SetTexCoord (0.0625, 0.9375, 0.0625, 0.9375)
				
				gump:Fade (row1, "out")
				
				for i = iter_last, instance.barraS[1], -1 do --> vai atualizar s� o range que esta sendo mostrado
					instance_container._ActorTable[i]:UpdateBar (barras_container, qual_barra, percentage_type, i, total, top, instance, force, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
					qual_barra = qual_barra+1
				end
			
			else
				for i = instance.barraS[2], instance.barraS[1], -1 do --> vai atualizar s� o range que esta sendo mostrado
					instance_container._ActorTable[i]:UpdateBar (barras_container, qual_barra, percentage_type, i, total, top, instance, force, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
					qual_barra = qual_barra+1
				end
			end
			
		end	
		
		if (force) then
			if (instance:IsGroupMode()) then
				for i = qual_barra, instance.rows_fit_in_window  do
					gump:Fade (instance.barras [i], "in", 0.3)
				end
			end
		end
		
	end
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> custom object functions

	local actor_class_color_r, actor_class_color_g, actor_class_color_b
	
	function atributo_custom:UpdateBar (row_container, index, percentage_type, rank, total, top, instance, is_forced, percent_script, total_script, combat, bars_show_data, bars_brackets, bars_separator)
	
		local row = row_container [index]
		
		local previous_table = row.minha_tabela
		row.colocacao = rank
		row.minha_tabela = self
		self.minha_barra = row
		
		local percent

		if (percent_script) then
			--local value, top, total, combat, instance = ...
			percent = percent_script (self.value, top, total, combat, instance)
		else
			if (percentage_type == 1) then
				percent = _cstr ("%.1f", self.value / total * 100)
			elseif (percentage_type == 2) then
				percent = _cstr ("%.1f", self.value / top * 100)
			end
		end

		if (not bars_show_data [3]) then
			percent = ""
		else
			percent = percent .. "%"
		end

		if (total_script) then
			local value = total_script (self.value, top, total, combat, instance)
			if (type (value) == "number") then
				row.texto_direita:SetText (SelectedToKFunction (_, value) .. bars_brackets[1] .. percent .. bars_brackets[2])
			else
				row.texto_direita:SetText (value .. bars_brackets[1] .. percent .. bars_brackets[2])
			end
		else
			local formated_value = SelectedToKFunction (_, self.value)
			if (UsingCustomRightText) then
				row.texto_direita:SetText (_string_replace (instance.row_info.textR_custom_text, formated_value, "", percent, self))
			else
				row.texto_direita:SetText (formated_value .. bars_brackets[1] .. percent .. bars_brackets[2])
			end
		end
		
		local row_value = _math_floor ((self.value / top) * 100)

		-- update tooltip function --

		if (self.id) then
			local school = _detalhes.spell_school_cache [self.nome]
			if (school) then
				local school_color = _detalhes.school_colors [school]
				if (not school_color) then
					school_color = _detalhes.school_colors ["unknown"]
				end
				actor_class_color_r, actor_class_color_g, actor_class_color_b = _unpack (school_color)
			else
				local color = _detalhes.school_colors ["unknown"]
				actor_class_color_r, actor_class_color_g, actor_class_color_b = _unpack (color)
			end
		else
			actor_class_color_r, actor_class_color_g, actor_class_color_b = self:GetBarColor()
		end
		
		self:RefreshBarra2 (row, instance, previous_table, is_forced, row_value, index, row_container)
		
	end
	
	function atributo_custom:RefreshBarra2 (esta_barra, instancia, tabela_anterior, forcar, esta_porcentagem, qual_barra, barras_container)
		
		--> primeiro colocado
		if (esta_barra.colocacao == 1) then
			if (not tabela_anterior or tabela_anterior ~= esta_barra.minha_tabela or forcar) then
				esta_barra.statusbar:SetValue (100)
				
				if (esta_barra.hidden or esta_barra.fading_in or esta_barra.faded) then
					gump:Fade (esta_barra, "out")
				end
				
				return self:RefreshBarra (esta_barra, instancia)
			else
				return
			end
		else

			if (esta_barra.hidden or esta_barra.fading_in or esta_barra.faded) then
			
				esta_barra.statusbar:SetValue (esta_porcentagem)
				gump:Fade (esta_barra, "out")
				
				if (instancia.row_info.texture_class_colors) then
					esta_barra.textura:SetVertexColor (actor_class_color_r, actor_class_color_g, actor_class_color_b)
				end
				if (instancia.row_info.texture_background_class_color) then
					esta_barra.background:SetVertexColor (actor_class_color_r, actor_class_color_g, actor_class_color_b)
				end
				
				return self:RefreshBarra (esta_barra, instancia)
				
			else
				--> agora esta comparando se a tabela da barra � diferente da tabela na atualiza��o anterior
				if (not tabela_anterior or tabela_anterior ~= esta_barra.minha_tabela or forcar) then --> aqui diz se a barra do jogador mudou de posi��o ou se ela apenas ser� atualizada
				
					esta_barra.statusbar:SetValue (esta_porcentagem)
				
					esta_barra.last_value = esta_porcentagem --> reseta o ultimo valor da barra
					
					if (_detalhes.is_using_row_animations and forcar) then
						esta_barra.tem_animacao = 0
						esta_barra:SetScript ("OnUpdate", nil)
					end
					
					return self:RefreshBarra (esta_barra, instancia)
					
				elseif (esta_porcentagem ~= esta_barra.last_value) then --> continua mostrando a mesma tabela ent�o compara a porcentagem
					--> apenas atualizar
					if (_detalhes.is_using_row_animations) then
						
						local upRow = barras_container [qual_barra-1]
						if (upRow) then
							if (upRow.statusbar:GetValue() < esta_barra.statusbar:GetValue()) then
								esta_barra.statusbar:SetValue (esta_porcentagem)
							else
								instancia:AnimarBarra (esta_barra, esta_porcentagem)
							end
						else
							instancia:AnimarBarra (esta_barra, esta_porcentagem)
						end
					else
						esta_barra.statusbar:SetValue (esta_porcentagem)
					end
					esta_barra.last_value = esta_porcentagem
				end
			end

		end
		
	end

	function atributo_custom:RefreshBarra (esta_barra, instancia, from_resize)
		
		if (from_resize) then
			if (self.id) then
				local school = _detalhes.spell_school_cache [self.nome]
				if (school) then
					local school_color = _detalhes.school_colors [school]
					if (not school_color) then
						school_color = _detalhes.school_colors ["unknown"]
					end
					actor_class_color_r, actor_class_color_g, actor_class_color_b = _unpack (school_color)
				else
					local color = _detalhes.school_colors ["unknown"]
					actor_class_color_r, actor_class_color_g, actor_class_color_b = _unpack (color)
				end
			else
				actor_class_color_r, actor_class_color_g, actor_class_color_b = self:GetBarColor()
			end
		end

		if (instancia.row_info.texture_class_colors) then
			esta_barra.textura:SetVertexColor (actor_class_color_r, actor_class_color_g, actor_class_color_b)
		end
		if (instancia.row_info.texture_background_class_color) then
			esta_barra.background:SetVertexColor (actor_class_color_r, actor_class_color_g, actor_class_color_b)
		end	

		if (self.classe == "UNKNOW") then
			esta_barra.icone_classe:SetTexture ("Interface\\LFGFRAME\\LFGROLE_BW")
			esta_barra.icone_classe:SetTexCoord (.25, .5, 0, 1)
			esta_barra.icone_classe:SetVertexColor (1, 1, 1)

		elseif (self.classe == "UNGROUPPLAYER") then
			if (self.enemy) then
				if (_detalhes.faction_against == "Horde") then
					esta_barra.icone_classe:SetTexture ("Interface\\ICONS\\Achievement_Character_Orc_Male")
					esta_barra.icone_classe:SetTexCoord (0, 1, 0, 1)
				else
					esta_barra.icone_classe:SetTexture ("Interface\\ICONS\\Achievement_Character_Human_Male")
					esta_barra.icone_classe:SetTexCoord (0, 1, 0, 1)
				end
			else
				if (_detalhes.faction_against == "Horde") then
					esta_barra.icone_classe:SetTexture ("Interface\\ICONS\\Achievement_Character_Human_Male")
					esta_barra.icone_classe:SetTexCoord (0, 1, 0, 1)
				else
					esta_barra.icone_classe:SetTexture ("Interface\\ICONS\\Achievement_Character_Orc_Male")
					esta_barra.icone_classe:SetTexCoord (0, 1, 0, 1)
				end
			end
			esta_barra.icone_classe:SetVertexColor (1, 1, 1)
		
		elseif (self.classe == "PET") then
			esta_barra.icone_classe:SetTexture (instancia.row_info.icon_file)
			esta_barra.icone_classe:SetTexCoord (0.25, 0.49609375, 0.75, 1)
			esta_barra.icone_classe:SetVertexColor (actor_class_color_r, actor_class_color_g, actor_class_color_b)

		else
			if (self.id) then
				esta_barra.icone_classe:SetTexCoord (0.078125, 0.921875, 0.078125, 0.921875)
				esta_barra.icone_classe:SetTexture (self.icon)
			else
				if (instancia.row_info.use_spec_icons and (self.spec or self.my_actor.spec)) then
					esta_barra.icone_classe:SetTexture (instancia.row_info.spec_file)
					esta_barra.icone_classe:SetTexCoord (_unpack (_detalhes.class_specs_coords [self.spec or self.my_actor.spec]))
				else
					esta_barra.icone_classe:SetTexture (instancia.row_info.icon_file)
					esta_barra.icone_classe:SetTexCoord (_unpack (CLASS_ICON_TCOORDS [self.classe]))
				end
			end
			esta_barra.icone_classe:SetVertexColor (1, 1, 1)
		end

		--texture and text
		
		local bar_number = ""
		if (instancia.row_info.textL_show_number) then
			bar_number = esta_barra.colocacao .. ". "
		end

		if (self.enemy) then
			if (self.arena_enemy) then
				if (UsingCustomLeftText) then
					esta_barra.texto_esquerdo:SetText (_string_replace (instancia.row_info.textL_custom_text, esta_barra.colocacao, self.displayName, "|TInterface\\LFGFRAME\\UI-LFG-ICON-ROLES:" .. instancia.row_info.height .. ":" .. instancia.row_info.height .. ":0:0:256:256:" .. _detalhes.role_texcoord [self.role or "NONE"] .. "|t"))
				else
					esta_barra.texto_esquerdo:SetText (bar_number .. "|TInterface\\LFGFRAME\\UI-LFG-ICON-ROLES:" .. instancia.row_info.height .. ":" .. instancia.row_info.height .. ":0:0:256:256:" .. _detalhes.role_texcoord [self.role or "NONE"] .. "|t" .. self.displayName)
				end
				esta_barra.textura:SetVertexColor (actor_class_color_r, actor_class_color_g, actor_class_color_b)
			else
				if (_detalhes.faction_against == "Horde") then
					if (UsingCustomLeftText) then
						esta_barra.texto_esquerdo:SetText (_string_replace (instancia.row_info.textL_custom_text, esta_barra.colocacao, self.displayName, "|TInterface\\AddOns\\Details\\images\\icones_barra:"..instancia.row_info.height..":"..instancia.row_info.height..":0:0:256:32:0:32:0:32|t"))
					else
						esta_barra.texto_esquerdo:SetText (bar_number .. "|TInterface\\AddOns\\Details\\images\\icones_barra:"..instancia.row_info.height..":"..instancia.row_info.height..":0:0:256:32:0:32:0:32|t"..self.displayName) --seta o texto da esqueda -- HORDA
					end
				else
					if (UsingCustomLeftText) then
						esta_barra.texto_esquerdo:SetText (_string_replace (instancia.row_info.textL_custom_text, esta_barra.colocacao, self.displayName, "|TInterface\\AddOns\\Details\\images\\icones_barra:"..instancia.row_info.height..":"..instancia.row_info.height..":0:0:256:32:32:64:0:32|t"))
					else
						esta_barra.texto_esquerdo:SetText (bar_number .. "|TInterface\\AddOns\\Details\\images\\icones_barra:"..instancia.row_info.height..":"..instancia.row_info.height..":0:0:256:32:32:64:0:32|t"..self.displayName) --seta o texto da esqueda -- ALLY
					end
				end
				
				if (instancia.row_info.texture_class_colors) then
					esta_barra.textura:SetVertexColor (0.94117, 0, 0.01960, 1)
				end
			end
		else
			if (self.arena_ally) then
				if (UsingCustomLeftText) then
					esta_barra.texto_esquerdo:SetText (_string_replace (instancia.row_info.textL_custom_text, esta_barra.colocacao, self.displayName, "|TInterface\\LFGFRAME\\UI-LFG-ICON-ROLES:" .. instancia.row_info.height .. ":" .. instancia.row_info.height .. ":0:0:256:256:" .. _detalhes.role_texcoord [self.role or "NONE"] .. "|t"))
				else
					esta_barra.texto_esquerdo:SetText (bar_number .. "|TInterface\\LFGFRAME\\UI-LFG-ICON-ROLES:" .. instancia.row_info.height .. ":" .. instancia.row_info.height .. ":0:0:256:256:" .. _detalhes.role_texcoord [self.role or "NONE"] .. "|t" .. self.displayName)
				end
			else
				if (UsingCustomLeftText) then
					esta_barra.texto_esquerdo:SetText (_string_replace (instancia.row_info.textL_custom_text, esta_barra.colocacao, self.displayName, ""))
				else
					esta_barra.texto_esquerdo:SetText (bar_number .. self.displayName) --seta o texto da esqueda
				end
			end
		end
		
		if (instancia.row_info.textL_class_colors) then
			esta_barra.texto_esquerdo:SetTextColor (actor_class_color_r, actor_class_color_g, actor_class_color_b)
		end
		if (instancia.row_info.textR_class_colors) then
			esta_barra.texto_direita:SetTextColor (actor_class_color_r, actor_class_color_g, actor_class_color_b)
		end
		
		esta_barra.texto_esquerdo:SetSize (esta_barra:GetWidth() - esta_barra.texto_direita:GetStringWidth() - 20, 15)
		
	end	

	function atributo_custom:CreateCustomActorContainer()
		return _setmetatable ({
			_NameIndexTable = {},
			_ActorTable = {}
		}, {__index = atributo_custom})
	end
	
	function atributo_custom:ResetCustomActorContainer()
		for _, actor in _ipairs (self._ActorTable) do
			actor.value = actor.value - _math_floor (actor.value)
			--actor.value = _detalhes:GetOrderNumber (actor.nome)
		end
	end
	
	function atributo_custom:WipeCustomActorContainer()
		table.wipe (self._ActorTable)
		table.wipe (self._NameIndexTable)
	end

	function atributo_custom:GetValue (actor)
		local actor_table = self:GetActorTable (actor)
		return actor_table.value
	end
	-- ~add
	function atributo_custom:AddValue (actor, actortotal, checktop, name_complement)
		local actor_table = self:GetActorTable (actor, name_complement)
		actor_table.my_actor = actor
		actor_table.value = actor_table.value + actortotal
		
		if (checktop) then
			if (actor_table.value > atributo_custom._TargetActorsProcessedTop) then
				atributo_custom._TargetActorsProcessedTop = actor_table.value
			end
		end
		
		return actor_table.value
	end
	
	function atributo_custom:SetValue (actor, actortotal, name_complement)
		local actor_table = self:GetActorTable (actor, name_complement)
		actor_table.my_actor = actor
		actor_table.value = actortotal
	end

	function atributo_custom:UpdateClass (actors)
		actors.new_actor.classe = actors.actor.classe
	end

	local icon_cache = {}
	
	function atributo_custom:GetActorTable (actor, name_complement)
		local index = self._NameIndexTable [actor.nome]
		
		if (index) then
			return self._ActorTable [index]
		else
			--> if is a spell object
			local class
			if (actor.id) then
				local spellname, _, icon = _GetSpellInfo (actor.id)
				if (not icon_cache [spellname]) then
					icon_cache [spellname] = icon
				end
				actor.nome = spellname
				actor.classe = actor.spellschool
				class = actor.spellschool
				
				local index = self._NameIndexTable [actor.nome]
				if (index) then
					return self._ActorTable [index]
				end
				
			else
				class = actor.classe
				if (class == "UNKNOW") then
					--> try once again
					class = _detalhes:GetClass (actor.nome)
					if (class and class ~= "UNKNOW") then
						actor.classe = class
					end
				end
			end
		
			local new_actor = _setmetatable ({
				nome = actor.nome,
				classe = class,
				value = _detalhes:GetOrderNumber (actor.nome),
			}, atributo_custom.mt)
			
			new_actor.name_complement = name_complement
			new_actor.displayName = _detalhes:GetOnlyName (new_actor.nome) .. (name_complement or "")
			new_actor.spec = actor.spec
			
			new_actor.enemy = actor.enemy
			new_actor.arena_enemy = actor.arena_enemy
			new_actor.arena_ally = actor.arena_ally
			
			if (actor.id) then
				new_actor.id = actor.id
				--icon
				if (icon_cache [actor.nome]) then
					new_actor.icon = icon_cache [actor.nome]
				else
					local _, _, icon = _GetSpellInfo (actor.id)
					if (icon) then
						icon_cache [actor.nome] = icon
						new_actor.icon =  icon
					end
				end
			else
				if (not new_actor.classe) then
					new_actor.classe = _detalhes:GetClass (actor.nome) or "UNKNOW"
				end
				if (new_actor.classe == "UNGROUPPLAYER") then
					atributo_custom:ScheduleTimer ("UpdateClass", 5, {new_actor = new_actor, actor = actor})
				end
			end

			index = #self._ActorTable+1
			
			self._ActorTable [index] = new_actor
			self._NameIndexTable [actor.nome] = index
			return new_actor
		end
	end
	
	function atributo_custom:GetInstanceCustomActorContainer (instance)
		if (not atributo_custom._InstanceActorContainer [instance:GetId()]) then
			atributo_custom._InstanceActorContainer [instance:GetId()] = self:CreateCustomActorContainer()
		end
		return atributo_custom._InstanceActorContainer [instance:GetId()]
	end

	function atributo_custom:CreateCustomDisplayObject()
		return _setmetatable ({
			name = "new custom",
			icon = [[Interface\ICONS\TEMP]],
			author = "unknown",
			attribute = "damagedone",
			source = "[all]",
			target = "[all]",
			spellid = false,
			script = false,
		}, {__index = atributo_custom})
	end

	local custom_sort = function (t1, t2)
		return t1.value > t2.value
	end
	function atributo_custom:Sort (container)
		container = container or self
		_table_sort (container._ActorTable, custom_sort)
	end
	
	function atributo_custom:Remap()
		local map = self._NameIndexTable
		local actors = self._ActorTable
		for i = 1, #actors do
			map [actors[i].nome] = i
		end
	end

	function atributo_custom:ToolTip (instance, bar_number, row_object, keydown)
	
		--> get the custom object
		local custom_object = instance:GetCustomObject()
		
		--> get the actor
		local actor = self.my_actor
		
		local r, g, b
		if (actor.id) then
			local school_color = _detalhes.school_colors [actor.classe]
			if (not school_color) then
				school_color = _detalhes.school_colors ["unknown"]
			end
			r, g, b = _unpack (school_color)
		else
			r, g, b = actor:GetClassColor()
		end
		
		if (actor.id) then
			_detalhes:AddTooltipSpellHeaderText (select (1, _GetSpellInfo (actor.id)), "yellow", 1, 0, 0, 0)
			GameCooltip:AddIcon (select (3, _GetSpellInfo (actor.id)), 1, 1, 14, 14, 0.90625, 0.109375, 0.15625, 0.875)
		else
			_detalhes:AddTooltipSpellHeaderText (custom_object:GetName(), "yellow", 1, 0, 0, 0)
			GameCooltip:AddIcon (custom_object:GetIcon(), 1, 1, 14, 14, 0.90625, 0.109375, 0.15625, 0.875)
		end

		GameCooltip:AddStatusBar (100, 1, r, g, b, 1)
		
		if (custom_object:IsScripted()) then
			if (custom_object.tooltip) then
				local func = loadstring (custom_object.tooltip)
				func (actor, instance.showing, instance)
			end
		else
			--> get the attribute
			local attribute = custom_object:GetAttribute()
			local container_index = atributo_custom:GetCombatContainerIndex (attribute)
			
			--> get the tooltip function
			local func = atributo_custom [attribute .. "Tooltip"]
			
			--> build the tooltip
			func (_, actor, custom_object.target, custom_object.spellid, instance.showing, instance)
		end
		
		return true
	end
	
	function atributo_custom:GetName()
		return self.name
	end
	function atributo_custom:GetIcon()
		return self.icon
	end
	function atributo_custom:GetAuthor()
		return self.author
	end
	function atributo_custom:GetDesc()
		return self.desc
	end
	function atributo_custom:GetAttribute()
		return self.attribute
	end
	function atributo_custom:GetSource()
		return self.source
	end
	function atributo_custom:GetTarget()
		return self.target
	end
	function atributo_custom:GetSpellId()
		return self.spellid
	end
	function atributo_custom:GetScript()
		return self.script
	end
	function atributo_custom:GetScriptToolip()
		return self.tooltip
	end
	function atributo_custom:GetScriptTotal()
		return self.total_script
	end
	function atributo_custom:GetScriptPercent()
		return self.percent_script
	end

	function atributo_custom:SetName (name)
		self.name = name
	end
	function atributo_custom:SetIcon (path)
		self.icon = path
	end
	function atributo_custom:SetAuthor (author)
		self.author = author
	end
	function atributo_custom:SetDesc (desc)
		self.desc = desc
	end
	function atributo_custom:SetAttribute (newattribute)
		self.attribute = newattribute
	end
	function atributo_custom:SetSource (source)
		self.source = source
	end
	function atributo_custom:SetTarget (target)
		self.target = target
	end
	function atributo_custom:SetSpellId (spellid)
		self.spellid = spellid
	end
	function atributo_custom:SetScript (code)
		self.script = code
	end
	function atributo_custom:SetScriptToolip (code)
		self.tooltip = code
	end

	function atributo_custom:IsScripted()
		return self.script and true or false
	end
	
	function atributo_custom:IsSpellTarget()
		return self.spellid and self.target and true
	end
	
	function atributo_custom:RemoveCustom (index)
	
		if (not _detalhes.tabela_instancias) then
			--> do not remove customs while the addon is loading.
			return
		end
	
		table.remove (_detalhes.custom, index)
		
		for _, instance in _ipairs (_detalhes.tabela_instancias) do 
			if (instance.atributo == 5 and instance.sub_atributo == index) then 
				instance:ResetAttribute()
			elseif (instance.atributo == 5 and instance.sub_atributo > index) then
				instance.sub_atributo = instance.sub_atributo - 1
				instance.sub_atributo_last [5] = 1
			else
				instance.sub_atributo_last [5] = 1
			end
		end
		
		_detalhes.switch:OnRemoveCustom (index)
	end
	
	function _detalhes:ResetCustomFunctionsCache()
		table.wipe (_detalhes.custom_function_cache)
	end
	
	function _detalhes.refresh:r_atributo_custom()
		--> check for non used temp displays
		if (_detalhes.tabela_instancias) then

			for i = #_detalhes.custom, 1, -1 do
				local custom_object = _detalhes.custom [i]
				if (custom_object.temp) then
					--> check if there is a instance showing this custom
					local showing = false
					
					for index, instance in _ipairs (_detalhes.tabela_instancias) do
						if (instance.atributo == 5 and instance.sub_atributo == i) then 
							showing = true
						end
					end
					
					if (not showing) then
						atributo_custom:RemoveCustom (i)
					end
				end
			end
		end
	
		--> restore metatable and indexes
		for index, custom_object in _ipairs (_detalhes.custom) do
			_setmetatable (custom_object, atributo_custom)
			custom_object.__index = atributo_custom
		end
	end

	function _detalhes.clear:c_atributo_custom()
		for _, custom_object in _ipairs (_detalhes.custom) do
			custom_object.__index = nil
		end
	end

	function atributo_custom:UpdateSelectedToKFunction()
		SelectedToKFunction = ToKFunctions [_detalhes.ps_abbreviation]
		FormatTooltipNumber = ToKFunctions [_detalhes.tooltip.abbreviation]
		TooltipMaximizedMethod = _detalhes.tooltip.maximize_method
		atributo_custom:UpdateDamageDoneBracket()
		atributo_custom:UpdateHealingDoneBracket()
	end

	function _detalhes:AddDefaultCustomDisplays()
		
		local PotionUsed = {
			name = Loc ["STRING_CUSTOM_POT_DEFAULT"],
			icon = [[Interface\ICONS\Trade_Alchemy_PotionD4]],
			attribute = false,
			spellid = false,
			author = "Details!",
			desc = Loc ["STRING_CUSTOM_POT_DEFAULT_DESC"],
			source = false,
			target = false,
			script_version = 1,
			script = [[
				--init:
				local combat, instance_container, instance = ...
				local total, top, amount = 0, 0, 0

				--get the misc actor container
				local misc_container = combat:GetActorList ( DETAILS_ATTRIBUTE_MISC )

				--do the loop:
				for _, player in ipairs ( misc_container ) do 
				    
				    --only player in group
				    if (player:IsGroupPlayer()) then
					
					local found_potion = false
					
					--get the spell debuff uptime container
					local debuff_uptime_container = player.debuff_uptime and player.debuff_uptime_spells and player.debuff_uptime_spells._ActorTable
					if (debuff_uptime_container) then
					    --potion of focus (can't use as pre-potion, so, its amount is always 1
					    local focus_potion = debuff_uptime_container [156432] --WoD
					    --local focus_potion = debuff_uptime_container [105701] --MoP
					    if (focus_potion) then
						total = total + 1
						found_potion = true
						if (top < 1) then
						    top = 1
						end
						--add amount to the player 
						instance_container:AddValue (player, 1)
					    end
					end
					
					--get the spell buff uptime container
					local buff_uptime_container = player.buff_uptime and player.buff_uptime_spells and player.buff_uptime_spells._ActorTable
					if (buff_uptime_container) then
					    
					    --potion of the jade serpent
					    local jade_serpent_potion = buff_uptime_container [156426] --WoD
					    --local jade_serpent_potion = buff_uptime_container [105702] --MoP
					    if (jade_serpent_potion) then
						local used = jade_serpent_potion.activedamt
						if (used > 0) then
						    total = total + used
						    found_potion = true
						    if (used > top) then
							top = used
						    end
						    --add amount to the player 
						    instance_container:AddValue (player, used)
						end
					    end
					    
					    --potion of mogu power
					    local mogu_power_potion = buff_uptime_container [156428] --WoD
					    --local mogu_power_potion = buff_uptime_container [105706] --MoP
					    if (mogu_power_potion) then
						local used = mogu_power_potion.activedamt
						if (used > 0) then
						    total = total + used
						    found_potion = true
						    if (used > top) then
							top = used
						    end
						    --add amount to the player 
						    instance_container:AddValue (player, used)
						end
					    end
					    
					    --virmen's bite
					    local virmens_bite_potion = buff_uptime_container [156423] --WoD
					    --local virmens_bite_potion = buff_uptime_container [105697] --MoP
					    if (virmens_bite_potion) then
						local used = virmens_bite_potion.activedamt
						if (used > 0) then
						    total = total + used
						    found_potion = true
						    if (used > top) then
							top = used
						    end
						    --add amount to the player 
						    instance_container:AddValue (player, used)
						end
					    end
					    
					    --pure rage
					    local pure_rage_potion = buff_uptime_container [175821] --WoD
					    if (pure_rage_potion) then
						local used = pure_rage_potion.activedamt
						if (used > 0) then
						    total = total + used
						    found_potion = true
						    if (used > top) then
							top = used
						    end
						    --add amount to the player 
						    instance_container:AddValue (player, used)
						end
					    end
					    
					    --potion of the mountains
					    local mountains_potion = buff_uptime_container [156430] --WoD
					    --local mountains_potion = buff_uptime_container [105698] --MoP
					    if (mountains_potion) then
						local used = mountains_potion.activedamt
						if (used > 0) then
						    total = total + used
						    found_potion = true
						    if (used > top) then
							top = used
						    end
						    --add amount to the player 
						    instance_container:AddValue (player, used)
						end
					    end
					end
					
					if (found_potion) then
					    amount = amount + 1
					end    
				    end
				end

				--return:
				return total, top, amount
				]],
			tooltip = [[
			--init:
			local player, combat, instance = ...

			--get the debuff container for potion of focus
			local debuff_uptime_container = player.debuff_uptime and player.debuff_uptime_spells and player.debuff_uptime_spells._ActorTable
			if (debuff_uptime_container) then
			    local focus_potion = debuff_uptime_container [156432] --WoD
			    --local focus_potion = debuff_uptime_container [105701] --MoP
			    if (focus_potion) then
				local name, _, icon = GetSpellInfo (156432) --WoD
				--local name, _, icon = GetSpellInfo (105701) --MoP
				GameCooltip:AddLine (name, 1) --> can use only 1 focus potion (can't be pre-potion)
				_detalhes:AddTooltipBackgroundStatusbar()
				GameCooltip:AddIcon (icon, 1, 1, 14, 14)
			    end
			end

			--get the buff container for all the others potions
			local buff_uptime_container = player.buff_uptime and player.buff_uptime_spells and player.buff_uptime_spells._ActorTable
			if (buff_uptime_container) then
			    --potion of the jade serpent
			    local jade_serpent_potion = buff_uptime_container [156426] --WoD
			    --local jade_serpent_potion = buff_uptime_container [105702] --MoP
			    if (jade_serpent_potion) then
				local name, _, icon = GetSpellInfo (156426) --WoD
				--local name, _, icon = GetSpellInfo (105702) --MoP
				GameCooltip:AddLine (name, jade_serpent_potion.activedamt)
				_detalhes:AddTooltipBackgroundStatusbar()
				GameCooltip:AddIcon (icon, 1, 1, 14, 14)
			    end
			    
			    --potion of mogu power
			    local mogu_power_potion = buff_uptime_container [156428] --WoD
			    --local mogu_power_potion = buff_uptime_container [105706] --MoP
			    if (mogu_power_potion) then
				local name, _, icon = GetSpellInfo (156428) --WoD
				--local name, _, icon = GetSpellInfo (105706) --MoP
				GameCooltip:AddLine (name, mogu_power_potion.activedamt)
				_detalhes:AddTooltipBackgroundStatusbar()
				GameCooltip:AddIcon (icon, 1, 1, 14, 14)
			    end
			    
			    --pure rage
			    local pure_rage_potion = buff_uptime_container [175821] --WoD
			    if (pure_rage_potion) then
				local name, _, icon = GetSpellInfo (175821) --WoD
				GameCooltip:AddLine (name, pure_rage_potion.activedamt)
				_detalhes:AddTooltipBackgroundStatusbar()
				GameCooltip:AddIcon (icon, 1, 1, 14, 14)
			    end
			    
			    --virmen's bite
			    local virmens_bite_potion = buff_uptime_container [156423] --WoD
			    --local virmens_bite_potion = buff_uptime_container [105697] --MoP
			    if (virmens_bite_potion) then
				local name, _, icon = GetSpellInfo (156423) --WoD
				--local name, _, icon = GetSpellInfo (105697) --MoP
				GameCooltip:AddLine (name, virmens_bite_potion.activedamt)
				_detalhes:AddTooltipBackgroundStatusbar()
				GameCooltip:AddIcon (icon, 1, 1, 14, 14)
			    end
			    
			    --potion of the mountains
			    local mountains_potion = buff_uptime_container [156430] --WoD
			    --local mountains_potion = buff_uptime_container [105698] --MoP
			    if (mountains_potion) then
				local name, _, icon = GetSpellInfo (156430) --WoD
				--local name, _, icon = GetSpellInfo (105698) --MoP
				GameCooltip:AddLine (name, mountains_potion.activedamt)
				_detalhes:AddTooltipBackgroundStatusbar()
				GameCooltip:AddIcon (icon, 1, 1, 14, 14)
			    end
			end
		]]
		}
		
		local have = false
		for _, custom in ipairs (self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_POT_DEFAULT"] and (custom.script_version and custom.script_version >= PotionUsed.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs (self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_POT_DEFAULT"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable (PotionUsed, _detalhes.atributo_custom)
			PotionUsed.__index = _detalhes.atributo_custom
			self.custom [#self.custom+1] = PotionUsed
		end
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--		/run _detalhes:AddDefaultCustomDisplays()
		local Healthstone = {
			name = Loc ["STRING_CUSTOM_HEALTHSTONE_DEFAULT"],
			icon = [[Interface\ICONS\warlock_ healthstone]],
			attribute = false,
			spellid = false, 
			author = "Details! Team",
			desc = Loc ["STRING_CUSTOM_HEALTHSTONE_DEFAULT_DESC"],
			source = false,
			target = false,
			script = [[
			--get the parameters passed
			local combat, instance_container, instance = ...
			--declade the values to return
			local total, top, amount = 0, 0, 0
			
			--do the loop
			local AllHealCharacters = combat:GetActorList (DETAILS_ATTRIBUTE_HEAL)
			for index, character in ipairs (AllHealCharacters) do
				local AllSpells = character:GetSpellList()
				local found = false
				for spellid, spell in pairs (AllSpells) do
					if (spellid == 6262 or spellid == 156445 or spellid == 156438) then --healthstone, reju potion, health potion
						instance_container:AddValue (character, spell.total)
						total = total + spell.total
						if (top < spell.total) then
							top = spell.total
						end
						found = true
					end
				end
			
				if (found) then
					amount = amount + 1
				end
			end
			--loop end
			--return the values
			return total, top, amount
			]],
			tooltip = [[
			--get the parameters passed
			local actor, combat, instance = ...
			
			--get the cooltip object (we dont use the convencional GameTooltip here)
			local GameCooltip = GameCooltip
			local R, G, B, A = 0, 0, 0, 0.75
			
			local hs = actor:GetSpell (6262)
			if (hs) then
				GameCooltip:AddLine (select (1, GetSpellInfo(6262)),  _detalhes:ToK(hs.total))
				GameCooltip:AddIcon (select (3, GetSpellInfo (6262)), 1, 1, 16, 16)
				GameCooltip:AddStatusBar (100, 1, R, G, B, A)
			end
			
			local pot = actor:GetSpell (156445)
			if (pot) then
				GameCooltip:AddLine (select (1, GetSpellInfo(156445)),  _detalhes:ToK(pot.total))
				GameCooltip:AddIcon (select (3, GetSpellInfo (156445)), 1, 1, 16, 16)
				GameCooltip:AddStatusBar (100, 1, R, G, B, A)
			end
			
			local pot = actor:GetSpell (156438)
			if (pot) then
				GameCooltip:AddLine (select (1, GetSpellInfo(156438)),  _detalhes:ToK(pot.total))
				GameCooltip:AddIcon (select (3, GetSpellInfo (156438)), 1, 1, 16, 16)
				GameCooltip:AddStatusBar (100, 1, R, G, B, A)
			end

			--Cooltip code
			]],
			percent_script = false,
			total_script = false,
			script_version = 9,
		}
--	/run _detalhes:AddDefaultCustomDisplays()
		local have = false
		for _, custom in ipairs (self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_HEALTHSTONE_DEFAULT"] and (custom.script_version and custom.script_version >= Healthstone.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs (self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_HEALTHSTONE_DEFAULT"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable (Healthstone, _detalhes.atributo_custom)
			Healthstone.__index = _detalhes.atributo_custom
			self.custom [#self.custom+1] = Healthstone
		end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		
		local DamageActivityTime = {
			name = Loc ["STRING_CUSTOM_ACTIVITY_DPS"],
			icon = [[Interface\ICONS\Achievement_PVP_H_06]],
			attribute = false,
			spellid = false,
			author = "Details!",
			desc = Loc ["STRING_CUSTOM_ACTIVITY_DPS_DESC"],
			source = false,
			target = false,
			script_version = 1,
			total_script = [[
				local value, top, total, combat, instance = ...
				local minutos, segundos = math.floor (value/60), math.floor (value%60)
				return minutos .. "m " .. segundos .. "s"
			]],
			percent_script = [[
				local value, top, total, combat, instance = ...
				return string.format ("%.1f", value/top*100)
			]],
			script = [[
				--init:
				local combat, instance_container, instance = ...
				local total, amount = 0, 0

				--get the misc actor container
				local damage_container = combat:GetActorList ( DETAILS_ATTRIBUTE_DAMAGE )
				
				--do the loop:
				for _, player in ipairs ( damage_container ) do 
					if (player.grupo) then
						local activity = player:Tempo()
						total = total + activity
						amount = amount + 1
						--add amount to the player 
						instance_container:AddValue (player, activity)
					end
				end
				
				--return:
				return total, combat:GetCombatTime(), amount
			]],
			tooltip = [[
				
			]],
		}

		local have = false
		for _, custom in ipairs (self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_ACTIVITY_DPS"] and (custom.script_version and custom.script_version >= DamageActivityTime.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs (self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_ACTIVITY_DPS"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable (DamageActivityTime, _detalhes.atributo_custom)
			DamageActivityTime.__index = _detalhes.atributo_custom		
			self.custom [#self.custom+1] = DamageActivityTime
		end

		local HealActivityTime = {
			name = Loc ["STRING_CUSTOM_ACTIVITY_HPS"],
			icon = [[Interface\ICONS\Achievement_PVP_G_06]],
			attribute = false,
			spellid = false,
			author = "Details!",
			desc = Loc ["STRING_CUSTOM_ACTIVITY_HPS_DESC"],
			source = false,
			target = false,
			script_version = 1,
			total_script = [[
				local value, top, total, combat, instance = ...
				local minutos, segundos = math.floor (value/60), math.floor (value%60)
				return minutos .. "m " .. segundos .. "s"
			]],
			percent_script = [[
				local value, top, total, combat, instance = ...
				return string.format ("%.1f", value/top*100)
			]],
			script = [[
				--init:
				local combat, instance_container, instance = ...
				local total, top, amount = 0, 0, 0

				--get the misc actor container
				local damage_container = combat:GetActorList ( DETAILS_ATTRIBUTE_HEAL )
				
				--do the loop:
				for _, player in ipairs ( damage_container ) do 
					if (player.grupo) then
						local activity = player:Tempo()
						total = total + activity
						amount = amount + 1
						--add amount to the player 
						instance_container:AddValue (player, activity)
					end
				end
				
				--return:
				return total, combat:GetCombatTime(), amount
			]],
			tooltip = [[
				
			]],
		}

		local have = false
		for _, custom in ipairs (self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_ACTIVITY_HPS"] and (custom.script_version and custom.script_version >= HealActivityTime.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			for i, custom in ipairs (self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_ACTIVITY_HPS"]) then
					table.remove (self.custom, i)
				end
			end
			setmetatable (HealActivityTime, _detalhes.atributo_custom)
			HealActivityTime.__index = _detalhes.atributo_custom
			self.custom [#self.custom+1] = HealActivityTime
		end
		
---------------------------------------

		local DamageTakenBySpell = {
			name = Loc ["STRING_CUSTOM_DTBS"],
			icon = [[Interface\ICONS\spell_mage_infernoblast]],
			attribute = false,
			spellid = false,
			author = "Details!",
			desc = Loc ["STRING_CUSTOM_DTBS_DESC"],
			source = false,
			target = false,
			script_version = 29,
			on_shift_click = [[
				local row, object, instance = ...
				local spellname, _, spellicon = _detalhes.GetSpellInfo (object.id)
				_detalhes:OpenAuraPanel (object.id, spellname, spellicon)
			]],
			script = [[
				--> get the parameters passed
				local combat, instance_container, instance = ...
				--> declade the values to return
				local total, top, amount = 0, 0, 0
				--> get a list of all damage actors
				local AllDamageCharacters = combat:GetActorList (DETAILS_ATTRIBUTE_DAMAGE)

				--> no amount increase for repeated spells
				local NoRepeat = {}

				--> do a loop amoung the actors
				for index, character in ipairs (AllDamageCharacters) do
				    
				    --> is the actor a player?
				    if (character:IsPlayer()) then
					
					local taken_from = character.damage_from
					
					for source_name, _ in pairs (taken_from) do
					    
					    local source = combat (1, source_name)
					    
					    if (source) then
						--> came from an enemy
						if (not source:IsPlayer()) then
						    
						    local AllSpells = source:GetSpellList()
						    for spellid, spell in pairs (AllSpells) do
							local on_player = spell.targets [character.nome]
							
							if (on_player and on_player >= 1) then                            
							    instance_container:AddValue (spell, on_player)
							    total = total + on_player
							    local value = instance_container:GetValue (spell)
							    if (value > top) then
								top = value
							    end
							    if (not NoRepeat [spellid]) then
								amount = amount + 1
								NoRepeat [spellid] = true
							    end
							end
						    end
						    
						elseif (source:IsGroupPlayer()) then -- friendly fire
						    
						    local AllSpells = source.friendlyfire [character.nome] and source.friendlyfire [character.nome].spells
						    for spellid, on_player in pairs (AllSpells) do
							if (on_player and on_player >= 1) then
							    
							    local spellname = select (1, GetSpellInfo(spellid))
							    local TEMP_SPELL_OBJECT = _G ["DetailsDamageTakenBySpellTemp"..spellid]
							    if (not TEMP_SPELL_OBJECT) then
								TEMP_SPELL_OBJECT = {}
								_G ["DetailsDamageTakenBySpellTemp"..spellid] = TEMP_SPELL_OBJECT
							    end
							    
							    TEMP_SPELL_OBJECT.id = spellid
							    TEMP_SPELL_OBJECT.spellschool =  1
							    
							    instance_container:AddValue (TEMP_SPELL_OBJECT, on_player)
							    total = total + on_player
							    local value = instance_container:GetValue (TEMP_SPELL_OBJECT)
							    if (value > top) then
								top = value
							    end
							    if (not NoRepeat [spellid]) then
								amount = amount + 1
								NoRepeat [spellid] = true
							    end
							end
						    end
						end 
					    end
					end            
				    end
				end

				return total, top, amount
			]],
			
			tooltip = [[
			--get the parameters passed
			local actor, combat, instance = ...
			local Loc = LibStub ("AceLocale-3.0"):GetLocale ( "Details" )
			local GameCooltip = GameCooltip
			local from_spell = actor.id
			local from_spellname
			if (from_spell) then
			    from_spellname = select (1, GetSpellInfo (actor.id))
			end

			--> get a list of all damage actors
			local AllDamageCharacters = combat:GetActorList (DETAILS_ATTRIBUTE_DAMAGE)

			--> hold the targets
			local Targets = {}
			local total = 0
			local top = 0

			local is_custom_spell = false
			for _, spellcustom in ipairs (_detalhes.savedCustomSpells) do
			    if (spellcustom[1] == from_spell) then
				is_custom_spell = true
			    end
			end

			for index, character in ipairs (AllDamageCharacters) do
			    
			    if (is_custom_spell) then
				for playername, ff_table in pairs (character.friendlyfire) do
				    if (ff_table.spells [from_spell]) then
					local damage_actor = combat (1, playername)
					local heal_actor = combat (2, playername)
					
					if ((damage_actor or heal_actor) and ( (damage_actor and damage_actor:IsPlayer()) or (heal_actor and heal_actor:IsPlayer()))) then
					    
					    local got
					    
					    for index, t in ipairs (Targets) do
						if (t[1] == playername) then
						    t[2] = t[2] + ff_table.spells [from_spell]
						    if (t[2] > top) then
							top = t[2]
						    end
						    got = true
						    break
						end
					    end
					    
					    if (not got) then
						
						Targets [#Targets+1] = {playername, ff_table.spells [from_spell]}
						if (ff_table.spells [from_spell] > top) then
						    top = ff_table.spells [from_spell]
						end
					    end
					end
				    end
				end
			    else
				
				for playername, ff_table in pairs (character.friendlyfire) do
				    for spellid, amount in pairs (ff_table.spells) do
					local spellname = select (1, GetSpellInfo (spellid))
					if (spellname == from_spellname) then
					    local damage_actor = combat (1, playername)
					    local heal_actor = combat (2, playername)                    
					    if ((damage_actor or heal_actor) and ( (damage_actor and damage_actor:IsPlayer()) or (heal_actor and heal_actor:IsPlayer()))) then
						local got
						for index, t in ipairs (Targets) do
						    if (t[1] == playername) then
							t[2] = t[2] + amount
							if (t[2] > top) then
							    top = t[2]
							end
							got = true
							break
						    end
						end
						
						if (not got) then
						    Targets [#Targets+1] = {playername, amount}
						    if (amount > top) then
							top = amount
						    end
						end                        
					    end
					end     
				    end
				end
			    end
			    
			    --> search actors which used the spell shown in the bar
			    local spell = character.spells._ActorTable [from_spell]
			    
			    if (spell) then
				for targetname, amount in pairs (spell.targets) do
				    
				    local got = false
				    
				    local damage_actor = combat (1, targetname)
				    local heal_actor = combat (2, targetname)
				    
				    if ( (damage_actor or heal_actor) and ( (damage_actor and damage_actor:IsPlayer()) or (heal_actor and heal_actor:IsPlayer()) ) ) then
					for index, t in ipairs (Targets) do
					    if (t[1] == targetname) then
						t[2] = t[2] + amount
						if (t[2] > top) then
						    top = t[2]
						end
						got = true
						break
					    end
					end
					if (not got) then
					    Targets [#Targets+1] = {targetname, amount}
					    if (amount > top) then
						top = amount
					    end
					end
					--            else
					--                for index, t in ipairs (Targets) do
					--                    if (t[1] == Loc ["STRING_TARGETS_OTHER1"]) then
					--                        t[2] = t[2] + amount
					--                        got = true
					--print (damage_actor and damage_actor.nome, heal_actor and heal_actor.nome)
					--                        break
					--                    end
					--                end
					--                if (not got) then
					--                    Targets [#Targets+1] = {Loc ["STRING_TARGETS_OTHER1"], amount}
					--                end
				    end
				end
			    end
			    
			    if (not is_custom_spell) then
				for spellid, spell in pairs (character.spells._ActorTable) do
				    if (spellid ~= from_spell) then
					local spellname = select (1, GetSpellInfo (spellid))
					if (spellname == from_spellname) then
					    for targetname, amount in pairs (spell.targets) do
						
						local got = false
						
						local damage_actor = combat (1, targetname)
						local heal_actor = combat (2, targetname)
						
						if ( (damage_actor or heal_actor) and ( (damage_actor and damage_actor:IsPlayer()) or (heal_actor and heal_actor:IsPlayer()) ) ) then
						    for index, t in ipairs (Targets) do
							if (t[1] == targetname) then
							    t[2] = t[2] + amount
							    if (t[2] > top) then
								top = t[2]
							    end
							    got = true
							    break
							end
						    end
						    if (not got) then
							Targets [#Targets+1] = {targetname, amount}
							if (amount > top) then
							    top = amount
							end
						    end
						end
					    end
					end                
				    end             
				end        
			    end    
			    
			end

			table.sort (Targets, _detalhes.Sort2)

			GameCooltip:SetOption ("StatusBarTexture", "Interface\\AddOns\\Details\\images\\bar_serenity")

			--local bar_background = {value = 100, color = {0.1, 0.1, 0.1, 0.9}, texture = "Interface\\AddOns\\Details\\images\\bar_background"}
			local bar_background = {value = 100, color = {0.1, 0.1, 0.15, 1}, texture = "Interface\\AddOns\\Details\\images\\bar_background2"}

			for index, t in ipairs (Targets) do
			    GameCooltip:AddLine (_detalhes:GetOnlyName(t[1]), _detalhes:ToK (t[2]))
			    local class, _, _, _, _, r, g, b = _detalhes:GetClass (t[1])
			    
			    GameCooltip:AddStatusBar (t[2]/top*100, 1, r, g, b, 0.8, false,  bar_background)
			    
			    if (class) then
				local texture, l, r, t, b = _detalhes:GetClassIcon (class)
				GameCooltip:AddIcon ("Interface\\AddOns\\Details\\images\\classes_small_alpha", 1, 1, 14, 14, l, r, t, b)
			    elseif (t[1] == Loc ["STRING_TARGETS_OTHER1"]) then
				GameCooltip:AddIcon ("Interface\\AddOns\\Details\\images\\classes_small_alpha", 1, 1, 14, 14, 0.25, 0.49609375, 0.75, 1)
			    end
			end

			local aura = ""
			if (WeakAuras) then
			    aura = "|cFFffa200Shift Click|r: Create Aura"
			end

			GameCooltip:AddLine (" ")
			GameCooltip:AddLine ("|cFFffa200Click|r: Report Results", aura, 1, "white", "white")
			GameCooltip:AddStatusBar (100, 1, 0, 0, 0, 0.7, false,  bar_background)
]],
		}

		local have = false
		for _, custom in ipairs (self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_DTBS"] and (custom.script_version and custom.script_version >= DamageTakenBySpell.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			setmetatable (DamageTakenBySpell, _detalhes.atributo_custom)
			DamageTakenBySpell.__index = _detalhes.atributo_custom
			
			for i, custom in ipairs (self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_DTBS"]) then
					table.remove (self.custom, i)
					tinsert (self.custom, i, DamageTakenBySpell)
					have = true
				end
			end
			
			if (not have) then
				self.custom [#self.custom+1] = DamageTakenBySpell
			end
		end
		
		----------------------------------------------------------------------------------------------------------------------------------------------------
		--doas
		local CC_Done = {
			name = "Crowd Control",
			icon = [[Interface\ICONS\Spell_Frost_FreezingBreath]],
			attribute = false,
			spellid = false,
			author = "Details!",
			desc = "Show the crowd control amount for each player.",
			source = false,
			target = false,
			script_version = 7,
			script = [[
				local combat, instance_container, instance = ...
				local total, top, amount = 0, 0, 0

				local misc_actors = combat:GetActorList (DETAILS_ATTRIBUTE_MISC)

				for index, character in ipairs (misc_actors) do
					if (character.cc_done and character:IsPlayer()) then
						local cc_done = floor (character.cc_done)
						instance_container:AddValue (character, cc_done)
						total = total + cc_done
						if (cc_done > top) then
							top = cc_done
						end
						amount = amount + 1
					end
				end

				return total, top, amount
			]],
			tooltip = [[
				local actor, combat, instance = ...
				local spells = {}
				for spellid, spell in pairs (actor.cc_done_spells._ActorTable) do
				    tinsert (spells, {spellid, spell.counter})
				end

				table.sort (spells, _detalhes.Sort2)

				for index, spell in ipairs (spells) do
				    local name, _, icon = GetSpellInfo (spell [1])
				    GameCooltip:AddLine (name, spell [2])
				    _detalhes:AddTooltipBackgroundStatusbar()
				    GameCooltip:AddIcon (icon, 1, 1, 14, 14)
				end

				local targets = {}
				for playername, amount in pairs (actor.cc_done_targets) do
				    tinsert (targets, {playername, amount})
				end

				table.sort (targets, _detalhes.Sort2)

				_detalhes:AddTooltipSpellHeaderText ("Targets", "yellow", r, g, b, #targets)
				local class, _, _, _, _, r, g, b = _detalhes:GetClass (actor.nome)
				GameCooltip:AddStatusBar (100, 1, r, g, b, 1)


				for index, target in ipairs (targets) do
				    GameCooltip:AddLine (target[1], target [2])
				    _detalhes:AddTooltipBackgroundStatusbar()
				    
				    local class, _, _, _, _, r, g, b = _detalhes:GetClass (target [1])
				    if (class and class ~= "UNKNOW") then
					local texture, l, r, t, b = _detalhes:GetClassIcon (class)
					GameCooltip:AddIcon ("Interface\\AddOns\\Details\\images\\classes_small_alpha", 1, 1, 14, 14, l, r, t, b)
				    else
					GameCooltip:AddIcon ("Interface\\GossipFrame\\IncompleteQuestIcon", 1, 1, 14, 14)
				    end
				    --
				end
			]],
			total_script = [[
				local value, top, total, combat, instance = ...
				return floor (value)
			]],
		}
		
--		/run _detalhes:AddDefaultCustomDisplays()
		
		local have = false
		for _, custom in ipairs (self.custom) do
			if (custom.name == "Crowd Control" and (custom.script_version and custom.script_version >= CC_Done.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			setmetatable (CC_Done, _detalhes.atributo_custom)
			CC_Done.__index = _detalhes.atributo_custom
			
			for i, custom in ipairs (self.custom) do
				if (custom.name == "Crowd Control") then
					table.remove (self.custom, i)
					tinsert (self.custom, i, CC_Done)
					have = true
				end
			end
			if (not have) then
				self.custom [#self.custom+1] = CC_Done
			end
		end	
		
		----------------------------------------------------------------------------------------------------------------------------------------------------
		
		local MySpells = {
			name = Loc ["STRING_CUSTOM_MYSPELLS"],
			icon = [[Interface\ICONS\ABILITY_MAGE_ARCANEBARRAGE]],
			attribute = false,
			spellid = false,
			author = "Details!",
			desc = Loc ["STRING_CUSTOM_MYSPELLS_DESC"],
			source = false,
			target = false,
			script_version = 4,
			script = [[
				--get the parameters passed
				local combat, instance_container, instance = ...
				--declade the values to return
				local total, top, amount = 0, 0, 0

				local player
				local role = UnitGroupRolesAssigned ("player")
				local pet_attribute

				if (role == "DAMAGER") then
					player = combat (DETAILS_ATTRIBUTE_DAMAGE, _detalhes.playername)
					pet_attribute = DETAILS_ATTRIBUTE_DAMAGE
				elseif (role == "HEALER") then    
					player = combat (DETAILS_ATTRIBUTE_HEAL, _detalhes.playername)
					pet_attribute = DETAILS_ATTRIBUTE_HEAL
				else
					player = combat (DETAILS_ATTRIBUTE_DAMAGE, _detalhes.playername)
					pet_attribute = DETAILS_ATTRIBUTE_DAMAGE
				end

				--do the loop

				if (player) then
					local spells = player:GetSpellList()
					for spellid, spell in pairs (spells) do
						instance_container:AddValue (spell, spell.total)
						total = total + spell.total
						if (top < spell.total) then
							top = spell.total
						end
						amount = amount + 1
					end
				    
					for _, PetName in ipairs (player.pets) do
						local pet = combat (pet_attribute, PetName)
						if (pet) then
							for spellid, spell in pairs (pet:GetSpellList()) do
								instance_container:AddValue (spell, spell.total, nil, " (" .. PetName:gsub ((" <.*"), "") .. ")")
								total = total + spell.total
								if (top < spell.total) then
									top = spell.total
								end
								amount = amount + 1
							end
						end
					end
				end

				--return the values
				return total, top, amount
			]],
			
			tooltip = [[
				--config:
				--Background RBG and Alpha:
				local R, G, B, A = 0, 0, 0, 0.75

				--get the parameters passed
				local spell, combat, instance = ...

				--get the cooltip object (we dont use the convencional GameTooltip here)
				local GC = GameCooltip
				GC:SetOption ("YSpacingMod", 1)

				local role = UnitGroupRolesAssigned ("player")

				if (spell.n_dmg) then
				    
				    local spellschool, schooltext = spell.spellschool, ""
				    if (spellschool) then
					local t = _detalhes.spells_school [spellschool]
					if (t and t.name) then
					    schooltext = t.formated
					end
				    end
				    
				    local total_hits = spell.counter
				    local combat_time = instance.showing:GetCombatTime()
				    
				    --Cooltip code
				    GC:AddLine ("Hits:", spell.counter)
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    local average = spell.total / total_hits
				    GC:AddLine ("Average:", _detalhes:ToK (average))
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    GC:AddLine ("E-Dps:", _detalhes:ToK (spell.total / combat_time))
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    GC:AddLine ("School:", schooltext)
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    --GC:AddLine (" ")
				    
				    GC:AddLine ("Normal Hits: ", spell.n_amt .. " (" ..floor ( spell.n_amt/total_hits*100) .. "%)")
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    local n_average = spell.n_dmg / spell.n_amt
				    local T = (combat_time*spell.n_dmg)/spell.total
				    local P = average/n_average*100
				    T = P*T/100
				    
				    GC:AddLine ("Average / E-Dps: ",  _detalhes:ToK (n_average) .. " / " .. format ("%.1f",spell.n_dmg / T ))
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    --GC:AddLine (" ")
				    
				    GC:AddLine ("Critical Hits: ", spell.c_amt .. " (" ..floor ( spell.c_amt/total_hits*100) .. "%)")
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    if (spell.c_amt > 0) then
					local c_average = spell.c_dmg/spell.c_amt
					local T = (combat_time*spell.c_dmg)/spell.total
					local P = average/c_average*100
					T = P*T/100
					local crit_dps = spell.c_dmg / T
					
					GC:AddLine ("Average / E-Dps: ",  _detalhes:ToK (c_average) .. " / " .. _detalhes:comma_value (crit_dps))
				    else
					GC:AddLine ("Average / E-Dps: ",  "0 / 0")    
				    end
				    
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    --GC:AddLine (" ")
				    
				    GC:AddLine ("Multistrike: ", spell.m_amt .. " (" ..floor ( spell.m_amt/total_hits*100) .. "%)")
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    GC:AddLine ("On Normal / On Critical:", spell.m_amt - spell.m_crit .. "  / " .. spell.m_crit)
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				elseif (spell.n_curado) then
				    
				    local spellschool, schooltext = spell.spellschool, ""
				    if (spellschool) then
					local t = _detalhes.spells_school [spellschool]
					if (t and t.name) then
					    schooltext = t.formated
					end
				    end
				    
				    local total_hits = spell.counter
				    local combat_time = instance.showing:GetCombatTime()
				    
				    --Cooltip code
				    GC:AddLine ("Hits:", spell.counter)
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    local average = spell.total / total_hits
				    GC:AddLine ("Average:", _detalhes:ToK (average))
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    GC:AddLine ("E-Hps:", _detalhes:ToK (spell.total / combat_time))
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    GC:AddLine ("School:", schooltext)
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    --GC:AddLine (" ")
				    
				    GC:AddLine ("Normal Hits: ", spell.n_amt .. " (" ..floor ( spell.n_amt/total_hits*100) .. "%)")
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    local n_average = spell.n_curado / spell.n_amt
				    local T = (combat_time*spell.n_curado)/spell.total
				    local P = average/n_average*100
				    T = P*T/100
				    
				    GC:AddLine ("Average / E-Dps: ",  _detalhes:ToK (n_average) .. " / " .. format ("%.1f",spell.n_curado / T ))
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    --GC:AddLine (" ")
				    
				    GC:AddLine ("Critical Hits: ", spell.c_amt .. " (" ..floor ( spell.c_amt/total_hits*100) .. "%)")
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    if (spell.c_amt > 0) then
					local c_average = spell.c_curado/spell.c_amt
					local T = (combat_time*spell.c_curado)/spell.total
					local P = average/c_average*100
					T = P*T/100
					local crit_dps = spell.c_curado / T
					
					GC:AddLine ("Average / E-Hps: ",  _detalhes:ToK (c_average) .. " / " .. _detalhes:comma_value (crit_dps))
				    else
					GC:AddLine ("Average / E-Hps: ",  "0 / 0")    
				    end
				    
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    --GC:AddLine (" ")
				    
				    GC:AddLine ("Multistrike: ", spell.m_amt .. " (" ..floor ( spell.m_amt/total_hits*100) .. "%)")
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    GC:AddLine ("On Normal / On Critical:", spell.m_amt - spell.m_crit .. "  / " .. spell.m_crit)
				    GC:AddStatusBar (100, 1, R, G, B, A)
				    
				    
				end
			]],
			
			percent_script = [[
				local value, top, total, combat, instance = ...
				local dps = _detalhes:ToK (floor (value) / combat:GetCombatTime())
				local percent = string.format ("%.1f", value/total*100)
				return dps .. ", " .. percent
			]],
		}

		local have = false
		for _, custom in ipairs (self.custom) do
			if (custom.name == Loc ["STRING_CUSTOM_MYSPELLS"] and (custom.script_version and custom.script_version >= MySpells.script_version) ) then
				have = true
				break
			end
		end
		if (not have) then
			setmetatable (MySpells, _detalhes.atributo_custom)
			MySpells.__index = _detalhes.atributo_custom
			
			for i, custom in ipairs (self.custom) do
				if (custom.name == Loc ["STRING_CUSTOM_MYSPELLS"]) then
					table.remove (self.custom, i)
					tinsert (self.custom, i, MySpells)
					have = true
				end
			end
			if (not have) then
				self.custom [#self.custom+1] = MySpells
			end
		end		
		
		_detalhes:ResetCustomFunctionsCache()
		
	end
