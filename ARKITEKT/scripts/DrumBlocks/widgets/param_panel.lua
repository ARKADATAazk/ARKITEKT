-- @noindex
-- DrumBlocks/widgets/param_panel.lua
-- Parameter panel with waveform display and pad controls using knobs

local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local Colors = Ark.Colors
local Theme = require('arkitekt.theme')
local Knob = require('arkitekt.gui.widgets.primitives.knob')
local Bridge = require('DrumBlocks.domain.bridge')
local WaveformDisplay = require('DrumBlocks.widgets.waveform_display')

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local COLORS = {
  bg = 0x1E1E1EFF,
  section_bg = 0x252525FF,
  section_header = 0x888888FF,
  text = 0xCCCCCCFF,
  text_dim = 0x888888FF,
  accent = 0x44CCFFFF,
}

local KNOB_SIZE = 48
local KNOB_SPACING = 8

-- ============================================================================
-- FORMAT FUNCTIONS
-- ============================================================================

-- Volume: 0-1 linear to dB display
local function format_volume_db(value)
  if value <= 0 then return '-inf' end
  local db = 20 * math.log(value, 10)
  if db <= -60 then return '-inf' end
  return string.format('%.1f', db)
end

-- Pan: -1 to 1 to L/R display
local function format_pan(value)
  if math.abs(value) < 0.01 then return 'C' end
  local pct = math.abs(value) * 100
  if value < 0 then
    return string.format('%d L', math.floor(pct + 0.5))
  else
    return string.format('%d R', math.floor(pct + 0.5))
  end
end

-- Tune: semitones
local function format_tune(value)
  return string.format('%+.1f', value)
end

-- Cutoff: Hz with k suffix for thousands
local function format_cutoff(value)
  if value >= 1000 then
    return string.format('%.1fk', value / 1000)
  else
    return string.format('%.0f', value)
  end
end

-- Resonance: 0-1 to percentage
local function format_resonance(value)
  return string.format('%.0f%%', value * 100)
end

-- ADSR: milliseconds
local function format_ms(value)
  if value >= 1000 then
    return string.format('%.1fs', value / 1000)
  else
    return string.format('%.0f', value)
  end
end

-- ============================================================================
-- CUTOFF EXPONENTIAL CONVERSION
-- ============================================================================

-- Normalized 0-1 to Hz (exponential)
local function cutoff_from_normalized(t)
  return 20 * math.pow(1000, t)  -- 20Hz at t=0, 20000Hz at t=1
end

-- Hz to normalized 0-1
local function cutoff_to_normalized(hz)
  hz = math.max(20, math.min(20000, hz))
  return math.log(hz / 20) / math.log(1000)
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function section_header(ctx, label)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, COLORS.section_header)
  ImGui.Text(ctx, label)
  ImGui.PopStyleColor(ctx)
  ImGui.Spacing(ctx)
end

local function labeled_combo(ctx, label, current, items, width)
  ImGui.Text(ctx, label)
  ImGui.SameLine(ctx)

  local avail_w = ImGui.GetContentRegionAvail(ctx)
  width = width or math.min(avail_w - 50, 150)

  ImGui.SetNextItemWidth(ctx, width)
  local preview = items[current + 1] or tostring(current)

  local changed = false
  local new_value = current

  if ImGui.BeginCombo(ctx, '##' .. label, preview) then
    for i, item in ipairs(items) do
      local is_selected = (i - 1) == current
      if ImGui.Selectable(ctx, item, is_selected) then
        new_value = i - 1
        changed = true
      end
      if is_selected then
        ImGui.SetItemDefaultFocus(ctx)
      end
    end
    ImGui.EndCombo(ctx)
  end

  return changed, new_value
end

-- Draw a row of knobs
local function knob_row(ctx, knobs, state, pad_index, pad_data)
  local start_x = ImGui.GetCursorPosX(ctx)
  local changed = false

  for i, knob_def in ipairs(knobs) do
    if i > 1 then
      ImGui.SameLine(ctx, start_x + (i - 1) * (KNOB_SIZE + KNOB_SPACING))
    end

    local result = Knob.Draw(ctx, {
      id = knob_def.id .. '_' .. pad_index,
      label = knob_def.label,
      value = knob_def.get_value(pad_data),
      min = knob_def.min,
      max = knob_def.max,
      default = knob_def.default,
      size = KNOB_SIZE,
      variant = 'serum',
      format_func = knob_def.format_func,
      show_value = true,
      show_label = true,
    })

    if result.changed then
      knob_def.set_value(state, pad_index, pad_data, result.value)
      changed = true
    end
  end

  return changed
end

-- ============================================================================
-- MAIN DRAW FUNCTION
-- ============================================================================

function M.draw(ctx, opts)
  opts = opts or {}

  local state = opts.state
  if not state then return { width = 0, height = 0 } end

  local width = opts.width or 280
  local pad_index = state.getSelectedPad()

  -- No pad selected
  if not pad_index then
    ImGui.BeginChild(ctx, '##param_panel_empty', width, -1)
    ImGui.Text(ctx, 'Select a pad')
    ImGui.EndChild(ctx)
    return { width = width, height = 0 }
  end

  local pad_data = state.getPadData(pad_index)
  local has_sample = state.hasSample(pad_index)
  local changed = false

  ImGui.BeginChild(ctx, '##param_panel', width, -1)

  -- ========================================================================
  -- PAD HEADER
  -- ========================================================================

  local pad_num = (pad_index % 16) + 1
  local bank_letter = string.char(65 + math.floor(pad_index / 16))  -- A-H
  ImGui.Text(ctx, string.format('Pad %s%d', bank_letter, pad_num))

  if pad_data.name then
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.text_dim, '- ' .. pad_data.name)
  end

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- WAVEFORM DISPLAY
  -- ========================================================================

  local waveform_w = width - 16
  -- Use width-based peak resolution (auto-selects tier, triggers async if needed)
  local peaks = state.getPadPeaksForDisplay(pad_index, 0, waveform_w)

  WaveformDisplay.draw(ctx, {
    peaks = peaks,
    width = waveform_w,
    height = 80,
    show_adsr = has_sample,
    attack = pad_data.attack or 0,
    decay = pad_data.decay or 100,
    sustain = pad_data.sustain or 1,
    release = pad_data.release or 200,
  })

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- LEVEL: Volume / Pan / Tune
  -- ========================================================================

  section_header(ctx, 'LEVEL')

  local level_knobs = {
    {
      id = 'vol', label = 'Vol',
      min = 0, max = 1, default = 0.8,
      format_func = format_volume_db,
      get_value = function(pd) return pd.volume or 0.8 end,
      set_value = function(st, pi, pd, v) st.setPadVolume(pi, v) end,
    },
    {
      id = 'pan', label = 'Pan',
      min = -1, max = 1, default = 0,
      format_func = format_pan,
      get_value = function(pd) return pd.pan or 0 end,
      set_value = function(st, pi, pd, v) st.setPadPan(pi, v) end,
    },
    {
      id = 'tune', label = 'Tune',
      min = -24, max = 24, default = 0,
      format_func = format_tune,
      get_value = function(pd) return pd.tune or 0 end,
      set_value = function(st, pi, pd, v) st.setPadTune(pi, v) end,
    },
  }

  if knob_row(ctx, level_knobs, state, pad_index, pad_data) then
    changed = true
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- ENVELOPE: A / D / S / R
  -- ========================================================================

  section_header(ctx, 'ENVELOPE')

  local adsr_knobs = {
    {
      id = 'attack', label = 'A',
      min = 0, max = 1000, default = 0,
      format_func = format_ms,
      get_value = function(pd) return pd.attack or 0 end,
      set_value = function(st, pi, pd, v)
        pd.attack = v
        if st.hasDrumBlocks() then
          Bridge.setAttack(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
    {
      id = 'decay', label = 'D',
      min = 0, max = 2000, default = 100,
      format_func = format_ms,
      get_value = function(pd) return pd.decay or 100 end,
      set_value = function(st, pi, pd, v)
        pd.decay = v
        if st.hasDrumBlocks() then
          Bridge.setDecay(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
    {
      id = 'sustain', label = 'S',
      min = 0, max = 1, default = 1,
      format_func = format_resonance,  -- Also works for 0-1 to %
      get_value = function(pd) return pd.sustain or 1 end,
      set_value = function(st, pi, pd, v)
        pd.sustain = v
        if st.hasDrumBlocks() then
          Bridge.setSustain(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
    {
      id = 'release', label = 'R',
      min = 0, max = 3000, default = 200,
      format_func = format_ms,
      get_value = function(pd) return pd.release or 200 end,
      set_value = function(st, pi, pd, v)
        pd.release = v
        if st.hasDrumBlocks() then
          Bridge.setRelease(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
  }

  if knob_row(ctx, adsr_knobs, state, pad_index, pad_data) then
    changed = true
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- FILTER: Cutoff / Resonance
  -- ========================================================================

  section_header(ctx, 'FILTER')

  -- Cutoff uses normalized 0-1 internally for exponential behavior
  local cutoff_hz = pad_data.filter_cutoff or 20000
  local cutoff_norm = cutoff_to_normalized(cutoff_hz)

  local cutoff_result = Knob.Draw(ctx, {
    id = 'cutoff_' .. pad_index,
    label = 'Cutoff',
    value = cutoff_norm,
    min = 0, max = 1, default = 1,
    size = KNOB_SIZE,
    variant = 'serum',
    format_func = function(v) return format_cutoff(cutoff_from_normalized(v)) end,
    show_value = true,
    show_label = true,
  })

  if cutoff_result.changed then
    local new_hz = cutoff_from_normalized(cutoff_result.value)
    pad_data.filter_cutoff = new_hz
    if state.hasDrumBlocks() then
      Bridge.setFilterCutoff(state.getTrack(), state.getFxIndex(), pad_index, new_hz)
    end
    changed = true
  end

  ImGui.SameLine(ctx)

  local reso_result = Knob.Draw(ctx, {
    id = 'reso_' .. pad_index,
    label = 'Reso',
    value = pad_data.filter_reso or 0,
    min = 0, max = 1, default = 0,
    size = KNOB_SIZE,
    variant = 'serum',
    format_func = format_resonance,
    show_value = true,
    show_label = true,
  })

  if reso_result.changed then
    pad_data.filter_reso = reso_result.value
    if state.hasDrumBlocks() then
      Bridge.setFilterReso(state.getTrack(), state.getFxIndex(), pad_index, reso_result.value)
    end
    changed = true
  end

  -- Filter Type dropdown
  do
    local filter_type = pad_data.filter_type or 0
    local filter_items = { 'Lowpass', 'Highpass', 'Bandpass' }
    local ft_changed, new_ft = labeled_combo(ctx, 'Type', filter_type, filter_items)
    if ft_changed then
      pad_data.filter_type = new_ft
      if state.hasDrumBlocks() then
        Bridge.setFilterType(state.getTrack(), state.getFxIndex(), pad_index, new_ft)
      end
      changed = true
    end
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- PITCH ENVELOPE (808-style)
  -- ========================================================================

  section_header(ctx, 'PITCH ENV')

  local pitch_env_knobs = {
    {
      id = 'penv_amt', label = 'Amt',
      min = -24, max = 24, default = 0,
      format_func = format_tune,
      get_value = function(pd) return pd.pitch_env_amount or 0 end,
      set_value = function(st, pi, pd, v)
        pd.pitch_env_amount = v
        if st.hasDrumBlocks() then
          Bridge.setPitchEnvAmount(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
    {
      id = 'penv_a', label = 'A',
      min = 0, max = 100, default = 0,
      format_func = format_ms,
      get_value = function(pd) return pd.pitch_env_attack or 0 end,
      set_value = function(st, pi, pd, v)
        pd.pitch_env_attack = v
        if st.hasDrumBlocks() then
          Bridge.setPitchEnvAttack(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
    {
      id = 'penv_d', label = 'D',
      min = 0, max = 2000, default = 100,
      format_func = format_ms,
      get_value = function(pd) return pd.pitch_env_decay or 100 end,
      set_value = function(st, pi, pd, v)
        pd.pitch_env_decay = v
        if st.hasDrumBlocks() then
          Bridge.setPitchEnvDecay(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
    {
      id = 'penv_s', label = 'S',
      min = 0, max = 1, default = 0,
      format_func = format_resonance,
      get_value = function(pd) return pd.pitch_env_sustain or 0 end,
      set_value = function(st, pi, pd, v)
        pd.pitch_env_sustain = v
        if st.hasDrumBlocks() then
          Bridge.setPitchEnvSustain(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
  }

  if knob_row(ctx, pitch_env_knobs, state, pad_index, pad_data) then
    changed = true
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- SATURATION
  -- ========================================================================

  section_header(ctx, 'SATURATION')

  -- Saturation Type dropdown
  do
    local sat_type = pad_data.saturation_type or 0
    local sat_items = { 'Soft', 'Hard', 'Tube', 'Tape', 'Fold', 'Crush' }
    local st_changed, new_st = labeled_combo(ctx, 'Type', sat_type, sat_items)
    if st_changed then
      pad_data.saturation_type = new_st
      if state.hasDrumBlocks() then
        Bridge.setSaturationType(state.getTrack(), state.getFxIndex(), pad_index, new_st)
      end
      changed = true
    end
  end

  local sat_knobs = {
    {
      id = 'sat_drive', label = 'Drive',
      min = 0, max = 1, default = 0,
      format_func = format_resonance,
      get_value = function(pd) return pd.saturation_drive or 0 end,
      set_value = function(st, pi, pd, v)
        pd.saturation_drive = v
        if st.hasDrumBlocks() then
          Bridge.setSaturationDrive(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
    {
      id = 'sat_mix', label = 'Mix',
      min = 0, max = 1, default = 1,
      format_func = format_resonance,
      get_value = function(pd) return pd.saturation_mix or 1 end,
      set_value = function(st, pi, pd, v)
        pd.saturation_mix = v
        if st.hasDrumBlocks() then
          Bridge.setSaturationMix(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
  }

  if knob_row(ctx, sat_knobs, state, pad_index, pad_data) then
    changed = true
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- TRANSIENT SHAPER
  -- ========================================================================

  section_header(ctx, 'TRANSIENT')

  local trans_knobs = {
    {
      id = 'trans_atk', label = 'Attack',
      min = -1, max = 1, default = 0,
      format_func = function(v) return string.format('%+.0f%%', v * 100) end,
      get_value = function(pd) return pd.transient_attack or 0 end,
      set_value = function(st, pi, pd, v)
        pd.transient_attack = v
        if st.hasDrumBlocks() then
          Bridge.setTransientAttack(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
    {
      id = 'trans_sus', label = 'Sustain',
      min = -1, max = 1, default = 0,
      format_func = function(v) return string.format('%+.0f%%', v * 100) end,
      get_value = function(pd) return pd.transient_sustain or 0 end,
      set_value = function(st, pi, pd, v)
        pd.transient_sustain = v
        if st.hasDrumBlocks() then
          Bridge.setTransientSustain(st.getTrack(), st.getFxIndex(), pi, v)
        end
      end,
    },
  }

  if knob_row(ctx, trans_knobs, state, pad_index, pad_data) then
    changed = true
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- ROUTING
  -- ========================================================================

  section_header(ctx, 'ROUTING')

  -- Kill Group
  do
    local kg_items = { 'None', 'Group 1', 'Group 2', 'Group 3', 'Group 4', 'Group 5', 'Group 6', 'Group 7', 'Group 8' }
    local kg_changed, new_kg = labeled_combo(ctx, 'Kill', pad_data.kill_group or 0, kg_items)
    if kg_changed then
      state.setPadKillGroup(pad_index, new_kg)
      changed = true
    end
  end

  -- Output Group
  do
    local og_items = { 'Main', 'Kicks', 'Snares', 'HiHats', 'Perc', 'Group 5', 'Group 6', 'Group 7', 'Group 8' }
    local og_changed, new_og = labeled_combo(ctx, 'Output', pad_data.output_group or 0, og_items)
    if og_changed then
      state.setPadOutputGroup(pad_index, new_og)
      changed = true
    end
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- PLAYBACK OPTIONS
  -- ========================================================================

  section_header(ctx, 'PLAYBACK')

  -- Playback mode combo
  do
    local mode = pad_data.playback_mode or 'oneshot'
    local mode_idx = ({ oneshot = 0, loop = 1, pingpong = 2 })[mode] or 0
    local mode_changed, new_idx = ImGui.Combo(ctx, 'Mode', mode_idx, 'One-Shot\000Loop\000Ping-Pong\000')
    if mode_changed then
      local new_mode = ({ [0] = 'oneshot', [1] = 'loop', [2] = 'pingpong' })[new_idx]
      pad_data.playback_mode = new_mode
      if state.hasDrumBlocks() then
        Bridge.setPlaybackMode(state.getTrack(), state.getFxIndex(), pad_index, new_mode)
      end
      changed = true
    end
  end

  ImGui.SameLine(ctx)

  -- Reverse checkbox
  do
    local rev_changed, new_rev = ImGui.Checkbox(ctx, 'Reverse', pad_data.reverse or false)
    if rev_changed then
      pad_data.reverse = new_rev
      if state.hasDrumBlocks() then
        Bridge.setReverse(state.getTrack(), state.getFxIndex(), pad_index, new_rev)
      end
      changed = true
    end
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- TRIGGER BUTTONS
  -- ========================================================================

  local button_w = (width - 24) / 2

  if ImGui.Button(ctx, 'Trigger', button_w, 28) then
    if state.hasDrumBlocks() then
      Bridge.previewPad(state.getTrack(), state.getFxIndex(), pad_index, 100)
    end
  end

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, 'Stop', button_w, 28) then
    if state.hasDrumBlocks() then
      Bridge.stopPad(state.getTrack(), state.getFxIndex(), pad_index)
    end
  end

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- SAMPLE OPERATIONS
  -- ========================================================================

  if ImGui.Button(ctx, 'Load Sample...', width - 16, 24) then
    local retval, filename = reaper.GetUserFileNameForRead('', 'Load Sample', 'wav;mp3;ogg;flac;aif;aiff')
    if retval and filename ~= '' then
      state.setPadSample(pad_index, 0, filename)
      changed = true
    end
  end

  if has_sample then
    if ImGui.Button(ctx, 'Clear Sample', width - 16, 24) then
      state.setPadSample(pad_index, 0, '')
      changed = true
    end
  end

  ImGui.EndChild(ctx)

  return {
    width = width,
    height = ImGui.GetCursorPosY(ctx),
    changed = changed,
  }
end

return M
