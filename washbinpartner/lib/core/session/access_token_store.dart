/// Holds the current Washbin access token in memory.
///
/// Exists to break a cycle: `ApiClient` needs the token, and the session that
/// owns the token needs `ApiClient` to fetch one. Both depend on this instead
/// of on each other.
///
/// Memory only, and deliberately so. The token is derived from the Firebase
/// session, which the Firebase SDK already persists securely, so writing a
/// second copy to disk would widen the attack surface for nothing — a cold
/// start simply mints a fresh one. See `SessionController.start`.
class AccessTokenStore {
  String? _token;

  String? read() => _token;

  bool get hasToken => (_token ?? '').isNotEmpty;

  void write(String token) => _token = token;

  void clear() => _token = null;
}
