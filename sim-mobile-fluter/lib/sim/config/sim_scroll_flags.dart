class SimScrollFlags {
  const SimScrollFlags._();

  static const aulaChat = bool.fromEnvironment(
    'SIM_SCROLL_AULA_CHAT',
    defaultValue: false,
  );
}
