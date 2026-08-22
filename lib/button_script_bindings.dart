import 'dart:typed_data';

import 'package:javelin_steno_script/javelin_steno_script.dart';

class ButtonScriptBindings {
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
    InBuiltScriptFunction(
      'isWaitingForUserPresence',
      0,
      ReturnType.boolean,
      0x3d,
    ),
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
    InBuiltScriptFunction('playWaveform', 1, ReturnType.none, 0x48),
    InBuiltScriptFunction('callAllReleaseScripts', 0, ReturnType.none, 0x49),
    InBuiltScriptFunction('isInReleaseAll', 0, ReturnType.boolean, 0x4a),
    InBuiltScriptFunction('getPressCount', 0, ReturnType.value, 0x4b),
    InBuiltScriptFunction('getReleaseCount', 0, ReturnType.value, 0x4c),
    InBuiltScriptFunction('isStenoJoinNext', 0, ReturnType.boolean, 0x4d),
    InBuiltScriptFunction('pressButton', 1, ReturnType.none, 0x4e),
    InBuiltScriptFunction('releaseButton', 1, ReturnType.none, 0x4f),
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
    InBuiltScriptFunction('addCombo', 5, ReturnType.none, 0x6e),
    InBuiltScriptFunction('resetCombos', 0, ReturnType.none, 0x6f),
    InBuiltScriptFunction('sendInfraredMessage', 4, ReturnType.none, 0x70),
    InBuiltScriptFunction('sendInfraredData', 3, ReturnType.none, 0x71),
    InBuiltScriptFunction('stopInfrared', 0, ReturnType.none, 0x72),
    InBuiltScriptFunction('printData', 3, ReturnType.none, 0x73),
    InBuiltScriptFunction('measureTextWidth', 2, ReturnType.value, 0x74),
    InBuiltScriptFunction('enableScriptRgb', 0, ReturnType.none, 0x75),
    InBuiltScriptFunction('disableScriptRgb', 0, ReturnType.none, 0x76),
    InBuiltScriptFunction('sendInfraredSignal', 3, ReturnType.none, 0x77),
    InBuiltScriptFunction('createBuffer', 1, ReturnType.value, 0x78),
    InBuiltScriptFunction('sendMidi', 3, ReturnType.none, 0x79),
    InBuiltScriptFunction('getAssetSize', 1, ReturnType.value, 0x7a),
    InBuiltScriptFunction('getRelyingPartyId', 0, ReturnType.value, 0x7b),
    InBuiltScriptFunction('getSignatureAlgorithm', 0, ReturnType.value, 0x7c),
    InBuiltScriptFunction('setSignatureAlgorithms', 1, ReturnType.none, 0x7d),
    InBuiltScriptFunction('isLocationAdvertising', 0, ReturnType.boolean, 0x7e),
    InBuiltScriptFunction('setBleSplitRate', 1, ReturnType.none, 0x7f),
    InBuiltScriptFunction('analogInput', 2, ReturnType.none, 0x80),
    InBuiltScriptFunction('encoderInput', 2, ReturnType.none, 0x81),
    InBuiltScriptFunction('pointerInput', 4, ReturnType.none, 0x82),
    InBuiltScriptFunction('formatDateTime', 1, ReturnType.value, 0x83),
    InBuiltScriptFunction('isDateTimeValid', 0, ReturnType.boolean, 0x84),
    InBuiltScriptFunction('generateTotp', 1, ReturnType.value, 0x85),
    InBuiltScriptFunction('getTotpPeriod', 1, ReturnType.value, 0x86),
  ];

  static const constants = '''
const SC_NONE = 0;
const SC_A = 0x04;
const SC_B = 0x05;
const SC_C = 0x06;
const SC_D = 0x07;
const SC_E = 0x08;
const SC_F = 0x09;
const SC_G = 0x0a;
const SC_H = 0x0b;
const SC_I = 0x0c;
const SC_J = 0x0d;
const SC_K = 0x0e;
const SC_L = 0x0f;
const SC_M = 0x10;
const SC_N = 0x11;
const SC_O = 0x12;
const SC_P = 0x13;
const SC_Q = 0x14;
const SC_R = 0x15;
const SC_S = 0x16;
const SC_T = 0x17;
const SC_U = 0x18;
const SC_V = 0x19;
const SC_W = 0x1a;
const SC_X = 0x1b;
const SC_Y = 0x1c;
const SC_Z = 0x1d;
const SC_1 = 0x1e;
const SC_2 = 0x1f;
const SC_3 = 0x20;
const SC_4 = 0x21;
const SC_5 = 0x22;
const SC_6 = 0x23;
const SC_7 = 0x24;
const SC_8 = 0x25;
const SC_9 = 0x26;
const SC_0 = 0x27;
const SC_ENTER = 0x28;
const SC_ESC = 0x29;
const SC_BACKSPACE = 0x2a;
const SC_TAB = 0x2b;
const SC_SPACE = 0x2c;
const SC_MINUS = 0x2d;
const SC_EQUAL = 0x2e;
const SC_L_BRACKET = 0x2f;
const SC_R_BRACKET = 0x30;
const SC_BACKSLASH = 0x31;
const SC_HASH_TILDE = 0x32;
const SC_SEMICOLON = 0x33;
const SC_APOSTROPHE = 0x34;
const SC_GRAVE = 0x35;
const SC_COMMA = 0x36;
const SC_DOT = 0x37;
const SC_SLASH = 0x38;
const SC_CAPS = 0x39;
const SC_F1 = 0x3a;
const SC_F2 = 0x3b;
const SC_F3 = 0x3c;
const SC_F4 = 0x3d;
const SC_F5 = 0x3e;
const SC_F6 = 0x3f;
const SC_F7 = 0x40;
const SC_F8 = 0x41;
const SC_F9 = 0x42;
const SC_F10 = 0x43;
const SC_F11 = 0x44;
const SC_F12 = 0x45;
const SC_SYS_RQ = 0x46;
const SC_SCROLL_LOCK = 0x47;
const SC_PAUSE = 0x48;
const SC_INSERT = 0x49;
const SC_HOME = 0x4a;
const SC_PAGE_UP = 0x4b;
const SC_DELETE = 0x4c;
const SC_END = 0x4d;
const SC_PAGE_DOWN = 0x4e;
const SC_RIGHT = 0x4f;
const SC_LEFT = 0x50;
const SC_DOWN = 0x51;
const SC_UP = 0x52;
const SC_NUM_LOCK = 0x53;
const SC_KP_SLASH = 0x54;
const SC_KP_ASTERISK = 0x55;
const SC_KP_MINUS = 0x56;
const SC_KP_PLUS = 0x57;
const SC_KP_ENTER = 0x58;
const SC_KP_1 = 0x59;
const SC_KP_2 = 0x5a;
const SC_KP_3 = 0x5b;
const SC_KP_4 = 0x5c;
const SC_KP_5 = 0x5d;
const SC_KP_6 = 0x5e;
const SC_KP_7 = 0x5f;
const SC_KP_8 = 0x60;
const SC_KP_9 = 0x61;
const SC_KP_0 = 0x62;
const SC_KP_DOT = 0x63;
const SC_BACKSLASH_PIPE = 0x64;
const SC_COMPOSE = 0x65;
const SC_POWER = 0x66;
const SC_KP_EQUAL = 0x67;
const SC_F13 = 0x68;
const SC_F14 = 0x69;
const SC_F15 = 0x6a;
const SC_F16 = 0x6b;
const SC_F17 = 0x6c;
const SC_F18 = 0x6d;
const SC_F19 = 0x6e;
const SC_F20 = 0x6f;
const SC_F21 = 0x70;
const SC_F22 = 0x71;
const SC_F23 = 0x72;
const SC_F24 = 0x73;
const SC_OPEN = 0x74;
const SC_HELP = 0x75;
const SC_MENU = 0x76;
const SC_SELECT = 0x77;
const SC_STOP = 0x78;
const SC_AGAIN = 0x79;
const SC_UNDO = 0x7a;
const SC_CUT = 0x7b;
const SC_COPY = 0x7c;
const SC_PASTE = 0x7d;
const SC_FIND = 0x7e;
const SC_MUTE = 0x7f;
const SC_VOLUME_UP = 0x80;
const SC_VOLUME_DOWN = 0x81;
const SC_KP_COMMA = 0x85;
const SC_L_CTRL = 0xe0;
const SC_L_SHIFT = 0xe1;
const SC_L_ALT = 0xe2;
const SC_L_META = 0xe3;
const SC_R_CTRL = 0xe4;
const SC_R_SHIFT = 0xe5;
const SC_R_ALT = 0xe6;
const SC_R_META = 0xe7;
const SC_CONSUMER_PLAY = 0xa0;
const SC_CONSUMER_PAUSE = 0xa1;
const SC_CONSUMER_RECORD = 0xa2;
const SC_CONSUMER_FAST_FORWARD = 0xa3;
const SC_CONSUMER_REWIND = 0xa4;
const SC_CONSUMER_SCAN_NEXT_TRACK = 0xa5;
const SC_CONSUMER_SCAN_PREVIOUS_TRACK = 0xa6;
const SC_CONSUMER_STOP = 0xa7;
const SC_CONSUMER_EJECT = 0xa8;
const SC_CONSUMER_STOP_EJECT = 0xbc;
const SC_CONSUMER_PLAY_PAUSE = 0xbd;
const SC_CONSUMER_PLAY_SKIP = 0xbe;
const SC_CONSUMER_MUTE = 0xd2;
const SC_CONSUMER_VOLUME_UP = 0xd9;
const SC_CONSUMER_VOLUME_DOWN = 0xda;
const SC_CONSUMER_BRIGHTNESS_UP = 0xde;
const SC_CONSUMER_BRIGHTNESS_DOWN = 0xdf;
const SC_CONSUMER_FN_GLOBE = 0x1029d;
const MOUSE_BUTTON_LEFT = 0;
const MOUSE_BUTTON_RIGHT = 1;
const MOUSE_BUTTON_MIDDLE = 2;
const SK_NONE = -1;
const SK_S1 = 0;
const SK_S2 = 1;
const SK_TL = 2;
const SK_KL = 3;
const SK_PL = 4;
const SK_WL = 5;
const SK_HL = 6;
const SK_RL = 7;
const SK_A = 8;
const SK_O = 9;
const SK_STAR1 = 10;
const SK_STAR2 = 11;
const SK_STAR3 = 12;
const SK_STAR4 = 13;
const SK_E = 14;
const SK_U = 15;
const SK_FR = 16;
const SK_RR = 17;
const SK_PR = 18;
const SK_BR = 19;
const SK_LR = 20;
const SK_GR = 21;
const SK_TR = 22;
const SK_SR = 23;
const SK_DR = 24;
const SK_ZR = 25;
const SK_NUM1 = 26;
const SK_NUM2 = 27;
const SK_NUM3 = 28;
const SK_NUM4 = 29;
const SK_NUM5 = 30;
const SK_NUM6 = 31;
const SK_NUM7 = 32;
const SK_NUM8 = 33;
const SK_NUM9 = 34;
const SK_NUM10 = 35;
const SK_NUM11 = 36;
const SK_NUM12 = 37;
const SK_FUNCTION = 38;
const SK_POWER = 39;
const SK_RES1 = 40;
const SK_RES2 = 41;
const SK_X1 = 38;
const SK_X2 = 39;
const SK_X3 = 40;
const SK_X4 = 41;
const SK_X5 = 42;
const SK_X6 = 43;
const SK_X7 = 44;
const SK_X8 = 45;
const SK_X9 = 46;
const SK_X10 = 47;
const SK_X11 = 48;
const SK_X12 = 49;
const SK_X13 = 50;
const SK_X14 = 51;
const SK_X15 = 52;
const SK_X16 = 53;
const SK_X17 = 54;
const SK_X18 = 54;
const SK_X19 = 56;
const SK_X20 = 57;
const SK_X21 = 58;
const SK_X22 = 59;
const SK_X23 = 60;
const SK_X24 = 61;
const SK_X25 = 62;
const SK_X26 = 63;
const AUTO_DRAW_NONE = 0;
const AUTO_DRAW_PAPER_TAPE = 1;
const AUTO_DRAW_STENO_LAYOUT = 2;
const AUTO_DRAW_WPM = 3;
const AUTO_DRAW_STROKES = 4;
const TEXT_ALIGNMENT_LEFT = 0;
const TEXT_ALIGNMENT_MIDDLE = 1;
const TEXT_ALIGNMENT_RIGHT = 2;
const FONT_ID_NORMAL = 0;
const FONT_ID_LARGE = 1;
const FONT_ID_DOS = 2;
const FONT_ID_SMALL_DIGITS = 3;
const FONT_ID_MEDIUM_DIGITS = 4;
const FONT_ID_LARGE_DIGITS = 5;
const FONT_ID_HUGE_DIGITS = 6;
const CONNECTION_NONE = 0;
const CONNECTION_ANY = 0;
const CONNECTION_BLE = 1;
const CONNECTION_USB = 2;
const CONNECTION_USB2 = 3;
const PAIR_CONNECTION_ANY = 0;
const PAIR_CONNECTION_NONE = 0;
const PAIR_CONNECTION_BLE = 1;
const PAIR_CONNECTION_CABLE = 2;
const PAIR_BOARD_POWER_NO_OVERRIDE = 0;
const PAIR_BOARD_POWER_FORCE_OFF = 1;
const PAIR_BOARD_POWER_FORCE_ON = 2;
const PULL_NONE = 0;
const PULL_DOWN = 1;
const PULL_UP = 2;
const SIGNATURE_ALG_UNKNOWN = -1;
const SIGNATURE_ALG_ES256 = 0;
const SIGNATURE_ALG_EDDSA = 1;
const SIGNATURE_ALG_ES256K = 2;
const SIGNATURE_ALG_ESP256 = 3;
const SIGNATURE_ALG_ED25519 = 4;
const SIGNATURE_ALG_ES384 = 5;
const SIGNATURE_ALG_ESP384 = 6;
const SIGNATURE_ALG_ES512 = 7;
const SIGNATURE_ALG_ESP512 = 8;
const SIGNATURE_ALG_ML_DSA_44 = 9;
const SIGNATURE_ALG_ML_DSA_65 = 10;
const SIGNATURE_ALG_ML_DSA_87 = 11;
const LED_STATUS_NUM_LOCK = 0;
const LED_STATUS_CAPS_LOCK = 1;
const LED_STATUS_SCROLL_LOCK = 2;
const LED_STATUS_COMPOSE = 3;
const LED_STATUS_KANA = 4;
const SCRIPT_ID_DISPLAY_OVERLAY = 0;
const SCRIPT_ID_BATTERY_UPDATE = 1;
const SCRIPT_ID_CONNECTION_UPDATE = 2;
const SCRIPT_ID_PAIR_CONNECTION_UPDATE = 3;
const SCRIPT_ID_KEYBOARD_LED_STATUS_UPDATE = 4;
const SCRIPT_ID_BLE_ADVERTISING_UPDATE = 5;
const SCRIPT_ID_BLE_SCANNING_UPDATE = 6;
const SCRIPT_ID_U2F_STATUS_UPDATE = 7;
const SCRIPT_ID_U2F_WINK = 8;
const SCRIPT_ID_STENO_MODE_UPDATE = 9;
const SCRIPT_ID_BLE_PAIR_COMPLETE = 10;
const SCRIPT_ID_SET_LAYER = 11;
const SCRIPT_ID_USER1 = 12;
const SCRIPT_ID_USER2 = 13;
const SCRIPT_ID_USER3 = 14;
const SCRIPT_ID_USER4 = 15;
const SCRIPT_ID_USER5 = 16;
const SCRIPT_ID_USER6 = 17;
const SCRIPT_ID_USER7 = 18;
const SCRIPT_ID_CONSOLE_ACCESS_REQUESTED = 19;
const SCRIPT_ID_FLASH_WRITE_ACCESS_REQUESTED = 20;
const SCRIPT_ID_BEACON_STARTED = 21;
const SCRIPT_ID_LOCATION_ADVERTISING_UPDATE = 22;
const SCRIPT_ID_RTC_UPDATE = 23;
''';

  static List<String> createRootFunctionList({
    required int buttonCount,
    required int analogDataCount,
    required int encoderCount,
    required int pointerCount,
  }) {
    return [
      'init',
      'tick',
      for (var i = 0; i < buttonCount; ++i) ...['onPress$i', 'onRelease$i'],
      for (var i = 0; i < analogDataCount; ++i) 'onAnalogInput$i',
      for (var i = 0; i < encoderCount; ++i) 'onEncoderInput$i',
      for (var i = 0; i < pointerCount; ++i) 'onPointerInput$i',
    ];
  }
}

extension ButtonScriptModule on ScriptModule {
  static ScriptModule create() {
    final module = ScriptModule(ButtonScriptBindings.functions);
    module.constants.addAll(constantsModule.constants);
    return module;
  }

  static ScriptModule constantsModule = () {
    final module = ScriptModule(ButtonScriptBindings.functions);
    final parser = Parser(
      input: ButtonScriptBindings.constants,
      filename: '<inbuilt>',
      module: module,
    );
    parser.parse();
    return module;
  }();

  Uint8List createByteCode({
    required int buttonCount,
    required int analogInputCount,
    required int encoderCount,
    required int pointerCount,
    required int scriptByteCodeVersion,
  }) => ScriptByteCodeBuilder(
    module: this,
    byteCodeVersion: scriptByteCodeVersion,
    requiredFunctions: ButtonScriptBindings.createRootFunctionList(
      buttonCount: buttonCount,
      analogDataCount: analogInputCount,
      encoderCount: encoderCount,
      pointerCount: pointerCount,
    ),
  ).createByteCode();
}
