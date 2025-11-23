-- packages/metadata.lua
-- Utility for querying REAPER image metadata
-- Used for auto-tagging packages and providing tooltips

local M = {}

-- Image metadata embedded directly (no JSON parsing needed)
local IMAGE_DATA = {
  -- Global UI elements
  button_off = {area="global"}, button_on = {area="global"},
  scrollbar_v = {area="global"}, slider = {area="global"},
  spinner_left = {area="global"}, vEdge_resize = {area="global"},
  page_ol_off = {area="global"}, page_ol_on = {area="global"},
  col_chooser = {area="global"}, swatch = {area="global"},
  arcStalk = {area="global"}, arcStalk_closed = {area="global"},
  font_size_stack = {area="global"}, knobStack_20px_dark = {area="global"},
  roundBox_white25 = {area="global"}, hide = {area="global"},
  show = {area="global"}, always_hide = {area="global"},
  always_hide_on = {area="global"}, monitorScale = {area="global"},
  page_global = {area="global"}, page_tcp = {area="global"},
  page_envcp = {area="global"}, page_mcp = {area="global"},
  page_trans = {area="global"}, page_theme = {area="global"},
  page_error = {area="global"}, layoutA_off = {area="global"},
  layoutA_on = {area="global"}, layoutB_off = {area="global"},
  layoutB_on = {area="global"}, layoutC_off = {area="global"},
  layoutC_on = {area="global"},

  -- Backgrounds
  tcp_bg = {area="tcp"}, mcp_bg = {area="mcp"},
  envcp_bg = {area="envcp"}, transport_bg = {area="transport"},

  -- Knobs
  tcp_vol_knob = {area="tcp"}, tcp_pan_knob = {area="tcp"},
  tcp_width_knob = {area="tcp"}, mcp_vol_knob = {area="mcp"},
  mcp_pan_knob = {area="mcp"}, mcp_width_knob = {area="mcp"},

  -- TCP buttons
  tcp_mute = {area="tcp"}, tcp_solo = {area="tcp"},
  tcp_fx = {area="tcp"}, tcp_env = {area="tcp"},
  tcp_io = {area="tcp"}, tcp_phase = {area="tcp"},
  tcp_recarm = {area="tcp"}, tcp_recmon = {area="tcp"},

  -- MCP buttons
  mcp_mute = {area="mcp"}, mcp_solo = {area="mcp"},
  mcp_fx = {area="mcp"}, mcp_env = {area="mcp"},
  mcp_io = {area="mcp"}, mcp_phase = {area="mcp"},
  mcp_recarm = {area="mcp"}, mcp_recmon = {area="mcp"},

  -- Toolbar
  toolbar_bg = {area="toolbar"}, toolbar_button = {area="toolbar"},
  toolbar_dropdown = {area="toolbar"}, toolbar_blank = {area="toolbar"},
  toolbar_envitem_off = {area="toolbar"}, toolbar_envitem_on = {area="toolbar"},
  toolbar_lock_on = {area="toolbar"}, toolbar_lock_off = {area="toolbar"},
  toolbar_load = {area="toolbar"}, toolbar_save = {area="toolbar"},

  -- Meter
  meter_bg = {area="meter"}, meter_clip = {area="meter"},
  meter_fill = {area="meter"}, meter_automute = {area="meter"},
  meter_bg_h = {area="meter"}, meter_bg_mcp = {area="meter"},
  meter_bg_mcp_master = {area="meter"}, meter_bg_tcp = {area="meter"},
  meter_bg_v = {area="meter"}, meter_clip_h = {area="meter"},
  meter_clip_h_rms = {area="meter"}, meter_clip_v = {area="meter"},
  meter_clip_v_rms = {area="meter"}, meter_clip_v_rms2 = {area="meter"},
  meter_foldermute = {area="meter"}, meter_mute = {area="meter"},
  meter_ol_h = {area="meter"}, meter_ol_mcp = {area="meter"},
  meter_ol_mcp_master = {area="meter"}, meter_ol_tcp = {area="meter"},
  meter_ol_v = {area="meter"}, meter_solodim = {area="meter"},
  meter_strip_h = {area="meter"}, meter_strip_h_gr = {area="meter"},
  meter_strip_h_rms = {area="meter"}, meter_strip_v = {area="meter"},
  meter_strip_v_gr = {area="meter"}, meter_strip_v_rms = {area="meter"},
  meter_unsolo = {area="meter"}, vu_indicator = {area="meter"},

  -- Transport
  transport_play = {area="transport"}, transport_stop = {area="transport"},
  transport_pause = {area="transport"}, transport_rec = {area="transport"},
  transport_rew = {area="transport"}, transport_fwd = {area="transport"},
  transport_repeat = {area="transport"}, transport_basis_half = {area="transport"},
  transport_basis_half_dotted = {area="transport"}, transport_basis_quarter = {area="transport"},
  transport_basis_quarter_dotted = {area="transport"}, transport_basis_eighth = {area="transport"},
  transport_basis_eighth_dotted = {area="transport"}, global_trim = {area="transport"},
  global_read = {area="transport"}, global_touch = {area="transport"},
  global_write = {area="transport"}, global_latch = {area="transport"},
  global_bypass = {area="transport"}, global_off = {area="transport"},
  global_preview = {area="transport"}, transport_tap = {area="transport"},
  transport_bpm = {area="transport"}, transport_bpm_bg = {area="transport"},
  transport_edit_bg = {area="transport"}, transport_end = {area="transport"},
  transport_group_bg = {area="transport"}, transport_knob_bg_large = {area="transport"},
  transport_knob_bg_small = {area="transport"}, transport_playspeedbg = {area="transport"},
  transport_playspeedbg_vert = {area="transport"}, transport_playspeedthumb = {area="transport"},
  transport_playspeedthumb_vert = {area="transport"}, transport_next = {area="transport"},
  transport_pause_on = {area="transport"}, transport_play_on = {area="transport"},
  transport_play_sync = {area="transport"}, transport_play_sync_on = {area="transport"},
  transport_previous = {area="transport"}, transport_record = {area="transport"},
  transport_record_on = {area="transport"}, transport_record_item = {area="transport"},
  transport_record_item_on = {area="transport"}, transport_record_loop = {area="transport"},
  transport_record_loop_on = {area="transport"}, transport_repeat_off = {area="transport"},
  transport_repeat_on = {area="transport"}, transport_home = {area="transport"},
  transport_status_bg = {area="transport"}, transport_status_bg_err = {area="transport"},

  -- EnvCP
  envcp_hide = {area="envcp"}, envcp_bypass = {area="envcp"},
  envcp_mod = {area="envcp"}, envcp_learn = {area="envcp"},
  envcp_arm_off = {area="envcp"}, envcp_arm_on = {area="envcp"},
  envcp_bgsel = {area="envcp"}, envcp_bypass_off = {area="envcp"},
  envcp_bypass_on = {area="envcp"}, envcp_faderbg = {area="envcp"},
  envcp_faderbg_vert = {area="envcp"}, envcp_fader = {area="envcp"},
  envcp_fader_vert = {area="envcp"}, envcp_knob_large = {area="envcp"},
  envcp_knob_small = {area="envcp"}, envcp_knob_stack = {area="envcp"},
  envcp_knob_stack_1 = {area="envcp"}, envcp_knob_stack_2 = {area="envcp"},
  envcp_learn_on = {area="envcp"}, envcp_namebg = {area="envcp"},
  envcp_parammod = {area="envcp"}, envcp_parammod_on = {area="envcp"},

  -- TCP detailed
  folder_start = {area="tcp"}, folder_indent = {area="tcp"}, folder_end = {area="tcp"},
  tcp_bgsel = {area="tcp"}, tcp_folderbg = {area="tcp"}, tcp_folderbgsel = {area="tcp"},
  tcp_fxembed_header_bg_h = {area="tcp"}, tcp_fxembed_header_bg_v = {area="tcp"},
  tcp_fxembed_header_float = {area="tcp"}, tcp_fxembed_header_minimize = {area="tcp"},
  tcp_fxlist_bg = {area="tcp"}, tcp_fxlist_byp = {area="tcp"},
  tcp_fxlist_empty = {area="tcp"}, tcp_fxlist_norm = {area="tcp"},
  tcp_fxlist_off = {area="tcp"}, tcp_fxparm_bg = {area="tcp"},
  tcp_fxparm_byp = {area="tcp"}, tcp_fxparm_empty = {area="tcp"},
  tcp_fxparm_fx_byp = {area="tcp"}, tcp_fxparm_fx_norm = {area="tcp"},
  tcp_fxparm_fx_off = {area="tcp"}, tcp_fxparm_knob = {area="tcp"},
  tcp_fxparm_knob_bg = {area="tcp"}, tcp_fxparm_knob_stack = {area="tcp"},
  tcp_fxparm_norm = {area="tcp"}, tcp_fxparm_off = {area="tcp"},
  tcp_iconbg = {area="tcp"}, tcp_iconbgsel = {area="tcp"},
  tcp_mainiconbg = {area="tcp"}, tcp_mainiconbgsel = {area="tcp"},
  tcp_mainbg = {area="tcp"}, tcp_mainbgsel = {area="tcp"},
  tcp_main_namebg = {area="tcp"}, tcp_main_namebg_sel = {area="tcp"},
  tcp_master_fxlist_bg = {area="tcp"}, tcp_master_fxlist_byp = {area="tcp"},
  tcp_master_fxlist_empty = {area="tcp"}, tcp_master_fxlist_norm = {area="tcp"},
  tcp_master_fxlist_off = {area="tcp"}, tcp_master_pan_label = {area="tcp"},
  tcp_master_sendlist_bg = {area="tcp"}, tcp_master_sendlist_empty = {area="tcp"},
  tcp_master_sendlist_knob = {area="tcp"}, tcp_master_sendlist_knob2 = {area="tcp"},
  tcp_master_sendlist_meter = {area="tcp"}, tcp_master_sendlist_meter2 = {area="tcp"},
  tcp_master_sendlist_mute = {area="tcp"}, tcp_master_sendlist_mute2 = {area="tcp"},
  tcp_master_sendlist_norm = {area="tcp"}, tcp_master_sendlist_norm2 = {area="tcp"},
  tcp_master_vol_label = {area="tcp"}, tcp_master_wid_label = {area="tcp"},
  tcp_namebg = {area="tcp"}, tcp_pan_knob_large = {area="tcp"},
  tcp_pan_knob_small = {area="tcp"}, tcp_pan_knob_stack = {area="tcp"},
  tcp_pan_knob_stack_1 = {area="tcp"}, tcp_pan_knob_stack_2 = {area="tcp"},
  tcp_pan_label = {area="tcp"}, tcp_panbg = {area="tcp"},
  tcp_panbg_vert = {area="tcp"}, tcp_panthumb = {area="tcp"},
  tcp_panthumb_vert = {area="tcp"}, tcp_pinned_divider = {area="tcp"},
  tcp_pinned_divider_overflow = {area="tcp"}, tcp_recinput = {area="tcp"},
  tcp_send_knob_stack = {area="tcp"}, tcp_send_knob_stack2 = {area="tcp"},
  tcp_sendlist_bg = {area="tcp"}, tcp_sendlist_empty = {area="tcp"},
  tcp_sendlist_knob = {area="tcp"}, tcp_sendlist_knob2 = {area="tcp"},
  tcp_sendlist_knob_bg = {area="tcp"}, tcp_sendlist_knob_bg2 = {area="tcp"},
  tcp_sendlist_meter = {area="tcp"}, tcp_sendlist_meter2 = {area="tcp"},
  tcp_sendlist_midihw = {area="tcp"}, tcp_sendlist_midihw2 = {area="tcp"},
  tcp_sendlist_mute = {area="tcp"}, tcp_sendlist_mute2 = {area="tcp"},
  tcp_sendlist_norm = {area="tcp"}, tcp_sendlist_norm2 = {area="tcp"},
  tcp_solodefeat_on = {area="tcp"}, tcp_idxbg = {area="tcp"},
  tcp_idxbg_sel = {area="tcp"}, tcp_vol_knob_large = {area="tcp"},
  tcp_vol_knob_small = {area="tcp"}, tcp_vol_knob_stack = {area="tcp"},
  tcp_vol_knob_stack_1 = {area="tcp"}, tcp_vol_knob_stack_2 = {area="tcp"},
  tcp_vol_label = {area="tcp"}, tcp_volbg = {area="tcp"},
  tcp_volbg_vert = {area="tcp"}, tcp_volthumb = {area="tcp"},
  tcp_volthumb_vert = {area="tcp"}, tcp_vu = {area="tcp"},
  tcp_width_knob_large = {area="tcp"}, tcp_width_knob_small = {area="tcp"},
  tcp_wid_knob_stack = {area="tcp"}, tcp_wid_knob_stack_1 = {area="tcp"},
  tcp_wid_knob_stack_2 = {area="tcp"}, tcp_wid_label = {area="tcp"},
  tcp_widthbg = {area="tcp"}, tcp_widthbg_vert = {area="tcp"},
  tcp_widththumb = {area="tcp"}, tcp_widththumb_vert = {area="tcp"},
  master_tcp_io = {area="tcp"},

  -- Track (shared TCP/MCP)
  track_env = {area="track"}, track_env_read = {area="track"},
  track_env_touch = {area="track"}, track_env_write = {area="track"},
  track_env_latch = {area="track"}, track_env_preview = {area="track"},
  track_folder_off = {area="track"}, track_folder_on = {area="track"},
  track_folder_last = {area="track"}, track_fcomp_off = {area="track"},
  track_fcomp_small = {area="track"}, track_fcomp_tiny = {area="track"},
  track_fx_norm = {area="track"}, track_fx_dis = {area="track"},
  track_fx_empty = {area="track"}, track_fx_in_norm = {area="track"},
  track_fx_in_empty = {area="track"}, track_fxoff_v = {area="track"},
  track_fxon_v = {area="track"}, track_fxempty_v = {area="track"},
  track_fxoff_h = {area="track"}, track_fxon_h = {area="track"},
  track_fxempty_h = {area="track"}, track_io = {area="track"},
  track_io_dis = {area="track"}, track_io_r = {area="track"},
  track_io_s = {area="track"}, track_io_s_r = {area="track"},
  track_io_r_dis = {area="track"}, track_io_s_dis = {area="track"},
  track_io_s_r_dis = {area="track"}, track_monitor_off = {area="track"},
  track_monitor_on = {area="track"}, track_monitor_auto = {area="track"},
  track_stereo = {area="track"}, track_mono = {area="track"},
  track_mute_off = {area="track"}, track_mute_on = {area="track"},
  track_phase_norm = {area="track"}, track_phase_inv = {area="track"},
  track_recarm_off = {area="track"}, track_recarm_on = {area="track"},
  track_recarm_auto = {area="track"}, track_recarm_auto_on = {area="track"},
  track_recarm_norec = {area="track"}, track_recarm_auto_norec = {area="track"},
  track_recmode_in = {area="track"}, track_recmode_out = {area="track"},
  track_recmode_off = {area="track"}, track_solo_off = {area="track"},
  track_solo_on = {area="track"},

  -- MCP detailed
  mcp_bgsel = {area="mcp"}, mcp_env_read = {area="mcp"},
  mcp_env_touch = {area="mcp"}, mcp_env_write = {area="mcp"},
  mcp_env_latch = {area="mcp"}, mcp_env_preview = {area="mcp"},
  mcp_extmixbg = {area="mcp"}, mcp_extmixbgsel = {area="mcp"},
  mcp_mainextmixbg = {area="mcp"}, mcp_mainextmixbgsel = {area="mcp"},
  mcp_folder_on = {area="mcp"}, mcp_folder_last = {area="mcp"},
  mcp_folderbg = {area="mcp"}, mcp_folderbgsel = {area="mcp"},
  mcp_fcomp_off = {area="mcp"}, mcp_fcomp_tiny = {area="mcp"},
  mcp_fx_norm = {area="mcp"}, mcp_fx_dis = {area="mcp"},
  mcp_fx_empty = {area="mcp"}, mcp_fx_in_norm = {area="mcp"},
  mcp_fx_in_empty = {area="mcp"}, mcp_fxlist_bg = {area="mcp"},
  mcp_fxlist_byp = {area="mcp"}, mcp_fxlist_empty = {area="mcp"},
  mcp_fxlist_norm = {area="mcp"}, mcp_fxlist_off = {area="mcp"},
  mcp_fxparm_bg = {area="mcp"}, mcp_fxparm_byp = {area="mcp"},
  mcp_fxparm_empty = {area="mcp"}, mcp_fxparm_knob = {area="mcp"},
  mcp_fxparm_knob_bg = {area="mcp"}, mcp_fxparm_knob_stack = {area="mcp"},
  mcp_fxparm_norm = {area="mcp"}, mcp_fxparm_off = {area="mcp"},
  mcp_iconbg = {area="mcp"}, mcp_iconbgsel = {area="mcp"},
  mcp_mainiconbg = {area="mcp"}, mcp_mainiconbgsel = {area="mcp"},
  mcp_io_dis = {area="mcp"}, mcp_io_r = {area="mcp"},
  mcp_io_s = {area="mcp"}, mcp_io_s_r = {area="mcp"},
  mcp_io_r_dis = {area="mcp"}, mcp_io_s_dis = {area="mcp"},
  mcp_io_s_r_dis = {area="mcp"}, mcp_mainbg = {area="mcp"},
  mcp_mainbgsel = {area="mcp"}, mcp_main_namebg = {area="mcp"},
  mcp_main_namebg_sel = {area="mcp"}, mcp_master_fxlist_bg = {area="mcp"},
  mcp_master_fxlist_byp = {area="mcp"}, mcp_master_fxlist_empty = {area="mcp"},
  mcp_master_fxlist_norm = {area="mcp"}, mcp_master_fxlist_off = {area="mcp"},
  mcp_master_pan_label = {area="mcp"}, mcp_master_sendlist_bg = {area="mcp"},
  mcp_master_sendlist_empty = {area="mcp"}, mcp_master_sendlist_knob = {area="mcp"},
  mcp_master_sendlist_meter = {area="mcp"}, mcp_master_sendlist_mute = {area="mcp"},
  mcp_master_sendlist_norm = {area="mcp"}, mcp_master_vol_label = {area="mcp"},
  mcp_master_volbg_horz = {area="mcp"}, mcp_master_volbg = {area="mcp"},
  mcp_master_volthumb_horz = {area="mcp"}, mcp_master_volthumb = {area="mcp"},
  mcp_master_vu = {area="mcp"}, mcp_master_wid_label = {area="mcp"},
  mcp_monitor_off = {area="mcp"}, mcp_monitor_on = {area="mcp"},
  mcp_monitor_auto = {area="mcp"}, mcp_stereo = {area="mcp"},
  mcp_mono = {area="mcp"}, mcp_mute_off = {area="mcp"},
  mcp_mute_on = {area="mcp"}, mcp_namebg = {area="mcp"},
  mcp_pan_knob_large = {area="mcp"}, mcp_pan_knob_small = {area="mcp"},
  mcp_pan_knob_stack = {area="mcp"}, mcp_pan_knob_stack_1 = {area="mcp"},
  mcp_pan_knob_stack_2 = {area="mcp"}, mcp_pan_label = {area="mcp"},
  mcp_panbg = {area="mcp"}, mcp_panbg_vert = {area="mcp"},
  mcp_panthumb = {area="mcp"}, mcp_panthumb_vert = {area="mcp"},
  mcp_phase_norm = {area="mcp"}, mcp_phase_inv = {area="mcp"},
  mcp_recarm_off = {area="mcp"}, mcp_recarm_on = {area="mcp"},
  mcp_recarm_auto = {area="mcp"}, mcp_recarm_auto_on = {area="mcp"},
  mcp_recarm_norec = {area="mcp"}, mcp_recarm_auto_norec = {area="mcp"},
  mcp_recinput = {area="mcp"}, mcp_recmode_in = {area="mcp"},
  mcp_recmode_out = {area="mcp"}, mcp_recmode_off = {area="mcp"},
  mcp_send_knob_stack = {area="mcp"}, mcp_sendlist_bg = {area="mcp"},
  mcp_sendlist_empty = {area="mcp"}, mcp_sendlist_knob = {area="mcp"},
  mcp_sendlist_knob_bg = {area="mcp"}, mcp_sendlist_meter = {area="mcp"},
  mcp_sendlist_midihw = {area="mcp"}, mcp_sendlist_mute = {area="mcp"},
  mcp_sendlist_norm = {area="mcp"}, mcp_solo_off = {area="mcp"},
  mcp_solo_on = {area="mcp"}, mcp_solodefeat_on = {area="mcp"},
  mcp_idxbg = {area="mcp"}, mcp_idxbg_sel = {area="mcp"},
  mcp_vol_knob_large = {area="mcp"}, mcp_vol_knob_small = {area="mcp"},
  mcp_vol_knob_stack = {area="mcp"}, mcp_vol_knob_stack_1 = {area="mcp"},
  mcp_vol_knob_stack_2 = {area="mcp"}, mcp_vol_label = {area="mcp"},
  mcp_volbg_horz = {area="mcp"}, mcp_volbg = {area="mcp"},
  mcp_volthumb_horz = {area="mcp"}, mcp_volthumb = {area="mcp"},
  mcp_vu = {area="mcp"}, mcp_width_knob_large = {area="mcp"},
  mcp_width_knob_small = {area="mcp"}, mcp_wid_knob_stack = {area="mcp"},
  mcp_wid_knob_stack_1 = {area="mcp"}, mcp_wid_knob_stack_2 = {area="mcp"},
  mcp_wid_label = {area="mcp"}, mcp_widthbg = {area="mcp"},
  mcp_widthbg_vert = {area="mcp"}, mcp_widththumb = {area="mcp"},
  mcp_widththumb_vert = {area="mcp"}, master_mcp_io = {area="mcp"},
  mixer_menu = {area="mcp"},

  -- MIDI
  midi_note_colormap = {area="midi"}, midi_score_colormap = {area="midi"},
  piano_black_key = {area="midi"}, piano_black_key_sel = {area="midi"},
  piano_white_key = {area="midi"}, piano_white_key_sel = {area="midi"},
  midi_inline_ccwithitems_off = {area="midi"}, midi_inline_ccwithitems_on = {area="midi"},
  midi_inline_close = {area="midi"}, midi_inline_fold_custom_view = {area="midi"},
  midi_inline_fold_none = {area="midi"}, midi_inline_fold_unnamed = {area="midi"},
  midi_inline_fold_unused_unnamed = {area="midi"}, midi_inline_noteview_rect = {area="midi"},
  midi_inline_noteview_diamond = {area="midi"}, midi_inline_noteview_triangle = {area="midi"},
  midi_inline_scroll = {area="midi"}, midi_inline_scrollbar = {area="midi"},
  midi_inline_scrollthumb = {area="midi"}, midi_item_bounds = {area="midi"},

  -- Item
  item_bg = {area="item"}, item_bg_sel = {area="item"},
  item_env_off = {area="item"}, item_env_on = {area="item"},
  item_rank = {area="item"}, item_rank_up = {area="item"},
  item_rank_down = {area="item"}, item_fx_off = {area="item"},
  item_fx_on = {area="item"}, item_group = {area="item"},
  item_group_sel = {area="item"}, item_lock_off = {area="item"},
  item_lock_on = {area="item"}, item_loop = {area="item"},
  item_mute_off = {area="item"}, item_mute_on = {area="item"},
  item_note_off = {area="item"}, item_note_on = {area="item"},
  item_pooled = {area="item"}, item_pooled_on = {area="item"},
  item_props = {area="item"}, item_props_on = {area="item"},
  item_seldot = {area="item"}, item_timebase_beat = {area="item"},
  item_timebase_beat_on = {area="item"}, item_timebase_time = {area="item"},
  item_timebase_time_on = {area="item"}, item_volknob = {area="item"},
  item_volknob_stack = {area="item"},

  -- Global misc
  cursor_seltrack = {area="global"}, fixed_lanes_big = {area="global"},
  fixed_lanes_hidden = {area="global"}, fixed_lanes_one = {area="global"},
  fixed_lanes_small = {area="global"}, gen_back = {area="global"},
  gen_back_on = {area="global"}, gen_down_arrow = {area="global"},
  gen_down_arrow_on = {area="global"}, gen_env = {area="global"},
  gen_env_read = {area="global"}, gen_env_touch = {area="global"},
  gen_env_write = {area="global"}, gen_env_latch = {area="global"},
  gen_env_preview = {area="global"}, gen_forward = {area="global"},
  gen_forward_on = {area="global"}, gen_end = {area="global"},
  gen_io = {area="global"}, gen_midi_off = {area="global"},
  gen_midi_on = {area="global"}, gen_stereo = {area="global"},
  gen_mono = {area="global"}, gen_mute_off = {area="global"},
  gen_mute_on = {area="global"}, gen_panbg_horz = {area="global"},
  gen_panbg_vert = {area="global"}, gen_panthumb_horz = {area="global"},
  gen_panthumb_vert = {area="global"}, gen_panbg_horz_dark = {area="global"},
  gen_panbg_vert_dark = {area="global"}, gen_panthumb_horz_dark = {area="global"},
  gen_panthumb_vert_dark = {area="global"}, gen_pause = {area="global"},
  gen_pause_on = {area="global"}, gen_phase_norm = {area="global"},
  gen_phase_inv = {area="global"}, gen_play = {area="global"},
  gen_play_on = {area="global"}, gen_refresh = {area="global"},
  gen_repeat_off = {area="global"}, gen_repeat_on = {area="global"},
  gen_home = {area="global"}, gen_solo_off = {area="global"},
  gen_solo_on = {area="global"}, gen_stop = {area="global"},
  gen_up = {area="global"}, gen_up_arrow = {area="global"},
  gen_up_arrow_on = {area="global"}, gen_volbg_horz = {area="global"},
  gen_volbg_vert = {area="global"}, gen_volthumb_horz = {area="global"},
  gen_volthumb_vert = {area="global"}, gen_volbg_horz_dark = {area="global"},
  gen_volbg_vert_dark = {area="global"}, gen_volthumb_horz_dark = {area="global"},
  gen_volthumb_vert_dark = {area="global"}, gen_knob_bg_large = {area="global"},
  gen_knob_bg_small = {area="global"}, knob_stack = {area="global"},
  knob_stack_1 = {area="global"}, knob_stack_2 = {area="global"},
  lane_solo_off = {area="global"}, lane_solo_on = {area="global"},
  lane_solo_off_indicator = {area="global"}, lane_solo_on_indicator = {area="global"},
  lane_solo_down = {area="global"}, lane_solo_up = {area="global"},
  monitor_fx_byp_off = {area="global"}, monitor_fx_byp_on = {area="global"},
  monitor_fx_byp_byp = {area="global"}, monitor_fx_off = {area="global"},
  monitor_fx_on = {area="global"}, monitor_fx_byp = {area="global"},
  scrollbar = {area="global"}, scrollbar_2 = {area="global"},
  scrollbar_3 = {area="global"}, splash = {area="global"},
  tab_down = {area="global"}, tab_down_sel = {area="global"},
  tab_up = {area="global"}, tab_up_sel = {area="global"},
  table_expand_off = {area="global"}, table_expand_on = {area="global"},
  table_locked_off = {area="global"}, table_locked_on = {area="global"},
  table_locked_partial = {area="global"}, table_mute_off = {area="global"},
  table_mute_on = {area="global"}, table_recarm_off = {area="global"},
  table_recarm_on = {area="global"}, table_remove_off = {area="global"},
  table_remove_on = {area="global"}, table_solo_off = {area="global"},
  table_solo_on = {area="global"}, table_sub_expand_off = {area="global"},
  table_sub_expand_on = {area="global"}, table_target_off = {area="global"},
  table_target_on = {area="global"}, table_target_invalid = {area="global"},
  table_visible_off = {area="global"}, table_visible_on = {area="global"},
  table_visible_partial = {area="global"}, animation_toolbar_armed = {area="toolbar"},
  animation_toolbar_highlight = {area="toolbar"}, composite_toolbar_overlay = {area="toolbar"},
  toosmall_b = {area="global"}, toosmall_r = {area="global"},
  fader_h = {area="global"}, fader_v = {area="global"},
}

--- Get the area for an image
-- @param image_name string The image name (without extension)
-- @return string|nil The area or nil if not found
function M.get_area(image_name)
  local name = image_name:match("^(.+)%.[^.]+$") or image_name

  -- First try exact match
  local data = IMAGE_DATA[name]
  if data then
    return data.area
  end

  -- Fall back to prefix matching for robustness
  local prefix_map = {
    {prefix = "tcp_", area = "tcp"},
    {prefix = "mcp_", area = "mcp"},
    {prefix = "track_", area = "track"},
    {prefix = "transport_", area = "transport"},
    {prefix = "toolbar_", area = "toolbar"},
    {prefix = "meter_", area = "meter"},
    {prefix = "envcp_", area = "envcp"},
    {prefix = "item_", area = "item"},
    {prefix = "midi_", area = "midi"},
    {prefix = "piano_", area = "midi"},
    {prefix = "gen_", area = "global"},
    {prefix = "global_", area = "transport"},  -- global_trim, etc. are transport controls
    {prefix = "knob_", area = "global"},
    {prefix = "scrollbar", area = "global"},
    {prefix = "button_", area = "global"},
    {prefix = "slider", area = "global"},
    {prefix = "fader_", area = "global"},
    {prefix = "folder_", area = "tcp"},
    {prefix = "master_tcp_", area = "tcp"},
    {prefix = "master_mcp_", area = "mcp"},
    {prefix = "mixer_", area = "mcp"},
    {prefix = "lane_", area = "global"},
    {prefix = "monitor_fx_", area = "global"},
    {prefix = "table_", area = "global"},
    {prefix = "tab_", area = "global"},
    {prefix = "fixed_lanes_", area = "global"},
    {prefix = "cursor_", area = "global"},
    {prefix = "vu_", area = "meter"},
  }

  for _, mapping in ipairs(prefix_map) do
    if name:sub(1, #mapping.prefix) == mapping.prefix then
      return mapping.area
    end
  end

  return nil
end

--- Get all valid areas
-- @return table Array of area names
function M.get_areas()
  return {"global", "tcp", "mcp", "transport", "toolbar", "meter", "envcp", "item", "midi", "track"}
end

--- Calculate area distribution for a set of images
-- @param image_names table Array of image names
-- @return table {area_name = count, ...}
function M.calculate_area_distribution(image_names)
  local distribution = {}

  for _, name in ipairs(image_names) do
    local area = M.get_area(name)
    if area then
      distribution[area] = (distribution[area] or 0) + 1
    end
  end

  return distribution
end

--- Suggest tags for a package based on its assets
-- @param image_names table Array of image names in the package
-- @param threshold number (ignored, kept for compatibility)
-- @return table Array of suggested tag names
function M.suggest_tags(image_names, threshold)
  local distribution = M.calculate_area_distribution(image_names)

  local tags = {}

  -- Map areas to display tags
  local area_to_tag = {
    tcp = "TCP",
    mcp = "MCP",
    transport = "Transport",
    toolbar = "Toolbar",
    meter = "Meter",
    envcp = "EnvCP",
    item = "Items",
    midi = "MIDI",
    track = "Track",
    global = "Global"
  }

  -- Add tag for every area present in the package
  for area, count in pairs(distribution) do
    if count > 0 then
      local tag = area_to_tag[area]
      if tag then
        table.insert(tags, tag)
      end
    end
  end

  -- Sort tags for consistency
  table.sort(tags)

  return tags
end

return M
