abstract class ScriptFunctionDefinition {
  String get name;
  int get numberOfParameters;
  int get numberOfLocals;
  bool get hasReturnValue;
}

enum InBuiltScriptFunction implements ScriptFunctionDefinition {
  pressScanCode('pressScanCode', 1, false, 0, false),
  releaseScanCode('releaseScanCode', 1, false, 1, false),
  tapScanCode('tapScanCode', 1, false, 2, false),
  isScanCodePressed('isScanCodePressed', 1, true, 3, true),
  pressStenoKey('pressStenoKey', 1, false, 4, false),
  releaseStenoKey('releaseStenoKey', 1, false, 5, false),
  isStenoKeyPressed('isStenoKeyPressed', 1, true, 6, true),
  releaseAll('releaseAll', 0, false, 7, false),
  isButtonPressed('isButtonPressed', 1, true, 8, true),
  pressAll('pressAll', 0, false, 9, false),
  sendText('sendText', 1, false, 0xa, false),
  console('console', 1, true, 0xb, false),
  checkButtonState('checkButtonState', 1, true, 0xc, true),
  isInPressAll('isInPressAll', 0, true, 0xd, true),
  setRgb('setRgb', 4, false, 0xe, false),
  getTime('getTime', 0, true, 0xf, false),
  getLedStatus('getLedStatus', 1, true, 0x10, true),
  setGpioPin('setGpioPin', 2, false, 0x11, false),
  clearDisplay('clearDisplay', 1, false, 0x12, false),
  setAutoDraw('setAutoDraw', 2, false, 0x13, false),
  setScreenOn('setScreenOn', 2, false, 0x14, false),
  setScreenContrast('setScreenContrast', 2, false, 0x15, false),
  drawPixel('drawPixel', 3, false, 0x16, false),
  drawLine('drawLine', 5, false, 0x17, false),
  drawImage('drawImage', 4, false, 0x18, false),
  drawText('drawText', 6, false, 0x19, false),
  setDrawColor('setDrawColor', 2, false, 0x1a, false),
  drawRect('drawRect', 5, false, 0x1b, false),
  setHsv('setHsv', 4, false, 0x1c, false),
  rand('rand', 0, true, 0x1d, false),
  isUsbConnected('isUsbConnected', 0, true, 0x1e, true),
  isUsbSuspended('isUsbSuspended', 0, true, 0x1f, true),
  getParameter('getParameter', 1, true, 0x20, false),
  isConnected('isConnected', 1, true, 0x21, true),
  getActiveConnection('getActiveConnection', 0, true, 0x22, false),
  setPreferredConnection('setPreferredConnection', 3, false, 0x23, false),
  isPairConnected('isPairConnected', 1, true, 0x24, true),
  startBlePairing('startBlePairing', 0, false, 0x25, false),
  getBleProfile('getBleProfile', 0, true, 0x26, false),
  setBleProfile('setBleProfile', 1, false, 0x27, false),
  isHostSleeping('isHostSleeping', 0, true, 0x28, true),
  isMainPowered('isMainPowered', 0, true, 0x29, true),
  isCharging('isCharging', 0, true, 0x2a, true),
  getBatteryPercentage('getBatteryPercentage', 0, true, 0x2b, false),
  getActivePairConnection('getActivePairConnection', 0, true, 0x2c, false),
  setBoardPower('setBoardPower', 1, false, 0x2d, false),
  sendEvent('sendEvent', 1, false, 0x2e, false),
  isPairPowered('isPairPowered', 0, true, 0x2f, true),
  setInputHint('setInputHint', 1, false, 0x30, false),
  setScript('setScript', 2, false, 0x31, false),
  isBoardPowered('isBoardPowered', 0, true, 0x32, true),
  startTimer('startTimer', 4, false, 0x33, false),
  stopTimer('stopTimer', 1, false, 0x34, false),
  isTimerActive('isTimerActive', 1, true, 0x35, true),
  isBleProfileConnected('isBleProfileConnected', 1, true, 0x36, true),
  disconnectBle('disconnectBle', 0, false, 0x37, false),
  unpairBle('unpairBle', 0, false, 0x38, false),
  isBleProfilePaired('isBleProfilePaired', 1, true, 0x39, true),
  isBleProfileSleeping('isBleProfileSleeping', 1, true, 0x3a, true),
  isBleAdvertising('isBleAdvertising', 0, true, 0x3b, true),
  isBleScanning('isBleScanning', 0, true, 0x3c, true),
  isWaitingForUserPresence('isWaitingForUserPresence', 0, true, 0x3d, true),
  replyUserPresence('replyUserPresence', 1, false, 0x3e, false),
  ;

  const InBuiltScriptFunction(
    this.functionName,
    this.numberOfParameters,
    this.hasReturnValue,
    this.functionIndex,
    this.isBooleanResult,
  ) : assert(!(hasReturnValue == false && isBooleanResult == true));

  final String functionName;

  @override
  String get name => functionName;

  @override
  final int numberOfParameters;

  @override
  int get numberOfLocals => 0;

  @override
  final bool hasReturnValue;

  final int functionIndex;

  final bool isBooleanResult;
}
