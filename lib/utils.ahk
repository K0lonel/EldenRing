objView(Obj, NewRow := "`n", Equal := "  =  ", Indent := "`t", Depth := 12, CurIndent := "")
{
    for k,v in Obj
        ToReturn .= CurIndent . k . (IsObject(v) && depth>1 ? NewRow . objView(v, NewRow, Equal, Indent, Depth-1, CurIndent . Indent) : Equal . v) . NewRow
    return RTrim(ToReturn, NewRow)
}

SecondsToTime(seconds)
{
    minutes := Floor(seconds / 60)
    seconds := Mod(seconds, 60)
    return Format("{:02}:{:02}", minutes, seconds)
}

HasVal(haystack, needle)
{
    if !(IsObject(haystack)) || (haystack.Length() = 0)
        return False
    for index, value in haystack
        if (value = needle)
        return True
    return False
}

ProcessExist(Name)
{
    Process, Exist, %Name%
    return Errorlevel
}

w2s(projection_matrix, target)
{
    static width := A_ScreenWidth/2, height := A_ScreenHeight/2
    out := []
    clip_coords_x := projection_matrix[1][1] * target.x + projection_matrix[2][1] * target.y + projection_matrix[3][1] * target.z + projection_matrix[4][1]
    clip_coords_y := projection_matrix[1][2] * target.x + projection_matrix[2][2] * target.y + projection_matrix[3][2] * target.z + projection_matrix[4][2]
    clip_coords_w := projection_matrix[1][4] * target.x + projection_matrix[2][4] * target.y + projection_matrix[3][4] * target.z + projection_matrix[4][4]

    if (clip_coords_w > 0.01)
    {
        NDC_X := clip_coords_x / clip_coords_w
        NDC_Y := clip_coords_y / clip_coords_w
        out.Push((width * NDC_X) + (width + NDC_X))
        out.Push(-(height * NDC_Y) + (height + NDC_Y))
    }
    return out
}

b64Encode(string)
{
    VarSetCapacity(bin, StrPut(string, "UTF-8")) && len := StrPut(string, &bin, "UTF-8") - 1
    if !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", 0, "uint*", size))
        throw Exception("CryptBinaryToString failed", -1)
    VarSetCapacity(buf, size << 1, 0)
    if !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", &buf, "uint*", size))
        throw Exception("CryptBinaryToString failed", -1)
    return StrGet(&buf)
}

APICall(method, site, request := "", j := True)
{
    static
    req.Open(method, site, False)
    req.setRequestHeader("Content-Type", "application/json")
    req.setRequestHeader("Accept", "application/json")
    req.setRequestHeader("Authorization", "Basic " . tokenENC)
    req.Option(4) := 0x3300
    if % (method == "POST" || method == "PUT" || method == "PATCH")
        req.Send(request)
    else
        req.Send()
    ; global httpstatus := req.Status
    Arr := req.responseBody
    pData := NumGet(ComObjValue(arr) + 8 + A_PtrSize)
    length := Arr.MaxIndex() + 1
    if(j == True)
        return JSON.Load(StrGet(pData, length, "UTF-8"))
    return StrGet(pData, length, "UTF-8")
}

rand(a, b)
{
    Random, c, a, b
    return c
}

StrUpper(text)
{
    StringUpper, text, text
    return text
}