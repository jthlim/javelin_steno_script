import 'src/functions.dart';

class ButtonScriptInBuiltFunctions {
  static const functions = <InBuiltScriptFunction>[
    InBuiltScriptFunction('pressScanCode', 1, ReturnType.none, 0),
    InBuiltScriptFunction('releaseScanCode', 1, ReturnType.none, 1),
    InBuiltScriptFunction('tapScanCode', 1, ReturnType.none, 2),
    InBuiltScriptFunction('isScanCodePressed', 1, ReturnType.boolean, 3),
    InBuiltScriptFunction('pressStenoKey', 1, ReturnType.none, 4),
    InBuiltScriptFunction('releaseStenoKey', 1, ReturnType.none, 5),
    InBuiltScriptFunction('isStenoKeyPressed', 1, ReturnType.boolean, 6),
    InBuiltScriptFunction('releaseAll', 0, ReturnType.none, 7),
    InBuiltScriptFunction('isButtonPressed', 1, ReturnType.boolean, 8),
    InBuiltScriptFunction('pressAll', 0, ReturnType.none, 9),
    InBuiltScriptFunction('sendText', 1, ReturnType.none, 0xa),
    InBuiltScriptFunction('console', 1, ReturnType.value, 0xb),
    InBuiltScriptFunction('checkButtonState', 1, ReturnType.boolean, 0xc),
    InBuiltScriptFunction('isInPressAll', 0, ReturnType.boolean, 0xd),
    InBuiltScriptFunction('setRgb', 4, ReturnType.none, 0xe),
    InBuiltScriptFunction('getTime', 0, ReturnType.value, 0xf),
    InBuiltScriptFunction('getLedStatus', 1, ReturnType.boolean, 0x10),
    InBuiltScriptFunction('setGpioPin', 2, ReturnType.none, 0x11),
    InBuiltScriptFunction('clearDisplay', 1, ReturnType.none, 0x12),
    InBuiltScriptFunction('setAutoDraw', 2, ReturnType.none, 0x13),
    InBuiltScriptFunction('setScreenOn', 2, ReturnType.none, 0x14),
    InBuiltScriptFunction('setScreenContrast', 2, ReturnType.none, 0x15),
    InBuiltScriptFunction('drawPixel', 3, ReturnType.none, 0x16),
    InBuiltScriptFunction('drawLine', 5, ReturnType.none, 0x17),
    InBuiltScriptFunction('drawImage', 4, ReturnType.none, 0x18),
    InBuiltScriptFunction('drawText', 6, ReturnType.none, 0x19),
    InBuiltScriptFunction('setDrawColor', 2, ReturnType.none, 0x1a),
    InBuiltScriptFunction('drawRect', 5, ReturnType.none, 0x1b),
    InBuiltScriptFunction('setHsv', 4, ReturnType.none, 0x1c),
    InBuiltScriptFunction('rand', 0, ReturnType.value, 0x1d),
    InBuiltScriptFunction('isUsbConnected', 0, ReturnType.boolean, 0x1e),
    InBuiltScriptFunction('isUsbSuspended', 0, ReturnType.boolean, 0x1f),
    InBuiltScriptFunction('getParameter', 1, ReturnType.value, 0x20),
    InBuiltScriptFunction('isConnected', 1, ReturnType.boolean, 0x21),
    InBuiltScriptFunction('getActiveConnection', 0, ReturnType.value, 0x22),
    InBuiltScriptFunction('setPreferredConnection', 3, ReturnType.none, 0x23),
    InBuiltScriptFunction('isPairConnected', 1, ReturnType.boolean, 0x24),
    InBuiltScriptFunction('startBlePairing', 0, ReturnType.none, 0x25),
    InBuiltScriptFunction('getBleProfile', 0, ReturnType.value, 0x26),
    InBuiltScriptFunction('setBleProfile', 1, ReturnType.none, 0x27),
    InBuiltScriptFunction('isHostSleeping', 0, ReturnType.boolean, 0x28),
    InBuiltScriptFunction('isMainPowered', 0, ReturnType.boolean, 0x29),
    InBuiltScriptFunction('isCharging', 0, ReturnType.boolean, 0x2a),
    InBuiltScriptFunction('getBatteryPercentage', 0, ReturnType.value, 0x2b),
    InBuiltScriptFunction('getActivePairConnection', 0, ReturnType.value, 0x2c),
    InBuiltScriptFunction('setBoardPower', 1, ReturnType.none, 0x2d),
    InBuiltScriptFunction('sendEvent', 1, ReturnType.none, 0x2e),
    InBuiltScriptFunction('isPairPowered', 0, ReturnType.boolean, 0x2f),
    InBuiltScriptFunction('setInputHint', 1, ReturnType.none, 0x30),
    InBuiltScriptFunction('setScript', 2, ReturnType.none, 0x31),
    InBuiltScriptFunction('isBoardPowered', 0, ReturnType.boolean, 0x32),
    InBuiltScriptFunction('startTimer', 4, ReturnType.none, 0x33),
    InBuiltScriptFunction('stopTimer', 1, ReturnType.none, 0x34),
    InBuiltScriptFunction('isTimerActive', 1, ReturnType.boolean, 0x35),
    InBuiltScriptFunction('isBleProfileConnected', 1, ReturnType.boolean, 0x36),
    InBuiltScriptFunction('disconnectBle', 0, ReturnType.none, 0x37),
    InBuiltScriptFunction('unpairBle', 0, ReturnType.none, 0x38),
    InBuiltScriptFunction('isBleProfilePaired', 1, ReturnType.boolean, 0x39),
    InBuiltScriptFunction('isBleProfileSleeping', 1, ReturnType.boolean, 0x3a),
    InBuiltScriptFunction('isBleAdvertising', 0, ReturnType.boolean, 0x3b),
    InBuiltScriptFunction('isBleScanning', 0, ReturnType.boolean, 0x3c),
    InBuiltScriptFunction('isWaitingForUserPresence', 0, ReturnType.boolean, 0x3d),
    InBuiltScriptFunction('replyUserPresence', 1, ReturnType.none, 0x3e),
    InBuiltScriptFunction('setGpioInputPin', 2, ReturnType.none, 0x3f),
    InBuiltScriptFunction('readGpioPin', 1, ReturnType.boolean, 0x40),
    InBuiltScriptFunction('drawLuminanceRange', 6, ReturnType.none, 0x41),
    InBuiltScriptFunction('setGpioPinDutyCycle', 2, ReturnType.none, 0x42),
    InBuiltScriptFunction('cancelAllStenoKeys', 0, ReturnType.none, 0x43),
    InBuiltScriptFunction('cancelStenoKey', 1, ReturnType.none, 0x44),
    InBuiltScriptFunction('stopSound', 0, ReturnType.none, 0x45),
    InBuiltScriptFunction('playFrequency', 1, ReturnType.none, 0x46),
    InBuiltScriptFunction('playSequence', 1, ReturnType.none, 0x47),
    InBuiltScriptFunction('playWaveform', 3, ReturnType.none, 0x48),
    InBuiltScriptFunction('callAllReleaseScripts', 0, ReturnType.none, 0x49),
    InBuiltScriptFunction('isInReleaseAll', 0, ReturnType.boolean, 0x4a),
    InBuiltScriptFunction('getPressCount', 0, ReturnType.value, 0x4b),
    InBuiltScriptFunction('getReleaseCount', 0, ReturnType.value, 0x4c),
    InBuiltScriptFunction('isStenoJoinNext', 0, ReturnType.boolean, 0x4d),
    InBuiltScriptFunction('callPress', 1, ReturnType.none, 0x4e),
    InBuiltScriptFunction('callRelease', 1, ReturnType.none, 0x4f),
    InBuiltScriptFunction('pressMouseButton', 1, ReturnType.none, 0x50),
    InBuiltScriptFunction('releaseMouseButton', 1, ReturnType.none, 0x51),
    InBuiltScriptFunction('tapMouseButton', 1, ReturnType.none, 0x52),
    InBuiltScriptFunction('isMouseButtonPressed', 1, ReturnType.boolean, 0x53),
    InBuiltScriptFunction('moveMouse', 2, ReturnType.none, 0x54),
    InBuiltScriptFunction('vWheelMouse', 1, ReturnType.none, 0x55),
    InBuiltScriptFunction('setEnableButtonStates', 1, ReturnType.none, 0x56),
    InBuiltScriptFunction('printValue', 2, ReturnType.none, 0x57),
    InBuiltScriptFunction('getWpm', 1, ReturnType.value, 0x58),
    InBuiltScriptFunction('setPairBoardPower', 1, ReturnType.none, 0x59),
    InBuiltScriptFunction('hWheelMouse', 1, ReturnType.none, 0x5a),
    InBuiltScriptFunction('enableConsole', 0, ReturnType.none, 0x5b),
    InBuiltScriptFunction('disableConsole', 0, ReturnType.none, 0x5c),
    InBuiltScriptFunction('isConsoleEnabled', 0, ReturnType.boolean, 0x5d),
    InBuiltScriptFunction('enableFlashWrite', 0, ReturnType.none, 0x5e),
    InBuiltScriptFunction('disableFlashWrite', 0, ReturnType.none, 0x5f),
    InBuiltScriptFunction('isFlashWriteEnabled', 0, ReturnType.boolean, 0x60),
    InBuiltScriptFunction('isInReinit', 0, ReturnType.boolean, 0x61),
    InBuiltScriptFunction('setDrawColorRgb', 4, ReturnType.none, 0x62),
    InBuiltScriptFunction('setDrawColorHsv', 4, ReturnType.none, 0x63),
    InBuiltScriptFunction('drawEffect', 3, ReturnType.none, 0x64),
    InBuiltScriptFunction('sin', 1, ReturnType.value, 0x65),
    InBuiltScriptFunction('cos', 1, ReturnType.value, 0x66),
    InBuiltScriptFunction('tan', 1, ReturnType.value, 0x67),
    InBuiltScriptFunction('asin', 1, ReturnType.value, 0x68),
    InBuiltScriptFunction('acos', 1, ReturnType.value, 0x69),
    InBuiltScriptFunction('atan', 1, ReturnType.value, 0x6a),
    InBuiltScriptFunction('atan2', 2, ReturnType.value, 0x6b),
    InBuiltScriptFunction('formatString', 2, ReturnType.value, 0x6c),
    InBuiltScriptFunction('getAsset', 1, ReturnType.value, 0x6d),
  ];
}
