-- @noindex
-- ThemeAdjuster/ui/views/debug_view.lua
-- Debug tab with theme info and image browser

local ImGui = require 'imgui' '0.10'
local TilesContainer = require('arkitekt.gui.widgets.containers.panel')
local Theme = require('ThemeAdjuster.core.theme')
local ImageCache = require('arkitekt.core.images')  -- Use ARKITEKT's central image system
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}
local DebugView = {}
DebugView.__index = DebugView

function M.new(State, AppConfig, settings)
  local self = setmetatable({
    State = State,
    Config = AppConfig,
    settings = settings,
    container = nil,

    -- Image browser state
    img_dir = nil,
    image_list = {},
    total_images = 0,
    preview_size = settings and settings:get('debug_preview_size', 96) or 96,
    page_size = settings and settings:get('debug_page_size', 120) or 120,
    page_index = settings and settings:get('debug_page_index', 1) or 1,
    recursive = settings and settings:get('debug_recursive', true) or true,
    filter_text = settings and settings:get('debug_filter', "") or "",

    -- Image cache
    image_cache = nil,
    first_draw = true,
  }, DebugView)

  -- Initialize image cache using ARKITEKT's system
  -- Use moderate budget (12 images per frame) for progressive loading without UI freeze
  self.image_cache = ImageCache.new({ budget = 12, no_crop = true })

  -- Create container (Panel) with header
  local container_config = self:create_container_config()
  self.container = TilesContainer.new({
    id = "debug_container",
    config = container_config,
  })

  return self
end

function DebugView:create_container_config()
  return {
    header = {
      enabled = true,
      height = 32,
      elements = {
        {
          id = "rescan_images",
          type = "button",
          width = 120,
          spacing_before = 0,
          config = {
            label = "Rescan Images",
            on_click = function()
              self.img_dir = Theme.prepare_images(true)
              if self.img_dir then
                self:fetch_image_list()  -- This will clear cache automatically
              end
            end,
          },
        },
        {
          id = "reload_theme",
          type = "button",
          width = 150,
          spacing_before = 0,
          config = {
            label = "Reload in REAPER",
            on_click = function()
              Theme.reload_theme_in_reaper()
              self.image_list = {}
              self.total_images = 0
              self.img_dir = Theme.prepare_images(false)
              if self.img_dir then
                self:fetch_image_list()  -- This will clear cache automatically
              end
            end,
          },
        },
        {
          id = "filter",
          type = "search_field",
          width = 200,
          spacing_before = 0,
          config = {
            placeholder = "Filter images...",
            on_change = function(text)
              self.filter_text = text
              if self.settings then self.settings:set('debug_filter', text) end
              self.page_index = 1
              self:fetch_image_list()
            end,
          },
        },
        {
          id = "recursive",
          type = "checkbox",
          width = 85,
          spacing_before = 0,
          config = {
            label = "Recursive",
            checked = self.recursive,
            on_change = function(value)
              self.recursive = value
              if self.settings then self.settings:set('debug_recursive', value) end
              self.page_index = 1
              self:fetch_image_list()
            end,
          },
        },
        {
          id = "spacer1",
          type = "separator",
          flex = 1,
          spacing_before = 0,
          config = { show_line = false },
        },
        {
          id = "prev_page",
          type = "button",
          width = 70,
          spacing_before = 0,
          config = {
            label = "<< Prev",
            on_click = function()
              -- Only navigate if not already at first page
              if self.page_index > 1 then
                self.page_index = self.page_index - 1
                if self.settings then self.settings:set('debug_page_index', self.page_index) end
                -- Clear cache to avoid invalid image handle errors
                if self.image_cache then self.image_cache:clear() end
              end
            end,
          },
        },
        {
          id = "next_page",
          type = "button",
          width = 70,
          spacing_before = 0,
          config = {
            label = "Next >>",
            on_click = function()
              local total_pages = self:get_total_pages()
              -- Only navigate if not already at last page
              if self.page_index < total_pages then
                self.page_index = self.page_index + 1
                if self.settings then self.settings:set('debug_page_index', self.page_index) end
                -- Clear cache to avoid invalid image handle errors
                if self.image_cache then self.image_cache:clear() end
              end
            end,
          },
        },
      },
    },
  }
end

function DebugView:fetch_image_list()
  if not self.img_dir then
    self.image_list = {}
    self.total_images = 0
    self.page_index = 1
    return
  end

  local prefetch_count = math.max(1, self.page_size) * 10
  local list, total = Theme.sample_images(self.img_dir, prefetch_count, {
    recursive = self.recursive,
    filter = self.filter_text
  })

  self.image_list = list or {}
  self.total_images = total or 0

  if self.page_index < 1 then
    self.page_index = 1
  end

  if self.image_cache then
    self.image_cache:clear()
  end
end

function DebugView:get_total_pages()
  local shown = #self.image_list
  if shown == 0 then return 1 end
  return math.max(1, math.ceil(shown / math.max(1, self.page_size)))
end

function DebugView:get_page_bounds()
  local N = #self.image_list
  if N == 0 then return 0, -1 end
  local a = (self.page_index - 1) * self.page_size + 1
  local b = math.min(a + self.page_size - 1, N)
  return a, b
end

function DebugView:draw_theme_info(ctx)
  local info = Theme.get_theme_info()
  local status, dir, zip_name = Theme.get_status()

  ImGui.Text(ctx, 'Theme:')
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, hexrgb("#FFFFFF"), info.theme_name or 'Unknown')

  ImGui.BulletText(ctx, ('Path: %s'):format(info.theme_path or '—'))
  ImGui.BulletText(ctx, ('Type: %s'):format(info.theme_ext or '—'))
  ImGui.BulletText(ctx, ('REAPER: %s'):format(info.reaper_ver or '—'))

  ImGui.Separator(ctx)

  -- Status display with color coding
  ImGui.Text(ctx, 'Status: ')
  ImGui.SameLine(ctx)

  if status == 'direct' and dir then
    ImGui.TextColored(ctx, hexrgb("#41E0A3"), ('READY - Direct: %s'):format(dir))
  elseif (status == 'linked-ready' or status == 'zip-ready') and dir then
    local msg = zip_name and ('READY - ZIP Cache: %s'):format(zip_name) or ('READY - ZIP Cache: %s'):format(dir)
    ImGui.TextColored(ctx, hexrgb("#E0B341"), msg)
  elseif status == 'linked-needs-build' then
    local msg = zip_name and ('LINKED - Build needed: %s'):format(zip_name) or 'LINKED - Build cache to continue'
    ImGui.TextColored(ctx, hexrgb("#E0B341"), msg)
  elseif status == 'needs-link' then
    ImGui.TextColored(ctx, hexrgb("#E04141"), 'NOT LINKED - Pick a .ReaperThemeZip to continue')
  else
    ImGui.TextColored(ctx, hexrgb("#E04141"), 'ERROR - Check theme status')
  end

  ImGui.Separator(ctx)

  -- Statistics
  local shown = #self.image_list
  local total_pages = self:get_total_pages()

  ImGui.BulletText(ctx, ('Image Dir: %s'):format(self.img_dir or '—'))
  ImGui.BulletText(ctx, ('Listed: %d / Total PNGs: %d — Page %d / %d'):format(
    shown, self.total_images, self.page_index, total_pages
  ))
end

function DebugView:draw_image_grid(ctx)
  local shown = #self.image_list
  if shown == 0 then
    ImGui.Text(ctx, 'No images found.')
    return
  end

  local cell = math.max(48, self.preview_size)
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local cols = math.max(1, math.floor(avail_w / (cell + 12)))

  -- Use simple table flags that are guaranteed to exist
  local table_flags = 0  -- No special flags needed for simple grid

  if ImGui.BeginTable(ctx, 'debug_img_grid', cols, table_flags) then
    local a, b = self:get_page_bounds()
    local idx = 0

    for i = a, b do
      local path = self.image_list[i]
      if not path then break end

      if idx % cols == 0 then
        ImGui.TableNextRow(ctx)
      end
      ImGui.TableNextColumn(ctx)

      -- Draw thumbnail
      if self.image_cache then
        self.image_cache:draw_thumb(ctx, path, cell)
      end

      -- Tooltip
      if ImGui.IsItemHovered(ctx) then
        local name = path:match("[^\\/]+$") or path
        ImGui.SetTooltip(ctx, name)
      end

      -- Filename label
      local name = path:match("[^\\/]+$") or path
      -- Truncate if too long
      if #name > 30 then
        name = name:sub(1, 27) .. "..."
      end
      ImGui.Text(ctx, name)

      idx = idx + 1
    end

    ImGui.EndTable(ctx)
  end
end

function DebugView:update(dt)
  -- No animations currently
end

function DebugView:draw(ctx, shell_state)
  -- First-time initialization
  if self.first_draw then
    self.first_draw = false
    if not self.img_dir then
      self.img_dir = Theme.prepare_images(false)
      if self.img_dir then
        self:fetch_image_list()
      end
    end
  end

  -- Begin frame for image cache budget
  if self.image_cache then
    self.image_cache:begin_frame()
  end

  self:draw_theme_info(ctx)

  ImGui.Separator(ctx)

  -- Begin container (Panel)
  if self.container:begin_draw(ctx) then
    self:draw_image_grid(ctx)
  end
  self.container:end_draw(ctx)
end

return M
