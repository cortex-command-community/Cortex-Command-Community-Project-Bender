Rem
 ██████  ██████  ██████  ████████ ███████ ██   ██      ██████  ██████  ███    ███ ███    ███  █████  ███    ██ ██████      ██████  ███████ ███    ██ ██████  ███████ ██████
██      ██    ██ ██   ██    ██    ██       ██ ██      ██      ██    ██ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██     ██   ██ ██      ████   ██ ██   ██ ██      ██   ██
██      ██    ██ ██████     ██    █████     ███       ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██     ██████  █████   ██ ██  ██ ██   ██ █████   ██████
██      ██    ██ ██   ██    ██    ██       ██ ██      ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██     ██   ██ ██      ██  ██ ██ ██   ██ ██      ██   ██
 ██████  ██████  ██   ██    ██    ███████ ██   ██      ██████  ██████  ██      ██ ██      ██ ██   ██ ██   ████ ██████      ██████  ███████ ██   ████ ██████  ███████ ██   ██
EndRem

SuperStrict

Import "EmbeddedAssets.bmx"
Import "Types/UserInterface.bmx"
Import "Types/FileIO.bmx"
Import "Types/GraphicsOutput.bmx"

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

AppTitle = "CC Bender 2.0.1" '28 Apr 2021

Global g_SettingsManager:SettingsManager = Null
Global g_UserInterface:UserInterface = Null
Global g_FileIO:FileIO = Null
Global g_GraphicsOutput:GraphicsOutput = Null

'//// MAIN LOOP AND EVENT HANDLING //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Repeat
	g_SettingsManager = New SettingsManager()
	g_UserInterface = New UserInterface(g_DefaultMaximizeWindow)
	g_FileIO = New FileIO()
	g_GraphicsOutput = New GraphicsOutput(g_UserInterface.GetMaxWorkspaceWidth(), g_UserInterface.GetCanvasVisibleArea())

	'Apply user settings/defaults.
	g_UserInterface.SetColorTextboxValues(g_GraphicsOutput.SetBackgroundColor(Int[][g_DefaultBackgroundRed, g_DefaultBackgroundGreen, g_DefaultBackgroundBlue]))
	g_UserInterface.SetInputZoomTextboxValue(g_GraphicsOutput.SetInputZoom(g_DefaultInputZoom))
	g_UserInterface.SetOutputZoomTextboxValue(g_GraphicsOutput.SetOutputZoom(g_DefaultOutputZoom))
	g_UserInterface.SetFramesTextboxValue(g_GraphicsOutput.SetFrameCount(g_DefaultFrameCount))
	g_UserInterface.SetSaveAsFramesCheckboxValue(g_GraphicsOutput.SetDrawOutputFrameBounds(g_FileIO.SetSaveAsFrames(g_DefaultSaveAsFrames)))
	g_UserInterface.SetFileTypeComboBoxVisible(g_UserInterface.SetSaveAsIndexedCheckboxValue(g_FileIO.SetSaveAsIndexed(g_DefaultSaveAsIndexed)))
	g_UserInterface.SetFileTypeComboBoxSelectedItem(g_FileIO.SetIndexedFileType(g_DefaultIndexedFileType))

	Local refreshTimer:TTimer = CreateTimer(g_DefaultOutputRefreshRate)
	Local refreshOutput:Int = False

	EnablePolledInput()

	Repeat
		refreshOutput = False
		PollEvent()

		Select EventID()
			Case EVENT_TIMERTICK
				Select EventSource()
					Case refreshTimer
						refreshOutput = True
				EndSelect
			Case EVENT_APPRESUME
				ActivateWindow(g_UserInterface.m_MainWindow)
				ActivateGadget(g_UserInterface.m_CanvasGraphics)
			Case EVENT_WINDOWSIZE
				g_GraphicsOutput.SetCanvasVisibleArea(g_UserInterface.ProcessWindowResize())
			Case EVENT_WINDOWACCEPT
				g_GraphicsOutput.LoadFile(g_FileIO.SetFileToLoad(EventExtra().ToString()))
			Case EVENT_MENUACTION
				Select EventData()
					Case g_UserInterface.c_SaveSettingsMenuTag
						g_SettingsManager.WriteSettingsFile(g_UserInterface.GetSettingsValuesForSaving())
					Case g_UserInterface.c_HelpMenuTag
						Notify(g_UserInterface.m_HelpMenuText, False)
					Case g_UserInterface.c_AboutMenuTag
						Notify(g_UserInterface.m_AboutMenuText, False)
				EndSelect
			Case EVENT_GADGETACTION
				Select EventSource()
					'Loading.
					Case g_UserInterface.m_LoadButton
						g_UserInterface.SetSaveButtonEnabled(g_GraphicsOutput.LoadFile(g_FileIO.SetFileToLoad()))
					'Saving.
					Case g_UserInterface.m_SaveButton
						If g_FileIO.GetSaveAsFrames() Then
							g_GraphicsOutput.RevertBackgroundColorAfterSave(g_FileIO.SaveFileAsFrames(g_GraphicsOutput.GrabOutputFramesForSaving(), g_GraphicsOutput.GetFrameCount()))
						Else
							g_GraphicsOutput.RevertBackgroundColorAfterSave(g_FileIO.SaveFile(g_GraphicsOutput.GrabOutputForSaving()))
						EndIf
						Continue
					'Input Scale.
					Case g_UserInterface.m_SettingsInputZoomTextbox
						g_UserInterface.SetInputZoomTextboxValue(g_GraphicsOutput.SetInputZoom(g_UserInterface.GetInputZoomTextboxValue()))
					'Output Scale.
					Case g_UserInterface.m_SettingsOutputZoomTextbox
						g_UserInterface.SetOutputZoomTextboxValue(g_GraphicsOutput.SetOutputZoom(g_UserInterface.GetOutputZoomTextboxValue()))
					'Frames.
					Case g_UserInterface.m_SettingsFramesTextbox
						g_UserInterface.SetFramesTextboxValue(g_GraphicsOutput.SetFrameCount(g_UserInterface.GetFramesTextboxValue()))
					'BG Color.
					Case g_UserInterface.m_SettingsColorRTextbox, g_UserInterface.m_SettingsColorGTextbox, g_UserInterface.m_SettingsColorBTextbox
						g_UserInterface.SetColorTextboxValues(g_GraphicsOutput.SetBackgroundColor(g_UserInterface.GetColorTextboxValues()))
					'Save as Frames.
					Case g_UserInterface.m_SettingsSaveAsFramesCheckbox
						g_GraphicsOutput.SetDrawOutputFrameBounds(g_FileIO.SetSaveAsFrames(g_UserInterface.GetSaveAsFramesCheckboxValue()))
					'Save as Indexed.
					Case g_UserInterface.m_SettingsIndexedCheckbox
						g_UserInterface.SetFileTypeComboBoxVisible(g_FileIO.SetSaveAsIndexed(g_UserInterface.GetSaveAsIndexedCheckboxValue()))
					'Indexed Filetype.
					Case g_UserInterface.m_SettingsIndexedFileTypeComboBox
						g_FileIO.SetIndexedFileType(GadgetText(g_UserInterface.m_SettingsIndexedFileTypeComboBox))
					'Layering Controls.
					Case g_UserInterface.m_LayeringArmFGCheckbox, g_UserInterface.m_LayeringArmBGCheckbox, g_UserInterface.m_LayeringLegFGCheckbox, g_UserInterface.m_LayeringLegBGCheckbox
						g_GraphicsOutput.SetBentLimbPartDrawOrder(g_UserInterface.SetLayerCheckboxLabels(g_UserInterface.GetLayerCheckboxValues()))
				EndSelect
			Case EVENT_KEYDOWN
				If g_UserInterface.GetSaveButtonEnabled() And (KeyDown(KEY_LCONTROL) Or KeyDown(KEY_RCONTROL)) And KeyDown(KEY_S) Then
					If g_FileIO.GetSaveAsFrames() Then
						g_GraphicsOutput.RevertBackgroundColorAfterSave(g_FileIO.SaveFileAsFrames(g_GraphicsOutput.GrabOutputFramesForSaving(), g_GraphicsOutput.GetFrameCount()))
					Else
						g_GraphicsOutput.RevertBackgroundColorAfterSave(g_FileIO.SaveFile(g_GraphicsOutput.GrabOutputForSaving()))
					EndIf
					FlushKeys()
					Continue
				EndIf
			Case EVENT_WINDOWCLOSE, EVENT_APPTERMINATE
				If Confirm("Quit program?") Then End
		EndSelect

		g_GraphicsOutput.Update()
		If refreshOutput Then
			g_GraphicsOutput.Draw()
		EndIf
	Forever
Forever