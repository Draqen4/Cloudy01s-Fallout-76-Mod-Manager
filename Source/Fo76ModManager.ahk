;;;;;;;;;;;;;;;;;;;;;;
;Pre-run
;;;;;;;;;;;;;;;;;;;;;;
;Temp files
  ifnotexist,%A_Temp%\FO76ModMan.temp
    filecreatedir,%A_Temp%\FO76ModMan.temp
  FileInstall, FalloutGuy.png, %A_Temp%\FO76ModMan.temp\Fallout76ModManagerGuy.png,1
  FileInstall, bsab.exe, %A_Temp%\FO76ModMan.temp\bsab.exe,1

;System vars
  #NoEnv
  #SingleInstance Force
  #NoTrayIcon
  VersionNumber = 1.13

;Handle scrolling the UI
  OnMessage(0x115, "OnScroll") ; WM_VSCROLL
  OnMessage(0x114, "OnScroll") ; WM_HSCROLL
  Gui, +Resize +0x300000 ; WS_VSCROLL | WS_HSCROLL

;Help stuff that appears in multiple places.
  IniFileHelp = This typically is in your my documents folder\My Games\Fallout 76`n`nEg: C:\Users\USERNAME\Documents\My Games\Fallout 76`n`nIf you don't have a Fallout76Custom.ini file, then copy Fallout76.ini and rename it to Fallout76Custom.ini, and then use Notepad to make the file empty.
  ModFolderHelp = This is usually the data folder in Fallout76`n`nEg: C:\Program Files (x86)\Bethesda.net Launcher\Games\Fallout76\Data
  Fallout76PrefsIni = %A_MyDocuments%\My Games\Fallout 76\Fallout76Prefs.ini

;Check for the settings file, do a first time setup if not found (We need to know what folder the mods are in so we can populate the GUI with them.)
  ifnotexist,ModManagerPrefs.ini
  {
    ModsFolder := FindModFolder()
    if !(ModsFolder) ;Auto-detect wasn't able to successfully find the right folder. Ask user to do it manually.
    {
      msgbox,,Welcome!,Welcome to the mod manager. In order to use it, please select the folder where your mods are installed.`n`n%ModFolderHelp%
      SetupSelectModFolder:
        FileSelectFolder,NewModsFolder,,2
        IfNotExist,%NewModsFolder%\*.ba2
        {
          msgbox,5,Error!,The folder you selected does not contain any .ba2 mod files. Please try again by selecting the folder where mods are installed.`n`n%ModFolderHelp%
          ifMsgBox Retry
            goto,SetupSelectModFolder
          else
            Exitapp
        }
        else
          ModsFolder := NewModsFolder
    }
    IfNotExist,%A_MyDocuments%\My Games\Fallout 76\Fallout76Custom.ini
      FileAppend,,%A_MyDocuments%\My Games\Fallout 76\Fallout76Custom.ini
    Fallout76CustomIni = %A_MyDocuments%\My Games\Fallout 76\Fallout76Custom.ini
    gosub,SaveSettingsFile
  }
  else
    gosub,LoadSettingsFile

;Get the list of currently enabled mods. The GUI needs this to default mods to on/off
  Iniread,sResourceArchive2List,%Fallout76CustomIni%,Archive,sResourceArchive2List
  Iniread,sResourceStartUpArchiveList,%Fallout76CustomIni%,Archive,sResourceStartUpArchiveList
  Iniread,sResourceIndexFileList,%Fallout76CustomIni%,Archive,sResourceIndexFileList



;;;;;;;;;;;;;
;GUI
;;;;;;;;;;;;;
CreateGUI:
  DesiredGUIHeight = 220 ;Default height if zero mods are found. Height is added later on on a per mod found basis.
  Gui, Add, Picture, x320 y300 H200 W150, %A_Temp%\FO76ModMan.temp\Fallout76ModManagerGuy.png
  Gui, Add, Text, x22 y15 w70 h20 , Mods Folder:
  Gui, Add, Edit, x92 y9 w361 h20 vModsFolder,%ModsFolder%
  Gui, Add, Button, x455 y9 w30 h20 gSelectModFolderButton, .. ;Define mods folder button
  Gui, Add, Button, x490 y9 w15 h20 gModFolderHelpButton, ? ;Mods help button
  Gui, Add, Text, x22 y37 w150 h20 , Fallout76Custom.ini:
  Gui, Add, Edit, x122 y30 w330 h20 vFallout76CustomIni,%Fallout76CustomIni%
  Gui, Add, Button, x455 y30 w30 h20 gSelectIniFileButton, .. ;Define ini file button
  Gui, Add, Button, x490 y30 w15 h20 gIniFileHelpButton, ? ;Ini help button
  Gui, Add, Text, x22 y75 w150 h20, Mods:

  ;Look for mods and add them to the GUI
    CurrentModNumber = 0 ;Used to create an array of mods with the corresponding values. eg: Mod2 = glow.ba2 (This is used so when writing the fallout65custom.ini we know which mods are enabled.)
    Loop Files, %ModsFolder%\*.ba2 ;Look at all the potential mod files
    {
      ifinstring,A_LoopFileName,SeventySix - ;Skip default game files. Only interested in mods.
        continue
      CurrentModNumber ++
      ModName%CurrentModNumber% := A_LoopFileName ;Add this mod and its value to the mod array. Eg Mod2 = glow.ba2
      if ModAlreadyEnabled(A_LoopFileName) ;Default the checkboxes to on/off depending on if they're already enabled in the ini file.
        Gui, Add, CheckBox, w250 h15 vModStatus%CurrentModNumber% Checked, %A_LoopFileName%
      else
        Gui, Add, CheckBox, w250 h15 vModStatus%CurrentModNumber%, %A_LoopFileName%
      DesiredGUIHeight := DesiredGUIHeight + 17 ;Expand the GUI to fit the current mod in it.
    }
    TotalNumberOfMods := CurrentModNumber ;Used by the save button to determine loop count when saving each mod.

  ;We should find which settings need to be pre-filled on the GUI, so the user can load their settings.
    IntroCheckbox := DefaultCheckedStatus(Fallout76CustomIni,"General","sIntroSequence",1) ;These need to be either blank or "Checked" in AHK Language so the GUI can create them accordingly.
    DOFCheckbox := DefaultCheckedStatus(Fallout76CustomIni,"ImageSpace","bDynamicDepthOfField",1)
    MotionBlurCheckbox := DefaultCheckedStatus(Fallout76CustomIni,"ImageSpace","bMBEnable",1)
    VSyncCheckbox := DefaultCheckedStatus(Fallout76PrefsIni,"Display","iPresentInterval",1)
    MouseSensitivityTweakCheckbox := DefaultCheckedStatus(Fallout76CustomIni,"Controls","fMouseHeadingYScale",0)

    Gui, Add, Text, w1 h1 x340 y75,
    Gui, Add, Text, w80 h20, Misc goodies:
    Gui, Add, CheckBox, w100 h15 vIntroVideosStatus %IntroCheckbox%, Intro videos
    Gui, Add, CheckBox, w150 h15 vMotionBlurStatus %MotionblurCheckbox%, Motion blur effects
    Gui, Add, CheckBox, w150 h15 vDOFStatus %DOFCheckbox%, Depth of field effects
    Gui, Add, CheckBox, w150 h15 vVsyncStatus %VSyncCheckbox%, Capped FPS (Vsync)
    Gui, Add, CheckBox, w150 h15 vMouseSensitivityTweakStatus %MouseSensitivityTweakCheckbox%, Fix mouse Y sensitivity
    Gui, Add, Button,gSaveButton, Save Settings
    Gui, Add, Button,gRescanButton, Re-scan for new mods

  ;Error handling
    if CurrentModNumber = 0
    {
      if (AutoDetectedModsFolder)
        msgbox,,Oh noes!,The mods folder was auto-detected, but didn't seem to contain any mods.`nPlease make sure the mods folder is correct in the mod manager.
      else
        msgbox,,Error!,No mods were found! Did you pick the correct folder that holds the .ba2 files?`n%ModFolderHelp%
    }
    ;Check if any mods have been deleted since they were last enabled.
    ;  if sResourceArchive2List != ERROR ;If Fallout76Custom exists and contains mods, then we should do a test to see if they're still there.
    ;  {
    ;    sResourceArchive2ListArray := StrSplit(sResourceArchive2List,",")
    ;    loop % sResourceArchive2ListArray.Length() ;Check all previously enabled mods
    ;    {
    ;      CurrentModBeingChecked := sResourceArchive2ListArray[A_Index]
    ;      ifinstring,CurrentModBeingChecked,SeventySix
    ;        continue ;ignore default mods.
    ;      SearchDir := ModsFolder . "\" . CurrentModBeingChecked
    ;      ifnotexist,%SearchDir%
    ;      {
    ;        msgbox,,Notice,% "The mod: " . CurrentModBeingChecked " was previously enabled, but is now missing from the mod folder.`n`nIt has automatically been disabled."
    ;        ;Remove the offending deleted mod from the ini list immediately so it isn't attempted to be loaded by the game.
    ;          sResourceArchive2List := RemoveModFromList(CurrentModBeingChecked,sResourceArchive2List)
    ;          EditCustomIni(sResourceArchive2List,"sResourceArchive2List","Archive")
    ;      }
    ;    }
    ;  }

  ;Cap the height from going too tall and off the monitor. Capped it at 75%
    if (DesiredGUIHeight / A_ScreenHeight * 100) >= 75
      DesiredGUIHeight := 0.5 * A_ScreenHeight
  ;Show the GUI
    Gui, Show, H%DesiredGUIHeight%,Cloudy01's Fallout 76 Mod Manager Ver %VersionNumber%
    Gui, +LastFound
    GroupAdd, MyGui, % "ahk_id " . WinExist()
return














;;;;;;;;;;;;;;;;
;Subroutines
;;;;;;;;;;;;;;;;
SaveSettingsFile:
  EditModManagerIni(ModsFolder,"ModsFolder","Settings")
  EditModManagerIni(Fallout76CustomIni,"Fallout76CustomIni","Settings")
return

LoadSettingsFile:
  ifexist,ModManagerPrefs.ini
  {
      IniRead,ModsFolder,ModManagerPrefs.ini,Settings,ModsFolder
      IniRead,Fallout76CustomIni,ModManagerPrefs.ini,Settings,Fallout76CustomIni
  }
return

RemoveToolTip: ;Used by the timer, so we don't have to sleep and bog down the main thread.
SetTimer, RemoveToolTip, Off
ToolTip
return

GuiSize:
  UpdateScrollBars(A_Gui, A_GuiWidth * 1.5, A_GuiHeight)
return

GuiClose:
  ExitApp


















;;;;;;;;;;;;;;;;;
;GUI Buttons
;;;;;;;;;;;;;;;;;
SaveButton:
  gui,submit,NoHide

  ;Goodies
    if IntroVideosStatus = 0
    {
      EditCustomIni(IntroVideosStatus,"sIntroSequence","General")
      EditCustomIni(IntroVideosStatus,"uMainMenuDelayBeforeAllowSkip","General")
    }
    else
    {
      DeleteFromCustomIni("sIntroSequence","General")
      DeleteFromCustomIni("uMainMenuDelayBeforeAllowSkip","General")
    }
    if MotionBlurStatus = 0
      EditCustomIni(MotionBlurStatus,"bMBEnable","ImageSpace")
    else
      DeleteFromCustomIni("bMBEnable","ImageSpace")
    if DOFStatus = 0
    {
      EditCustomIni(DOFStatus,"bDynamicDepthOfField","ImageSpace")
      EditCustomIni(0,"fDOFBlendRatio","Display")
      EditCustomIni(999999,"fDOFMinFocalCoefDist","Display")
      EditCustomIni(99999999,"fDOFMaxFocalCoefDist","Display")
      EditCustomIni(99999999,"fDOFDynamicFarRang","Display")
      EditCustomIni(0,"fDOFCenterWeightInt","Display")
      EditCustomIni(99999999,"fDOFFarDistance","Display")
    }
    else
    {
      DeleteFromCustomIni("bDynamicDepthOfField","ImageSpace")
      DeleteFromCustomIni("fDOFBlendRatio","Display")
      DeleteFromCustomIni("fDOFMinFocalCoefDist","Display")
      DeleteFromCustomIni("fDOFMaxFocalCoefDist","Display")
      DeleteFromCustomIni("fDOFDynamicFarRang","Display")
      DeleteFromCustomIni("fDOFCenterWeightInt","Display")
      DeleteFromCustomIni("fDOFFarDistance","Display")
    }
    if VSyncStatus = 1
      EditPrefsIni(1,"iPresentInterval","Display")
    else
      EditPrefsIni(0,"iPresentInterval","Display")
    if MouseSensitivityTweakStatus = 1
    {
      EditCustomIni(0.021,"fMouseHeadingXScale","Controls")
      EditCustomIni(GetMouseYRatio(),"fMouseHeadingYScale","Controls")
    }
    else
    {
      DeleteFromCustomIni("fMouseHeadingXScale","Controls")
      DeleteFromCustomIni("fMouseHeadingYScale","Controls")
    }

  ;FO76 Needs a list of mods in a comma delimited fasion, and mods in different load orders. With the default files first (or the in-game store doesn't load)
    ShowTooltip("Detecting best load order",30000)
    CurrentEnabledModNumber = 1
    sResourceArchive2List := "SeventySix - ATX_Main.ba2, SeventySix - ATX_Textures.ba2"
    sResourceStartUpArchiveList := "SeventySix - Interface.ba2, SeventySix - Localization.ba2, SeventySix - Shaders.ba2, SeventySix - Startup.ba2"
    sResourceIndexFileList := "SeventySix - Textures01.ba2, SeventySix - Textures02.ba2, SeventySix - Textures03.ba2, SeventySix - Textures04.ba2, SeventySix - Textures05.ba2, SeventySix - Textures06.ba2"

    loop %TotalNumberOfMods%
    {
      if ModStatus%A_Index% = 1
      {
        if GetModsCorrectLocation(ModName%A_Index%) = "sResourceStartUpArchiveList"
          sResourceStartUpArchiveList := sResourceStartUpArchiveList . "," . ModName%A_Index%
        else if GetModsCorrectLocation(ModName%A_Index%) = "sResourceIndexFileList"
          sResourceIndexFileList := sResourceIndexFileList . "," . ModName%A_Index%
        else
          sResourceArchive2List := sResourceArchive2List "," . ModName%A_Index%
        CurrentEnabledModNumber ++
      }
    }
    EditCustomIni(sResourceStartUpArchiveList,"sResourceStartUpArchiveList","Archive")
    EditCustomIni(sResourceIndexFileList,"sResourceIndexFileList","Archive")
    EditCustomIni(sResourceArchive2List,"sResourceArchive2List","Archive")

  ShowTooltip("Successfully saved",1000)
  return

SelectModFolderButton:
  FileSelectFolder,NewModsFolder,,2
  if NewModsFolder !=
  {
    ModsFolder := NewModsFolder
    GuiControl,,ModsFolder,%ModsFolder%
    gosub,SaveSettingsFile
    gosub,ReScanButton ;We need to re-scan for mods because the user defined a new mod folder.
  }
  return

ReScanButton:
  gui,destroy
  gosub,CreateGUI
  return

SelectIniFileButton:
  FileSelectFile,NewFallout76CustomIni,2,,Select your Fallout76Custom.ini file,Fallout76Custom.ini
  if NewFallout76CustomIni !=
  {
      Fallout76Custom := NewFallout76CustomIni
      GuiControl,,Fallout76CustomIni,%Fallout76CustomIni%
      gosub,SaveSettingsFile
  }
  return

ModFolderHelpButton:
  Msgbox,,Help,This is where your mods are currently installed.`n`n%ModFolderHelp%
  return

IniFileHelpButton:
  Msgbox,,Help,This is where your Fallout76Custom.ini is stored. Typically in your documents folder\My Games\Fallout 76`n`nEg: C:\Users\USERNAME\Documents\My Games\Fallout 76`n`nIf you don't have a Fallout76Custom.ini file, then copy Fallout76.ini and rename it to Fallout76Custom.ini, and then use Notepad to make the file empty.
  return











;;;;;;;;;;;;;;;;;;;;;
;Functions
;;;;;;;;;;;;;;;;;;;;;

;Mod Management
  GetModsCorrectLocation(TheMod)
  {
    global ModsFolder

    ;We should re-scan existing mods if the mod was updated (In-case it needs a changed load order)
      if HasBeenModified(TheMod)
        filedelete,%A_Temp%\FO76ModMan.temp\%TheMod%.txt

    ;We need to dump the contents of the mod so we can scan what files it contains, then sort accordingly
      ifnotexist,%A_Temp%\FO76ModMan.temp\%TheMod%.txt
      {
        cmd := "cmd.exe /q /c " . A_Temp . "\FO76ModMan.temp\bsab.exe /l """ . ModsFolder . "\" . TheMod . """" ;This mess is because the command must be literal: bsab.exe "C:\PATH-TO-FILE\TheMod.ba2" to work.
      ;  msgbox % cmd
        ListOfFiles := ComObjCreate("WScript.Shell").Exec(cmd).StdOut.ReadAll()
        FileAppend,%ListOfFiles%,%A_Temp%\FO76ModMan.temp\%TheMod%.txt
      }
      else
        fileread,ListOfFiles,%A_Temp%\FO76ModMan.temp\%TheMod%.txt

    ;Determine the correct folder. Certain types of mods need to be in specific load orders, because FO76 just works in funky ways.
      ;Commented out because Bag and BagGlow weren't working when in sResourceIndexFileList. I checked Nexusmods and I can't seem to see any mods that even need to be in this list?
        ;  if InStr(ListOfFiles,"model") or InStr(ListOfFiles,"texture") or InStr(ListOfFiles,"sfx")
        ;    return "sResourceIndexFileList"
        ;  else if InStr(ListOfFiles,"interface") or InStr(ListOfFiles,"strings") or InStr(ListOfFiles,"music")
        ;if InStr(ListOfFiles,"interface") or InStr(ListOfFiles,"strings") or InStr(ListOfFiles,"music")
          ;return "sResourceStartUpArchiveList"
      Loop, read, %A_Temp%\FO76ModMan.temp\%TheMod%.txt, %A_Temp%\FO76ModMan.temp\%TheMod%.txt
      {
        if (A_LoopReadLine) ;If this line isn't blank
        {
          RootFolder := StrReplace(A_LoopReadLine,"\","/") ;bsab sometimes makes paths with slashes the wrong way around. They need to be the right way around so strsplit works.
          RootFolder := StrSplit(RootFolder,"/")
          if (RootFolder[1] = "interface" or RootFolder[1] = "strings" or RootFolder[1] = "music")
           return "sResourceStartUpArchiveList"
        }
        else
          return "sResourceArchive2List"
      }
  }


  HasBeenModified(TheMod)
  {
    global ModsFolder

    FileGetTime,CurrentModifiedDate,%ModsFolder%\%TheMod%
    Iniread,OldModifiedDate,%A_Temp%\FO76ModMan.temp\ModModifiedDateDatabase.ini,ModifiedDates,%TheMod%

    if CurrentModifiedDate = %OldModifiedDate%
      return false
    else
    {
      IniWrite,%CurrentModifiedDate%,%A_Temp%\FO76ModMan.temp\ModModifiedDateDatabase.ini,ModifiedDates,%TheMod%
      return true
    }
  }


  FindModFolder()
  {
    ;We should check if the game is in a default location on each HDD. We do this so the user doesn't have to manually define the mod folder upon first launch.
      DriveGet,DriveLetters,List
      DriveLettersArray := StrSplit(DriveLetters)
      PossibleGameLocationsArray := Array("Program Files\","Program Files (x86)\","Games\","")
      TypicalGameSubDir = Bethesda.net Launcher\Games\Fallout76\Data

    loop % DriveLettersArray.Length()
    {
      CurrentDrive := DriveLettersArray[A_Index]
      loop % PossibleGameLocationsArray.Length()
      {
          GameFolder := CurrentDrive . ":\" . PossibleGameLocationsArray[A_Index] . TypicalGameSubDir
          if FileExist(GameFolder)
          {
            ModsFolder := GameFolder
            break
          }
      }
    }
    return ModsFolder
  }

  ModAlreadyEnabled(Query)
  {
    global sResourceArchive2List
    global sResourceStartUpArchiveList
    global sResourceIndexFileList
    CombinedModsArray := sResourceArchive2List . "," . sResourceStartUpArchiveList . "," . sResourceIndexFileList
    EnabledModsArray := StrSplit(CombinedModsArray,",")  ;This needs to be an array instead of just contains because otherwise "BagGlow" and "Glow" would both return true.
    return ArrayContainsValue(EnabledModsArray,Query)
  }

;Ini Files
  DeleteFromCustomIni(Name,Section)
  {
    global Fallout76CustomIni
    IniDelete,%Fallout76CustomIni%,%Section%,%Name%
    return
  }

  EditCustomIni(Value,Name,Section)
  {
    global Fallout76CustomIni
    IniWrite,%Value%,%Fallout76CustomIni%,%Section%,%Name%
    return
  }

  EditModManagerIni(Value,Name,Section)
  {
   IniWrite,%Value%,ModManagerPrefs.ini,%Section%,%Name%
   return
  }

  EditPrefsIni(Value,Name,Section)
  {
    global Fallout76PrefsIni
    IniWrite,%Value%,%Fallout76PrefsIni%,%Section%,%Name%
    return
  }

  DefaultCheckedStatus(IniFile,Section,Key,DefaultState)
  {
    Iniread,Query,%IniFile%,%Section%,%Key%
    if DefaultState = 1
    {
      if (Query = 1 or Query = "ERROR")
        return "Checked" ;Needs to be literal string for AHK Language to be either blank or checked.
      else return
    }
    else
    {
      if (Query = 0 or Query = "ERROR")
        return
      else return "Checked"
    }
  }

;Utility
  RemoveModFromList(Needle,Haystack) ;Just to be safe, removes both the one containing a comma and without. So that it's definitely gone.
  {
    stringreplace,Haystack,Haystack,%Needle%`,
    stringreplace,Haystack,Haystack,%Needle%,
    return Haystack
  }

  ShowTooltip(Text,Duration)
  {
    tooltip,%Text%
    SetTimer, RemoveToolTip, %Duration%
    return
  }

  ArrayContainsValue(haystack, needle) ; Thanks Blauhirn for this function
  {
    if(!isObject(haystack))
        return false
    if(haystack.Length()==0)
        return false
    for k,v in haystack
        if(v==needle)
            return true
    return false
  }

  GetMouseYRatio()
  {
    AspectRatio := Round(A_ScreenWidth / A_ScreenHeight,2)
    If AspectRatio = 1.78 ;16:9
      return 0.03738
    else if AspectRatio = 1.33 ;4:3
      return 0.028
    else if AspectRatio = 1.60 ;16:10
      return 0.0336
    else if AspectRatio = 2.37 ;21:9
      return 0.042
    else
      return Round(AspectRatio / 4.761904761904762,5) ;User is using some crazy resolution, try guessing the correct value. (Correct values are on PCGW. Eg: 1920x1080 / X = 0.3738. Find X by dividing the divisor by quotient)"
  }

;Scroll GUI
  #IfWinActive ahk_group MyGui
  WheelUp::
  WheelDown::
  +WheelUp::
  +WheelDown::
    ; SB_LINEDOWN=1, SB_LINEUP=0, WM_HSCROLL=0x114, WM_VSCROLL=0x115
    OnScroll(InStr(A_ThisHotkey,"Down") ? 1 : 0, 0, GetKeyState("Shift") ? 0x114 : 0x115, WinExist())
    return
  #IfWinActive

  UpdateScrollBars(GuiNum, GuiWidth, GuiHeight)
  {
    static SIF_RANGE=0x1, SIF_PAGE=0x2, SIF_DISABLENOSCROLL=0x8, SB_HORZ=0, SB_VERT=1

    Gui, %GuiNum%:Default
    Gui, +LastFound

    ; Calculate scrolling area.
    Left := Top := 9999
    Right := Bottom := 0
    WinGet, ControlList, ControlList
    Loop, Parse, ControlList, `n
    {
        GuiControlGet, c, Pos, %A_LoopField%
        if (cX < Left)
            Left := cX
        if (cY < Top)
            Top := cY
        if (cX + cW > Right)
            Right := cX + cW
        if (cY + cH > Bottom)
            Bottom := cY + cH
    }
    Left -= 8
    Top -= 8
    Right += 8
    Bottom += 8
    ScrollWidth := Right-Left
    ScrollHeight := Bottom-Top

    ; Initialize SCROLLINFO.
    VarSetCapacity(si, 28, 0)
    NumPut(28, si, 0, "uint") ; cbSize
    NumPut(SIF_RANGE | SIF_PAGE, si, 4, "uint") ; fMask

    ; Update horizontal scroll bar.
    NumPut(ScrollWidth, si, 12, "int") ; nMax
    NumPut(GuiWidth, si, 16, "uint") ; nPage
    DllCall("SetScrollInfo", "ptr", WinExist(), "int", SB_HORZ, "ptr", &si, "int", 1)

    ; Update vertical scroll bar.
;     NumPut(SIF_RANGE | SIF_PAGE | SIF_DISABLENOSCROLL, si, 4, "uint") ; fMask
    NumPut(ScrollHeight, si, 12, "int") ; nMax
    NumPut(GuiHeight, si, 16, "uint") ; nPage
    DllCall("SetScrollInfo", "ptr", WinExist(), "int", SB_VERT, "ptr", &si, "int", 1)

    if (Left < 0 && Right < GuiWidth)
        x := Abs(Left) > GuiWidth-Right ? GuiWidth-Right : Abs(Left)
    if (Top < 0 && Bottom < GuiHeight)
        y := Abs(Top) > GuiHeight-Bottom ? GuiHeight-Bottom : Abs(Top)
    if (x || y)
        DllCall("ScrollWindow", "ptr", WinExist(), "int", x, "int", y, "ptr", 0, "ptr", 0)
  }

  OnScroll(wParam, lParam, msg, hwnd)
  {
    static SIF_ALL=0x17, SCROLL_STEP=10

    bar := msg=0x115 ; SB_HORZ=0, SB_VERT=1

    VarSetCapacity(si, 28, 0)
    NumPut(28, si, 0, "uint") ; cbSize
    NumPut(SIF_ALL, si, 4, "uint") ; fMask
    if !DllCall("GetScrollInfo", "ptr", hwnd, "int", bar, "ptr", &si)
        return

    VarSetCapacity(rect, 16)
    DllCall("GetClientRect", "ptr", hwnd, "ptr", &rect)

    new_pos := NumGet(si, 20, "int") ; nPos

    action := wParam & 0xFFFF
    if action = 0 ; SB_LINEUP
        new_pos -= SCROLL_STEP
    else if action = 1 ; SB_LINEDOWN
        new_pos += SCROLL_STEP
    else if action = 2 ; SB_PAGEUP
        new_pos -= NumGet(rect, 12, "int") - SCROLL_STEP
    else if action = 3 ; SB_PAGEDOWN
        new_pos += NumGet(rect, 12, "int") - SCROLL_STEP
    else if (action = 5 || action = 4) ; SB_THUMBTRACK || SB_THUMBPOSITION
        new_pos := wParam>>16
    else if action = 6 ; SB_TOP
        new_pos := NumGet(si, 8, "int") ; nMin
    else if action = 7 ; SB_BOTTOM
        new_pos := NumGet(si, 12, "int") ; nMax
    else
        return

    min := NumGet(si, 8, "int") ; nMin
    max := NumGet(si, 12, "int") - NumGet(si, 16, "uint") ; nMax-nPage
    new_pos := new_pos > max ? max : new_pos
    new_pos := new_pos < min ? min : new_pos

    old_pos := NumGet(si, 20, "int") ; nPos

    x := y := 0
    if bar = 0 ; SB_HORZ
        x := old_pos-new_pos
    else
        y := old_pos-new_pos
    ; Scroll contents of window and invalidate uncovered area.
    DllCall("ScrollWindow", "ptr", hwnd, "int", x, "int", y, "ptr", 0, "ptr", 0)

    ; Update scroll bar.
    NumPut(new_pos, si, 20, "int") ; nPos
    DllCall("SetScrollInfo", "ptr", hwnd, "int", bar, "ptr", &si, "int", 1)
  }
