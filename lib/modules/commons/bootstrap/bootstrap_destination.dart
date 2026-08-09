enum BootstrapDestination {
  welcome,
  completeProfile,
  home,

  /// Running build is below the channel's min version (or ops flipped the
  /// kill switch). Blocking screen; the only way forward is the store.
  forcedUpdate,
}
