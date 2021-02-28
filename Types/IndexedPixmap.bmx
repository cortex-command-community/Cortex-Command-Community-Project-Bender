'//// INDEXED PIXMAP ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

'Since TPixmap does not support RGB332 format gotta set up this custom one
'Otherwise indexed PNG output is spaghetti because bad byte alignment (with RGB888/RGBA8888) or incorrect indexing (with I8)
Type IndexedPixmap
	Field m_Pixels:Byte Ptr = Null
	Field m_Width:Int = 0
	Field m_Height:Int = 0
	Field m_Capacity:Size_T = 0

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method New(width:Int, height:Int)
		Local capacity:Size_T = width * height
		m_Pixels = MemAlloc(capacity)
		m_Width = width
		m_Height = height
		m_Capacity = capacity
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method Delete()
		If m_Capacity >= 0 Then
			MemFree(m_Pixels)
		EndIf
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method PixelPtr:Byte Ptr(x:Int, y:Int)
		Return m_Pixels + (y * m_Width) + x
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method ReadPixel(x:Int, y:Int)
		Assert x >= 0 And x < m_Width And y >= 0 And y < m_Height Else "Pixmap coordinates out of bounds!"
		Local pixel:Byte Ptr = PixelPtr(x, y)
		Return pixel[0]
	EndMethod

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Method WritePixel(x:Int, y:Int, index:Byte)
		Assert x >= 0 And x < m_Width And y >= 0 And y < m_Height Else "Pixmap coordinates out of bounds!"
		Local pixel:Byte Ptr = PixelPtr(x, y)
		pixel[0] = index
	EndMethod
EndType