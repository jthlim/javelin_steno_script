abstract class ScriptFunctionDefinition {
  String get functionName;
  int get numberOfParameters;
  int get numberOfLocals;
  bool get hasReturnValue;
}

enum ReturnType {
  none,
  boolean,
  value,
}

enum InBuiltScriptFunction implements ScriptFunctionDefinition {
  pressScanCode(1, ReturnType.none, 0),
  releaseScanCode(1, ReturnType.none, 1),
  tapScanCode(1, ReturnType.none, 2),
  isScanCodePressed(1, ReturnType.boolean, 3),
  pressStenoKey(1, ReturnType.none, 4),
  releaseStenoKey(1, ReturnType.none, 5),
  isStenoKeyPressed(1, ReturnType.boolean, 6),
  releaseAll(0, ReturnType.none, 7),
  isButtonPressed(1, ReturnType.boolean, 8),
  pressAll(0, ReturnType.none, 9),
  sendText(1, ReturnType.none, 0xa),
  console(1, ReturnType.value, 0xb),
  checkButtonState(1, ReturnType.boolean, 0xc),
  isInPressAll(0, ReturnType.boolean, 0xd),
  setRgb(4, ReturnType.none, 0xe),
  getTime(0, ReturnType.value, 0xf),
  getLedStatus(1, ReturnType.boolean, 0x10),
  setGpioPin(2, ReturnType.none, 0x11),
  clearDisplay(1, ReturnType.none, 0x12),
  setAutoDraw(2, ReturnType.none, 0x13),
  setScreenOn(2, ReturnType.none, 0x14),
  setScreenContrast(2, ReturnType.none, 0x15),
  drawPixel(3, ReturnType.none, 0x16),
  drawLine(5, ReturnType.none, 0x17),
  drawImage(4, ReturnType.none, 0x18),
  drawText(6, ReturnType.none, 0x19),
  setDrawColor(2, ReturnType.none, 0x1a),
  drawRect(5, ReturnType.none, 0x1b),
  setHsv(4, ReturnType.none, 0x1c),
  rand(0, ReturnType.value, 0x1d),
  isUsbConnected(0, ReturnType.boolean, 0x1e),
  isUsbSuspended(0, ReturnType.boolean, 0x1f),
  getParameter(1, ReturnType.value, 0x20),
  isConnected(1, ReturnType.boolean, 0x21),
  getActiveConnection(0, ReturnType.value, 0x22),
  setPreferredConnection(3, ReturnType.none, 0x23),
  isPairConnected(1, ReturnType.boolean, 0x24),
  startBlePairing(0, ReturnType.none, 0x25),
  getBleProfile(0, ReturnType.value, 0x26),
  setBleProfile(1, ReturnType.none, 0x27),
  isHostSleeping(0, ReturnType.boolean, 0x28),
  isMainPowered(0, ReturnType.boolean, 0x29),
  isCharging(0, ReturnType.boolean, 0x2a),
  getBatteryPercentage(0, ReturnType.value, 0x2b),
  getActivePairConnection(0, ReturnType.value, 0x2c),
  setBoardPower(1, ReturnType.none, 0x2d),
  sendEvent(1, ReturnType.none, 0x2e),
  isPairPowered(0, ReturnType.boolean, 0x2f),
  setInputHint(1, ReturnType.none, 0x30),
  setScript(2, ReturnType.none, 0x31),
  isBoardPowered(0, ReturnType.boolean, 0x32),
  startTimer(4, ReturnType.none, 0x33),
  stopTimer(1, ReturnType.none, 0x34),
  isTimerActive(1, ReturnType.boolean, 0x35),
  isBleProfileConnected(1, ReturnType.boolean, 0x36),
  disconnectBle(0, ReturnType.none, 0x37),
  unpairBle(0, ReturnType.none, 0x38),
  isBleProfilePaired(1, ReturnType.boolean, 0x39),
  isBleProfileSleeping(1, ReturnType.boolean, 0x3a),
  isBleAdvertising(0, ReturnType.boolean, 0x3b),
  isBleScanning(0, ReturnType.boolean, 0x3c),
  isWaitingForUserPresence(0, ReturnType.boolean, 0x3d),
  replyUserPresence(1, ReturnType.none, 0x3e),
  setGpioInputPin(2, ReturnType.none, 0x3f),
  readGpioPin(1, ReturnType.boolean, 0x40),
  drawGrayscaleRange(6, ReturnType.none, 0x41),
  setGpioPinDutyCycle(2, ReturnType.none, 0x42),
  cancelAllStenoKeys(0, ReturnType.none, 0x43),
  cancelStenoKey(1, ReturnType.none, 0x44),
  stopSound(0, ReturnType.none, 0x45),
  playFrequency(1, ReturnType.none, 0x46),
  playSequence(1, ReturnType.none, 0x47),
  playWaveform(3, ReturnType.none, 0x48),
  callAllReleaseScripts(0, ReturnType.none, 0x49),
  isInReleaseAll(0, ReturnType.boolean, 0x4a),
  getPressCount(0, ReturnType.value, 0x4b),
  getReleaseCount(0, ReturnType.value, 0x4c),
  isStenoJoinNext(0, ReturnType.boolean, 0x4d),
  callPress(1, ReturnType.none, 0x4e),
  callRelease(1, ReturnType.none, 0x4f),
  pressMouseButton(1, ReturnType.none, 0x50),
  releaseMouseButton(1, ReturnType.none, 0x51),
  tapMouseButton(1, ReturnType.none, 0x52),
  isMouseButtonPressed(1, ReturnType.boolean, 0x53),
  moveMouse(2, ReturnType.none, 0x54),
  vWheelMouse(1, ReturnType.none, 0x55),
  setEnableButtonStates(1, ReturnType.none, 0x56),
  printValue(2, ReturnType.none, 0x57),
  getWpm(1, ReturnType.value, 0x58),
  setPairBoardPower(1, ReturnType.none, 0x59),
  hWheelMouse(1, ReturnType.none, 0x5a),
  enableConsole(0, ReturnType.none, 0x5b),
  disableConsole(0, ReturnType.none, 0x5c),
  isConsoleEnabled(0, ReturnType.boolean, 0x5d),
  enableFlashWrite(0, ReturnType.none, 0x5e),
  disableFlashWrite(0, ReturnType.none, 0x5f),
  isFlashWriteEnabled(0, ReturnType.boolean, 0x60),
  isInReinit(0, ReturnType.boolean, 0x61),
  setDrawColorRgb(4, ReturnType.none, 0x62),
  setDrawColorHsv(4, ReturnType.none, 0x63),
  drawEffect(3, ReturnType.none, 0x64),
  ;

  const InBuiltScriptFunction(
    this.numberOfParameters,
    this.returnValue,
    this.functionIndex,
  );

  final ReturnType returnValue;

  @override
  String get functionName => name;

  @override
  final int numberOfParameters;

  @override
  int get numberOfLocals => 0;

  @override
  bool get hasReturnValue => returnValue != ReturnType.none;

  final int functionIndex;

  bool get isBooleanResult => returnValue == ReturnType.boolean;
}
