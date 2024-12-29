abstract class ScriptFunctionDefinition {
  String get functionName;
  int get numberOfParameters;
  int get numberOfLocals;
  bool get hasReturnValue;
}

enum InBuiltScriptFunction implements ScriptFunctionDefinition {
  pressScanCode(1, false, 0, false),
  releaseScanCode(1, false, 1, false),
  tapScanCode(1, false, 2, false),
  isScanCodePressed(1, true, 3, true),
  pressStenoKey(1, false, 4, false),
  releaseStenoKey(1, false, 5, false),
  isStenoKeyPressed(1, true, 6, true),
  releaseAll(0, false, 7, false),
  isButtonPressed(1, true, 8, true),
  pressAll(0, false, 9, false),
  sendText(1, false, 0xa, false),
  console(1, true, 0xb, false),
  checkButtonState(1, true, 0xc, true),
  isInPressAll(0, true, 0xd, true),
  setRgb(4, false, 0xe, false),
  getTime(0, true, 0xf, false),
  getLedStatus(1, true, 0x10, true),
  setGpioPin(2, false, 0x11, false),
  clearDisplay(1, false, 0x12, false),
  setAutoDraw(2, false, 0x13, false),
  setScreenOn(2, false, 0x14, false),
  setScreenContrast(2, false, 0x15, false),
  drawPixel(3, false, 0x16, false),
  drawLine(5, false, 0x17, false),
  drawImage(4, false, 0x18, false),
  drawText(6, false, 0x19, false),
  setDrawColor(2, false, 0x1a, false),
  drawRect(5, false, 0x1b, false),
  setHsv(4, false, 0x1c, false),
  rand(0, true, 0x1d, false),
  isUsbConnected(0, true, 0x1e, true),
  isUsbSuspended(0, true, 0x1f, true),
  getParameter(1, true, 0x20, false),
  isConnected(1, true, 0x21, true),
  getActiveConnection(0, true, 0x22, false),
  setPreferredConnection(3, false, 0x23, false),
  isPairConnected(1, true, 0x24, true),
  startBlePairing(0, false, 0x25, false),
  getBleProfile(0, true, 0x26, false),
  setBleProfile(1, false, 0x27, false),
  isHostSleeping(0, true, 0x28, true),
  isMainPowered(0, true, 0x29, true),
  isCharging(0, true, 0x2a, true),
  getBatteryPercentage(0, true, 0x2b, false),
  getActivePairConnection(0, true, 0x2c, false),
  setBoardPower(1, false, 0x2d, false),
  sendEvent(1, false, 0x2e, false),
  isPairPowered(0, true, 0x2f, true),
  setInputHint(1, false, 0x30, false),
  setScript(2, false, 0x31, false),
  isBoardPowered(0, true, 0x32, true),
  startTimer(4, false, 0x33, false),
  stopTimer(1, false, 0x34, false),
  isTimerActive(1, true, 0x35, true),
  isBleProfileConnected(1, true, 0x36, true),
  disconnectBle(0, false, 0x37, false),
  unpairBle(0, false, 0x38, false),
  isBleProfilePaired(1, true, 0x39, true),
  isBleProfileSleeping(1, true, 0x3a, true),
  isBleAdvertising(0, true, 0x3b, true),
  isBleScanning(0, true, 0x3c, true),
  isWaitingForUserPresence(0, true, 0x3d, true),
  replyUserPresence(1, false, 0x3e, false),
  setGpioInputPin(2, false, 0x3f, false),
  readGpioPin(1, true, 0x40, true),
  drawGrayscaleRange(6, false, 0x41, false),
  setGpioPinDutyCycle(2, false, 0x42, false),
  cancelAllStenoKeys(0, false, 0x43, false),
  cancelStenoKey(1, false, 0x44, false),
  stopSound(0, false, 0x45, false),
  playFrequency(1, false, 0x46, false),
  playSequence(1, false, 0x47, false),
  playWaveform(3, false, 0x48, false),
  callAllReleaseScripts(0, false, 0x49, false),
  isInReleaseAll(0, true, 0x4a, true),
  getPressCount(0, true, 0x4b, false),
  getReleaseCount(0, true, 0x4c, false),
  isStenoJoinNext(0, true, 0x4d, true),
  callPress(1, false, 0x4e, false),
  callRelease(1, false, 0x4f, false),
  pressMouseButton(1, false, 0x50, false),
  releaseMouseButton(1, false, 0x51, false),
  tapMouseButton(1, false, 0x52, false),
  isMouseButtonPressed(1, true, 0x53, true),
  moveMouse(2, false, 0x54, false),
  wheelMouse(1, false, 0x55, false),
  setEnableButtonStates(1, false, 0x56, false),
  printValue(2, false, 0x57, false),
  getWpm(1, true, 0x58, false),
  ;

  const InBuiltScriptFunction(
    this.numberOfParameters,
    this.hasReturnValue,
    this.functionIndex,
    this.isBooleanResult,
  ) : assert(!(hasReturnValue == false && isBooleanResult == true));

  @override
  String get functionName => name;

  @override
  final int numberOfParameters;

  @override
  int get numberOfLocals => 0;

  @override
  final bool hasReturnValue;

  final int functionIndex;

  final bool isBooleanResult;
}
