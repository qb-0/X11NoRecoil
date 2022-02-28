import 
  x11/[x, xlib, xtst, keysym],
  os, parsecfg, strutils, terminal

let 
  dpy = XOpenDisplay(nil)
  rootWin = XRootWindow(dpy, 0)

var mvDelay: int

type Settings = object
  sleep, y, delay: int
  status: bool

proc keyPressed*(key: KeySym): bool =
  var keys: array[0..31, char]
  discard XQueryKeymap(dpy, keys)
  let keycode = XKeysymToKeycode(dpy, key)
  (ord(keys[keycode.int div 8]) and (1 shl (keycode.int mod 8))) != 0

proc parseConfig*(f: string): Settings =
  try:
    var c = loadConfig(f)
    result.sleep = parseInt(c.getSectionValue("", "sleep"))
    result.y = parseInt(c.getSectionValue("", "y"))
    result.delay = parseInt(c.getSectionValue("", "delay"))
  except:
    echo "Unable to parse Config: " & getCurrentExceptionMsg()
    quit(QuitFailure)

proc noRecoil(y, delay: int) =
  var
    qRoot, qChild: Window
    qRootX, qRootY: cint
    qChildX, qChildY: cint
    qMask: cuint
    
  discard XQueryPointer(dpy, rootWin, qRoot.addr, qChild.addr, qRootX.addr, qRootY.addr, qChildX.addr, qChildY.addr, qMask.addr)

  if (qMask and Button1Mask).bool:
    inc mvDelay
    if mvDelay >= delay:
      discard XTestFakeRelativeMotionEvent(dpy, 0, y.cint, CurrentTime)
      discard XFlush(dpy)
  elif mvDelay != 0:
    mvDelay = 0

proc main =
  template echos(args: varargs[untyped]) = stdout.styledWriteLine(args)

  discard execShellCmd("clear")
  echos(bgBlack, fgCyan, "X11 No Recoil")
  var cfg = parseConfig("config.ini")
  echos("Sleep time:\t", bgBlack, fgCyan, $cfg.sleep, "ms")
  echos("Mouse offset:\t", bgBlack, fgCyan, $cfg.y, " pixel")
  echos("Delay:\t\t", bgBlack, fgCyan, $(cfg.delay * cfg.sleep), "ms")
  echos("Status\t\t", bgBlack, fgRed, "Off")

  while true:
    if keyPressed(XK_Home):
      cfg.status = not cfg.status
      stdout.cursorUp(1); stdout.eraseLine()
      echos("Status:\t\t", bgBlack, if cfg.status: fgGreen else: fgRed, if cfg.status: "On" else: "Off")
      sleep(500)
    
    if cfg.status:
      sleep(cfg.sleep)
      noRecoil(cfg.y, cfg.delay)
    else:
      sleep(50)

if isMainModule:
  main()