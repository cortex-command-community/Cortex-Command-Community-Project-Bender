Import "Utility.bmx"
Import "JointMarker.bmx"

'//// LIMB MANAGER //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Const c_MaxFrameCount:Int = 20
Const c_LimbPartCount:Int = 8
Const c_LimbCount:Int = c_LimbPartCount / 2
Const c_JointMarkerCount:Int = c_LimbPartCount * 2

Type LimbManager
	Const c_MinExtend:Float = 0.30	'Possibly make definable in settings (slider).
	Const c_MaxExtend:Float = 0.99	'Possibly make definable in settings (slider).

	Field m_InputZoom:Int = 0
	Field m_TileSize:Int = 0

	Field m_LimbPartTilePos:SVec2I[c_LimbPartCount]
	Field m_LimbPartImage:TImage[c_LimbPartCount]
	Field m_LimbPartLength:Float[c_LimbPartCount]
	Field m_LimbPartAngle:Int[c_LimbPartCount, c_MaxFrameCount]
	Field m_LimbPartPosX:Int[c_LimbPartCount, c_MaxFrameCount]
	Field m_LimbPartPosY:Int[c_LimbPartCount, c_MaxFrameCount]

	Field m_JointMarkers:JointMarker[c_JointMarkerCount]

	Field m_DrawJointMarkerBounds:Int[] = Null

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method CreateLimbParts(inputZoom:Int, tileSize:Int)
		m_InputZoom = inputZoom
		m_TileSize = tileSize

		'Clear all the arrays before recreating.
		DestroyLimbParts()

		For Local part:Int = 0 Until c_LimbPartCount
			m_LimbPartTilePos[part] = New SVec2I(part * m_TileSize, 0)
			m_LimbPartImage[part] = CreateImage(m_TileSize, m_TileSize, 1, DYNAMICIMAGE | MASKEDIMAGE)
			GrabImage(m_LimbPartImage[part], part * m_TileSize, 0)

			'Set up default limb part sizes.
			m_LimbPartLength[part] = ((m_TileSize / 2.0) - (m_TileSize / 3.3)) * 2
			m_JointMarkers[part * 2] = New JointMarker(m_LimbPartTilePos[part], Int(m_TileSize / 2.0), Int(m_TileSize / 3.3), m_InputZoom) 'Top marker
			m_JointMarkers[(part * 2) + 1] = New JointMarker(m_LimbPartTilePos[part], Int(m_TileSize / 2.0), Int(m_JointMarkers[part * 2].GetPosOnCanvasY() + m_LimbPartLength[part]), m_InputZoom) 'Bottom marker
			SetImageHandle(m_LimbPartImage[part], m_JointMarkers[part * 2].GetPosOnTileX() / m_InputZoom, m_JointMarkers[part * 2].GetPosOnCanvasY() / m_InputZoom)
		Next
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method DestroyLimbParts()
		For Local part:Int = 0 Until c_LimbPartCount
			m_LimbPartTilePos[part] = Null
			m_LimbPartImage[part] = Null
			m_LimbPartLength[part] = Null
		Next
		For Local marker:Int = 0 Until c_JointMarkerCount
			m_JointMarkers[marker] = Null
		Next
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method SetJointMarker(mousePos:SVec2I)
		Local selectedPart:Int = -1
		Local selectedMarker:Int = -1

		For Local part:Int = 0 Until c_LimbPartCount
			If Utility.PointIsWithinBox(mousePos, New SVec2I(part * (m_TileSize), 0), New SVec2I(m_TileSize, m_TileSize)) Then
				selectedPart = part
				Exit
			EndIf
		Next

		If selectedPart = -1 Then
			Return
		Else
			If Utility.PointIsWithinBox(mousePos, New SVec2I(selectedPart * m_TileSize, 0), New SVec2I(m_TileSize, (m_TileSize / 2) - m_InputZoom)) Then
				selectedMarker = 0
			ElseIf Utility.PointIsWithinBox(mousePos, New SVec2I(selectedPart * m_TileSize, (m_TileSize / 2) + m_InputZoom), New SVec2I(m_TileSize, (m_TileSize / 2) - m_InputZoom)) Then
				selectedMarker = 1
			Else
				FlushMouse() 'Reset mouse input so markers don't snap when leaving vertical bounds and entering bounds of another marker.
				Return
			EndIf
		EndIf

		Local marker:JointMarker = m_JointMarkers[(selectedPart * 2) + selectedMarker]
		marker.SetSelected()
		marker.SetPosOnTile(mousePos[0] - marker.GetParentTilePosOnCanvas()[0], mousePos[1] - marker.GetParentTilePosOnCanvas()[1])

		'Adjust limb part properties to new joint position.
		Local topMarkerPos:SVec2I = m_JointMarkers[selectedPart * 2].GetPosOnTile()
		Local bottomMarkerPos:SVec2I = m_JointMarkers[(selectedPart * 2) + 1].GetPosOnTile()
		m_LimbPartLength[selectedPart] = topMarkerPos.DistanceTo(bottomMarkerPos)
		SetImageHandle(m_LimbPartImage[selectedPart], topMarkerPos[0] / m_InputZoom, topMarkerPos[1] / m_InputZoom)

		m_DrawJointMarkerBounds = [True, selectedPart, selectedMarker]
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method DrawJointMarkers()
		SetRotation(0)
		For Local marker:JointMarker = EachIn m_JointMarkers
			marker.Draw()
		Next
		Utility.ResetDrawColor()
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method DrawTileOutlines()
		Local outlineSize:SVec2I = New SVec2I(m_TileSize, m_TileSize + 1)
		Local drawColor:Int[] = [0, 0, 80]
		For Local tilePos:SVec2I = EachIn m_LimbPartTilePos
			Utility.DrawRectOutline(New SVec2I(tilePos[0], tilePos[1] - 1), outlineSize, drawColor)
		Next

		'Draw lines to show where joint adjustment cuts off vertically.
		SetColor(drawColor[0], drawColor[1], drawColor[2])
		If m_DrawJointMarkerBounds <> Null And m_DrawJointMarkerBounds[0] = True Then
			If m_DrawJointMarkerBounds[2] = 0 Then
				DrawLine(m_DrawJointMarkerBounds[1] * m_TileSize, (m_TileSize / 2) - m_InputZoom, m_DrawJointMarkerBounds[1] * m_TileSize + m_TileSize, (m_TileSize / 2) - m_InputZoom)
			ElseIf m_DrawJointMarkerBounds[2] = 1 Then
				DrawLine(m_DrawJointMarkerBounds[1] * m_TileSize, (m_TileSize / 2) + m_InputZoom, m_DrawJointMarkerBounds[1] * m_TileSize + m_TileSize, (m_TileSize / 2) + m_InputZoom)
			EndIf
			m_DrawJointMarkerBounds = Null
		EndIf
		Utility.ResetDrawColor()
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method BendLimbs(frameCount:Int)
		Local stepSize:Float = (c_MaxExtend - c_MinExtend) / (frameCount - 1) '-1 to make inclusive of last value (full range).
		For Local limb:Float = 0 Until c_LimbCount
			For Local frame:Int = 0 Until frameCount
				Local limbPart:Int = limb * 2
				Local posX:Float = (frame * 32)			'Drawing position X.
				Local posY:Float = ((limb * 32) * 1.5 )	'Drawing position Y.
				Local upperLength:Float = m_LimbPartLength[limbPart] / m_InputZoom
				Local lowerLength:Float = m_LimbPartLength[limbPart + 1] / m_InputZoom
				Local airLength:Float = ((stepSize * frame) + c_MinExtend) * (upperLength + lowerLength) 'Sum of the two bones times step scaler for frame (hip-ankle).
				Local bendAngle:Float[] = Utility.LawOfCosines(airLength, upperLength, lowerLength)
				m_LimbPartAngle[limbPart, frame] = bendAngle[1]
				m_LimbPartPosX[limbPart, frame] = posX
				m_LimbPartPosY[limbPart, frame] = posY
				posX :- Sin(m_LimbPartAngle[limbPart, frame]) * upperLength 'Position of knee.
				posY :+ Cos(m_LimbPartAngle[limbPart, frame]) * upperLength
				m_LimbPartAngle[limbPart + 1, frame] = bendAngle[1] + bendAngle[2] + 180
				m_LimbPartPosX[limbPart + 1, frame] = posX
				m_LimbPartPosY[limbPart + 1, frame] = posY
			Next
		Next
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method DrawBentLimbs(drawPos:SVec2I, frameCount:Int, drawOrder:Int[])
		BendLimbs(frameCount)
		For Local frame:Int = 0 Until frameCount
			'Arm FG.
			If Not drawOrder[0] Then
				For Local limbPart:Int = 0 To 1
					SetRotation(m_LimbPartAngle[limbPart, frame])
					DrawImageRect(m_LimbPartImage[limbPart], m_LimbPartPosX[limbPart, frame] + drawPos[0], m_LimbPartPosY[limbPart, frame] + drawPos[1], m_LimbPartImage[limbPart].Width / m_InputZoom, m_LimbPartImage[limbPart].Height / m_InputZoom)
				Next
			Else
				For Local limbPart = 1 To 0 Step -1
					SetRotation(m_LimbPartAngle[limbPart, frame])
					DrawImageRect(m_LimbPartImage[limbPart], m_LimbPartPosX[limbPart, frame] + drawPos[0], m_LimbPartPosY[limbPart, frame] + drawPos[1], m_LimbPartImage[limbPart].Width / m_InputZoom, m_LimbPartImage[limbPart].Height / m_InputZoom)
				Next
			EndIf
			'Arm BG.
			If Not drawOrder[1] Then
				For Local limbPart:Int = 2 To 3
					SetRotation(m_LimbPartAngle[limbPart, frame])
					DrawImageRect(m_LimbPartImage[limbPart], m_LimbPartPosX[limbPart, frame] + drawPos[0], m_LimbPartPosY[limbPart, frame] + drawPos[1], m_LimbPartImage[limbPart].Width / m_InputZoom, m_LimbPartImage[limbPart].Height / m_InputZoom)
				Next
			Else
				For Local limbPart = 3 To 2 Step -1
					SetRotation(m_LimbPartAngle[limbPart, frame])
					DrawImageRect(m_LimbPartImage[limbPart], m_LimbPartPosX[limbPart, frame] + drawPos[0], m_LimbPartPosY[limbPart, frame] + drawPos[1], m_LimbPartImage[limbPart].Width / m_InputZoom, m_LimbPartImage[limbPart].Height / m_InputZoom)
				Next
			EndIf
			'Leg FG.
			If Not drawOrder[2] Then
				For Local limbPart:Int = 4 To 5
					SetRotation(m_LimbPartAngle[limbPart, frame])
					DrawImageRect(m_LimbPartImage[limbPart], m_LimbPartPosX[limbPart, frame] + drawPos[0], m_LimbPartPosY[limbPart, frame] + drawPos[1], m_LimbPartImage[limbPart].Width / m_InputZoom, m_LimbPartImage[limbPart].Height / m_InputZoom)
				Next
			Else
				For Local limbPart = 5 To 4 Step -1
					SetRotation(m_LimbPartAngle[limbPart, frame])
					DrawImageRect(m_LimbPartImage[limbPart], m_LimbPartPosX[limbPart, frame] + drawPos[0], m_LimbPartPosY[limbPart, frame] + drawPos[1], m_LimbPartImage[limbPart].Width / m_InputZoom, m_LimbPartImage[limbPart].Height / m_InputZoom)
				Next
			EndIf
			'Leg BG.
			If Not drawOrder[3] Then
				For Local limbPart:Int = 6 To 7
					SetRotation(m_LimbPartAngle[limbPart, frame])
					DrawImageRect(m_LimbPartImage[limbPart], m_LimbPartPosX[limbPart, frame] + drawPos[0], m_LimbPartPosY[limbPart, frame] + drawPos[1], m_LimbPartImage[limbPart].Width / m_InputZoom, m_LimbPartImage[limbPart].Height / m_InputZoom)
				Next
			Else
				For Local limbPart = 7 To 6 Step -1
					SetRotation(m_LimbPartAngle[limbPart, frame])
					DrawImageRect(m_LimbPartImage[limbPart], m_LimbPartPosX[limbPart, frame] + drawPos[0], m_LimbPartPosY[limbPart, frame] + drawPos[1], m_LimbPartImage[limbPart].Width / m_InputZoom, m_LimbPartImage[limbPart].Height / m_InputZoom)
				Next
			EndIf
		Next
		SetRotation(0)
	EndMethod
EndType