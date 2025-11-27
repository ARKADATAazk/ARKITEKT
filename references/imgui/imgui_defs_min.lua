-- @noindex
--- ReaImGui LuaCATS definitions
---
--- Generated for version 0.10.0.2 - API version 0.10
---
--- @meta  imgui
--- @class ImGui
---
--- **Button > Cardinal Directions > Dir\_Down**
---
--- @since 0.1
--- @field Dir_Down integer
--- @since 0.1
--- @field Dir_Left integer
--- @since 0.1
--- @field Dir_None integer
--- @since 0.1
--- @field Dir_Right integer
--- @since 0.1
--- @field Dir_Up integer
--- @since 0.10
--- @field ButtonFlags_EnableNav integer
--- @since 0.1
--- @field ButtonFlags_MouseButtonLeft integer
--- @since 0.1
--- @field ButtonFlags_MouseButtonMiddle integer
--- @since 0.1
--- @field ButtonFlags_MouseButtonRight integer
--- @since 0.1
--- @field ButtonFlags_None integer
--- @since 0.1
--- @field ColorEditFlags_NoAlpha integer
--- @since 0.1
--- @field ColorEditFlags_NoBorder integer
--- @since 0.1
--- @field ColorEditFlags_NoDragDrop integer
--- @since 0.1
--- @field ColorEditFlags_NoInputs integer
--- @since 0.1
--- @field ColorEditFlags_NoLabel integer
--- @since 0.1
--- @field ColorEditFlags_NoOptions integer
--- @since 0.1
--- @field ColorEditFlags_NoPicker integer
--- @since 0.1
--- @field ColorEditFlags_NoSidePreview integer
--- @since 0.1
--- @field ColorEditFlags_NoSmallPreview integer
--- @since 0.1
--- @field ColorEditFlags_NoTooltip integer
--- @since 0.1
--- @field ColorEditFlags_None integer
--- @since 0.10
--- @field ColorEditFlags_AlphaNoBg integer
--- @since 0.10
--- @field ColorEditFlags_AlphaOpaque integer
--- @since 0.1
--- @field ColorEditFlags_AlphaPreviewHalf integer
--- @since 0.1
--- @field ColorEditFlags_AlphaBar integer
--- @since 0.1
--- @field ColorEditFlags_DisplayHSV integer
--- @since 0.1
--- @field ColorEditFlags_DisplayHex integer
--- @since 0.1
--- @field ColorEditFlags_DisplayRGB integer
--- @since 0.1
--- @field ColorEditFlags_Float integer
--- @since 0.1
--- @field ColorEditFlags_InputHSV integer
--- @since 0.1
--- @field ColorEditFlags_InputRGB integer
--- @since 0.1
--- @field ColorEditFlags_PickerHueBar integer
--- @since 0.1
--- @field ColorEditFlags_PickerHueWheel integer
--- @since 0.1
--- @field ColorEditFlags_Uint8 integer
--- @since 0.1
--- @field ComboFlags_HeightLarge integer
--- @since 0.1
--- @field ComboFlags_HeightLargest integer
--- @since 0.1
--- @field ComboFlags_HeightRegular integer
--- @since 0.1
--- @field ComboFlags_HeightSmall integer
--- @since 0.1
--- @field ComboFlags_NoArrowButton integer
--- @since 0.1
--- @field ComboFlags_NoPreview integer
--- @since 0.1
--- @field ComboFlags_None integer
--- @since 0.1
--- @field ComboFlags_PopupAlignLeft integer
--- @since 0.9
--- @field ComboFlags_WidthFitPreview integer
--- @since 0.1
--- @field SelectableFlags_AllowDoubleClick integer
--- @since 0.9
--- @field SelectableFlags_AllowOverlap integer
--- @since 0.1
--- @field SelectableFlags_Disabled integer
--- @since 0.10
--- @field SelectableFlags_Highlight integer
--- @since 0.10
--- @field SelectableFlags_NoAutoClosePopups integer
--- @since 0.1
--- @field SelectableFlags_None integer
--- @since 0.1
--- @field SelectableFlags_SpanAllColumns integer
--- @since 0.5
--- @field ConfigFlags_DockingEnable integer
--- @since 0.1
--- @field ConfigFlags_NavEnableKeyboard integer
--- @since 0.9.2
--- @field ConfigFlags_NoKeyboard integer
--- @since 0.1
--- @field ConfigFlags_NoMouse integer
--- @since 0.1
--- @field ConfigFlags_NoMouseCursorChange integer
--- @since 0.4
--- @field ConfigFlags_NoSavedSettings integer
--- @since 0.1
--- @field ConfigFlags_None integer
--- @since 0.8.5
--- @field ConfigVar_DebugBeginReturnValueLoop integer
--- @since 0.8.5
--- @field ConfigVar_DebugBeginReturnValueOnce integer
--- @since 0.10
--- @field ConfigVar_DebugHighlightIdConflicts integer
--- @since 0.7
--- @field ConfigVar_DockingNoSplit integer
--- @since 0.7
--- @field ConfigVar_DockingTransparentPayload integer
--- @since 0.7
--- @field ConfigVar_DockingWithShift integer
--- @since 0.7
--- @field ConfigVar_DragClickToInputText integer
--- @since 0.7
--- @field ConfigVar_Flags integer
--- @since 0.8
--- @field ConfigVar_HoverDelayNormal integer
--- @since 0.8
--- @field ConfigVar_HoverDelayShort integer
--- @since 0.9
--- @field ConfigVar_HoverFlagsForTooltipMouse integer
--- @since 0.9
--- @field ConfigVar_HoverFlagsForTooltipNav integer
--- @since 0.9
--- @field ConfigVar_HoverStationaryDelay integer
--- @since 0.7
--- @field ConfigVar_InputTextCursorBlink integer
--- @since 0.8
--- @field ConfigVar_InputTextEnterKeepActive integer
--- @since 0.7
--- @field ConfigVar_InputTrickleEventQueue integer
--- @since 0.7
--- @field ConfigVar_KeyRepeatDelay integer
--- @since 0.7
--- @field ConfigVar_KeyRepeatRate integer
--- @since 0.7
--- @field ConfigVar_MacOSXBehaviors integer
--- @since 0.7
--- @field ConfigVar_MouseDoubleClickMaxDist integer
--- @since 0.7
--- @field ConfigVar_MouseDoubleClickTime integer
--- @since 0.7
--- @field ConfigVar_MouseDragThreshold integer
--- @since 0.10
--- @field ConfigVar_NavCaptureKeyboard integer
--- @since 0.10
--- @field ConfigVar_NavCursorVisibleAlways integer
--- @since 0.10
--- @field ConfigVar_NavCursorVisibleAuto integer
--- @since 0.10
--- @field ConfigVar_NavEscapeClearFocusItem integer
--- @since 0.10
--- @field ConfigVar_NavEscapeClearFocusWindow integer
--- @since 0.10
--- @field ConfigVar_NavMoveSetMousePos integer
--- @since 0.10
--- @field ConfigVar_ScrollbarScrollByPage integer
--- @since 0.7
--- @field ConfigVar_ViewportsNoDecoration integer
--- @since 0.7
--- @field ConfigVar_WindowsMoveFromTitleBarOnly integer
--- @since 0.7
--- @field ConfigVar_WindowsResizeFromEdges integer
--- @since 0.1
--- @field DragDropFlags_None integer
--- @since 0.1
--- @field DragDropFlags_AcceptBeforeDelivery integer
--- @since 0.1
--- @field DragDropFlags_AcceptNoDrawDefaultRect integer
--- @since 0.1
--- @field DragDropFlags_AcceptNoPreviewTooltip integer
--- @since 0.1
--- @field DragDropFlags_AcceptPeekOnly integer
--- @since 0.9.2
--- @field DragDropFlags_PayloadAutoExpire integer
--- @since 0.1
--- @field DragDropFlags_SourceAllowNullID integer
--- @since 0.1
--- @field DragDropFlags_SourceExtern integer
--- @since 0.1
--- @field DragDropFlags_SourceNoDisableHover integer
--- @since 0.1
--- @field DragDropFlags_SourceNoHoldToOpenOthers integer
--- @since 0.1
--- @field DragDropFlags_SourceNoPreviewTooltip integer
--- @since 0.10
--- @field SliderFlags_AlwaysClamp integer
--- @since 0.10
--- @field SliderFlags_ClampOnInput integer
--- @since 0.10
--- @field SliderFlags_ClampZeroRange integer
--- @since 0.1
--- @field SliderFlags_Logarithmic integer
--- @since 0.1
--- @field SliderFlags_NoInput integer
--- @since 0.1
--- @field SliderFlags_NoRoundToFormat integer
--- @since 0.10
--- @field SliderFlags_NoSpeedTweaks integer
--- @since 0.1
--- @field SliderFlags_None integer
--- @since 0.9.2
--- @field SliderFlags_WrapAround integer
--- @since 0.2
--- @field DrawFlags_Closed integer
--- @since 0.2
--- @field DrawFlags_None integer
--- @since 0.2
--- @field DrawFlags_RoundCornersAll integer
--- @since 0.2
--- @field DrawFlags_RoundCornersBottom integer
--- @since 0.2
--- @field DrawFlags_RoundCornersBottomLeft integer
--- @since 0.2
--- @field DrawFlags_RoundCornersBottomRight integer
--- @since 0.2
--- @field DrawFlags_RoundCornersLeft integer
--- @since 0.2
--- @field DrawFlags_RoundCornersNone integer
--- @since 0.2
--- @field DrawFlags_RoundCornersRight integer
--- @since 0.2
--- @field DrawFlags_RoundCornersTop integer
--- @since 0.2
--- @field DrawFlags_RoundCornersTopLeft integer
--- @since 0.2
--- @field DrawFlags_RoundCornersTopRight integer
--- @since 0.4
--- @field FontFlags_Bold integer
--- @since 0.4
--- @field FontFlags_Italic integer
--- @since 0.4
--- @field FontFlags_None integer
--- @since 0.10
--- @field ImageFlags_NoErrors integer
--- @since 0.10
--- @field ImageFlags_None integer
--- @since 0.1
--- @field HoveredFlags_AllowWhenBlockedByActiveItem integer
--- @since 0.1
--- @field HoveredFlags_AllowWhenBlockedByPopup integer
--- @since 0.9
--- @field HoveredFlags_ForTooltip integer
--- @since 0.7
--- @field HoveredFlags_NoNavOverride integer
--- @since 0.1
--- @field HoveredFlags_None integer
--- @since 0.9
--- @field HoveredFlags_Stationary integer
--- @since 0.1
--- @field HoveredFlags_AllowWhenDisabled integer
--- @since 0.1
--- @field HoveredFlags_AllowWhenOverlapped integer
--- @since 0.9
--- @field HoveredFlags_AllowWhenOverlappedByItem integer
--- @since 0.9
--- @field HoveredFlags_AllowWhenOverlappedByWindow integer
--- @since 0.1
--- @field HoveredFlags_RectOnly integer
--- @since 0.9
--- @field HoveredFlags_DelayNone integer
--- @since 0.8
--- @field HoveredFlags_DelayNormal integer
--- @since 0.8
--- @field HoveredFlags_DelayShort integer
--- @since 0.8
--- @field HoveredFlags_NoSharedDelay integer
--- @since 0.1
--- @field HoveredFlags_AnyWindow integer
--- @since 0.1
--- @field HoveredFlags_ChildWindows integer
--- @since 0.5.10
--- @field HoveredFlags_DockHierarchy integer
--- @since 0.5.10
--- @field HoveredFlags_NoPopupHierarchy integer
--- @since 0.1
--- @field HoveredFlags_RootAndChildWindows integer
--- @since 0.1
--- @field HoveredFlags_RootWindow integer
--- @since 0.10
--- @field ItemFlags_AllowDuplicateId integer
--- @since 0.10
--- @field ItemFlags_AutoClosePopups integer
--- @since 0.10
--- @field ItemFlags_ButtonRepeat integer
--- @since 0.10
--- @field ItemFlags_NoNav integer
--- @since 0.10
--- @field ItemFlags_NoNavDefaultFocus integer
--- @since 0.10
--- @field ItemFlags_NoTabStop integer
--- @since 0.10
--- @field ItemFlags_None integer
--- @since 0.6
--- @field Key_0 integer
--- @since 0.6
--- @field Key_1 integer
--- @since 0.6
--- @field Key_2 integer
--- @since 0.6
--- @field Key_3 integer
--- @since 0.6
--- @field Key_4 integer
--- @since 0.6
--- @field Key_5 integer
--- @since 0.6
--- @field Key_6 integer
--- @since 0.6
--- @field Key_7 integer
--- @since 0.6
--- @field Key_8 integer
--- @since 0.6
--- @field Key_9 integer
--- @since 0.6
--- @field Key_A integer
--- @since 0.6
--- @field Key_Apostrophe integer
--- @since 0.9
--- @field Key_AppBack integer
--- @since 0.9
--- @field Key_AppForward integer
--- @since 0.6
--- @field Key_B integer
--- @since 0.6
--- @field Key_Backslash integer
--- @since 0.6
--- @field Key_Backspace integer
--- @since 0.6
--- @field Key_C integer
--- @since 0.6
--- @field Key_CapsLock integer
--- @since 0.6
--- @field Key_Comma integer
--- @since 0.6
--- @field Key_D integer
--- @since 0.6
--- @field Key_Delete integer
--- @since 0.6
--- @field Key_DownArrow integer
--- @since 0.6
--- @field Key_E integer
--- @since 0.6
--- @field Key_End integer
--- @since 0.6
--- @field Key_Enter integer
--- @since 0.6
--- @field Key_Equal integer
--- @since 0.6
--- @field Key_Escape integer
--- @since 0.6
--- @field Key_F integer
--- @since 0.6
--- @field Key_F1 integer
--- @since 0.6
--- @field Key_F10 integer
--- @since 0.6
--- @field Key_F11 integer
--- @since 0.6
--- @field Key_F12 integer
--- @since 0.9
--- @field Key_F13 integer
--- @since 0.9
--- @field Key_F14 integer
--- @since 0.9
--- @field Key_F15 integer
--- @since 0.9
--- @field Key_F16 integer
--- @since 0.9
--- @field Key_F17 integer
--- @since 0.9
--- @field Key_F18 integer
--- @since 0.9
--- @field Key_F19 integer
--- @since 0.6
--- @field Key_F2 integer
--- @since 0.9
--- @field Key_F20 integer
--- @since 0.9
--- @field Key_F21 integer
--- @since 0.9
--- @field Key_F22 integer
--- @since 0.9
--- @field Key_F23 integer
--- @since 0.9
--- @field Key_F24 integer
--- @since 0.6
--- @field Key_F3 integer
--- @since 0.6
--- @field Key_F4 integer
--- @since 0.6
--- @field Key_F5 integer
--- @since 0.6
--- @field Key_F6 integer
--- @since 0.6
--- @field Key_F7 integer
--- @since 0.6
--- @field Key_F8 integer
--- @since 0.6
--- @field Key_F9 integer
--- @since 0.6
--- @field Key_G integer
--- @since 0.6
--- @field Key_GraveAccent integer
--- @since 0.6
--- @field Key_H integer
--- @since 0.6
--- @field Key_Home integer
--- @since 0.6
--- @field Key_I integer
--- @since 0.6
--- @field Key_Insert integer
--- @since 0.6
--- @field Key_J integer
--- @since 0.6
--- @field Key_K integer
--- @since 0.6
--- @field Key_Keypad0 integer
--- @since 0.6
--- @field Key_Keypad1 integer
--- @since 0.6
--- @field Key_Keypad2 integer
--- @since 0.6
--- @field Key_Keypad3 integer
--- @since 0.6
--- @field Key_Keypad4 integer
--- @since 0.6
--- @field Key_Keypad5 integer
--- @since 0.6
--- @field Key_Keypad6 integer
--- @since 0.6
--- @field Key_Keypad7 integer
--- @since 0.6
--- @field Key_Keypad8 integer
--- @since 0.6
--- @field Key_Keypad9 integer
--- @since 0.6
--- @field Key_KeypadAdd integer
--- @since 0.6
--- @field Key_KeypadDecimal integer
--- @since 0.6
--- @field Key_KeypadDivide integer
--- @since 0.6
--- @field Key_KeypadEnter integer
--- @since 0.6
--- @field Key_KeypadEqual integer
--- @since 0.6
--- @field Key_KeypadMultiply integer
--- @since 0.6
--- @field Key_KeypadSubtract integer
--- @since 0.6
--- @field Key_L integer
--- @since 0.6
--- @field Key_LeftAlt integer
--- @since 0.6
--- @field Key_LeftArrow integer
--- @since 0.6
--- @field Key_LeftBracket integer
--- @since 0.6
--- @field Key_LeftCtrl integer
--- @since 0.6
--- @field Key_LeftShift integer
--- @since 0.6
--- @field Key_LeftSuper integer
--- @since 0.6
--- @field Key_M integer
--- @since 0.6
--- @field Key_Menu integer
--- @since 0.6
--- @field Key_Minus integer
--- @since 0.6
--- @field Key_N integer
--- @since 0.6
--- @field Key_NumLock integer
--- @since 0.6
--- @field Key_O integer
--- @since 0.10
--- @field Key_Oem102 integer
--- @since 0.6
--- @field Key_P integer
--- @since 0.6
--- @field Key_PageDown integer
--- @since 0.6
--- @field Key_PageUp integer
--- @since 0.6
--- @field Key_Pause integer
--- @since 0.6
--- @field Key_Period integer
--- @since 0.6
--- @field Key_PrintScreen integer
--- @since 0.6
--- @field Key_Q integer
--- @since 0.6
--- @field Key_R integer
--- @since 0.6
--- @field Key_RightAlt integer
--- @since 0.6
--- @field Key_RightArrow integer
--- @since 0.6
--- @field Key_RightBracket integer
--- @since 0.6
--- @field Key_RightCtrl integer
--- @since 0.6
--- @field Key_RightShift integer
--- @since 0.6
--- @field Key_RightSuper integer
--- @since 0.6
--- @field Key_S integer
--- @since 0.6
--- @field Key_ScrollLock integer
--- @since 0.6
--- @field Key_Semicolon integer
--- @since 0.6
--- @field Key_Slash integer
--- @since 0.6
--- @field Key_Space integer
--- @since 0.6
--- @field Key_T integer
--- @since 0.6
--- @field Key_Tab integer
--- @since 0.6
--- @field Key_U integer
--- @since 0.6
--- @field Key_UpArrow integer
--- @since 0.6
--- @field Key_V integer
--- @since 0.6
--- @field Key_W integer
--- @since 0.6
--- @field Key_X integer
--- @since 0.6
--- @field Key_Y integer
--- @since 0.6
--- @field Key_Z integer
--- @since 0.8
--- @field Mod_Alt integer
--- @since 0.9.2
--- @field Mod_Ctrl integer
--- @since 0.8
--- @field Mod_None integer
--- @since 0.8
--- @field Mod_Shift integer
--- @since 0.9.2
--- @field Mod_Super integer
--- @since 0.8
--- @field Key_MouseLeft integer
--- @since 0.8
--- @field Key_MouseMiddle integer
--- @since 0.8
--- @field Key_MouseRight integer
--- @since 0.8
--- @field Key_MouseWheelX integer
--- @since 0.8
--- @field Key_MouseWheelY integer
--- @since 0.8
--- @field Key_MouseX1 integer
--- @since 0.8
--- @field Key_MouseX2 integer
--- @since 0.1
--- @field MouseButton_Left integer
--- @since 0.1
--- @field MouseButton_Middle integer
--- @since 0.1
--- @field MouseButton_Right integer
--- @since 0.1
--- @field MouseCursor_Arrow integer
--- @since 0.1
--- @field MouseCursor_Hand integer
--- @since 0.8.4
--- @field MouseCursor_None integer
--- @since 0.1
--- @field MouseCursor_NotAllowed integer
--- @since 0.10
--- @field MouseCursor_Progress integer
--- @since 0.1
--- @field MouseCursor_ResizeAll integer
--- @since 0.1
--- @field MouseCursor_ResizeEW integer
--- @since 0.1
--- @field MouseCursor_ResizeNESW integer
--- @since 0.1
--- @field MouseCursor_ResizeNS integer
--- @since 0.1
--- @field MouseCursor_ResizeNWSE integer
--- @since 0.1
--- @field MouseCursor_TextInput integer
--- @since 0.10
--- @field MouseCursor_Wait integer
--- @since 0.9.2
--- @field InputFlags_None integer
--- @since 0.9.2
--- @field InputFlags_Repeat integer
--- @since 0.9.2
--- @field InputFlags_RouteFromRootWindow integer
--- @since 0.9.2
--- @field InputFlags_RouteOverActive integer
--- @since 0.9.2
--- @field InputFlags_RouteOverFocused integer
--- @since 0.9.2
--- @field InputFlags_RouteUnlessBgFocused integer
--- @since 0.9.2
--- @field InputFlags_Tooltip integer
--- @since 0.9.2
--- @field InputFlags_RouteActive integer
--- @since 0.9.2
--- @field InputFlags_RouteAlways integer
--- @since 0.9.2
--- @field InputFlags_RouteFocused integer
--- @since 0.9.2
--- @field InputFlags_RouteGlobal integer
--- @since 0.1
--- @field PopupFlags_None integer
--- @since 0.1
--- @field PopupFlags_MouseButtonLeft integer
--- @since 0.1
--- @field PopupFlags_MouseButtonMiddle integer
--- @since 0.1
--- @field PopupFlags_MouseButtonRight integer
--- @since 0.1
--- @field PopupFlags_NoOpenOverItems integer
--- @since 0.1
--- @field PopupFlags_AnyPopup integer
--- @since 0.1
--- @field PopupFlags_AnyPopupId integer
--- @since 0.1
--- @field PopupFlags_AnyPopupLevel integer
--- @since 0.1
--- @field PopupFlags_NoOpenOverExistingPopup integer
--- @since 0.9
--- @field PopupFlags_NoReopen integer
--- @since 0.1
--- @field Col_Border integer
--- @since 0.1
--- @field Col_BorderShadow integer
--- @since 0.1
--- @field Col_Button integer
--- @since 0.1
--- @field Col_ButtonActive integer
--- @since 0.1
--- @field Col_ButtonHovered integer
--- @since 0.1
--- @field Col_CheckMark integer
--- @since 0.1
--- @field Col_ChildBg integer
--- @since 0.5
--- @field Col_DockingEmptyBg integer
--- @since 0.5
--- @field Col_DockingPreview integer
--- @since 0.1
--- @field Col_DragDropTarget integer
--- @since 0.1
--- @field Col_FrameBg integer
--- @since 0.1
--- @field Col_FrameBgActive integer
--- @since 0.1
--- @field Col_FrameBgHovered integer
--- @since 0.1
--- @field Col_Header integer
--- @since 0.1
--- @field Col_HeaderActive integer
--- @since 0.1
--- @field Col_HeaderHovered integer
--- @since 0.10
--- @field Col_InputTextCursor integer
--- @since 0.1
--- @field Col_MenuBarBg integer
--- @since 0.1
--- @field Col_ModalWindowDimBg integer
--- @since 0.10
--- @field Col_NavCursor integer
--- @since 0.1
--- @field Col_NavWindowingDimBg integer
--- @since 0.1
--- @field Col_NavWindowingHighlight integer
--- @since 0.1
--- @field Col_PlotHistogram integer
--- @since 0.1
--- @field Col_PlotHistogramHovered integer
--- @since 0.1
--- @field Col_PlotLines integer
--- @since 0.1
--- @field Col_PlotLinesHovered integer
--- @since 0.1
--- @field Col_PopupBg integer
--- @since 0.1
--- @field Col_ResizeGrip integer
--- @since 0.1
--- @field Col_ResizeGripActive integer
--- @since 0.1
--- @field Col_ResizeGripHovered integer
--- @since 0.1
--- @field Col_ScrollbarBg integer
--- @since 0.1
--- @field Col_ScrollbarGrab integer
--- @since 0.1
--- @field Col_ScrollbarGrabActive integer
--- @since 0.1
--- @field Col_ScrollbarGrabHovered integer
--- @since 0.1
--- @field Col_Separator integer
--- @since 0.1
--- @field Col_SeparatorActive integer
--- @since 0.1
--- @field Col_SeparatorHovered integer
--- @since 0.1
--- @field Col_SliderGrab integer
--- @since 0.1
--- @field Col_SliderGrabActive integer
--- @since 0.1
--- @field Col_Tab integer
--- @since 0.9.2
--- @field Col_TabDimmed integer
--- @since 0.9.2
--- @field Col_TabDimmedSelected integer
--- @since 0.9.2
--- @field Col_TabDimmedSelectedOverline integer
--- @since 0.1
--- @field Col_TabHovered integer
--- @since 0.9.2
--- @field Col_TabSelected integer
--- @since 0.9.2
--- @field Col_TabSelectedOverline integer
--- @since 0.1
--- @field Col_TableBorderLight integer
--- @since 0.1
--- @field Col_TableBorderStrong integer
--- @since 0.1
--- @field Col_TableHeaderBg integer
--- @since 0.1
--- @field Col_TableRowBg integer
--- @since 0.1
--- @field Col_TableRowBgAlt integer
--- @since 0.1
--- @field Col_Text integer
--- @since 0.1
--- @field Col_TextDisabled integer
--- @since 0.10
--- @field Col_TextLink integer
--- @since 0.1
--- @field Col_TextSelectedBg integer
--- @since 0.1
--- @field Col_TitleBg integer
--- @since 0.1
--- @field Col_TitleBgActive integer
--- @since 0.1
--- @field Col_TitleBgCollapsed integer
--- @since 0.10
--- @field Col_TreeLines integer
--- @since 0.1
--- @field Col_WindowBg integer
--- @since 0.1
--- @field StyleVar_Alpha integer
--- @since 0.1
--- @field StyleVar_ButtonTextAlign integer
--- @since 0.1
--- @field StyleVar_CellPadding integer
--- @since 0.1
--- @field StyleVar_ChildBorderSize integer
--- @since 0.1
--- @field StyleVar_ChildRounding integer
--- @since 0.5.5
--- @field StyleVar_DisabledAlpha integer
--- @since 0.1
--- @field StyleVar_FrameBorderSize integer
--- @since 0.1
--- @field StyleVar_FramePadding integer
--- @since 0.1
--- @field StyleVar_FrameRounding integer
--- @since 0.1
--- @field StyleVar_GrabMinSize integer
--- @since 0.1
--- @field StyleVar_GrabRounding integer
--- @since 0.10
--- @field StyleVar_ImageBorderSize integer
--- @since 0.1
--- @field StyleVar_IndentSpacing integer
--- @since 0.1
--- @field StyleVar_ItemInnerSpacing integer
--- @since 0.1
--- @field StyleVar_ItemSpacing integer
--- @since 0.1
--- @field StyleVar_PopupBorderSize integer
--- @since 0.1
--- @field StyleVar_PopupRounding integer
--- @since 0.1
--- @field StyleVar_ScrollbarRounding integer
--- @since 0.1
--- @field StyleVar_ScrollbarSize integer
--- @since 0.1
--- @field StyleVar_SelectableTextAlign integer
--- @since 0.8.4
--- @field StyleVar_SeparatorTextAlign integer
--- @since 0.8.4
--- @field StyleVar_SeparatorTextBorderSize integer
--- @since 0.8.4
--- @field StyleVar_SeparatorTextPadding integer
--- @since 0.9
--- @field StyleVar_TabBarBorderSize integer
--- @since 0.10
--- @field StyleVar_TabBarOverlineSize integer
--- @since 0.9
--- @field StyleVar_TabBorderSize integer
--- @since 0.1
--- @field StyleVar_TabRounding integer
--- @since 0.9
--- @field StyleVar_TableAngledHeadersAngle integer
--- @since 0.9.1
--- @field StyleVar_TableAngledHeadersTextAlign integer
--- @since 0.10
--- @field StyleVar_TreeLinesRounding integer
--- @since 0.10
--- @field StyleVar_TreeLinesSize integer
--- @since 0.1
--- @field StyleVar_WindowBorderSize integer
--- @since 0.1
--- @field StyleVar_WindowMinSize integer
--- @since 0.1
--- @field StyleVar_WindowPadding integer
--- @since 0.1
--- @field StyleVar_WindowRounding integer
--- @since 0.1
--- @field StyleVar_WindowTitleAlign integer
--- @since 0.1
--- @field TabBarFlags_AutoSelectNewTabs integer
--- @since 0.9.2
--- @field TabBarFlags_DrawSelectedOverline integer
--- @since 0.1
--- @field TabBarFlags_FittingPolicyResizeDown integer
--- @since 0.1
--- @field TabBarFlags_FittingPolicyScroll integer
--- @since 0.1
--- @field TabBarFlags_NoCloseWithMiddleMouseButton integer
--- @since 0.1
--- @field TabBarFlags_NoTabListScrollingButtons integer
--- @since 0.1
--- @field TabBarFlags_NoTooltip integer
--- @since 0.1
--- @field TabBarFlags_None integer
--- @since 0.1
--- @field TabBarFlags_Reorderable integer
--- @since 0.1
--- @field TabBarFlags_TabListPopupButton integer
--- @since 0.1
--- @field TabItemFlags_Leading integer
--- @since 0.9
--- @field TabItemFlags_NoAssumedClosure integer
--- @since 0.1
--- @field TabItemFlags_NoCloseWithMiddleMouseButton integer
--- @since 0.1
--- @field TabItemFlags_NoPushId integer
--- @since 0.1
--- @field TabItemFlags_NoReorder integer
--- @since 0.1
--- @field TabItemFlags_NoTooltip integer
--- @since 0.1
--- @field TabItemFlags_None integer
--- @since 0.1
--- @field TabItemFlags_SetSelected integer
--- @since 0.1
--- @field TabItemFlags_Trailing integer
--- @since 0.1
--- @field TabItemFlags_UnsavedDocument integer
--- @since 0.1
--- @field TableRowFlags_Headers integer
--- @since 0.1
--- @field TableRowFlags_None integer
--- @since 0.1
--- @field TableBgTarget_CellBg integer
--- @since 0.1
--- @field TableBgTarget_None integer
--- @since 0.1
--- @field TableBgTarget_RowBg0 integer
--- @since 0.1
--- @field TableBgTarget_RowBg1 integer
--- @since 0.1
--- @field TableColumnFlags_None integer
--- @since 0.9
--- @field TableColumnFlags_AngledHeader integer
--- @since 0.1
--- @field TableColumnFlags_DefaultHide integer
--- @since 0.1
--- @field TableColumnFlags_DefaultSort integer
--- @since 0.5.5
--- @field TableColumnFlags_Disabled integer
--- @since 0.1
--- @field TableColumnFlags_IndentDisable integer
--- @since 0.1
--- @field TableColumnFlags_IndentEnable integer
--- @since 0.1
--- @field TableColumnFlags_NoClip integer
--- @since 0.5.5
--- @field TableColumnFlags_NoHeaderLabel integer
--- @since 0.1
--- @field TableColumnFlags_NoHeaderWidth integer
--- @since 0.1
--- @field TableColumnFlags_NoHide integer
--- @since 0.1
--- @field TableColumnFlags_NoReorder integer
--- @since 0.1
--- @field TableColumnFlags_NoResize integer
--- @since 0.1
--- @field TableColumnFlags_NoSort integer
--- @since 0.1
--- @field TableColumnFlags_NoSortAscending integer
--- @since 0.1
--- @field TableColumnFlags_NoSortDescending integer
--- @since 0.1
--- @field TableColumnFlags_PreferSortAscending integer
--- @since 0.1
--- @field TableColumnFlags_PreferSortDescending integer
--- @since 0.1
--- @field TableColumnFlags_WidthFixed integer
--- @since 0.1
--- @field TableColumnFlags_WidthStretch integer
--- @since 0.1
--- @field TableColumnFlags_IsEnabled integer
--- @since 0.1
--- @field TableColumnFlags_IsHovered integer
--- @since 0.1
--- @field TableColumnFlags_IsSorted integer
--- @since 0.1
--- @field TableColumnFlags_IsVisible integer
--- @since 0.1
--- @field SortDirection_Ascending integer
--- @since 0.1
--- @field SortDirection_Descending integer
--- @since 0.1
--- @field SortDirection_None integer
--- @since 0.1
--- @field TableFlags_None integer
--- @since 0.1
--- @field TableFlags_NoClip integer
--- @since 0.1
--- @field TableFlags_Borders integer
--- @since 0.1
--- @field TableFlags_BordersH integer
--- @since 0.1
--- @field TableFlags_BordersInner integer
--- @since 0.1
--- @field TableFlags_BordersInnerH integer
--- @since 0.1
--- @field TableFlags_BordersInnerV integer
--- @since 0.1
--- @field TableFlags_BordersOuter integer
--- @since 0.1
--- @field TableFlags_BordersOuterH integer
--- @since 0.1
--- @field TableFlags_BordersOuterV integer
--- @since 0.1
--- @field TableFlags_BordersV integer
--- @since 0.1
--- @field TableFlags_RowBg integer
--- @since 0.1
--- @field TableFlags_ContextMenuInBody integer
--- @since 0.1
--- @field TableFlags_Hideable integer
--- @since 0.4
--- @field TableFlags_NoSavedSettings integer
--- @since 0.1
--- @field TableFlags_Reorderable integer
--- @since 0.1
--- @field TableFlags_Resizable integer
--- @since 0.1
--- @field TableFlags_Sortable integer
--- @since 0.9
--- @field TableFlags_HighlightHoveredColumn integer
--- @since 0.1
--- @field TableFlags_NoPadInnerX integer
--- @since 0.1
--- @field TableFlags_NoPadOuterX integer
--- @since 0.1
--- @field TableFlags_PadOuterX integer
--- @since 0.1
--- @field TableFlags_ScrollX integer
--- @since 0.1
--- @field TableFlags_ScrollY integer
--- @since 0.1
--- @field TableFlags_NoHostExtendX integer
--- @since 0.1
--- @field TableFlags_NoHostExtendY integer
--- @since 0.1
--- @field TableFlags_NoKeepColumnsVisible integer
--- @since 0.1
--- @field TableFlags_PreciseWidths integer
--- @since 0.1
--- @field TableFlags_SizingFixedFit integer
--- @since 0.1
--- @field TableFlags_SizingFixedSame integer
--- @since 0.1
--- @field TableFlags_SizingStretchProp integer
--- @since 0.1
--- @field TableFlags_SizingStretchSame integer
--- @since 0.1
--- @field TableFlags_SortMulti integer
--- @since 0.1
--- @field TableFlags_SortTristate integer
--- @since 0.1
--- @field InputTextFlags_None integer
--- @since 0.1
--- @field InputTextFlags_CharsDecimal integer
--- @since 0.1
--- @field InputTextFlags_CharsHexadecimal integer
--- @since 0.1
--- @field InputTextFlags_CharsNoBlank integer
--- @since 0.1
--- @field InputTextFlags_CharsScientific integer
--- @since 0.1
--- @field InputTextFlags_CharsUppercase integer
--- @since 0.8.5
--- @field InputTextFlags_CallbackAlways integer
--- @since 0.8.5
--- @field InputTextFlags_CallbackCharFilter integer
--- @since 0.8.5
--- @field InputTextFlags_CallbackCompletion integer
--- @since 0.8.5
--- @field InputTextFlags_CallbackEdit integer
--- @since 0.8.5
--- @field InputTextFlags_CallbackHistory integer
--- @since 0.1
--- @field InputTextFlags_AllowTabInput integer
--- @since 0.1
--- @field InputTextFlags_CtrlEnterForNewLine integer
--- @since 0.1
--- @field InputTextFlags_EnterReturnsTrue integer
--- @since 0.8
--- @field InputTextFlags_EscapeClearsAll integer
--- @since 0.2
--- @field InputTextFlags_AlwaysOverwrite integer
--- @since 0.1
--- @field InputTextFlags_AutoSelectAll integer
--- @since 0.9.2
--- @field InputTextFlags_DisplayEmptyRefVal integer
--- @since 0.10
--- @field InputTextFlags_ElideLeft integer
--- @since 0.1
--- @field InputTextFlags_NoHorizontalScroll integer
--- @since 0.1
--- @field InputTextFlags_NoUndoRedo integer
--- @since 0.9.2
--- @field InputTextFlags_ParseEmptyRefVal integer
--- @since 0.1
--- @field InputTextFlags_Password integer
--- @since 0.1
--- @field InputTextFlags_ReadOnly integer
--- @since 0.9
--- @field TreeNodeFlags_AllowOverlap integer
--- @since 0.1
--- @field TreeNodeFlags_Bullet integer
--- @since 0.1
--- @field TreeNodeFlags_CollapsingHeader integer
--- @since 0.1
--- @field TreeNodeFlags_DefaultOpen integer
--- @since 0.10
--- @field TreeNodeFlags_DrawLinesFull integer
--- @since 0.10
--- @field TreeNodeFlags_DrawLinesNone integer
--- @since 0.10
--- @field TreeNodeFlags_DrawLinesToNodes integer
--- @since 0.1
--- @field TreeNodeFlags_FramePadding integer
--- @since 0.1
--- @field TreeNodeFlags_Framed integer
--- @since 0.10
--- @field TreeNodeFlags_LabelSpanAllColumns integer
--- @since 0.1
--- @field TreeNodeFlags_Leaf integer
--- @since 0.10
--- @field TreeNodeFlags_NavLeftJumpsToParent integer
--- @since 0.1
--- @field TreeNodeFlags_NoAutoOpenOnLog integer
--- @since 0.1
--- @field TreeNodeFlags_NoTreePushOnOpen integer
--- @since 0.1
--- @field TreeNodeFlags_None integer
--- @since 0.1
--- @field TreeNodeFlags_OpenOnArrow integer
--- @since 0.1
--- @field TreeNodeFlags_OpenOnDoubleClick integer
--- @since 0.1
--- @field TreeNodeFlags_Selected integer
--- @since 0.9
--- @field TreeNodeFlags_SpanAllColumns integer
--- @since 0.1
--- @field TreeNodeFlags_SpanAvailWidth integer
--- @since 0.1
--- @field TreeNodeFlags_SpanFullWidth integer
--- @since 0.9.1
--- @field TreeNodeFlags_SpanLabelWidth integer
--- @since 0.1
--- @field Cond_Always integer
--- @since 0.1
--- @field Cond_Appearing integer
--- @since 0.1
--- @field Cond_FirstUseEver integer
--- @since 0.1
--- @field Cond_Once integer
--- @since 0.9
--- @field ChildFlags_AlwaysAutoResize integer
--- @since 0.9
--- @field ChildFlags_AlwaysUseWindowPadding integer
--- @since 0.9
--- @field ChildFlags_AutoResizeX integer
--- @since 0.9
--- @field ChildFlags_AutoResizeY integer
--- @since 0.10
--- @field ChildFlags_Borders integer
--- @since 0.9
--- @field ChildFlags_FrameStyle integer
--- @since 0.9.2
--- @field ChildFlags_NavFlattened integer
--- @since 0.9
--- @field ChildFlags_None integer
--- @since 0.9
--- @field ChildFlags_ResizeX integer
--- @since 0.9
--- @field ChildFlags_ResizeY integer
--- @since 0.1
--- @field WindowFlags_AlwaysAutoResize integer
--- @since 0.1
--- @field WindowFlags_AlwaysHorizontalScrollbar integer
--- @since 0.1
--- @field WindowFlags_AlwaysVerticalScrollbar integer
--- @since 0.1
--- @field WindowFlags_HorizontalScrollbar integer
--- @since 0.1
--- @field WindowFlags_MenuBar integer
--- @since 0.1
--- @field WindowFlags_NoBackground integer
--- @since 0.1
--- @field WindowFlags_NoCollapse integer
--- @since 0.1
--- @field WindowFlags_NoDecoration integer
--- @since 0.5
--- @field WindowFlags_NoDocking integer
--- @since 0.1
--- @field WindowFlags_NoFocusOnAppearing integer
--- @since 0.1
--- @field WindowFlags_NoInputs integer
--- @since 0.1
--- @field WindowFlags_NoMouseInputs integer
--- @since 0.1
--- @field WindowFlags_NoMove integer
--- @since 0.1
--- @field WindowFlags_NoNav integer
--- @since 0.1
--- @field WindowFlags_NoNavFocus integer
--- @since 0.1
--- @field WindowFlags_NoNavInputs integer
--- @since 0.1
--- @field WindowFlags_NoResize integer
--- @since 0.4
--- @field WindowFlags_NoSavedSettings integer
--- @since 0.1
--- @field WindowFlags_NoScrollWithMouse integer
--- @since 0.1
--- @field WindowFlags_NoScrollbar integer
--- @since 0.1
--- @field WindowFlags_NoTitleBar integer
--- @since 0.1
--- @field WindowFlags_None integer
--- @since 0.5.5
--- @field WindowFlags_TopMost integer
--- @since 0.1
--- @field WindowFlags_UnsavedDocument integer
--- @since 0.1
--- @field FocusedFlags_AnyWindow integer
--- @since 0.1
--- @field FocusedFlags_ChildWindows integer
--- @since 0.5.10
--- @field FocusedFlags_DockHierarchy integer
--- @since 0.5.10
--- @field FocusedFlags_NoPopupHierarchy integer
--- @since 0.1
--- @field FocusedFlags_None integer
--- @since 0.1
--- @field FocusedFlags_RootAndChildWindows integer
--- @since 0.1
--- @field FocusedFlags_RootWindow integer
local ImGui = {}
--- @alias nil​ nil
--- @class (exact) ImGui_Resource         : userdata
--- @class (exact) ImGui_DrawList         : userdata
--- @class (exact) ImGui_Viewport         : userdata
--- @class (exact) ImGui_Context          : ImGui_Resource
--- @class (exact) ImGui_DrawListSplitter : ImGui_Resource
--- @class (exact) ImGui_Font             : ImGui_Resource
--- @class (exact) ImGui_Function         : ImGui_Resource
--- @class (exact) ImGui_Image            : ImGui_Resource
--- @class (exact) ImGui_Bitmap           : ImGui_Image
--- @class (exact) ImGui_ImageSet         : ImGui_Image
--- @class (exact) ImGui_ListClipper      : ImGui_Resource
--- @class (exact) ImGui_TextFilter       : ImGui_Resource
--- @class (exact) LICE_IBitmap           : userdata
--- @diagnostic disable: keyword
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id string
--- @param dir integer
--- @return boolean retval
function ImGui.ArrowButton(ctx, str_id, dir) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param size_w? number default value = `0.0`
--- @param size_h? number default value = `0.0`
--- @return boolean retval
function ImGui.Button(ctx, label, size_w, size_h) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v boolean
--- @return boolean retval
--- @return boolean v
function ImGui.Checkbox(ctx, label, v) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param flags integer
--- @param flags_value integer
--- @return boolean retval
--- @return integer flags
function ImGui.CheckboxFlags(ctx, label, flags, flags_value) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id string
--- @param size_w number
--- @param size_h number
--- @param flags? integer default value = `ButtonFlags_None`
--- @return boolean retval
function ImGui.InvisibleButton(ctx, str_id, size_w, size_h, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param active boolean
--- @return boolean retval
function ImGui.RadioButton(ctx, label, active) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v integer
--- @param v_button integer
--- @return boolean retval
--- @return integer v
function ImGui.RadioButtonEx(ctx, label, v, v_button) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @return boolean retval
function ImGui.SmallButton(ctx, label) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param desc_id string
--- @param col_rgba integer
--- @param flags? integer default value = `ColorEditFlags_None`
--- @param size_w? number default value = `0.0`
--- @param size_h? number default value = `0.0`
--- @return boolean retval
function ImGui.ColorButton(ctx, desc_id, col_rgba, flags, size_w, size_h) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param col_rgb integer
--- @param flags? integer default value = `ColorEditFlags_None`
--- @return boolean retval
--- @return integer col_rgb
function ImGui.ColorEdit3(ctx, label, col_rgb, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param col_rgba integer
--- @param flags? integer default value = `ColorEditFlags_None`
--- @return boolean retval
--- @return integer col_rgba
function ImGui.ColorEdit4(ctx, label, col_rgba, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param col_rgb integer
--- @param flags? integer default value = `ColorEditFlags_None`
--- @return boolean retval
--- @return integer col_rgb
function ImGui.ColorPicker3(ctx, label, col_rgb, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param col_rgba integer
--- @param flags? integer default value = `ColorEditFlags_None`
--- @param ref_col? integer default value = `nil`
--- @return boolean retval
--- @return integer col_rgba
function ImGui.ColorPicker4(ctx, label, col_rgba, flags, ref_col) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param flags integer
function ImGui.SetColorEditOptions(ctx, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param preview_value string
--- @param flags? integer default value = `ComboFlags_None`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginCombo(ctx, label, preview_value, flags) end
--- @since 0.7
--- @param ctx ImGui_Context
--- @param label string
--- @param current_item integer
--- @param items string
--- @param popup_max_height_in_items? integer default value = `-1`
--- @return boolean retval
--- @return integer current_item
function ImGui.Combo(ctx, label, current_item, items, popup_max_height_in_items) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.EndCombo(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param size_w? number default value = `0.0`
--- @param size_h? number default value = `0.0`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginListBox(ctx, label, size_w, size_h) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.EndListBox(ctx) end
--- @since 0.7
--- @param ctx ImGui_Context
--- @param label string
--- @param current_item integer
--- @param items string
--- @param height_in_items? integer default value = `-1`
--- @return boolean retval
--- @return integer current_item
function ImGui.ListBox(ctx, label, current_item, items, height_in_items) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param p_selected? boolean default value = `nil`
--- @param flags? integer default value = `SelectableFlags_None`
--- @param size_w? number default value = `0.0`
--- @param size_h? number default value = `0.0`
--- @return boolean retval
--- @return boolean p_selected
function ImGui.Selectable(ctx, label, p_selected, flags, size_w, size_h) end
--- @since 0.8
--- @param ctx ImGui_Context
--- @param obj ImGui_Resource
function ImGui.Attach(ctx, obj) end
--- @since 0.10
--- @param label string
--- @param config_flags? integer default value = `ConfigFlags_None`
--- @nodiscard
--- @return ImGui_Context retval
function ImGui.CreateContext(label, config_flags) end
--- @since 0.8
--- @param ctx ImGui_Context
--- @param obj ImGui_Resource
function ImGui.Detach(ctx, obj) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetDeltaTime(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return integer retval
function ImGui.GetFrameCount(ctx) end
--- @since 0.8
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetFramerate(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetTime(ctx) end
--- @since 0.7
--- @param ctx ImGui_Context
--- @param var_idx integer
--- @return number retval
function ImGui.GetConfigVar(ctx, var_idx) end
--- @since 0.7
--- @param ctx ImGui_Context
--- @param var_idx integer
--- @param value number
function ImGui.SetConfigVar(ctx, var_idx, value) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param type string
--- @param _1? nil​
--- @param flags? integer default value = `DragDropFlags_None`
--- @return boolean retval
--- @return string payload
function ImGui.AcceptDragDropPayload(ctx, type, _1, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param _1? nil​
--- @param flags? integer default value = `DragDropFlags_None`
--- @return boolean retval
--- @return integer count
function ImGui.AcceptDragDropPayloadFiles(ctx, _1, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param _1? nil​
--- @param flags? integer default value = `DragDropFlags_None`
--- @return boolean retval
--- @return integer rgb
function ImGui.AcceptDragDropPayloadRGB(ctx, _1, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param _1? nil​
--- @param flags? integer default value = `DragDropFlags_None`
--- @return boolean retval
--- @return integer rgba
function ImGui.AcceptDragDropPayloadRGBA(ctx, _1, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param flags? integer default value = `DragDropFlags_None`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginDragDropSource(ctx, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @nodiscard
--- @return boolean retval
function ImGui.BeginDragDropTarget(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.EndDragDropSource(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.EndDragDropTarget(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
--- @return string type
--- @return string payload
--- @return boolean is_preview
--- @return boolean is_delivery
function ImGui.GetDragDropPayload(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param index integer
--- @return boolean retval
--- @return string filename
function ImGui.GetDragDropPayloadFile(ctx, index) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param type string
--- @param data string
--- @param cond? integer default value = `Cond_Always`
--- @return boolean retval
function ImGui.SetDragDropPayload(ctx, type, data, cond) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v number
--- @param v_speed? number default value = `1.0`
--- @param v_min? number default value = `0.0`
--- @param v_max? number default value = `0.0`
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v
function ImGui.DragDouble(ctx, label, v, v_speed, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 number
--- @param v2 number
--- @param v_speed? number default value = `1.0`
--- @param v_min? number default value = `0.0`
--- @param v_max? number default value = `0.0`
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v1
--- @return number v2
function ImGui.DragDouble2(ctx, label, v1, v2, v_speed, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 number
--- @param v2 number
--- @param v3 number
--- @param v_speed? number default value = `1.0`
--- @param v_min? number default value = `0.0`
--- @param v_max? number default value = `0.0`
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v1
--- @return number v2
--- @return number v3
function ImGui.DragDouble3(ctx, label, v1, v2, v3, v_speed, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 number
--- @param v2 number
--- @param v3 number
--- @param v4 number
--- @param v_speed? number default value = `1.0`
--- @param v_min? number default value = `0.0`
--- @param v_max? number default value = `0.0`
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v1
--- @return number v2
--- @return number v3
--- @return number v4
function ImGui.DragDouble4(ctx, label, v1, v2, v3, v4, v_speed, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param values reaper.array
--- @param speed? number default value = `1.0`
--- @param min? number default value = `0.0`
--- @param max? number default value = `0.0`
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
function ImGui.DragDoubleN(ctx, label, values, speed, min, max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v_current_min number
--- @param v_current_max number
--- @param v_speed? number default value = `1.0`
--- @param v_min? number default value = `0.0`
--- @param v_max? number default value = `0.0`
--- @param format? string default value = `"%.3f"`
--- @param format_max? string default value = `nil`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v_current_min
--- @return number v_current_max
function ImGui.DragFloatRange2(ctx, label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v integer
--- @param v_speed? number default value = `1.0`
--- @param v_min? integer default value = `0`
--- @param v_max? integer default value = `0`
--- @param format? string default value = `"%d"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v
function ImGui.DragInt(ctx, label, v, v_speed, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 integer
--- @param v2 integer
--- @param v_speed? number default value = `1.0`
--- @param v_min? integer default value = `0`
--- @param v_max? integer default value = `0`
--- @param format? string default value = `"%d"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v1
--- @return integer v2
function ImGui.DragInt2(ctx, label, v1, v2, v_speed, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 integer
--- @param v2 integer
--- @param v3 integer
--- @param v_speed? number default value = `1.0`
--- @param v_min? integer default value = `0`
--- @param v_max? integer default value = `0`
--- @param format? string default value = `"%d"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v1
--- @return integer v2
--- @return integer v3
function ImGui.DragInt3(ctx, label, v1, v2, v3, v_speed, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 integer
--- @param v2 integer
--- @param v3 integer
--- @param v4 integer
--- @param v_speed? number default value = `1.0`
--- @param v_min? integer default value = `0`
--- @param v_max? integer default value = `0`
--- @param format? string default value = `"%d"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v1
--- @return integer v2
--- @return integer v3
--- @return integer v4
function ImGui.DragInt4(ctx, label, v1, v2, v3, v4, v_speed, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v_current_min integer
--- @param v_current_max integer
--- @param v_speed? number default value = `1.0`
--- @param v_min? integer default value = `0`
--- @param v_max? integer default value = `0`
--- @param format? string default value = `"%d"`
--- @param format_max? string default value = `nil`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v_current_min
--- @return integer v_current_max
function ImGui.DragIntRange2(ctx, label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v_rad number
--- @param v_degrees_min? number default value = `-360.0`
--- @param v_degrees_max? number default value = `+360.0`
--- @param format? string default value = `"%.0f deg"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v_rad
function ImGui.SliderAngle(ctx, label, v_rad, v_degrees_min, v_degrees_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v number
--- @param v_min number
--- @param v_max number
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v
function ImGui.SliderDouble(ctx, label, v, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 number
--- @param v2 number
--- @param v_min number
--- @param v_max number
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v1
--- @return number v2
function ImGui.SliderDouble2(ctx, label, v1, v2, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 number
--- @param v2 number
--- @param v3 number
--- @param v_min number
--- @param v_max number
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v1
--- @return number v2
--- @return number v3
function ImGui.SliderDouble3(ctx, label, v1, v2, v3, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 number
--- @param v2 number
--- @param v3 number
--- @param v4 number
--- @param v_min number
--- @param v_max number
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v1
--- @return number v2
--- @return number v3
--- @return number v4
function ImGui.SliderDouble4(ctx, label, v1, v2, v3, v4, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param values reaper.array
--- @param v_min number
--- @param v_max number
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
function ImGui.SliderDoubleN(ctx, label, values, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v integer
--- @param v_min integer
--- @param v_max integer
--- @param format? string default value = `"%d"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v
function ImGui.SliderInt(ctx, label, v, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 integer
--- @param v2 integer
--- @param v_min integer
--- @param v_max integer
--- @param format? string default value = `"%d"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v1
--- @return integer v2
function ImGui.SliderInt2(ctx, label, v1, v2, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 integer
--- @param v2 integer
--- @param v3 integer
--- @param v_min integer
--- @param v_max integer
--- @param format? string default value = `"%d"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v1
--- @return integer v2
--- @return integer v3
function ImGui.SliderInt3(ctx, label, v1, v2, v3, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 integer
--- @param v2 integer
--- @param v3 integer
--- @param v4 integer
--- @param v_min integer
--- @param v_max integer
--- @param format? string default value = `"%d"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v1
--- @return integer v2
--- @return integer v3
--- @return integer v4
function ImGui.SliderInt4(ctx, label, v1, v2, v3, v4, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param size_w number
--- @param size_h number
--- @param v number
--- @param v_min number
--- @param v_max number
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return number v
function ImGui.VSliderDouble(ctx, label, size_w, size_h, v, v_min, v_max, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param size_w number
--- @param size_h number
--- @param v integer
--- @param v_min integer
--- @param v_max integer
--- @param format? string default value = `"%d"`
--- @param flags? integer default value = `SliderFlags_None`
--- @return boolean retval
--- @return integer v
function ImGui.VSliderInt(ctx, label, size_w, size_h, v, v_min, v_max, format, flags) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
function ImGui.DrawList_PopClipRect(draw_list) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param clip_rect_min_x number
--- @param clip_rect_min_y number
--- @param clip_rect_max_x number
--- @param clip_rect_max_y number
--- @param intersect_with_current_clip_rect? boolean default value = `false`
function ImGui.DrawList_PushClipRect(draw_list, clip_rect_min_x, clip_rect_min_y, clip_rect_max_x, clip_rect_max_y, intersect_with_current_clip_rect) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
function ImGui.DrawList_PushClipRectFullScreen(draw_list) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return ImGui_DrawList retval
function ImGui.GetBackgroundDrawList(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return ImGui_DrawList retval
function ImGui.GetForegroundDrawList(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return ImGui_DrawList retval
function ImGui.GetWindowDrawList(ctx) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p1_x number
--- @param p1_y number
--- @param p2_x number
--- @param p2_y number
--- @param p3_x number
--- @param p3_y number
--- @param p4_x number
--- @param p4_y number
--- @param col_rgba integer
--- @param thickness number
--- @param num_segments? integer default value = `0`
function ImGui.DrawList_AddBezierCubic(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, col_rgba, thickness, num_segments) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p1_x number
--- @param p1_y number
--- @param p2_x number
--- @param p2_y number
--- @param p3_x number
--- @param p3_y number
--- @param col_rgba integer
--- @param thickness number
--- @param num_segments? integer default value = `0`
function ImGui.DrawList_AddBezierQuadratic(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, col_rgba, thickness, num_segments) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param center_x number
--- @param center_y number
--- @param radius number
--- @param col_rgba integer
--- @param num_segments? integer default value = `0`
--- @param thickness? number default value = `1.0`
function ImGui.DrawList_AddCircle(draw_list, center_x, center_y, radius, col_rgba, num_segments, thickness) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param center_x number
--- @param center_y number
--- @param radius number
--- @param col_rgba integer
--- @param num_segments? integer default value = `0`
function ImGui.DrawList_AddCircleFilled(draw_list, center_x, center_y, radius, col_rgba, num_segments) end
--- @since 0.9
--- @param draw_list ImGui_DrawList
--- @param points reaper.array
--- @param col_rgba integer
function ImGui.DrawList_AddConcavePolyFilled(draw_list, points, col_rgba) end
--- @since 0.6
--- @param draw_list ImGui_DrawList
--- @param points reaper.array
--- @param col_rgba integer
function ImGui.DrawList_AddConvexPolyFilled(draw_list, points, col_rgba) end
--- @since 0.9
--- @param draw_list ImGui_DrawList
--- @param center_x number
--- @param center_y number
--- @param radius_x number
--- @param radius_y number
--- @param col_rgba integer
--- @param rot? number default value = `0.0`
--- @param num_segments? integer default value = `0`
--- @param thickness? number default value = `1.0`
function ImGui.DrawList_AddEllipse(draw_list, center_x, center_y, radius_x, radius_y, col_rgba, rot, num_segments, thickness) end
--- @since 0.9
--- @param draw_list ImGui_DrawList
--- @param center_x number
--- @param center_y number
--- @param radius_x number
--- @param radius_y number
--- @param col_rgba integer
--- @param rot? number default value = `0.0`
--- @param num_segments? integer default value = `0`
function ImGui.DrawList_AddEllipseFilled(draw_list, center_x, center_y, radius_x, radius_y, col_rgba, rot, num_segments) end
--- @since 0.8
--- @param draw_list ImGui_DrawList
--- @param image ImGui_Image
--- @param p_min_x number
--- @param p_min_y number
--- @param p_max_x number
--- @param p_max_y number
--- @param uv_min_x? number default value = `0.0`
--- @param uv_min_y? number default value = `0.0`
--- @param uv_max_x? number default value = `1.0`
--- @param uv_max_y? number default value = `1.0`
--- @param col_rgba? integer default value = `0xFFFFFFFF`
function ImGui.DrawList_AddImage(draw_list, image, p_min_x, p_min_y, p_max_x, p_max_y, uv_min_x, uv_min_y, uv_max_x, uv_max_y, col_rgba) end
--- @since 0.8
--- @param draw_list ImGui_DrawList
--- @param image ImGui_Image
--- @param p1_x number
--- @param p1_y number
--- @param p2_x number
--- @param p2_y number
--- @param p3_x number
--- @param p3_y number
--- @param p4_x number
--- @param p4_y number
--- @param uv1_x? number default value = `0.0`
--- @param uv1_y? number default value = `0.0`
--- @param uv2_x? number default value = `1.0`
--- @param uv2_y? number default value = `0.0`
--- @param uv3_x? number default value = `1.0`
--- @param uv3_y? number default value = `1.0`
--- @param uv4_x? number default value = `0.0`
--- @param uv4_y? number default value = `1.0`
--- @param col_rgba? integer default value = `0xFFFFFFFF`
function ImGui.DrawList_AddImageQuad(draw_list, image, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, uv1_x, uv1_y, uv2_x, uv2_y, uv3_x, uv3_y, uv4_x, uv4_y, col_rgba) end
--- @since 0.8
--- @param draw_list ImGui_DrawList
--- @param image ImGui_Image
--- @param p_min_x number
--- @param p_min_y number
--- @param p_max_x number
--- @param p_max_y number
--- @param uv_min_x number
--- @param uv_min_y number
--- @param uv_max_x number
--- @param uv_max_y number
--- @param col_rgba integer
--- @param rounding number
--- @param flags? integer default value = `DrawFlags_None`
function ImGui.DrawList_AddImageRounded(draw_list, image, p_min_x, p_min_y, p_max_x, p_max_y, uv_min_x, uv_min_y, uv_max_x, uv_max_y, col_rgba, rounding, flags) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p1_x number
--- @param p1_y number
--- @param p2_x number
--- @param p2_y number
--- @param col_rgba integer
--- @param thickness? number default value = `1.0`
function ImGui.DrawList_AddLine(draw_list, p1_x, p1_y, p2_x, p2_y, col_rgba, thickness) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param center_x number
--- @param center_y number
--- @param radius number
--- @param col_rgba integer
--- @param num_segments integer
--- @param thickness? number default value = `1.0`
function ImGui.DrawList_AddNgon(draw_list, center_x, center_y, radius, col_rgba, num_segments, thickness) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param center_x number
--- @param center_y number
--- @param radius number
--- @param col_rgba integer
--- @param num_segments integer
function ImGui.DrawList_AddNgonFilled(draw_list, center_x, center_y, radius, col_rgba, num_segments) end
--- @since 0.2
--- @param draw_list ImGui_DrawList
--- @param points reaper.array
--- @param col_rgba integer
--- @param flags integer
--- @param thickness number
function ImGui.DrawList_AddPolyline(draw_list, points, col_rgba, flags, thickness) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p1_x number
--- @param p1_y number
--- @param p2_x number
--- @param p2_y number
--- @param p3_x number
--- @param p3_y number
--- @param p4_x number
--- @param p4_y number
--- @param col_rgba integer
--- @param thickness? number default value = `1.0`
function ImGui.DrawList_AddQuad(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, col_rgba, thickness) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p1_x number
--- @param p1_y number
--- @param p2_x number
--- @param p2_y number
--- @param p3_x number
--- @param p3_y number
--- @param p4_x number
--- @param p4_y number
--- @param col_rgba integer
function ImGui.DrawList_AddQuadFilled(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, col_rgba) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p_min_x number
--- @param p_min_y number
--- @param p_max_x number
--- @param p_max_y number
--- @param col_rgba integer
--- @param rounding? number default value = `0.0`
--- @param flags? integer default value = `DrawFlags_None`
--- @param thickness? number default value = `1.0`
function ImGui.DrawList_AddRect(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, col_rgba, rounding, flags, thickness) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p_min_x number
--- @param p_min_y number
--- @param p_max_x number
--- @param p_max_y number
--- @param col_rgba integer
--- @param rounding? number default value = `0.0`
--- @param flags? integer default value = `DrawFlags_None`
function ImGui.DrawList_AddRectFilled(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, col_rgba, rounding, flags) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p_min_x number
--- @param p_min_y number
--- @param p_max_x number
--- @param p_max_y number
--- @param col_upr_left integer
--- @param col_upr_right integer
--- @param col_bot_right integer
--- @param col_bot_left integer
function ImGui.DrawList_AddRectFilledMultiColor(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, col_upr_left, col_upr_right, col_bot_right, col_bot_left) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param x number
--- @param y number
--- @param col_rgba integer
--- @param text string
function ImGui.DrawList_AddText(draw_list, x, y, col_rgba, text) end
--- @since 0.4
--- @param draw_list ImGui_DrawList
--- @param font ImGui_Font|nil
--- @param font_size number
--- @param pos_x number
--- @param pos_y number
--- @param col_rgba integer
--- @param text string
--- @param wrap_width? number default value = `0.0`
--- @param cpu_fine_clip_rect_min_x? number default value = `nil`
--- @param cpu_fine_clip_rect_min_y? number default value = `nil`
--- @param cpu_fine_clip_rect_max_x? number default value = `nil`
--- @param cpu_fine_clip_rect_max_y? number default value = `nil`
function ImGui.DrawList_AddTextEx(draw_list, font, font_size, pos_x, pos_y, col_rgba, text, wrap_width, cpu_fine_clip_rect_min_x, cpu_fine_clip_rect_min_y, cpu_fine_clip_rect_max_x, cpu_fine_clip_rect_max_y) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p1_x number
--- @param p1_y number
--- @param p2_x number
--- @param p2_y number
--- @param p3_x number
--- @param p3_y number
--- @param col_rgba integer
--- @param thickness? number default value = `1.0`
function ImGui.DrawList_AddTriangle(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, col_rgba, thickness) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p1_x number
--- @param p1_y number
--- @param p2_x number
--- @param p2_y number
--- @param p3_x number
--- @param p3_y number
--- @param col_rgba integer
function ImGui.DrawList_AddTriangleFilled(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, col_rgba) end
--- @since 0.9
--- @param draw_list ImGui_DrawList
--- @nodiscard
--- @return ImGui_DrawListSplitter retval
function ImGui.CreateDrawListSplitter(draw_list) end
--- @since 0.7.1
--- @param splitter ImGui_DrawListSplitter
function ImGui.DrawListSplitter_Clear(splitter) end
--- @since 0.7.1
--- @param splitter ImGui_DrawListSplitter
function ImGui.DrawListSplitter_Merge(splitter) end
--- @since 0.7.1
--- @param splitter ImGui_DrawListSplitter
--- @param channel_idx integer
function ImGui.DrawListSplitter_SetCurrentChannel(splitter, channel_idx) end
--- @since 0.7.1
--- @param splitter ImGui_DrawListSplitter
--- @param count integer
function ImGui.DrawListSplitter_Split(splitter, count) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param center_x number
--- @param center_y number
--- @param radius number
--- @param a_min number
--- @param a_max number
--- @param num_segments? integer default value = `0`
function ImGui.DrawList_PathArcTo(draw_list, center_x, center_y, radius, a_min, a_max, num_segments) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param center_x number
--- @param center_y number
--- @param radius number
--- @param a_min_of_12 integer
--- @param a_max_of_12 integer
function ImGui.DrawList_PathArcToFast(draw_list, center_x, center_y, radius, a_min_of_12, a_max_of_12) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p2_x number
--- @param p2_y number
--- @param p3_x number
--- @param p3_y number
--- @param p4_x number
--- @param p4_y number
--- @param num_segments? integer default value = `0`
function ImGui.DrawList_PathBezierCubicCurveTo(draw_list, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, num_segments) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param p2_x number
--- @param p2_y number
--- @param p3_x number
--- @param p3_y number
--- @param num_segments? integer default value = `0`
function ImGui.DrawList_PathBezierQuadraticCurveTo(draw_list, p2_x, p2_y, p3_x, p3_y, num_segments) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
function ImGui.DrawList_PathClear(draw_list) end
--- @since 0.9
--- @param draw_list ImGui_DrawList
--- @param center_x number
--- @param center_y number
--- @param radius_x number
--- @param radius_y number
--- @param rot number
--- @param a_min number
--- @param a_max number
--- @param num_segments? integer default value = `0`
function ImGui.DrawList_PathEllipticalArcTo(draw_list, center_x, center_y, radius_x, radius_y, rot, a_min, a_max, num_segments) end
--- @since 0.9
--- @param draw_list ImGui_DrawList
--- @param col_rgba integer
function ImGui.DrawList_PathFillConcave(draw_list, col_rgba) end
--- @since 0.5.1
--- @param draw_list ImGui_DrawList
--- @param col_rgba integer
function ImGui.DrawList_PathFillConvex(draw_list, col_rgba) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param pos_x number
--- @param pos_y number
function ImGui.DrawList_PathLineTo(draw_list, pos_x, pos_y) end
--- @since 0.1
--- @param draw_list ImGui_DrawList
--- @param rect_min_x number
--- @param rect_min_y number
--- @param rect_max_x number
--- @param rect_max_y number
--- @param rounding? number default value = `0.0`
--- @param flags? integer default value = `DrawFlags_None`
function ImGui.DrawList_PathRect(draw_list, rect_min_x, rect_min_y, rect_max_x, rect_max_y, rounding, flags) end
--- @since 0.2
--- @param draw_list ImGui_DrawList
--- @param col_rgba integer
--- @param flags? integer default value = `DrawFlags_None`
--- @param thickness? number default value = `1.0`
function ImGui.DrawList_PathStroke(draw_list, col_rgba, flags, thickness) end
--- @since 0.10
--- @param family string
--- @param flags? integer default value = `FontFlags_None`
--- @nodiscard
--- @return ImGui_Font retval
function ImGui.CreateFont(family, flags) end
--- @since 0.10
--- @param file string
--- @param index? integer default value = `0`
--- @param flags? integer default value = `FontFlags_None`
--- @nodiscard
--- @return ImGui_Font retval
function ImGui.CreateFontFromFile(file, index, flags) end
--- @since 0.10
--- @param data string
--- @param index? integer default value = `0`
--- @param flags? integer default value = `FontFlags_None`
--- @nodiscard
--- @return ImGui_Font retval
function ImGui.CreateFontFromMem(data, index, flags) end
--- @since 0.4
--- @param ctx ImGui_Context
--- @return ImGui_Font retval
function ImGui.GetFont(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetFontSize(ctx) end
--- @since 0.4
--- @param ctx ImGui_Context
function ImGui.PopFont(ctx) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param font ImGui_Font|nil
--- @param font_size_base_unscaled number
function ImGui.PushFont(ctx, font, font_size_base_unscaled) end
--- @since 0.9
--- @param code string
--- @nodiscard
--- @return ImGui_Function retval
function ImGui.CreateFunctionFromEEL(code) end
--- @since 0.8.5
--- @param func ImGui_Function
function ImGui.Function_Execute(func) end
--- @since 0.8.5
--- @param func ImGui_Function
--- @param name string
--- @return number retval
function ImGui.Function_GetValue(func, name) end
--- @since 0.8.5
--- @param func ImGui_Function
--- @param name string
--- @param values reaper.array
function ImGui.Function_GetValue_Array(func, name, values) end
--- @since 0.8.5
--- @param func ImGui_Function
--- @param name string
--- @return string value
function ImGui.Function_GetValue_String(func, name) end
--- @since 0.8.5
--- @param func ImGui_Function
--- @param name string
--- @param value number
function ImGui.Function_SetValue(func, name, value) end
--- @since 0.8.5
--- @param func ImGui_Function
--- @param name string
--- @param values reaper.array
function ImGui.Function_SetValue_Array(func, name, values) end
--- @since 0.8.5
--- @param func ImGui_Function
--- @param name string
--- @param value string
function ImGui.Function_SetValue_String(func, name, value) end
--- @since 0.9
--- @param file string
--- @param flags? integer default value = `ImageFlags_None`
--- @nodiscard
--- @return ImGui_Image retval
function ImGui.CreateImage(file, flags) end
--- @since 0.9.2
--- @param bitmap LICE_IBitmap
--- @param flags? integer default value = `ImageFlags_None`
--- @nodiscard
--- @return ImGui_Image retval
function ImGui.CreateImageFromLICE(bitmap, flags) end
--- @since 0.9
--- @param data string
--- @param flags? integer default value = `ImageFlags_None`
--- @nodiscard
--- @return ImGui_Image retval
function ImGui.CreateImageFromMem(data, flags) end
--- @since 0.10
--- @param width integer
--- @param height integer
--- @param flags? integer default value = `ImageFlags_None`
--- @nodiscard
--- @return ImGui_Image retval
function ImGui.CreateImageFromSize(width, height, flags) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param image ImGui_Image
--- @param image_size_w number
--- @param image_size_h number
--- @param uv0_x? number default value = `0.0`
--- @param uv0_y? number default value = `0.0`
--- @param uv1_x? number default value = `1.0`
--- @param uv1_y? number default value = `1.0`
function ImGui.Image(ctx, image, image_size_w, image_size_h, uv0_x, uv0_y, uv1_x, uv1_y) end
--- @since 0.8
--- @param ctx ImGui_Context
--- @param str_id string
--- @param image ImGui_Image
--- @param image_size_w number
--- @param image_size_h number
--- @param uv0_x? number default value = `0.0`
--- @param uv0_y? number default value = `0.0`
--- @param uv1_x? number default value = `1.0`
--- @param uv1_y? number default value = `1.0`
--- @param bg_col_rgba? integer default value = `0x00000000`
--- @param tint_col_rgba? integer default value = `0xFFFFFFFF`
--- @return boolean retval
function ImGui.ImageButton(ctx, str_id, image, image_size_w, image_size_h, uv0_x, uv0_y, uv1_x, uv1_y, bg_col_rgba, tint_col_rgba) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param image ImGui_Image
--- @param image_size_w number
--- @param image_size_h number
--- @param uv0_x? number default value = `0.0`
--- @param uv0_y? number default value = `0.0`
--- @param uv1_x? number default value = `1.0`
--- @param uv1_y? number default value = `1.0`
--- @param bg_col_rgba? integer default value = `0x00000000`
--- @param tint_col_rgba? integer default value = `0xFFFFFFFF`
function ImGui.ImageWithBg(ctx, image, image_size_w, image_size_h, uv0_x, uv0_y, uv1_x, uv1_y, bg_col_rgba, tint_col_rgba) end
--- @since 0.10
--- @param image ImGui_Bitmap
--- @param x integer
--- @param y integer
--- @param w integer
--- @param h integer
--- @param pixels reaper.array
--- @param offset? integer default value = `0`
--- @param pitch? integer default value = `0`
function ImGui.Image_GetPixels_Array(image, x, y, w, h, pixels, offset, pitch) end
--- @since 0.8
--- @param image ImGui_Image
--- @return number w
--- @return number h
function ImGui.Image_GetSize(image) end
--- @since 0.10
--- @param image ImGui_Bitmap
--- @param x integer
--- @param y integer
--- @param w integer
--- @param h integer
--- @param pixels reaper.array
--- @param offset? integer default value = `0`
--- @param pitch? integer default value = `0`
function ImGui.Image_SetPixels_Array(image, x, y, w, h, pixels, offset, pitch) end
--- @since 0.9
--- @nodiscard
--- @return ImGui_ImageSet retval
function ImGui.CreateImageSet() end
--- @since 0.8
--- @param set ImGui_ImageSet
--- @param scale number
--- @param image ImGui_Image
function ImGui.ImageSet_Add(set, scale, image) end
--- @since 0.5.5
--- @param ctx ImGui_Context
--- @param disabled? boolean default value = `true`
function ImGui.BeginDisabled(ctx, disabled) end
--- @since 0.9
--- @param ctx ImGui_Context
function ImGui.DebugStartItemPicker(ctx) end
--- @since 0.5.5
--- @param ctx ImGui_Context
function ImGui.EndDisabled(ctx) end
--- @since 0.10
--- @param ctx ImGui_Context
function ImGui.PopItemFlag(ctx) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param option integer
--- @param enabled boolean
function ImGui.PushItemFlag(ctx, option, enabled) end
--- @since 0.9
--- @param ctx ImGui_Context
function ImGui.SetNextItemAllowOverlap(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.CalcItemWidth(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetItemRectMax(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetItemRectMin(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number w
--- @return number h
function ImGui.GetItemRectSize(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.PopItemWidth(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param item_width number
function ImGui.PushItemWidth(ctx, item_width) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param item_width number
function ImGui.SetNextItemWidth(ctx, item_width) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.SetItemDefaultFocus(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param offset? integer default value = `0`
function ImGui.SetKeyboardFocusHere(ctx, offset) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param visible boolean
function ImGui.SetNavCursorVisible(ctx, visible) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsAnyItemActive(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsAnyItemFocused(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsAnyItemHovered(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsItemActivated(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsItemActive(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param mouse_button? integer default value = `MouseButton_Left`
--- @return boolean retval
function ImGui.IsItemClicked(ctx, mouse_button) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsItemDeactivated(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsItemDeactivatedAfterEdit(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsItemEdited(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsItemFocused(ctx) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param flags? integer default value = `HoveredFlags_None`
--- @return boolean retval
function ImGui.IsItemHovered(ctx, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsItemVisible(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param idx integer
--- @return boolean retval
--- @return integer unicode_char
function ImGui.GetInputQueueCharacter(ctx, idx) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param key integer
--- @return number retval
function ImGui.GetKeyDownDuration(ctx, key) end
--- @since 0.8
--- @param ctx ImGui_Context
--- @return integer retval
function ImGui.GetKeyMods(ctx) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param key integer
--- @param repeat_delay number
--- @param rate number
--- @return integer retval
function ImGui.GetKeyPressedAmount(ctx, key, repeat_delay, rate) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param key integer
--- @return boolean retval
function ImGui.IsKeyDown(ctx, key) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param key integer
--- @param repeat? boolean default value = `true`
--- @return boolean retval
function ImGui.IsKeyPressed(ctx, key, repeat) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param key integer
--- @return boolean retval
function ImGui.IsKeyReleased(ctx, key) end
--- @since 0.7
--- @param ctx ImGui_Context
--- @param want_capture_keyboard boolean
function ImGui.SetNextFrameWantCaptureKeyboard(ctx, want_capture_keyboard) end
--- @since 0.5.10
--- @param ctx ImGui_Context
--- @param button integer
--- @return integer retval
function ImGui.GetMouseClickedCount(ctx, button) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param button integer
--- @return number x
--- @return number y
function ImGui.GetMouseClickedPos(ctx, button) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetMouseDelta(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param button integer
--- @return number retval
function ImGui.GetMouseDownDuration(ctx, button) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param _1? nil​
--- @param _2? nil​
--- @param button? integer default value = `MouseButton_Left`
--- @param lock_threshold? number default value = `-1.0`
--- @return number x
--- @return number y
function ImGui.GetMouseDragDelta(ctx, _1, _2, button, lock_threshold) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetMousePos(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetMousePosOnOpeningCurrentPopup(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number vertical
--- @return number horizontal
function ImGui.GetMouseWheel(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsAnyMouseDown(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param button integer
--- @param repeat? boolean default value = `false`
--- @return boolean retval
function ImGui.IsMouseClicked(ctx, button, repeat) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param button integer
--- @return boolean retval
function ImGui.IsMouseDoubleClicked(ctx, button) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param button integer
--- @return boolean retval
function ImGui.IsMouseDown(ctx, button) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param button integer
--- @param lock_threshold? number default value = `-1.0`
--- @return boolean retval
function ImGui.IsMouseDragging(ctx, button, lock_threshold) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param r_min_x number
--- @param r_min_y number
--- @param r_max_x number
--- @param r_max_y number
--- @param clip? boolean default value = `true`
--- @return boolean retval
function ImGui.IsMouseHoveringRect(ctx, r_min_x, r_min_y, r_max_x, r_max_y, clip) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param mouse_pos_x? number default value = `nil`
--- @param mouse_pos_y? number default value = `nil`
--- @return boolean retval
function ImGui.IsMousePosValid(ctx, mouse_pos_x, mouse_pos_y) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param button integer
--- @return boolean retval
function ImGui.IsMouseReleased(ctx, button) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param button integer
--- @param delay number
--- @return boolean retval
function ImGui.IsMouseReleasedWithDelay(ctx, button, delay) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param button? integer default value = `MouseButton_Left`
function ImGui.ResetMouseDragDelta(ctx, button) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return integer retval
function ImGui.GetMouseCursor(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param cursor_type integer
function ImGui.SetMouseCursor(ctx, cursor_type) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param key_chord integer
--- @return boolean retval
function ImGui.IsKeyChordPressed(ctx, key_chord) end
--- @since 0.9.2
--- @param ctx ImGui_Context
--- @param key_chord integer
--- @param flags? integer default value = `InputFlags_None`
function ImGui.SetNextItemShortcut(ctx, key_chord, flags) end
--- @since 0.9.2
--- @param ctx ImGui_Context
--- @param key_chord integer
--- @param flags? integer default value = `InputFlags_None`
--- @return boolean retval
function ImGui.Shortcut(ctx, key_chord, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.BeginGroup(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param size_w number
--- @param size_h number
function ImGui.Dummy(ctx, size_w, size_h) end
--- @since 0.8
--- @param ctx ImGui_Context
function ImGui.EndGroup(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param indent_w? number default value = `0.0`
function ImGui.Indent(ctx, indent_w) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.NewLine(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param offset_from_start_x? number default value = `0.0`
--- @param spacing? number default value = `-1.0`
function ImGui.SameLine(ctx, offset_from_start_x, spacing) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.Separator(ctx) end
--- @since 0.8.4
--- @param ctx ImGui_Context
--- @param label string
function ImGui.SeparatorText(ctx, label) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.Spacing(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param indent_w? number default value = `0.0`
function ImGui.Unindent(ctx, indent_w) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param size_w number
--- @param size_h number
--- @return boolean retval
function ImGui.IsRectVisible(ctx, size_w, size_h) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param rect_min_x number
--- @param rect_min_y number
--- @param rect_max_x number
--- @param rect_max_y number
--- @return boolean retval
function ImGui.IsRectVisibleEx(ctx, rect_min_x, rect_min_y, rect_max_x, rect_max_y) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.PopClipRect(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param clip_rect_min_x number
--- @param clip_rect_min_y number
--- @param clip_rect_max_x number
--- @param clip_rect_max_y number
--- @param intersect_with_current_clip_rect boolean
function ImGui.PushClipRect(ctx, clip_rect_min_x, clip_rect_min_y, clip_rect_max_x, clip_rect_max_y, intersect_with_current_clip_rect) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetContentRegionAvail(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetCursorPos(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetCursorPosX(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetCursorPosY(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetCursorScreenPos(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetCursorStartPos(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param local_pos_x number
--- @param local_pos_y number
function ImGui.SetCursorPos(ctx, local_pos_x, local_pos_y) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param local_x number
function ImGui.SetCursorPosX(ctx, local_x) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param local_y number
function ImGui.SetCursorPosY(ctx, local_y) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param pos_x number
--- @param pos_y number
function ImGui.SetCursorScreenPos(ctx, pos_x, pos_y) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @nodiscard
--- @return ImGui_ListClipper retval
function ImGui.CreateListClipper(ctx) end
--- @since 0.1
--- @param clipper ImGui_ListClipper
--- @param items_count integer
--- @param items_height? number default value = `-1.0`
function ImGui.ListClipper_Begin(clipper, items_count, items_height) end
--- @since 0.1
--- @param clipper ImGui_ListClipper
function ImGui.ListClipper_End(clipper) end
--- @since 0.3
--- @param clipper ImGui_ListClipper
--- @return integer display_start
--- @return integer display_end
function ImGui.ListClipper_GetDisplayRange(clipper) end
--- @since 0.9
--- @param clipper ImGui_ListClipper
--- @param item_index integer
function ImGui.ListClipper_IncludeItemByIndex(clipper, item_index) end
--- @since 0.9
--- @param clipper ImGui_ListClipper
--- @param item_begin integer
--- @param item_end integer
function ImGui.ListClipper_IncludeItemsByIndex(clipper, item_begin, item_end) end
--- @since 0.10
--- @param clipper ImGui_ListClipper
--- @param items_count integer
function ImGui.ListClipper_SeekCursorForItem(clipper, items_count) end
--- @since 0.1
--- @param clipper ImGui_ListClipper
--- @return boolean retval
function ImGui.ListClipper_Step(clipper) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param enabled? boolean default value = `true`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginMenu(ctx, label, enabled) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @nodiscard
--- @return boolean retval
function ImGui.BeginMenuBar(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.EndMenu(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.EndMenuBar(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param shortcut? string default value = `nil`
--- @param p_selected? boolean default value = `nil`
--- @param enabled? boolean default value = `true`
--- @return boolean retval
--- @return boolean p_selected
function ImGui.MenuItem(ctx, label, shortcut, p_selected, enabled) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param values reaper.array
--- @param values_offset? integer default value = `0`
--- @param overlay_text? string default value = `nil`
--- @param scale_min? number default value = `FLT_MAX`
--- @param scale_max? number default value = `FLT_MAX`
--- @param graph_size_w? number default value = `0.0`
--- @param graph_size_h? number default value = `0.0`
function ImGui.PlotHistogram(ctx, label, values, values_offset, overlay_text, scale_min, scale_max, graph_size_w, graph_size_h) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param values reaper.array
--- @param values_offset? integer default value = `0`
--- @param overlay_text? string default value = `nil`
--- @param scale_min? number default value = `FLT_MAX`
--- @param scale_max? number default value = `FLT_MAX`
--- @param graph_size_w? number default value = `0.0`
--- @param graph_size_h? number default value = `0.0`
function ImGui.PlotLines(ctx, label, values, values_offset, overlay_text, scale_min, scale_max, graph_size_w, graph_size_h) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id string
--- @param flags? integer default value = `WindowFlags_None`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginPopup(ctx, str_id, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param name string
--- @param p_open? boolean default value = `nil`
--- @param flags? integer default value = `WindowFlags_None`
--- @nodiscard
--- @return boolean retval
--- @return boolean p_open
function ImGui.BeginPopupModal(ctx, name, p_open, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.CloseCurrentPopup(ctx) end
--- @since 0.8
--- @param ctx ImGui_Context
function ImGui.EndPopup(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id string
--- @param flags? integer default value = `PopupFlags_None`
--- @return boolean retval
function ImGui.IsPopupOpen(ctx, str_id, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id string
--- @param popup_flags? integer default value = `PopupFlags_None`
function ImGui.OpenPopup(ctx, str_id, popup_flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id? string default value = `nil`
--- @param popup_flags? integer default value = `PopupFlags_MouseButtonRight`
function ImGui.OpenPopupOnItemClick(ctx, str_id, popup_flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id? string default value = `nil`
--- @param popup_flags? integer default value = `PopupFlags_MouseButtonRight`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginPopupContextItem(ctx, str_id, popup_flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id? string default value = `nil`
--- @param popup_flags? integer default value = `PopupFlags_MouseButtonRight`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginPopupContextWindow(ctx, str_id, popup_flags) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @nodiscard
--- @return boolean retval
function ImGui.BeginItemTooltip(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @nodiscard
--- @return boolean retval
function ImGui.BeginTooltip(ctx) end
--- @since 0.8
--- @param ctx ImGui_Context
function ImGui.EndTooltip(ctx) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param text string
function ImGui.SetItemTooltip(ctx, text) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param text string
function ImGui.SetTooltip(ctx, text) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param idx integer
function ImGui.DebugFlashStyleColor(ctx, idx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param idx integer
--- @param alpha_mul? number default value = `1.0`
--- @return integer retval
function ImGui.GetColor(ctx, idx, alpha_mul) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param col_rgba integer
--- @param alpha_mul? number default value = `1.0`
--- @return integer retval
function ImGui.GetColorEx(ctx, col_rgba, alpha_mul) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param idx integer
--- @return integer retval
function ImGui.GetStyleColor(ctx, idx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param count? integer default value = `1`
function ImGui.PopStyleColor(ctx, count) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param idx integer
--- @param col_rgba integer
function ImGui.PushStyleColor(ctx, idx, col_rgba) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param var_idx integer
--- @return number val1
--- @return number val2
function ImGui.GetStyleVar(ctx, var_idx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param count? integer default value = `1`
function ImGui.PopStyleVar(ctx, count) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param idx integer
--- @param val1 number
--- @param val2? number default value = `nil`
function ImGui.PushStyleVar(ctx, idx, val1, val2) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param idx integer
--- @param val_x number
function ImGui.PushStyleVarX(ctx, idx, val_x) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param idx integer
--- @param val_y number
function ImGui.PushStyleVarY(ctx, idx, val_y) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id string
--- @param flags? integer default value = `TabBarFlags_None`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginTabBar(ctx, str_id, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.EndTabBar(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param p_open? boolean default value = `nil`
--- @param flags? integer default value = `TabItemFlags_None`
--- @nodiscard
--- @return boolean retval
--- @return boolean p_open
function ImGui.BeginTabItem(ctx, label, p_open, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.EndTabItem(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param tab_or_docked_window_label string
function ImGui.SetTabItemClosed(ctx, tab_or_docked_window_label) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param flags? integer default value = `TabItemFlags_None`
--- @return boolean retval
function ImGui.TabItemButton(ctx, label, flags) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param str_id string
--- @param columns integer
--- @param flags? integer default value = `TableFlags_None`
--- @param outer_size_w? number default value = `0.0`
--- @param outer_size_h? number default value = `0.0`
--- @param inner_width? number default value = `0.0`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginTable(ctx, str_id, columns, flags, outer_size_w, outer_size_h, inner_width) end
--- @since 0.8
--- @param ctx ImGui_Context
function ImGui.EndTable(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return integer retval
function ImGui.TableGetColumnCount(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return integer retval
function ImGui.TableGetColumnIndex(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return integer retval
function ImGui.TableGetRowIndex(ctx) end
--- @since 0.8
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.TableNextColumn(ctx) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param row_flags? integer default value = `TableRowFlags_None`
--- @param min_row_height? number default value = `0.0`
function ImGui.TableNextRow(ctx, row_flags, min_row_height) end
--- @since 0.8
--- @param ctx ImGui_Context
--- @param column_n integer
--- @return boolean retval
function ImGui.TableSetColumnIndex(ctx, column_n) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param target integer
--- @param color_rgba integer
--- @param column_n? integer default value = `-1`
function ImGui.TableSetBgColor(ctx, target, color_rgba, column_n) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.TableAngledHeadersRow(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param column_n? integer default value = `-1`
--- @return integer retval
function ImGui.TableGetColumnFlags(ctx, column_n) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param column_n? integer default value = `-1`
--- @return string retval
function ImGui.TableGetColumnName(ctx, column_n) end
--- @since 0.9.2
--- @param ctx ImGui_Context
--- @return integer retval
function ImGui.TableGetHoveredColumn(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
function ImGui.TableHeader(ctx, label) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.TableHeadersRow(ctx) end
--- @since 0.4.1
--- @param ctx ImGui_Context
--- @param column_n integer
--- @param v boolean
function ImGui.TableSetColumnEnabled(ctx, column_n, v) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param flags? integer default value = `TableColumnFlags_None`
--- @param init_width_or_weight? number default value = `0.0`
--- @param user_id? integer default value = `0`
function ImGui.TableSetupColumn(ctx, label, flags, init_width_or_weight, user_id) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param cols integer
--- @param rows integer
function ImGui.TableSetupScrollFreeze(ctx, cols, rows) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param id integer
--- @return boolean retval
--- @return integer column_index
--- @return integer column_user_id
--- @return integer sort_direction
function ImGui.TableGetColumnSortSpecs(ctx, id) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
--- @return boolean has_specs
function ImGui.TableNeedSort(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.AlignTextToFramePadding(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.Bullet(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param text string
function ImGui.BulletText(ctx, text) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param text string
--- @param _1? nil​
--- @param _2? nil​
--- @param hide_text_after_double_hash? boolean default value = `false`
--- @param wrap_width? number default value = `-1.0`
--- @return number w
--- @return number h
function ImGui.CalcTextSize(ctx, text, _1, _2, hide_text_after_double_hash, wrap_width) end
--- @since 0.7
--- @param ctx ImGui_Context
--- @param text string
function ImGui.DebugTextEncoding(ctx, text) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetFrameHeight(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetFrameHeightWithSpacing(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetTextLineHeight(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetTextLineHeightWithSpacing(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param text string
function ImGui.LabelText(ctx, label, text) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.PopTextWrapPos(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param wrap_local_pos_x? number default value = `0.0`
function ImGui.PushTextWrapPos(ctx, wrap_local_pos_x) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param text string
function ImGui.Text(ctx, text) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param col_rgba integer
--- @param text string
function ImGui.TextColored(ctx, col_rgba, text) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param text string
function ImGui.TextDisabled(ctx, text) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param label string
--- @return boolean retval
function ImGui.TextLink(ctx, label) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param label string
--- @param url? string default value = `nil`
--- @return boolean retval
function ImGui.TextLinkOpenURL(ctx, label, url) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param text string
function ImGui.TextWrapped(ctx, text) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v number
--- @param step? number default value = `0.0`
--- @param step_fast? number default value = `0.0`
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `InputTextFlags_None`
--- @return boolean retval
--- @return number v
function ImGui.InputDouble(ctx, label, v, step, step_fast, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 number
--- @param v2 number
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `InputTextFlags_None`
--- @return boolean retval
--- @return number v1
--- @return number v2
function ImGui.InputDouble2(ctx, label, v1, v2, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 number
--- @param v2 number
--- @param v3 number
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `InputTextFlags_None`
--- @return boolean retval
--- @return number v1
--- @return number v2
--- @return number v3
function ImGui.InputDouble3(ctx, label, v1, v2, v3, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 number
--- @param v2 number
--- @param v3 number
--- @param v4 number
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `InputTextFlags_None`
--- @return boolean retval
--- @return number v1
--- @return number v2
--- @return number v3
--- @return number v4
function ImGui.InputDouble4(ctx, label, v1, v2, v3, v4, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param values reaper.array
--- @param step? number default value = `nil`
--- @param step_fast? number default value = `nil`
--- @param format? string default value = `"%.3f"`
--- @param flags? integer default value = `InputTextFlags_None`
--- @return boolean retval
function ImGui.InputDoubleN(ctx, label, values, step, step_fast, format, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v integer
--- @param step? integer default value = `1`
--- @param step_fast? integer default value = `100`
--- @param flags? integer default value = `InputTextFlags_None`
--- @return boolean retval
--- @return integer v
function ImGui.InputInt(ctx, label, v, step, step_fast, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 integer
--- @param v2 integer
--- @param flags? integer default value = `InputTextFlags_None`
--- @return boolean retval
--- @return integer v1
--- @return integer v2
function ImGui.InputInt2(ctx, label, v1, v2, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 integer
--- @param v2 integer
--- @param v3 integer
--- @param flags? integer default value = `InputTextFlags_None`
--- @return boolean retval
--- @return integer v1
--- @return integer v2
--- @return integer v3
function ImGui.InputInt3(ctx, label, v1, v2, v3, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param v1 integer
--- @param v2 integer
--- @param v3 integer
--- @param v4 integer
--- @param flags? integer default value = `InputTextFlags_None`
--- @return boolean retval
--- @return integer v1
--- @return integer v2
--- @return integer v3
--- @return integer v4
function ImGui.InputInt4(ctx, label, v1, v2, v3, v4, flags) end
--- @since 0.8.5
--- @param ctx ImGui_Context
--- @param label string
--- @param buf string
--- @param flags? integer default value = `InputTextFlags_None`
--- @param callback? ImGui_Function default value = `nil`
--- @return boolean retval
--- @return string buf
function ImGui.InputText(ctx, label, buf, flags, callback) end
--- @since 0.8.5
--- @param ctx ImGui_Context
--- @param label string
--- @param buf string
--- @param size_w? number default value = `0.0`
--- @param size_h? number default value = `0.0`
--- @param flags? integer default value = `InputTextFlags_None`
--- @param callback? ImGui_Function default value = `nil`
--- @return boolean retval
--- @return string buf
function ImGui.InputTextMultiline(ctx, label, buf, size_w, size_h, flags, callback) end
--- @since 0.8.5
--- @param ctx ImGui_Context
--- @param label string
--- @param hint string
--- @param buf string
--- @param flags? integer default value = `InputTextFlags_None`
--- @param callback? ImGui_Function default value = `nil`
--- @return boolean retval
--- @return string buf
function ImGui.InputTextWithHint(ctx, label, hint, buf, flags, callback) end
--- @since 0.9
--- @param default_filter? string default value = `""`
--- @nodiscard
--- @return ImGui_TextFilter retval
function ImGui.CreateTextFilter(default_filter) end
--- @since 0.5.6
--- @param filter ImGui_TextFilter
function ImGui.TextFilter_Clear(filter) end
--- @since 0.5.6
--- @param filter ImGui_TextFilter
--- @param ctx ImGui_Context
--- @param label? string default value = `"Filter (inc,-exc)"`
--- @param width? number default value = `0.0`
--- @return boolean retval
function ImGui.TextFilter_Draw(filter, ctx, label, width) end
--- @since 0.5.6
--- @param filter ImGui_TextFilter
--- @return string retval
function ImGui.TextFilter_Get(filter) end
--- @since 0.5.6
--- @param filter ImGui_TextFilter
--- @return boolean retval
function ImGui.TextFilter_IsActive(filter) end
--- @since 0.5.6
--- @param filter ImGui_TextFilter
--- @param text string
--- @return boolean retval
function ImGui.TextFilter_PassFilter(filter, text) end
--- @since 0.5.6
--- @param filter ImGui_TextFilter
--- @param filter_text string
function ImGui.TextFilter_Set(filter, filter_text) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param p_visible? boolean default value = `nil`
--- @param flags? integer default value = `TreeNodeFlags_None`
--- @return boolean retval
--- @return boolean p_visible
function ImGui.CollapsingHeader(ctx, label, p_visible, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetTreeNodeToLabelSpacing(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsItemToggledOpen(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param is_open boolean
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetNextItemOpen(ctx, is_open, cond) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param label string
--- @param flags? integer default value = `TreeNodeFlags_None`
--- @return boolean retval
function ImGui.TreeNode(ctx, label, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id string
--- @param label string
--- @param flags? integer default value = `TreeNodeFlags_None`
--- @return boolean retval
function ImGui.TreeNodeEx(ctx, str_id, label, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.TreePop(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id string
function ImGui.TreePush(ctx, str_id) end
--- @since 0.9
--- @return string retval
function ImGui.GetBuiltinPath() end
--- @since 0.7
--- @return string imgui_version
--- @return integer imgui_version_num
--- @return string reaimgui_version
function ImGui.GetVersion() end
--- @since 0.8.4
--- @return number min
--- @return number max
function ImGui.NumericLimits_Double() end
--- @since 0.4
--- @return number min
--- @return number max
function ImGui.NumericLimits_Float() end
--- @since 0.8.4
--- @return integer min
--- @return integer max
function ImGui.NumericLimits_Int() end
--- @since 0.5.1
--- @param ctx ImGui_Context
--- @param x number
--- @param y number
--- @param to_native? boolean default value = `false`
--- @return number x
--- @return number y
function ImGui.PointConvertNative(ctx, x, y, to_native) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param fraction number
--- @param size_arg_w? number default value = `-FLT_MIN`
--- @param size_arg_h? number default value = `0.0`
--- @param overlay? string default value = `nil`
function ImGui.ProgressBar(ctx, fraction, size_arg_w, size_arg_h, overlay) end
--- @since 0.3
--- @param pointer userdata
--- @param type string
--- @return boolean retval
function ImGui.ValidatePtr(pointer, type) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return string retval
function ImGui.GetClipboardText(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param text string
function ImGui.SetClipboardText(ctx, text) end
--- @since 0.7
--- @param r number
--- @param g number
--- @param b number
--- @param a number
--- @return integer retval
function ImGui.ColorConvertDouble4ToU32(r, g, b, a) end
--- @since 0.7
--- @param h number
--- @param s number
--- @param v number
--- @return number r
--- @return number g
--- @return number b
function ImGui.ColorConvertHSVtoRGB(h, s, v) end
--- @since 0.3
--- @param rgb integer
--- @return integer retval
function ImGui.ColorConvertNative(rgb) end
--- @since 0.7
--- @param r number
--- @param g number
--- @param b number
--- @return number h
--- @return number s
--- @return number v
function ImGui.ColorConvertRGBtoHSV(r, g, b) end
--- @since 0.7
--- @param rgba integer
--- @return number r
--- @return number g
--- @return number b
--- @return number a
function ImGui.ColorConvertU32ToDouble4(rgba) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.PopID(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param str_id string
function ImGui.PushID(ctx, str_id) end
--- @since 0.10
--- @param ctx ImGui_Context
--- @param text string
function ImGui.DebugLog(ctx, text) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.LogFinish(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param text string
function ImGui.LogText(ctx, text) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param auto_open_depth? integer default value = `-1`
function ImGui.LogToClipboard(ctx, auto_open_depth) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param auto_open_depth? integer default value = `-1`
--- @param filename? string default value = `nil`
function ImGui.LogToFile(ctx, auto_open_depth, filename) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param auto_open_depth? integer default value = `-1`
function ImGui.LogToTTY(ctx, auto_open_depth) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return ImGui_Viewport retval
function ImGui.GetMainViewport(ctx) end
--- @since 0.7
--- @param ctx ImGui_Context
--- @return ImGui_Viewport retval
function ImGui.GetWindowViewport(ctx) end
--- @since 0.1
--- @param viewport ImGui_Viewport
--- @return number x
--- @return number y
function ImGui.Viewport_GetCenter(viewport) end
--- @since 0.1
--- @param viewport ImGui_Viewport
--- @return number x
--- @return number y
function ImGui.Viewport_GetPos(viewport) end
--- @since 0.1
--- @param viewport ImGui_Viewport
--- @return number w
--- @return number h
function ImGui.Viewport_GetSize(viewport) end
--- @since 0.1
--- @param viewport ImGui_Viewport
--- @return number x
--- @return number y
function ImGui.Viewport_GetWorkCenter(viewport) end
--- @since 0.1
--- @param viewport ImGui_Viewport
--- @return number x
--- @return number y
function ImGui.Viewport_GetWorkPos(viewport) end
--- @since 0.1
--- @param viewport ImGui_Viewport
--- @return number w
--- @return number h
function ImGui.Viewport_GetWorkSize(viewport) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @param name string
--- @param p_open? boolean default value = `nil`
--- @param flags? integer default value = `WindowFlags_None`
--- @nodiscard
--- @return boolean retval
--- @return boolean p_open
function ImGui.Begin(ctx, name, p_open, flags) end
--- @since 0.8
--- @param ctx ImGui_Context
function ImGui.End(ctx) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param str_id string
--- @param size_w? number default value = `0.0`
--- @param size_h? number default value = `0.0`
--- @param child_flags? integer default value = `ChildFlags_None`
--- @param window_flags? integer default value = `WindowFlags_None`
--- @nodiscard
--- @return boolean retval
function ImGui.BeginChild(ctx, str_id, size_w, size_h, child_flags, window_flags) end
--- @since 0.8
--- @param ctx ImGui_Context
function ImGui.EndChild(ctx) end
--- @since 0.5.4
--- @param ctx ImGui_Context
--- @param p_open? boolean default value = `nil`
--- @return boolean p_open
function ImGui.ShowAboutWindow(ctx, p_open) end
--- @since 0.7
--- @param ctx ImGui_Context
--- @param p_open? boolean default value = `nil`
--- @return boolean p_open
function ImGui.ShowDebugLogWindow(ctx, p_open) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param p_open? boolean default value = `nil`
--- @return boolean p_open
function ImGui.ShowIDStackToolWindow(ctx, p_open) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param p_open? boolean default value = `nil`
--- @return boolean p_open
function ImGui.ShowMetricsWindow(ctx, p_open) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @return integer retval
function ImGui.GetWindowDockID(ctx) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsWindowDocked(ctx) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @param dock_id integer
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetNextWindowDockID(ctx, dock_id, cond) end
--- @since 0.7.2
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetWindowDpiScale(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetWindowHeight(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number x
--- @return number y
function ImGui.GetWindowPos(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number w
--- @return number h
function ImGui.GetWindowSize(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetWindowWidth(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return boolean retval
function ImGui.IsWindowAppearing(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param flags? integer default value = `FocusedFlags_None`
--- @return boolean retval
function ImGui.IsWindowFocused(ctx, flags) end
--- @since 0.9
--- @param ctx ImGui_Context
--- @param flags? integer default value = `HoveredFlags_None`
--- @return boolean retval
function ImGui.IsWindowHovered(ctx, flags) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param alpha number
function ImGui.SetNextWindowBgAlpha(ctx, alpha) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param collapsed boolean
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetNextWindowCollapsed(ctx, collapsed, cond) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param size_w number
--- @param size_h number
function ImGui.SetNextWindowContentSize(ctx, size_w, size_h) end
--- @since 0.1
--- @param ctx ImGui_Context
function ImGui.SetNextWindowFocus(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param pos_x number
--- @param pos_y number
--- @param cond? integer default value = `Cond_Always`
--- @param pivot_x? number default value = `0.0`
--- @param pivot_y? number default value = `0.0`
function ImGui.SetNextWindowPos(ctx, pos_x, pos_y, cond, pivot_x, pivot_y) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param scroll_x number
--- @param scroll_y number
function ImGui.SetNextWindowScroll(ctx, scroll_x, scroll_y) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param size_w number
--- @param size_h number
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetNextWindowSize(ctx, size_w, size_h, cond) end
--- @since 0.8.5
--- @param ctx ImGui_Context
--- @param size_min_w number
--- @param size_min_h number
--- @param size_max_w number
--- @param size_max_h number
--- @param custom_callback? ImGui_Function default value = `nil`
function ImGui.SetNextWindowSizeConstraints(ctx, size_min_w, size_min_h, size_max_w, size_max_h, custom_callback) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @param collapsed boolean
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetWindowCollapsed(ctx, collapsed, cond) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @param name string
--- @param collapsed boolean
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetWindowCollapsedEx(ctx, name, collapsed, cond) end
--- @since 0.5
--- @param ctx ImGui_Context
function ImGui.SetWindowFocus(ctx) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @param name string
function ImGui.SetWindowFocusEx(ctx, name) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @param pos_x number
--- @param pos_y number
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetWindowPos(ctx, pos_x, pos_y, cond) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @param name string
--- @param pos_x number
--- @param pos_y number
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetWindowPosEx(ctx, name, pos_x, pos_y, cond) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @param size_w number
--- @param size_h number
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetWindowSize(ctx, size_w, size_h, cond) end
--- @since 0.5
--- @param ctx ImGui_Context
--- @param name string
--- @param size_w number
--- @param size_h number
--- @param cond? integer default value = `Cond_Always`
function ImGui.SetWindowSizeEx(ctx, name, size_w, size_h, cond) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetScrollMaxX(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetScrollMaxY(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetScrollX(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @return number retval
function ImGui.GetScrollY(ctx) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param local_x number
--- @param center_x_ratio? number default value = `0.5`
function ImGui.SetScrollFromPosX(ctx, local_x, center_x_ratio) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param local_y number
--- @param center_y_ratio? number default value = `0.5`
function ImGui.SetScrollFromPosY(ctx, local_y, center_y_ratio) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param center_x_ratio? number default value = `0.5`
function ImGui.SetScrollHereX(ctx, center_x_ratio) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param center_y_ratio? number default value = `0.5`
function ImGui.SetScrollHereY(ctx, center_y_ratio) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param scroll_x number
function ImGui.SetScrollX(ctx, scroll_x) end
--- @since 0.1
--- @param ctx ImGui_Context
--- @param scroll_y number
function ImGui.SetScrollY(ctx, scroll_y) end
--- @param api_version string
--- @return ImGui
return function(api_version) end
