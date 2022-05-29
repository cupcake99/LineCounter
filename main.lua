--_AUTO_RELOAD_DEBUG = true

--set up variables to shorten API access calls
local tool = renoise.tool
local app = renoise.app
local song = renoise.song

--create preferences
local prefs = renoise.Document.create {
  active = true,
  edit_step_change = true,
  clear = 1500,
  default = false
}
tool().preferences = prefs

--main variables
local selection_changed = false
local flagged = prefs.default.value
local selection, last_selection = {}, {}
local check_interval = 100
local clear_time = prefs.clear.value
local wait_time = 330

--add menu entries (obviously)
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Line Counter:Active",
  selected = function() return tool():has_timer(selection_timer) end,
  invoke = function() 
    if tool():has_timer(selection_timer) then
      tool():remove_timer(selection_timer)
      prefs.active.value = false
    else
      tool():add_timer(selection_timer, check_interval)
      prefs.active.value = true
    end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Line Counter:Link Edit Step to Selection",
  selected = function() return prefs.edit_step_change.value end,
  invoke = function() prefs.edit_step_change.value = not prefs.edit_step_change.value end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Line Counter:Message Time:Renoise Default",
  selected = function() return flagged end,
  invoke = function() flagged = true; prefs.default.value = flagged end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Line Counter:Message Time:1500",
  selected = function() return clear_time == 1500 and flagged == false end,
  invoke = function() clear_time = 1500; flagged = false; prefs.clear.value = clear_time; prefs.default.value = flagged end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Line Counter:Message Time:1250",
  selected = function() return clear_time == 1250 and flagged == false end,
  invoke = function() clear_time = 1250; flagged = false; prefs.clear.value = clear_time; prefs.default.value = flagged end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Line Counter:Message Time:1000",
  selected = function() return clear_time == 1000 and flagged == false end,
  invoke = function() clear_time = 1000; flagged = false; prefs.clear.value = clear_time; prefs.default.value = flagged end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Line Counter:Message Time:750",
  selected = function() return clear_time == 750 and flagged == false end,
  invoke = function() clear_time = 750; flagged = false; prefs.clear.value = clear_time; prefs.default.value = flagged end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Line Counter:Message Time:500",
  selected = function() return clear_time == 500 and flagged == false end,
  invoke = function() clear_time = 500; flagged = false; prefs.clear.value = clear_time; prefs.default.value = flagged end
}

--init function for selections, called below once document is loaded
function initialise_selection()
  if song().selection_in_pattern ~= nil then
    selection = song().selection_in_pattern
    last_selection = song().selection_in_pattern
  end
end

--write selection length to status bar
function write_status_msg(selection)
  if selection ~= nil then
   local num_lines = selection.end_line - selection.start_line + 1
   local bpm = 60000 / ((60000 / song().transport.bpm / song().transport.lpb) * num_lines)
   app():show_status(string.format("Number of lines in selection: %d, BPM of selected time at current BPM and LPB: %f", num_lines, bpm))
  end
end

--clear status message timer - currently only called when selection is one line long
function clear_status_msg()
  app():show_status("")
  if tool():has_timer(clear_status_msg) then
    tool():remove_timer(clear_status_msg)
  end
end

--set edit step to number of lines in selection (and check it doesn't go out of bounds)
function setEditStep(selection)
  if selection ~= nil and prefs.edit_step_change.value then
    if selection.end_line - selection.start_line + 1 > 64 then
        song().transport.edit_step = 64
    else
        song().transport.edit_step = selection.end_line - selection.start_line + 1
    end
  end
end

--compare two pattern selection tables
function compare_selection(current, last)
  if current ~= nil and last ~= nil then
   if current.start_line == last.start_line and
      current.end_line == last.end_line and
      current.start_track == last.start_track and
      current.end_track == last.end_track then
      return true
   else 
      return false
   end
  end
end

--set one selection table to another
function get_selection(current, selection)
  if current ~= nil and selection ~= nil then
    selection.start_line = current.start_line
    selection.end_line = current.end_line
    selection.start_track = current.start_track
    selection.end_track = current.end_track
  else return
  end
end

--main timer callback to check if selection in pattern changes - timer stops itself once it detects a change and is then rescheduled from the check_selection() function
function selection_timer()
  get_selection(song().selection_in_pattern, selection)
  if not compare_selection(selection, last_selection) then
    selection_changed = true
    if tool():has_timer(selection_timer) then
      tool():remove_timer(selection_timer)
    end
    check_selection()
    return
  end
  if selection_changed then
    selection_changed = false
  end
end

--main action in here
function check_selection()

--check for nil selection and reschedule main timer if found - this likely never gets called, it's probably useful for safety
  if song().selection_in_pattern == nil then 
    if not tool():has_timer(selection_timer) then
      tool():add_timer(selection_timer, check_interval)
    end 
    return 
  end

  if selection_changed then
  
--call functions to write message, set edit step and schedule clear timer
    if (song().selection_in_pattern.end_line - song().selection_in_pattern.start_line) >= 0 then
     write_status_msg(song().selection_in_pattern)
     setEditStep(song().selection_in_pattern)
     if tool():has_timer(clear_status_msg) then
        tool():remove_timer(clear_status_msg)
        tool():add_timer(clear_status_msg, clear_time)
     else 
        tool():add_timer(clear_status_msg, clear_time)
     end
    end

--remove clear timer for status bar if time is set to renoise default
    if flagged then
     if tool():has_timer(clear_status_msg) then
        tool():remove_timer(clear_status_msg)
     end  
    end

-- reset everything and reschedule main timer
    selection_changed = false
    if not tool():has_timer(selection_timer) then
      tool():add_timer(selection_timer, check_interval)
    end 
  end
  get_selection(song().selection_in_pattern, last_selection)
end

--__get the ball rolling__--
tool().app_new_document_observable:add_notifier(initialise_selection)
if prefs.active.value then tool():add_timer(selection_timer, check_interval) end
