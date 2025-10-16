local M = {}

function M.new()
  return {
    disabled_audio = {},
    disabled_midi = {},
  }
end

function M.is_disabled_audio(disabled, filename)
  return disabled.disabled_audio[filename] == true
end

function M.is_disabled_midi(disabled, track_idx)
  return disabled.disabled_midi[track_idx] == true
end

function M.toggle_audio(disabled, filename)
  if disabled.disabled_audio[filename] then
    disabled.disabled_audio[filename] = nil
  else
    disabled.disabled_audio[filename] = true
  end
end

function M.toggle_midi(disabled, track_idx)
  if disabled.disabled_midi[track_idx] then
    disabled.disabled_midi[track_idx] = nil
  else
    disabled.disabled_midi[track_idx] = true
  end
end

function M.clear_audio(disabled)
  disabled.disabled_audio = {}
end

function M.clear_midi(disabled)
  disabled.disabled_midi = {}
end

function M.clear_all(disabled)
  disabled.disabled_audio = {}
  disabled.disabled_midi = {}
end

function M.get_disabled_count(disabled)
  local audio_count = 0
  local midi_count = 0
  
  for _ in pairs(disabled.disabled_audio) do
    audio_count = audio_count + 1
  end
  
  for _ in pairs(disabled.disabled_midi) do
    midi_count = midi_count + 1
  end
  
  return audio_count, midi_count
end

return M