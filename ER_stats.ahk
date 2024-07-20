#Requires AutoHotkey v1+
#NoEnv
#SingleInstance, Force
; #Persistent
SendMode, Input
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
RunAsAdmin() ; required to get game handle

#Include <JSON>
#Include <utils>
#Include <JSONFile>
#Include <ShinsMemoryClass>
#Include <ShinsOverlayClass>

resists := {"current": [], "max": []}
cheatVer := "2.2.0.0" ; cheatVer should be gameVer
targetEXE := "eldenring.exe"
isSameVersion := isEligible()

ring_mem := new ShinsMemoryClass("ahk_exe " targetEXE,, "lib")
ring_draw := new ShinsOverlayClass("ahk_exe " targetEXE)
ring_json := new JSONFile("settings.json")
settings := ring_json.Object().bars

x := ring_draw.width/2
y := (800/1080)*ring_draw.height
w := 300
h := 150
rect := AnchorTopMiddle(x, y, w, h)
global index := 1


if(isSameVersion) {
    LockOnTarget := ring_mem.GetPointer(ring_mem.baseAddress + 0x716FAE)
    GameDataMan := ring_mem.ReadInt64(ring_mem.baseAddress + 0x3D5DF38)
    EventFlagMan := ring_mem.ReadInt64(ring_mem.baseAddress + 0x3D68448)
}
else {
    LockOnTarget := ring_mem.AOB("48 8B 48 08 49 89 8D B0 06 00 00 49 8B CE E8")

    GameDataManTemp := ring_mem.AOB("48 8B 05 ?? ?? ?? ?? 48 85 C0 74 05 48 8B 40 58 C3 C3")
    GameDataMan := ring_mem.ReadInt64(GameDataManTemp + ring_mem.ReadInt64(GameDataManTemp+0x3) + 0x7)

    EventFlagManTemp := ring_mem.AOB("48 8B 3D ?? ?? ?? ?? 48 85 FF ?? ?? 32 C0 E9")
    EventFlagMan := ring_mem.ReadInt64(EventFlagManTemp + ring_mem.ReadInt64(EventFlagManTemp+0x3) + 0x7)
}

entry := ring_mem.baseAddress + 0x1302
LastLockOnTarget := new HookHelper(ring_mem, entry,, LockOnTarget)
if (LastLockOnTarget.address = 0) {
	msgbox % "Problem allocating a LastLockOnTarget!`n`nProgram will now exit"
	exitapp
}

str := "00 00"  ;add [rax],al
str .= " 00 00"  ;add [rax],al
str .= " 00 00"  ;add [rax],al
str .= " 00 00"  ;add [rax],al
str .= " 48 A3 REPLE64"  ;mov [LastLockOnTarget],rax
str .= " 48 8B 48 08"  ;mov rcx,[rax+08]
str .= " 49 89 8D B0 06 00 00"  ;mov [r13+000006B0],rcx
str .= " E9 JUMP"  ;jmp eldenring.exe+716FB9

LastLockOnTarget.WriteASM(str, LastLockOnTarget.address, LockOnTarget+0xB)
LastLockOnTarget.hook(LockOnTarget, LastLockOnTarget.address + 0x8)


resistances := ["poison", "rot", "bleed", "blight", "frost", "sleep", "mad", "poison_max", "rot_max", "bleed_max", "blight_max", "frost_max", "sleep_max", "mad_max"]
loop
{
    deathCount := ring_mem.ReadInt(GameDataMan+0x94)
    level := ring_mem.ReadInt(GameDataMan, [0x8, 0x68]*)
    isScene := ring_mem.ReadUChar(EventFlagMan, [0x28, 0x113]*)
    target := ring_mem.ReadPtr(LastLockOnTarget.address)

    resists.current.hp := ring_mem.ReadInt(target, [0x190, 0x0, 0x138]*)
    resists.max.hp_max := ring_mem.ReadInt(target, [0x190, 0x0, 0x13C]*)
    resists.current.poise := Format("{:d}", ring_mem.ReadFloat(target, [0x190, 0x40, 0x10]*)) 
    resists.max.poise_max := Format("{:d}", ring_mem.ReadFloat(target, [0x190, 0x40, 0x14]*)) 

    res := ring_mem.ReadPtr(target, [0x190, 0x20]*)
    for k, v in resistances
    {
        if(A_Index <= 7)
            resists.current[v] := ring_mem.ReadInt(res+0x10+(k-1)*0x4)
        else
            resists.max[v] := ring_mem.ReadInt(res+0x10+(k-1)*0x4)
    }
    ; ToolTip % objView(resists)

    if(ring_draw.Begindraw()) {
        if(isScene) {
            ring_draw.EndDraw()
            continue
        }
        ring_draw.DrawText("NL Runes: " lvlToRunes(level), -5, 50, 18, 0xAAD2A622,,"aRight dsFF000000")
        ring_draw.DrawText("Death Count: " deathCount, -5, 68, 18, 0xAAD2A622,,"aRight dsFF000000")

        if(!target || resists["current"]["hp"] <= 0 || resists["max"]["poise_max"] <= 0) {
            ring_draw.EndDraw()
            continue
        }
        for name, value in settings {
            if(value.on == False)
                continue
            if(!InStr(value.name, "hp"))
		        Bar(value.name, value.value)
            else
                Bar(value.name, value.value,,, True)
            index++
        }
        
        index := 1
		ring_draw.EndDraw()
	}
}
return

Bar(name, color, withName := True, withNumbers := True, headLess := False) {
    global rect, ring_draw, index, resists
    static count := 8, pad := 6 ;???
    w := rect.w
    h := (rect.h-(count-1)*pad)/count
    bW := ring_draw.width/2 + w/2 + pad*2
    bH := rect.y+h*(index-1)+pad*(index-1)
    
    ratio := resists["current"][name] / resists["max"][name "_max"]
    barW := ratio * rect.w

    if(!headLess) {
        ring_draw.FillRectangle(rect.x, bH, w, h, 0x99333333)
        ring_draw.FillRectangle(rect.x, bH, barW, h, color)
        if(withName)
            ring_draw.DrawText(name, -bW, bH, h, color,,"aRight dsFF000000")
        if(withNumbers)
            ring_draw.DrawText(resists["current"][name] "/" resists["max"][name "_max"], bW, bH, h, color,,"aLeft dsFF000000")
    }
    else
        ring_draw.DrawText(resists["current"][name] "/" resists["max"][name "_max"], 0, bH, h, color,,"aCenter dsFF000000")
}

lvlToRunes(lvl) {
    x := ((lvl+81)-92)*0.02
    runeCost := ((x+0.1)*((lvl+81)**2))+1
    return floor(runeCost)
}

AnchorTopMiddle(boxX, boxY, boxWidth, boxHeight) {
    boxX := boxX - (boxWidth / 2)

    r := {"x": boxX
         ,"y": boxY
         ,"w": boxWidth
         ,"h": boxHeight}
    return r
}

getPathByExe(name) {
    for process in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" name "'")
    {
        return process.ExecutablePath
    }
    return ""
}

isEligible() {
    global targetEXE, cheatVer
    
    isSameVersion := 0

    if(FilePath := getPathByExe(targetEXE)) {
        FileGetVersion, FileVersion, % FilePath
        isSameVersion := VerCompare(FileVersion, cheatVer)
        if(isSameVersion != 0)
            msgbox % "The game version is " FileVersion " and the cheat runs on version " cheatVer ". `nRun at your own risk."
    }
    else
        msgbox % "Failed to get game path.`nGame should run on version " cheatVer
    
    if(WinExist("ahk_exe EasyAntiCheat_EOS.exe")) {
        msgbox % "You must first disable the anticheat."
        ExitApp
    }
    
    if(!WinExist("ahk_exe " targetEXE)) {
        msgbox % "Game is not running."
        ExitApp
    }
    return isSameVersion = 0 ? 1 : 0
}

RunAsAdmin() {
    if(!A_IsAdmin) {
        Run *RunAs "%A_ScriptFullPath%"
        ExitApp
    } 
}

rewrite() {
    global ring_mem, LockOnTarget
    ring_mem.WriteByteString(LockOnTarget, "48 8B 48 08 49 89 8D B0 06 00 00 49 8B CE E8 2F BD CD FF 84 C0 75 18 49 8B 5E 08 48 8D 4D B8 E8 FE E3 FF FF 48 8B C8 48 8B D3 E8 D3 74 05 00 49")
}

$^x::
{
    rewrite()
    ExitApp
}