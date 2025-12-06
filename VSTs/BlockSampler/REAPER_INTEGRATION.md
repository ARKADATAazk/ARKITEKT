# BlockSampler REAPER Integration

> Lua/ReaScript patterns for extending BlockSampler with REAPER's audio processing.

The VST handles real-time playback. REAPER handles offline processing. This separation keeps the VST lean while leveraging REAPER's powerful audio engine.

---

## Table of Contents

1. [Time-Stretching](#time-stretching)
2. [Pitch Detection](#pitch-detection)
3. [Transient Detection & Auto-Slicing](#transient-detection--auto-slicing)
4. [Normalization & Loudness](#normalization--loudness)
5. [Sample Rate Conversion](#sample-rate-conversion)
6. [Batch Processing](#batch-processing)
7. [Named Config Params Reference](#named-config-params-reference)

---

## Time-Stretching

REAPER has world-class time-stretch algorithms (élastique). Use them instead of implementing in the VST.

### Stretch Modes

| Mode | Constant | Best For |
|------|----------|----------|
| élastique Pro | `0x70000` | General purpose, drums |
| élastique Efficient | `0x60000` | CPU-light, live |
| élastique SOLOIST | `0x80000` | Monophonic, vocals |
| Rubber Band | `0x50000` | Alternative algo |

### Offline Stretch via Take

```lua
-- Stretch a sample file using REAPER's engine
-- Returns path to stretched file (cached)
function BlockSampler_StretchSample(inputPath, stretchRatio, pitchMode)
    pitchMode = pitchMode or 0x70000  -- élastique Pro default

    if stretchRatio == 1.0 then
        return inputPath  -- No change needed
    end

    -- Generate cache path
    local cacheDir = reaper.GetProjectPath() .. "/BlockSampler_Cache/"
    reaper.RecursiveCreateDirectory(cacheDir, 0)

    local filename = inputPath:match("([^/\\]+)$")
    local cacheName = string.format("%s_x%.3f.wav", filename:gsub("%.[^.]+$", ""), stretchRatio)
    local cachePath = cacheDir .. cacheName

    -- Check cache
    if reaper.file_exists(cachePath) then
        return cachePath
    end

    -- Create temp track and item
    local trackIdx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(trackIdx, false)
    local tempTrack = reaper.GetTrack(0, trackIdx)

    -- Insert media
    reaper.SetOnlyTrackSelected(tempTrack)
    reaper.InsertMedia(inputPath, 0)  -- 0 = current track

    local item = reaper.GetTrackMediaItem(tempTrack, 0)
    local take = reaper.GetActiveTake(item)

    if not take then
        reaper.DeleteTrack(tempTrack)
        return nil
    end

    -- Apply stretch (playrate is inverse of stretch ratio)
    -- stretchRatio 2.0 = twice as long = playrate 0.5
    reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", 1.0 / stretchRatio)
    reaper.SetMediaItemTakeInfo_Value(take, "I_PITCHMODE", pitchMode)
    reaper.SetMediaItemTakeInfo_Value(take, "B_PPITCH", 1)  -- Preserve pitch

    -- Update item length to match stretched audio
    local srcLength = reaper.GetMediaSourceLength(reaper.GetMediaItemTake_Source(take))
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", srcLength * stretchRatio)

    -- Render to new file
    local renderOK = BlockSampler_RenderItemToFile(item, cachePath)

    -- Cleanup
    reaper.DeleteTrack(tempTrack)

    return renderOK and cachePath or nil
end

-- Helper: Render item to file
function BlockSampler_RenderItemToFile(item, outputPath)
    -- Select only this item
    reaper.SelectAllMediaItems(0, false)
    reaper.SetMediaItemSelected(item, true)

    -- Store render settings
    local oldBounds = reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, false)
    local oldFile = reaper.GetSetProjectInfo_String(0, "RENDER_FILE", "", false)
    local oldPattern = reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "", false)

    -- Set render to selected items
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 4, true)  -- Selected items

    local dir = outputPath:match("(.+)[/\\]")
    local file = outputPath:match("([^/\\]+)$"):gsub("%.wav$", "")

    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", dir, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", file, true)

    -- Render
    reaper.Main_OnCommand(42230, 0)  -- Render project using last settings

    -- Restore settings
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", oldBounds, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", oldFile, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", oldPattern, true)

    return reaper.file_exists(outputPath)
end
```

### Integration with BlockSampler

```lua
-- Stretch pad sample and reload
function DrumBlocks_StretchPad(fx, padIndex, stretchRatio)
    local paramName = string.format("P%d_L0_SAMPLE", padIndex)
    local currentPath = BlockSampler_GetNamedParam(fx, paramName)

    if currentPath == "" then return false end

    local stretchedPath = BlockSampler_StretchSample(currentPath, stretchRatio)
    if stretchedPath then
        BlockSampler_SetNamedParam(fx, paramName, stretchedPath)
        return true
    end
    return false
end
```

---

## Pitch Detection

Detect the pitch/key of a sample for auto-tuning or display.

```lua
-- Analyze pitch using ReaTune or built-in detection
function BlockSampler_DetectPitch(filePath)
    local source = reaper.PCM_Source_CreateFromFile(filePath)
    if not source then return nil end

    local sampleRate = reaper.GetMediaSourceSampleRate(source)
    local length = reaper.GetMediaSourceLength(source)

    -- Create accessor for reading samples
    local accessor = reaper.CreateTakeAudioAccessor(source)

    -- Read samples (first 4096 for quick analysis)
    local bufferSize = 4096
    local buffer = reaper.new_array(bufferSize)
    reaper.GetAudioAccessorSamples(accessor, sampleRate, 1, 0, bufferSize, buffer)

    -- Simple zero-crossing pitch detection
    local crossings = 0
    local lastSample = buffer[1]
    for i = 2, bufferSize do
        local sample = buffer[i]
        if (lastSample >= 0 and sample < 0) or (lastSample < 0 and sample >= 0) then
            crossings = crossings + 1
        end
        lastSample = sample
    end

    local duration = bufferSize / sampleRate
    local frequency = (crossings / 2) / duration

    reaper.DestroyAudioAccessor(accessor)
    reaper.PCM_Source_Destroy(source)

    -- Convert to note name
    local noteNum = 12 * math.log(frequency / 440) / math.log(2) + 69
    local noteNames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    local noteName = noteNames[(math.floor(noteNum + 0.5) % 12) + 1]
    local octave = math.floor((noteNum + 0.5) / 12) - 1

    return {
        frequency = frequency,
        note = noteName,
        octave = octave,
        midiNote = math.floor(noteNum + 0.5),
        cents = (noteNum % 1) * 100  -- Cents offset from nearest note
    }
end
```

---

## Transient Detection & Auto-Slicing

Use REAPER's transient detection to auto-slice samples to pads.

```lua
-- Detect transients in a sample
function BlockSampler_DetectTransients(filePath, sensitivity)
    sensitivity = sensitivity or 0.5  -- 0-1, higher = more transients

    -- Create temp item for analysis
    local trackIdx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(trackIdx, false)
    local tempTrack = reaper.GetTrack(0, trackIdx)

    reaper.SetOnlyTrackSelected(tempTrack)
    reaper.InsertMedia(filePath, 0)

    local item = reaper.GetTrackMediaItem(tempTrack, 0)
    local take = reaper.GetActiveTake(item)

    -- Use dynamic split to detect transients
    -- Action 40513 = Dynamic split items
    reaper.SetMediaItemSelected(item, true)

    -- Configure transient sensitivity via project settings
    -- (This is a simplified version - real implementation would use
    -- reaper.GetSetMediaTrackInfo_String for transient detection settings)

    local transients = {}
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    -- Get stretch markers (includes transients after detection)
    local smCount = reaper.GetTakeNumStretchMarkers(take)
    for i = 0, smCount - 1 do
        local pos = reaper.GetTakeStretchMarker(take, i)
        table.insert(transients, pos)
    end

    -- Cleanup
    reaper.DeleteTrack(tempTrack)

    return transients
end

-- Auto-slice loop to pads
function DrumBlocks_SliceToPads(fx, filePath, startPad, maxSlices)
    maxSlices = maxSlices or 16
    startPad = startPad or 0

    local transients = BlockSampler_DetectTransients(filePath)
    local source = reaper.PCM_Source_CreateFromFile(filePath)
    local totalLength = reaper.GetMediaSourceLength(source)
    reaper.PCM_Source_Destroy(source)

    -- Add end point
    table.insert(transients, totalLength)

    local sliceCount = math.min(#transients, maxSlices)

    for i = 1, sliceCount do
        local sliceStart = transients[i] or 0
        local sliceEnd = transients[i + 1] or totalLength

        -- Render slice
        local slicePath = BlockSampler_RenderSlice(filePath, sliceStart, sliceEnd)

        -- Load to pad
        local padIdx = startPad + i - 1
        if padIdx < 128 then
            local paramName = string.format("P%d_L0_SAMPLE_ASYNC", padIdx)
            BlockSampler_SetNamedParam(fx, paramName, slicePath)
        end
    end

    return sliceCount
end
```

---

## Normalization & Loudness

REAPER-side loudness analysis and normalization.

```lua
-- Analyze loudness (peak and RMS)
function BlockSampler_AnalyzeLoudness(filePath)
    local source = reaper.PCM_Source_CreateFromFile(filePath)
    if not source then return nil end

    local sampleRate = reaper.GetMediaSourceSampleRate(source)
    local length = reaper.GetMediaSourceLength(source)
    local numSamples = math.floor(length * sampleRate)
    local numChannels = reaper.GetMediaSourceNumChannels(source)

    local accessor = reaper.CreateTakeAudioAccessor(source)

    local peak = 0
    local sumSquares = 0
    local chunkSize = 8192
    local buffer = reaper.new_array(chunkSize * numChannels)

    local pos = 0
    while pos < numSamples do
        local toRead = math.min(chunkSize, numSamples - pos)
        reaper.GetAudioAccessorSamples(accessor, sampleRate, numChannels, pos / sampleRate, toRead, buffer)

        for i = 1, toRead * numChannels do
            local sample = math.abs(buffer[i])
            peak = math.max(peak, sample)
            sumSquares = sumSquares + sample * sample
        end

        pos = pos + toRead
    end

    reaper.DestroyAudioAccessor(accessor)
    reaper.PCM_Source_Destroy(source)

    local rms = math.sqrt(sumSquares / (numSamples * numChannels))

    return {
        peak = peak,
        peakDb = 20 * math.log10(peak + 1e-10),
        rms = rms,
        rmsDb = 20 * math.log10(rms + 1e-10),
        crestFactor = peak / (rms + 1e-10),
        normGain = 1.0 / (peak + 1e-10)  -- Gain to normalize to 0dB
    }
end

-- Apply offline normalization (renders new file)
function BlockSampler_NormalizeSample(filePath, targetPeakDb)
    targetPeakDb = targetPeakDb or 0

    local analysis = BlockSampler_AnalyzeLoudness(filePath)
    if not analysis then return nil end

    local gainDb = targetPeakDb - analysis.peakDb

    if math.abs(gainDb) < 0.1 then
        return filePath  -- Already normalized
    end

    -- Create temp item, apply gain, render
    local trackIdx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(trackIdx, false)
    local tempTrack = reaper.GetTrack(0, trackIdx)

    reaper.SetOnlyTrackSelected(tempTrack)
    reaper.InsertMedia(filePath, 0)

    local item = reaper.GetTrackMediaItem(tempTrack, 0)

    -- Apply gain to item
    local gainLinear = 10 ^ (gainDb / 20)
    reaper.SetMediaItemInfo_Value(item, "D_VOL", gainLinear)

    -- Render
    local cacheDir = reaper.GetProjectPath() .. "/BlockSampler_Cache/"
    local filename = filePath:match("([^/\\]+)$"):gsub("%.%w+$", "")
    local outputPath = cacheDir .. filename .. "_norm.wav"

    BlockSampler_RenderItemToFile(item, outputPath)

    reaper.DeleteTrack(tempTrack)

    return outputPath
end
```

---

## Sample Rate Conversion

Convert samples to project sample rate using REAPER's resamplers.

```lua
-- Get available resampling modes
function BlockSampler_GetResampleModes()
    local modes = {}
    local idx = 0
    while true do
        local name = reaper.Resample_EnumModes(idx)
        if not name or name == "" then break end
        table.insert(modes, { index = idx, name = name })
        idx = idx + 1
    end
    return modes
end

-- Resample file to target sample rate
function BlockSampler_Resample(filePath, targetRate, mode)
    mode = mode or 4  -- High quality default

    local source = reaper.PCM_Source_CreateFromFile(filePath)
    local sourceRate = reaper.GetMediaSourceSampleRate(source)
    reaper.PCM_Source_Destroy(source)

    if sourceRate == targetRate then
        return filePath  -- Already at target rate
    end

    -- Use REAPER render with target sample rate
    -- (Implementation similar to stretch, but adjusting project render settings)

    local cacheDir = reaper.GetProjectPath() .. "/BlockSampler_Cache/"
    local filename = filePath:match("([^/\\]+)$"):gsub("%.%w+$", "")
    local outputPath = string.format("%s%s_%dHz.wav", cacheDir, filename, targetRate)

    -- Store and set render sample rate
    local oldRate = reaper.GetSetProjectInfo(0, "RENDER_SRATE", 0, false)
    reaper.GetSetProjectInfo(0, "RENDER_SRATE", targetRate, true)

    -- Create temp item and render
    local trackIdx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(trackIdx, false)
    local tempTrack = reaper.GetTrack(0, trackIdx)

    reaper.SetOnlyTrackSelected(tempTrack)
    reaper.InsertMedia(filePath, 0)

    local item = reaper.GetTrackMediaItem(tempTrack, 0)
    BlockSampler_RenderItemToFile(item, outputPath)

    -- Cleanup
    reaper.DeleteTrack(tempTrack)
    reaper.GetSetProjectInfo(0, "RENDER_SRATE", oldRate, true)

    return outputPath
end
```

---

## Batch Processing

Process multiple samples efficiently.

```lua
-- Batch process samples with a custom function
function BlockSampler_BatchProcess(filePaths, processFunc, progressCallback)
    local results = {}
    local total = #filePaths

    for i, path in ipairs(filePaths) do
        if progressCallback then
            progressCallback(i, total, path)
        end

        local ok, result = pcall(processFunc, path)
        table.insert(results, {
            input = path,
            output = ok and result or nil,
            error = not ok and result or nil
        })

        -- Yield to REAPER UI periodically
        if i % 5 == 0 then
            reaper.defer(function() end)
        end
    end

    return results
end

-- Example: Batch normalize and load to pads
function DrumBlocks_BatchLoadNormalized(fx, filePaths, startPad)
    startPad = startPad or 0

    local results = BlockSampler_BatchProcess(filePaths, function(path)
        return BlockSampler_NormalizeSample(path, -1)  -- -1 dB peak
    end)

    for i, result in ipairs(results) do
        if result.output then
            local padIdx = startPad + i - 1
            if padIdx < 128 then
                local paramName = string.format("P%d_L0_SAMPLE_ASYNC", padIdx)
                BlockSampler_SetNamedParam(fx, paramName, result.output)
            end
        end
    end

    return results
end
```

---

## Named Config Params Reference

Communication between Lua and BlockSampler VST.

### Sample Loading

| Param | Format | Description |
|-------|--------|-------------|
| `P{n}_L{l}_SAMPLE` | path | Sync load sample to pad n, layer l |
| `P{n}_L{l}_SAMPLE_ASYNC` | path | Async load (non-blocking) |
| `P{n}_L{l}_RR_ASYNC` | path | Add round-robin sample |
| `P{n}_L{l}_CLEAR_RR` | any | Clear round-robin samples |
| `P{n}_CLEAR` | any | Clear all layers on pad |

### Queries

| Param | Returns | Description |
|-------|---------|-------------|
| `P{n}_L{l}_SAMPLE` | path | Get sample path |
| `P{n}_L{l}_RR_COUNT` | int | Round-robin count |
| `P{n}_L{l}_DURATION` | float | Sample duration (seconds) |
| `P{n}_HAS_SAMPLE` | 0/1 | Any layer loaded? |
| `P{n}_IS_PLAYING` | 0/1 | Currently playing? |

### Playback Control

| Param | Value | Description |
|-------|-------|-------------|
| `P{n}_PREVIEW` | 1-127 | Trigger pad with velocity |
| `P{n}_STOP` | any | Stop pad immediately (hard cut) |
| `P{n}_RELEASE` | any | Trigger release phase (graceful fade-out) |
| `STOP_ALL` | any | Stop all pads |

### Helper Functions

```lua
-- Get/Set named config params
function BlockSampler_GetNamedParam(fx, name)
    local track = reaper.GetTrack(0, 0)  -- Adjust as needed
    local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, name)
    return retval and value or ""
end

function BlockSampler_SetNamedParam(fx, name, value)
    local track = reaper.GetTrack(0, 0)  -- Adjust as needed
    return reaper.TrackFX_SetNamedConfigParm(track, fx, name, tostring(value))
end
```

---

## Cache Management

```lua
-- Get cache directory
function BlockSampler_GetCacheDir()
    local dir = reaper.GetProjectPath() .. "/BlockSampler_Cache/"
    reaper.RecursiveCreateDirectory(dir, 0)
    return dir
end

-- Clear old cache files (older than N days)
function BlockSampler_CleanCache(maxAgeDays)
    maxAgeDays = maxAgeDays or 7
    local cacheDir = BlockSampler_GetCacheDir()
    local now = os.time()
    local maxAge = maxAgeDays * 24 * 60 * 60

    local i = 0
    while true do
        local file = reaper.EnumerateFiles(cacheDir, i)
        if not file then break end

        local path = cacheDir .. file
        local modTime = reaper.GetFileModTime(path) -- Custom helper needed

        if now - modTime > maxAge then
            os.remove(path)
        end
        i = i + 1
    end
end
```

---

## Performance Notes

1. **Always use async loading** (`_ASYNC` params) during playback
2. **Cache stretched/processed files** - don't re-process on every load
3. **Batch operations** with `defer()` to keep UI responsive
4. **Clean cache periodically** to avoid disk bloat
5. **Use temp tracks** for processing, delete when done

---

## See Also

- [README.md](README.md) - VST overview
- [ARCHITECTURE.md](ARCHITECTURE.md) - VST internals
- [FEATURES.md](FEATURES.md) - Feature list
