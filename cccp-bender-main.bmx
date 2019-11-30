Rem
------- CORTEX COMMAND COMMUNITY PROJECT BENDER -----------------------------------------------------------------------
EndRem

SuperStrict

'Import dependencies into build
Import MaxGUI.Drivers
Import BRL.Max2D
Import BRL.Pixmap
Import BRL.PNGLoader
Import BRL.Stream
Import BRL.EndianStream

'Version
Global appVersion:String = "1.2.1"
Global appVersionDate:String = "22 Sep 2019"

Rem
------- INDEXING ------------------------------------------------------------------------------------------------------
EndRem

Type TBitmapIndex
	'Color Value Bytes
	Global palR:Byte[256]
	Global palG:Byte[256]
	Global palB:Byte[256]
	
	'Data Streams
	Global dataStream:TStream

	'Load color table file
	Function FLoadPalette(paletteFile:String)
		Local index:Int
		If FileSize(paletteFile) = 768
			Local paletteStream:TStream = ReadFile(paletteFile)
			For index = 0 To 255
				palR[index] = ReadByte(paletteStream)
				palG[index] = ReadByte(paletteStream)
				palB[index] = ReadByte(paletteStream)
			Next
			CloseStream paletteStream
		EndIf
	EndFunction

	'Indexed Bitmap File Writer
	Function FPixmapToIndexedBitmap(image:TPixmap,filename:String)
		'Foolproofing
		If filename = "" Then
			TAppFileIO.FRevertPrep()
		Else
			'Variables
			Local paletteIndex:Int
			Local bmpWidth:Int, bmpWidthM4:Int
			Local bmpHeight:Int
			Local bmpSizeTotal:Int, bmpSizeTotalM4:Int
			
			'Dimensions calc
			bmpWidth = PixmapWidth(image)
			bmpWidthM4 = ((bmpWidth + 3) / 4) * 4
			bmpHeight = PixmapHeight(image)
			
			'Filesize calc
			bmpSizeTotal = (14 + 40) + (256 * 4) + (bmpWidthM4 * bmpHeight)
			bmpSizeTotalM4 = ((bmpSizeTotal + 3) / 4) * 4
			
			'Begin writing BMP file manually
			dataStream = WriteFile(filename)
			
	'------ Bitmap File Header
			'Data is stored in little-endian format (least-significant byte first)
			dataStream = LittleEndianStream(dataStream)
	
			WriteShort(dataStream,19778)			'File ID (2 bytes (short)) - 19778 (deci) or 42 4D (hex) or BM (ascii) for bitmap
			WriteInt(dataStream,bmpSizeTotalM4)		'File Size (4 bytes (signed int))
			WriteInt(dataStream,0)					'Reserved (4 bytes)
			WriteInt(dataStream,1078)				'Pixel Array Offset (4 bytes) - pixel array starts at 1078th byte (14 bytes Header + 40 bytes DIB + 1024 (256 * 4) bytes Color Table)
	
	'------ DIB Header (File Info)
			WriteInt(dataStream,40)					'DIB Header Size (4 bytes) - 40 bytes
			WriteInt(dataStream,bmpWidth)			'Bitmap Width (4 bytes)
			WriteInt(dataStream,bmpHeight)			'Bitmap Height (4 bytes)
			WriteShort(dataStream,1)				'Color Planes (2 bytes) - Must be 1
			WriteShort(dataStream,8)				'Color Depth (2 bytes) - Bits Per Pixel
			WriteInt(dataStream,0)					'Compression Method (4 bytes) - 0 equals BI_RGB (no compression)
			WriteInt(dataStream,bmpSizeTotalM4)		'Size of the raw bitmap data (4 bytes) - 0 can be given for BI_RGB bitmaps
			WriteInt(dataStream,2835)				'Horizontal resolution of the image (4 bytes) - Pixels Per Metre (2835 PPM equals 72.009 DPI/PPI)
			WriteInt(dataStream,2835)				'Vertical resolution of the image (4 bytes) - Pixels Per Metre (2835 PPM equals 72.009 DPI/PPI)
			WriteInt(dataStream,256)				'Number of colors in the color palette (4 bytes)
			WriteInt(dataStream,0)					'Number of important colors (4 bytes) - 0 when every color is important
	
	'------ Color Table
			For paletteIndex = 0 To 255
				WriteByte(dataStream,palB[paletteIndex])	'Blue (1 byte)
				WriteByte(dataStream,palG[paletteIndex])	'Green (1 byte)
				WriteByte(dataStream,palR[paletteIndex])	'Red (1 byte)
				WriteByte(dataStream,0)						'Reserved (1 byte) - Alpha channel, irrelevant for indexed bitmaps
				
				Rem
				Color Table is 4 bytes (ARGB) times the amount of colors in the palette
				EndRem
			Next
				
	'------ Pixel Array
			Local px:Int, py:Int
			Local pixelData:Long
			Local bestIndex:Int = 0
			Local magenta:Int = 16711935	
			For py = bmpHeight -1 To 0 Step -1
				For px = 0 To bmpWidthM4 -1
					'if a valid pixel on canvas
					If px < bmpWidth
						'Read pixel data
						pixelData = ReadPixel(image,px,py)
						'skip diffing magenta
						If pixelData = 16711935 Then
							WriteByte(dataStream,1)
						Else
							'Check all color indexes for best match by pythagora
							Local R:Int, G:Int, B:Int
							Local RDIFF:Int, GDIFF:Int, BDIFF:Int
							Local bestDistance:Int = 17000000
							Local distance:Int = 0
							For paletteIndex = 0 To 255
								R = (pixelData & $00FF0000) Shr 16
								G = (pixelData & $FF00) Shr 8
								B = (pixelData & $FF)
								RDIFF = Abs(R - palR[paletteIndex])
								GDIFF = Abs(G - palG[paletteIndex])
								BDIFF = Abs(B - palB[paletteIndex])
								distance = (RDIFF^2 + GDIFF^2 + BDIFF^2)
								If distance <= bestDistance Then
									bestIndex = paletteIndex
									bestDistance = distance
								EndIf
							Next
						EndIf
						WriteByte(dataStream,bestIndex)
					Else
						WriteByte(dataStream,0) 'line padding
					EndIf
				Next
			Next
			'eof padding
			For paletteIndex = 1 To bmpSizeTotalM4 - bmpSizeTotal
				WriteByte(dataStream,0)
			Next
			'Writing file finished, close stream
			CloseStream(dataStream)
		EndIf
	EndFunction
EndType

Rem
------- FILE IO -------------------------------------------------------------------------------------------------------
EndRem

'Filepaths
Global importedFile:String = Null
Global exportedFile:String = Null

'File Filters
Global fileFilters:String

Type TAppFileIO
	'Save Bools
	Global saveAsIndexed:Int = False
	Global prepForSave:Int = False
	Global rdyForSave:Int = False
	Global runOnce:Int = False
	
	'Output copy for saving
	Global tempOutputImage:TPixmap
	
	'Load Source Image
	Function FLoadFile()
		Local oldImportedFile:String = importedFile
		importedFile = RequestFile("Select graphic file to open","Image Files:png,bmp,jpg")
		'Foolproofing
		If importedFile = Null Then
			importedFile = oldImportedFile
			TAppOutput.sourceImage = TAppOutput.sourceImage
		Else
			TAppOutput.sourceImage = LoadImage(importedFile,0)
			TAppOutput.redoLimbTiles = True
		EndIf
	EndFunction
	
	'Prep Output For Saving
	Function FPrepForSave()
		If prepForSave Then
			If Not runOnce Then
				runOnce = True
				TAppOutput.FOutputUpdate()
			Else
				FSaveFile()
			EndIf
		EndIf
	EndFunction
	
	Function FRevertPrep()
		prepForSave = False
		rdyForSave = False
		runOnce = False
		TAppOutput.FOutputUpdate()
	EndFunction
	
	'Save Output Content To File
	Function FSaveFile()
		exportedFile = RequestFile("Save graphic output",fileFilters,True)
		'Foolproofing
		If exportedFile = importedFile Then
			Notify("Cannot overwrite source image!",True)
		ElseIf exportedFile <> importedFile Then
			'Writing new file
			If saveAsIndexed = True
				TBitmapIndex.FPixmapToIndexedBitmap(tempOutputImage,exportedFile)
			Else
	      		SavePixmapPNG(tempOutputImage,exportedFile)
			EndIf
			FRevertPrep()
		Else
			'On Cancel
			FRevertPrep()
		EndIf
	EndFunction
EndType

Rem
------- OUTPUT ELEMENTS -----------------------------------------------------------------------------------------------
EndRem

Type TAppOutput
	'Output Window
	Global outputWindow:TGraphics
	'Draw Bools
	Global redoLimbTiles:Int = False
	'Constants
	Const BONES:Int = 8
	Const LIMBS:Int = BONES/2
	Const UPPER_BONE:Int = 0
	Const LOWER_BONE:Int = 1
	'Graphic Assets
	Global logoImage:TImage = LoadImage("assets/logo-image",MASKEDIMAGE)
	Global sourceImage:TImage
	Global boneImage:TImage[BONES]
	'Output Settings
	Global INPUTZOOM:Int = 1
	Global FRAMES:Int = 7
	Global BACKGROUND_RED:Int = 50
	Global BACKGROUND_GREEN:Int = 170
	Global BACKGROUND_BLUE:Int = 255
	'Limb Parts
	Global jointX:Float[BONES]
	Global jointY:Float[BONES]
	Global boneLength:Float[BONES]
	'Precalc for drawing
	Global TILESIZE:Int = 24
	Global angle:Int[BONES,20]
	Global xBone:Int[BONES,20]
	Global yBone:Int[BONES,20]
	'Variables
	Global angA:Float
	Global angB:Float
	Global angC:Float
	
	'Rotation Calc
	Function FLawOfCosines(ab:Float,bc:Float,ca:Float)
		angA = ACos((ca^2+ab^2-bc^2)/(2*ca*ab))
		angB = ACos((bc^2+ab^2-ca^2)/(2*bc*ab))
		angC = (180-(angA+angB))
	EndFunction
	
	'Create limb part tiles from source image
	Function FCreateLimbTiles()
		Local b:Int, i:Int
		For b = 0 To BONES-1 'Because I (arne) can't set handles on inidividial anim image frames, I must use my own frame sys
			boneImage[b] = CreateImage(TILESIZE,TILESIZE,1,DYNAMICIMAGE|MASKEDIMAGE)
			GrabImage(boneImage[b],b*TILESIZE,0)
			SetColor(120,0,120)
			DrawLine(i*TILESIZE,0,i*TILESIZE,TILESIZE-1,True)
		Next
		'Set up default bone sizes
		For i = 0 To BONES-1
			jointX[i] = TILESIZE/2
			jointY[i] = TILESIZE/3.3 '3.6
			boneLength[i] = (TILESIZE/2-jointY[i])*2
			SetImageHandle(boneImage[i],jointX[i]/INPUTZOOM,jointY[i]/INPUTZOOM)
		Next
	EndFunction
	
	'Set Joint Marker
	Function FSetJointMarker()
		Local xm:Int = MouseX()
		Local ym:Int = MouseY()
		If ym < (TILESIZE/2-2) And ym > 0 And xm > 0 And xm < TILESIZE*BONES Then
			Local b:Int = xm/TILESIZE
			jointX[b] = TILESIZE/2 		'X is always at center, so kinda pointless to even bother - at the moment
			jointY[b] = ym				'Determines length
			boneLength[b] = (TILESIZE/2 -ym)*2
			SetImageHandle(boneImage[b],jointX[b]/INPUTZOOM,jointY[b]/INPUTZOOM) 'Rotation handle.
		EndIf
	EndFunction
	
	'Bending
	Function FLimbBend()
		Local maxExtend:Float = 0.99		'Possibly make definable in settings (slider)
		Local minExtend:Float = 0.30		'Possibly make definable in settings (slider)
		Local stepSize:Float = (maxExtend-minExtend)/(FRAMES-1) ' -1 to make inclusive of last value (full range)
		Local b:Int, f:Int, l:Float, x:Float, y:Float, airLength:Float, upperLength:Float, lowerLength:Float 
		For l = 0 To LIMBS-1
			For f = 0 To FRAMES-1 
				b = l*2
				x = (f * 32) + 80 						'Drawing position X
				y = ((l * 32) * 1.5 ) + 144				'Drawing position Y
				upperLength = boneLength[b]/INPUTZOOM
				lowerLength = boneLength[b+1]/INPUTZOOM
				airLength = (stepSize * f + minExtend) * (upperLength + lowerLength)	'Sum of the two bones * step scaler for frame (hip-ankle)
				FLawOfCosines(airLength,upperLength,lowerLength)
				angle[b,f] = angB
				xBone[b,f] = x
				yBone[b,f] = y
				x:-Sin(angle[b,f])*upperLength		'Position of knee
				y:+Cos(angle[b,f])*upperLength		'Could just use another angle of the triangle though, but I (arne) didn't
				angle[b+1,f] = angC + angB + 180	'It looks correct on screen so i'm (arne) just gonna leave it at that!
				xBone[b+1,f] = x
				yBone[b+1,f] = y
			Next
		Next
	EndFunction

	'Create Joint Markers
	Function FCreateJointMarker(x:Float,y:Float)
		SetRotation(0)
		SetColor(0,0,80)
		x:+1 y:+1 'Add a shade for clarity on bright colours
		DrawLine(x-1-INPUTZOOM,y,x+1+INPUTZOOM,y)
		DrawLine(x,y-1-INPUTZOOM,x,y+1+INPUTZOOM)
		x:-1 y:-1 'Cross
		SetColor(255,230,80)
		DrawLine(x-1-INPUTZOOM,y,x+1+INPUTZOOM,y)
		DrawLine(x,y-1-INPUTZOOM,x,y+1+INPUTZOOM)
		SetColor(255,255,255)
	End Function

	'Update Output Window
	Function FOutputUpdate()
		Local i:Int, f:Int, b:Int
		Cls
		'Left mouse to adjust joint markers, click or hold and drag
		If MouseDown(1) Then
			FSetJointMarker()
		EndIf
		'Drawing Output	
		'Set background color
		If TAppFileIO.prepForSave
			SetClsColor(255,0,255)
		Else
			SetClsColor(BACKGROUND_RED,BACKGROUND_GREEN,BACKGROUND_BLUE)
		EndIf
		'Draw source image
		SetColor(255,255,255)
		DrawImageRect(sourceImage,0,0,ImageWidth(sourceImage)*INPUTZOOM,ImageHeight(sourceImage)*INPUTZOOM)
		If redoLimbTiles Then
			FCreateLimbTiles()
			redoLimbTiles = False
		EndIf
		For i = 0 To BONES-1
			'Draw limb tile dividers
			SetColor(120,0,120)
			DrawLine(i*TILESIZE,0,i*TILESIZE,TILESIZE-1,True)
			'Draw the joint markers
			FCreateJointMarker(jointX[i]+i*TILESIZE,jointY[i])
			FCreateJointMarker(jointX[i]+i*TILESIZE,jointY[i]+boneLength[i])
		Next	
		'Draw footer image and text
		DrawImage(logoImage,0,480-ImageHeight(logoImage))
		'SetColor(255,230,80)
		'DrawText("TBA",ImageWidth(logoImage)+7,480-18)
		'Draw bent limbs
		FLimbBend()
		SetColor(255,255,255)
		For f = 0 To FRAMES-1
			'These might be in a specific draw-order for joint overlapping purposes
			b = 0 SetRotation(angle[b,f]) DrawImageRect(boneImage[b],xBone[b,f],yBone[b,f],ImageWidth(boneImage[b])/INPUTZOOM,ImageHeight(boneImage[b])/INPUTZOOM)
			b = 1 SetRotation(angle[b,f]) DrawImageRect(boneImage[b],xBone[b,f],yBone[b,f],ImageWidth(boneImage[b])/INPUTZOOM,ImageHeight(boneImage[b])/INPUTZOOM)
			b = 2 SetRotation(angle[b,f]) DrawImageRect(boneImage[b],xBone[b,f],yBone[b,f],ImageWidth(boneImage[b])/INPUTZOOM,ImageHeight(boneImage[b])/INPUTZOOM)
			b = 3 SetRotation(angle[b,f]) DrawImageRect(boneImage[b],xBone[b,f],yBone[b,f],ImageWidth(boneImage[b])/INPUTZOOM,ImageHeight(boneImage[b])/INPUTZOOM)
			b = 4 SetRotation(angle[b,f]) DrawImageRect(boneImage[b],xBone[b,f],yBone[b,f],ImageWidth(boneImage[b])/INPUTZOOM,ImageHeight(boneImage[b])/INPUTZOOM)
			b = 5 SetRotation(angle[b,f]) DrawImageRect(boneImage[b],xBone[b,f],yBone[b,f],ImageWidth(boneImage[b])/INPUTZOOM,ImageHeight(boneImage[b])/INPUTZOOM)
			b = 6 SetRotation(angle[b,f]) DrawImageRect(boneImage[b],xBone[b,f],yBone[b,f],ImageWidth(boneImage[b])/INPUTZOOM,ImageHeight(boneImage[b])/INPUTZOOM)
			b = 7 SetRotation(angle[b,f]) DrawImageRect(boneImage[b],xBone[b,f],yBone[b,f],ImageWidth(boneImage[b])/INPUTZOOM,ImageHeight(boneImage[b])/INPUTZOOM)
		Next
		SetRotation(0)
		'Output copy for saving
		If TAppFileIO.saveAsIndexed = True Then
			'If saving indexed grab a smaller pixmap to speed up indexing
			TAppFileIO.tempOutputImage = GrabPixmap(55,120,34*FRAMES,210)
		Else
			TAppFileIO.tempOutputImage = GrabPixmap(0,96,768,384)
		EndIf
		Flip(1)
		If TAppFileIO.prepForSave
			TAppFileIO.FPrepForSave()
		EndIf
	EndFunction
	
	'Create output window and draw assets
	Function FOutputBoot()
		SetGraphicsDriver GLMax2DDriver()
		SetGraphics CanvasGraphics(TAppGUI.editCanvas)
		'Window background color
		SetClsColor(BACKGROUND_RED,BACKGROUND_GREEN,BACKGROUND_BLUE)
		SetMaskColor(255,0,255)
		DrawImage(logoImage,0,480-ImageHeight(logoImage))
		DrawImageRect(sourceImage,0,0,ImageWidth(sourceImage)*INPUTZOOM,ImageHeight(sourceImage)*INPUTZOOM)
		FCreateLimbTiles()
		'Have to do all this to start editor window with source image zoomed in otherwise markers and tiles don't scale properly.
		INPUTZOOM = 4
		SetGadgetText(TAppGUI.editSettingsZoomTextbox,TAppOutput.INPUTZOOM)
		TILESIZE = 24 * TAppOutput.INPUTZOOM
		redoLimbTiles = True
		FLimbBend()
		FOutputUpdate()
	EndFunction
EndType

Rem
------- GUI ELEMENTS --------------------------------------------------------------------------------------------------
EndRem

'Bool For Quitting
Global quitResult:Int = False

Type TAppGUI
	'Window Transition Bool
	Global mainToEdit:Int = False
	'Main Window
	Global mainWindow:TGadget
	'Main Window Footer Label
	Global mainWindowFooterLabel:TGadget
	'Main Window Buttons
	Global mainWindowButtonPanel:TGadget
	Global mainLoadButton:TGadget
	Global mainQuitButton:TGadget
	'Main Window About
	Global mainAboutPanel:TGadget
	Global mainAboutTextbox:TGadget
	'Editor Window
	Global editWindow:TGadget
	'Editor Window Canvas Graphics
	Global editCanvas:TGadget
	'Editor Window Buttons
	Global editWindowButtonPanel:TGadget
	Global editLoadButton:TGadget
	Global editSaveButton:TGadget
	Global editQuitButton:TGadget
	'Editor Window Settings
	Global editSettingsPanel:TGadget
	Global editSettingsZoomTextbox:TGadget
	Global editSettingsFramesTextbox:TGadget
	Global editSettingsColorRTextbox:TGadget
	Global editSettingsColorGTextbox:TGadget
	Global editSettingsColorBTextbox:TGadget
	Global editSettingsZoomLabel:TGadget
	Global editSettingsFramesLabel:TGadget
	Global editSettingsColorLabel:TGadget
	Global editSettingsColorRLabel:TGadget
	Global editSettingsColorGLabel:TGadget
	Global editSettingsColorBLabel:TGadget
	Global editSettingsIndexedLabel:TGadget
	Global editSettingsIndexedCheckbox:TGadget
	'Editor Window Help
	Global editHelpPanel:TGadget
	Global editHelpTextbox:TGadget
	'Textboxes content
	Global aboutTextboxContent:String[7]
	Global helpTextboxContent:String[17]
	
	'Create Main App Window
	Function FAppMain()
		mainWindow = CreateWindow("CCCP Bender v"+appVersion,DesktopWidth()/2-150,DesktopHeight()/2-180,300,340,Null,WINDOW_TITLEBAR|WINDOW_CLIENTCOORDS)
		mainWindowButtonPanel = CreatePanel(GadgetWidth(mainWindow)/2-80,5,150,97,mainWindow,PANEL_GROUP)
		mainLoadButton = CreateButton("Load Sprite",GadgetWidth(mainWindowButtonPanel)/2-69,0,130,30,mainWindowButtonPanel,BUTTON_PUSH)
		mainQuitButton = CreateButton("Quit",GadgetWidth(mainWindowButtonPanel)/2-69,40,130,30,mainWindowButtonPanel,BUTTON_PUSH)
		mainAboutPanel = CreatePanel(GadgetWidth(mainWindow)/2-140,GadgetHeight(mainWindowButtonPanel)+15,280,200,mainWindow,PANEL_GROUP,"  About :  ")
		mainAboutTextbox = CreateTextArea(7,3,GadgetWidth(mainAboutPanel)-21,GadgetHeight(mainAboutPanel)-30,mainAboutPanel,TEXTAREA_WORDWRAP|TEXTAREA_READONLY)
		mainWindowFooterLabel = CreateLabel("CCCP Bender v"+appVersion+" - "+appVersionDate,10,GadgetHeight(mainWindow)-20,GadgetWidth(mainWindow),15,mainWindow,LABEL_LEFT)
		'About textbox Content
		aboutTextboxContent[0] = "Welcome to the CCCP Bender utility! ~n~n"
		aboutTextboxContent[1] = "It's purpose is to make the life of modders easier by automagically generating bent limb frames. ~n~n"
		aboutTextboxContent[2] = "The CC Bender was originally created by Arne Jansson (AndroidArts), the man behind all the Cortex Command artwork. ~n"
		aboutTextboxContent[3] = "The CCCommunityProject Bender, however, is a brand new tool that allows more control and convenience for the modder (hopefully). ~n~n"
		aboutTextboxContent[4] = "Arne's original bend code was used as base for this utility, and has been modified and improved to enable the new features. ~n~n"
		aboutTextboxContent[5] = "Created by MaximDude using BlitzMax 0.105.3.35 and MaxIDE 1.52 ~n"
		aboutTextboxContent[6] = "Bender logo image by Arne Jansson - Edited by MaximDude ~n"
		SetGadgetText(mainAboutTextbox,aboutTextboxContent[0]+aboutTextboxContent[1]+aboutTextboxContent[2]+aboutTextboxContent[3]+aboutTextboxContent[4]+aboutTextboxContent[5]+aboutTextboxContent[6])
	EndFunction
	
	'Create Editor Window
	Function FAppEditor()
		EnablePolledInput()
		editWindow = CreateWindow("CCCP Bender v"+appversion+" - Editor",DesktopWidth()/2-700,DesktopHeight()/2-240,300+768,430+50,Null,WINDOW_TITLEBAR|WINDOW_CLIENTCOORDS)
		editCanvas = CreateCanvas(300,0,768,480,editWindow)
		editWindowButtonPanel = CreatePanel(10,7,280,57,editWindow,PANEL_GROUP)	
		editLoadButton = CreateButton("Load",6,0,80,30,editWindowButtonPanel,BUTTON_PUSH)
		editSaveButton = CreateButton("Save",96,0,80,30,editWindowButtonPanel,BUTTON_PUSH)
		editQuitButton = CreateButton("Quit",186,0,80,30,editWindowButtonPanel,BUTTON_PUSH)
		editSettingsPanel = CreatePanel(10,73,280,120,editWindow,PANEL_GROUP,"  Settings :  ")
		editSettingsZoomTextbox = CreateTextField(80,12,30,20,editSettingsPanel)
		editSettingsFramesTextbox = CreateTextField(190,12,30,20,editSettingsPanel)
		editSettingsColorRTextbox = CreateTextField(80,42,30,20,editSettingsPanel)
		editSettingsColorGTextbox = CreateTextField(135,42,30,20,editSettingsPanel)
		editSettingsColorBTextbox = CreateTextField(190,42,30,20,editSettingsPanel)
		editSettingsZoomLabel = CreateLabel("Zoom:",10,15,50,20,editSettingsPanel,LABEL_LEFT)
		editSettingsFramesLabel = CreateLabel("Frames:",120,15,50,20,editSettingsPanel,LABEL_LEFT)
		editSettingsColorLabel = CreateLabel("BG Color:",10,45,50,20,editSettingsPanel,LABEL_LEFT)
		editSettingsColorRLabel = CreateLabel("R:",65,45,50,20,editSettingsPanel,LABEL_LEFT)
		editSettingsColorGLabel = CreateLabel("G:",120,45,50,20,editSettingsPanel,LABEL_LEFT)
		editSettingsColorBLabel = CreateLabel("B:",175,45,50,20,editSettingsPanel,LABEL_LEFT)
		editSettingsIndexedLabel = CreateLabel("Save as Indexed Bitmap:",10,75,130,20,editSettingsPanel,LABEL_LEFT)
		editSettingsIndexedCheckbox = CreateButton("",140,73,20,20,editSettingsPanel,BUTTON_CHECKBOX)
		editHelpPanel = CreatePanel(10,203,280,250,editWindow,PANEL_GROUP,"  Help :  ")
		editHelpTextbox = CreateTextArea(7,5,GadgetWidth(editHelpPanel)-21,GadgetHeight(editHelpPanel)-32,editHelpPanel,TEXTAREA_WORDWRAP|TEXTAREA_READONLY)
		SetGadgetText(editSettingsZoomTextbox,TAppOutput.INPUTZOOM)
		SetGadgetText(editSettingsFramesTextbox,TAppOutput.FRAMES)
		SetGadgetText(editSettingsColorRTextbox,TAppOutput.BACKGROUND_RED)
		SetGadgetText(editSettingsColorGTextbox,TAppOutput.BACKGROUND_GREEN)
		SetGadgetText(editSettingsColorBTextbox,TAppOutput.BACKGROUND_BLUE)
		'Help textbox content
		helpTextboxContent[0] = "-------------------------- GUI -------------------------- ~n~n"
		helpTextboxContent[1] = "LOAD: ~nThis loads an image file and starts bending. Supported formats are bmp, png and jpg. ~n~n"
		helpTextboxContent[2] = "- Note: ~nThe loaded file is being cut to 24x24px tiles internally. For best results, use provided template to create correct input files. ~n~n"
		helpTextboxContent[3] = "SAVE: ~nThis saves the bended limbs into a file or creates a new file with specified name. ~n~n"
		helpTextboxContent[4] = "- Note: ~nFiles are saved in .png format, typing in the extension is not needed. Currently loaded file cannot be overwritten. ~n~n"
		helpTextboxContent[5] = "----------------- ADJUSTING JOINTS ---------------- ~n~n"
		helpTextboxContent[6] = "To adjust the joint positing on a limb part, click the upper joint marker on and drag it up/down, or click at desired point to set it there. Output will update automatically as you adjust the markers.~n~n"
		helpTextboxContent[7] = "- Note: Joint markers cannot be adjusted on the X axis, and will adjust equally on the Y axis. For best results, please position the limb parts as close to dead center as possible for each tile in the input file. ~n~n"
		helpTextboxContent[8] = "---------------------- SETTINGS ----------------------- ~n~n"
		helpTextboxContent[9] = "ZOOM : ~nThis magnifies the source image For easier placement of joint markers. Zooming does Not magnify the output. ~n~nAccepts values from 1 To 4. ~n~n"
		helpTextboxContent[10] = "- Warning : ~nChanging zoom level will reset the joint markers to initial positions. Zoom first, adjust markers later. ~n~n"		
		helpTextboxContent[11] = "FRAMES: ~nThis sets the amount of frames output will generate. ~n~nAccepts values from 1 to 20. ~n~n"
		helpTextboxContent[12] = "- Note : ~nLimb bending will automatically adjust to number of frames. ~n~n"
		helpTextboxContent[13] = "BG COLOR R,G,B: ~nThis changes the background color of the output. ~n~nAccepts values from 0 to 255. ~n~n"	
		helpTextboxContent[14] = "- Note : ~nWhen saving file, the output will automatically set background to magenta, so no manual setting before saving is needed. ~n~n"
		helpTextboxContent[15] = "SAVE AS INDEXED BITMAP : ~nWhen ticked the output will be saved as a BMP file indexed to the CC palette. ~nWhen not ticked, output will be saved as a non-indexed PNG. ~n~n"
		helpTextboxContent[16] = "- Warning : ~nTHE INDEXING PROCESS IS SLOW! ~nI've done my best to speed it up but it still isn't blazing fast like PNG saving. ~nWhen saving indexed, the app may hang and appear unresponsive but in fact it's doing what it's supposed to. ~nFor best results, DO NOT TOUCH ANYTHING until the background color reverts from magenta to whatever it was before!" 
		SetGadgetText(TAppGUI.editHelpTextbox,helpTextboxContent[0]+helpTextboxContent[1]+helpTextboxContent[2]+helpTextboxContent[3]+helpTextboxContent[4]+helpTextboxContent[5]+helpTextboxContent[6]+helpTextboxContent[7]+helpTextboxContent[8]+helpTextboxContent[9]+helpTextboxContent[10]+helpTextboxContent[11]+helpTextboxContent[12]+helpTextboxContent[13]+helpTextboxContent[14]+helpTextboxContent[15]+helpTextboxContent[16]);
		'Delete no longer used MainWindow
		FreeGadget(mainWindow)
	EndFunction
	
	'Transition between windows
	Function FAppUpdate()
		If Not mainToEdit And importedFile <> Null Then
			FAppEditor()
			TAppOutput.FOutputBoot()
			TBitmapIndex.FLoadPalette("assets/palette.act")
			mainToEdit = True
		EndIf
	EndFunction
EndType

Rem
------- BOOT ----------------------------------------------------------------------------------------------------------
EndRem

New TAppGUI
New TAppOutput
New TAppFileIO
New TBitmapIndex
TAppGUI.FAppMain()

Rem
------- EVENT HANDLING ------------------------------------------------------------------------------------------------
EndRem

While True	
	If Not TAppGUI.mainToEdit Then
		TAppGUI.FAppUpdate()
	Else
		TAppOutput.FOutputUpdate()
		If ButtonState(TAppGUI.editSettingsIndexedCheckbox) = True Then
			fileFilters = "Image Files:bmp"
			TAppFileIO.saveAsIndexed = True
		Else
			fileFilters = "Image Files:png"
			TAppFileIO.saveAsIndexed = False
		EndIf
	EndIf

	WaitEvent
	'Print CurrentEvent.ToString()

	'Event Responses
	'In Main Window
	If Not TAppGUI.mainToEdit Then
		Select EventID()
			Case EVENT_GADGETACTION
				Select EventSource()
					'Quitting
					Case TAppGUI.mainQuitButton
						Exit
					'Loading
					Case TAppGUI.mainLoadButton
						TAppFileIO.FLoadFile()
				EndSelect
			'Quitting
			Case EVENT_WINDOWCLOSE, EVENT_APPTERMINATE
				Exit	
		EndSelect
	'In Editor Window
	ElseIf TAppGUI.mainToEdit Then
		Select EventID()
			Case EVENT_APPRESUME
				ActivateWindow(TAppGUI.editWindow)
				TAppOutput.FOutputUpdate()
			Case EVENT_WINDOWACTIVATE
				TAppOutput.FOutputUpdate()
			Case EVENT_GADGETLOSTFOCUS
				TAppOutput.FOutputUpdate()	
			Case EVENT_GADGETACTION
				Select EventSource()
					'Quitting confirm
					Case TAppGUI.editQuitButton
						quitResult = Confirm("Quit program?")
					'Loading
					Case TAppGUI.editLoadButton
						TAppFileIO.FLoadFile()
						TAppOutput.FOutputUpdate()
					'Saving
					Case TAppGUI.editSaveButton
						TAppFileIO.prepForSave = True
						TAppOutput.FOutputUpdate()
					'Settings textbox inputs
					'Scale
					Case TAppGUI.editSettingsZoomTextbox
						Local userInputValue:Int = GadgetText(TAppGUI.editSettingsZoomTextbox).ToInt()	
						'Foolproofing
						If userInputValue > 4 Then
							TAppOutput.INPUTZOOM = 4
						ElseIf userInputValue <= 0 Then
							TAppOutput.INPUTZOOM = 1
						Else
							TAppOutput.INPUTZOOM = userInputValue
						EndIf
						SetGadgetText(TAppGUI.editSettingsZoomTextbox,TAppOutput.INPUTZOOM)
						TAppOutput.TILESIZE = 24 * TAppOutput.INPUTZOOM
						TAppOutput.redoLimbTiles = True
						TAppOutput.FOutputUpdate()
					'Frames
					Case TAppGUI.editSettingsFramesTextbox
						Local userInputValue:Int = GadgetText(TAppGUI.editSettingsFramesTextbox).ToInt()
						'Foolproofing
						If userInputValue > 20 Then
							TAppOutput.FRAMES = 20
						ElseIf userInputValue <= 0 Then
							TAppOutput.FRAMES = 1
						Else
							TAppOutput.FRAMES = userInputValue
						EndIf
						SetGadgetText(TAppGUI.editSettingsFramesTextbox,TAppOutput.FRAMES)
						TAppOutput.FOutputUpdate()
					'Bacground Color
					'Red
					Case TAppGUI.editSettingsColorRTextbox
						Local userInputValue:Int = GadgetText(TAppGUI.editSettingsColorRTextbox).ToInt()
						'Foolproofing
						If userInputValue > 255 Then
							TAppOutput.BACKGROUND_RED = 255
						ElseIf userInputValue < 0 Then
							TAppOutput.BACKGROUND_RED = 0
						Else
							TAppOutput.BACKGROUND_RED = userInputValue
						EndIf
						SetGadgetText(TAppGUI.editSettingsColorRTextbox,TAppOutput.BACKGROUND_RED)
						TAppOutput.FOutputUpdate()
					'Green
					Case TAppGUI.editSettingsColorGTextbox
						Local userInputValue:Int = GadgetText(TAppGUI.editSettingsColorGTextbox).ToInt()
						'Foolproofing
						If userInputValue > 255 Then
							TAppOutput.BACKGROUND_GREEN = 255
						ElseIf userInputValue < 0 Then
							TAppOutput.BACKGROUND_GREEN = 0
						Else
							TAppOutput.BACKGROUND_GREEN = userInputValue
						EndIf
						SetGadgetText(TAppGUI.editSettingsColorGTextbox,TAppOutput.BACKGROUND_GREEN)
						TAppOutput.FOutputUpdate()
					'Blue
					Case TAppGUI.editSettingsColorBTextbox
						Local userInputValue:Int = GadgetText(TAppGUI.editSettingsColorBTextbox).ToInt()
						'Foolproofing
						If userInputValue > 255 Then
							TAppOutput.BACKGROUND_BLUE = 255
						ElseIf userInputValue < 0 Then
							TAppOutput.BACKGROUND_BLUE = 0
						Else
							TAppOutput.BACKGROUND_BLUE = userInputValue
						EndIf
						SetGadgetText(TAppGUI.editSettingsColorBTextbox,TAppOutput.BACKGROUND_BLUE)
						TAppOutput.FOutputUpdate()
				EndSelect
			'Quitting confirm
			Case EVENT_WINDOWCLOSE, EVENT_APPTERMINATE
				quitResult = Confirm("Quit program?")
		EndSelect
		'Quitting
		If quitResult Then Exit
	EndIf
EndWhile