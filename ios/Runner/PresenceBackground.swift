import CoreLocation
import Flutter
import Foundation

// Native iOS driver-presence recovery.
//
// iOS cannot keep a Dart isolate alive after the user force-quits the
// app, and `startUpdatingLocation` does not relaunch a terminated app.
// Significant-location-change monitoring DOES relaunch a terminated app
// (with the location launch key), so this shim is the force-quit safety
// net: while the driver is online we monitor significant changes and,
// on each one, POST the driver's position straight to
// `upsert_driver_presence` over URLSession — no Flutter engine required.
//
// Continuous, high-frequency updates while the app is merely backgrounded
// are handled by the geolocator stream on the Dart side (kept alive by
// the `location` UIBackgroundMode). This file only covers the gap Apple
// leaves after a force-quit / OS termination.

// MARK: - Session store

struct PresenceSession {
  var supabaseUrl: String
  var anonKey: String
  var accessToken: String
  var refreshToken: String
  var expiresAt: Int
  var vehicleId: String?
}

enum PresenceStore {
  private static let sessionKey = "drivio_presence_session"
  private static let onlineKey = "drivio_presence_online"
  private static var defaults: UserDefaults { UserDefaults.standard }

  static var isOnline: Bool { defaults.bool(forKey: onlineKey) }

  static func save(_ s: PresenceSession) {
    defaults.set(
      [
        "supabaseUrl": s.supabaseUrl,
        "anonKey": s.anonKey,
        "accessToken": s.accessToken,
        "refreshToken": s.refreshToken,
        "expiresAt": s.expiresAt,
        "vehicleId": s.vehicleId ?? "",
      ],
      forKey: sessionKey)
    defaults.set(true, forKey: onlineKey)
  }

  static func updateTokens(accessToken: String, refreshToken: String, expiresAt: Int) {
    guard var dict = defaults.dictionary(forKey: sessionKey) else { return }
    dict["accessToken"] = accessToken
    dict["refreshToken"] = refreshToken
    dict["expiresAt"] = expiresAt
    defaults.set(dict, forKey: sessionKey)
  }

  static func clear() {
    defaults.removeObject(forKey: sessionKey)
    defaults.set(false, forKey: onlineKey)
  }

  static func load() -> PresenceSession? {
    guard let dict = defaults.dictionary(forKey: sessionKey),
      let url = dict["supabaseUrl"] as? String, !url.isEmpty,
      let anon = dict["anonKey"] as? String, !anon.isEmpty,
      let access = dict["accessToken"] as? String, !access.isEmpty,
      let refresh = dict["refreshToken"] as? String, !refresh.isEmpty
    else { return nil }
    let vehicle = dict["vehicleId"] as? String
    return PresenceSession(
      supabaseUrl: url,
      anonKey: anon,
      accessToken: access,
      refreshToken: refresh,
      expiresAt: dict["expiresAt"] as? Int ?? 0,
      vehicleId: (vehicle?.isEmpty ?? true) ? nil : vehicle)
  }
}

// MARK: - Supabase uploader (PostgREST + GoTrue)

final class SupabasePresenceUploader {
  private var refreshing = false

  /// Upsert a presence row. Ensures the access token is fresh, then POSTs
  /// to the RPC; on a 401 it refreshes once and retries.
  func upsert(
    status: String,
    lat: Double?,
    lng: Double?,
    accuracyM: Int?,
    headingDeg: Int?,
    speedKph: Int?
  ) {
    guard let session = PresenceStore.load() else { return }
    ensureFreshToken(session) { fresh in
      self.postRpc(
        fresh, status: status, lat: lat, lng: lng,
        accuracyM: accuracyM, headingDeg: headingDeg, speedKph: speedKph
      ) { code in
        guard code == 401 else { return }
        // Token died between the freshness check and the call — refresh
        // once and retry the single upsert.
        self.refresh(fresh) { refreshed in
          guard let refreshed = refreshed else { return }
          self.postRpc(
            refreshed, status: status, lat: lat, lng: lng,
            accuracyM: accuracyM, headingDeg: headingDeg, speedKph: speedKph,
            completion: { _ in })
        }
      }
    }
  }

  private func postRpc(
    _ session: PresenceSession,
    status: String,
    lat: Double?,
    lng: Double?,
    accuracyM: Int?,
    headingDeg: Int?,
    speedKph: Int?,
    completion: @escaping (Int) -> Void
  ) {
    guard let url = URL(string: "\(session.supabaseUrl)/rest/v1/rpc/upsert_driver_presence")
    else {
      completion(-1)
      return
    }
    var body: [String: Any] = ["p_status": status]
    if let lat = lat { body["p_lat"] = lat }
    if let lng = lng { body["p_lng"] = lng }
    if let accuracyM = accuracyM { body["p_accuracy_m"] = accuracyM }
    if let headingDeg = headingDeg { body["p_heading_deg"] = headingDeg }
    if let speedKph = speedKph { body["p_speed_kph"] = speedKph }
    if let vehicleId = session.vehicleId { body["p_vehicle_id"] = vehicleId }

    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(session.anonKey, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    req.timeoutInterval = 12

    URLSession.shared.dataTask(with: req) { _, response, _ in
      let code = (response as? HTTPURLResponse)?.statusCode ?? -1
      completion(code)
    }.resume()
  }

  private func ensureFreshToken(
    _ session: PresenceSession,
    completion: @escaping (PresenceSession) -> Void
  ) {
    let now = Int(Date().timeIntervalSince1970)
    // Refresh proactively 60s before expiry.
    if session.expiresAt == 0 || now < session.expiresAt - 60 {
      completion(session)
      return
    }
    refresh(session) { refreshed in
      completion(refreshed ?? session)
    }
  }

  /// Exchange the refresh token for a new session via GoTrue and persist
  /// the rotated pair.
  private func refresh(
    _ session: PresenceSession,
    completion: @escaping (PresenceSession?) -> Void
  ) {
    if refreshing {
      completion(nil)
      return
    }
    refreshing = true
    guard
      let url = URL(string: "\(session.supabaseUrl)/auth/v1/token?grant_type=refresh_token")
    else {
      refreshing = false
      completion(nil)
      return
    }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(session.anonKey, forHTTPHeaderField: "apikey")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try? JSONSerialization.data(
      withJSONObject: ["refresh_token": session.refreshToken])
    req.timeoutInterval = 12

    URLSession.shared.dataTask(with: req) { data, response, _ in
      defer { self.refreshing = false }
      guard
        let data = data,
        (response as? HTTPURLResponse)?.statusCode == 200,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let access = json["access_token"] as? String,
        let refresh = json["refresh_token"] as? String
      else {
        completion(nil)
        return
      }
      let expiresAt =
        (json["expires_at"] as? Int)
        ?? (Int(Date().timeIntervalSince1970) + ((json["expires_in"] as? Int) ?? 3600))
      PresenceStore.updateTokens(
        accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
      var updated = session
      updated.accessToken = access
      updated.refreshToken = refresh
      updated.expiresAt = expiresAt
      completion(updated)
    }.resume()
  }
}

// MARK: - Significant-location manager

final class SignificantLocationManager: NSObject, CLLocationManagerDelegate {
  static let shared = SignificantLocationManager()

  private let manager = CLLocationManager()
  private let uploader = SupabasePresenceUploader()
  private var monitoring = false

  override private init() {
    super.init()
    manager.delegate = self
    manager.allowsBackgroundLocationUpdates = true
    manager.pausesLocationUpdatesAutomatically = false
    manager.desiredAccuracy = kCLLocationAccuracyBest
  }

  func start() {
    manager.requestAlwaysAuthorization()
    if !monitoring {
      manager.startMonitoringSignificantLocationChanges()
      monitoring = true
    }
  }

  func stop() {
    if monitoring {
      manager.stopMonitoringSignificantLocationChanges()
      monitoring = false
    }
  }

  func locationManager(
    _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    guard let loc = locations.last else { return }
    let heading = loc.course >= 0 ? Int(loc.course.rounded()) : nil
    let speed = loc.speed >= 0 ? Int((loc.speed * 3.6).rounded()) : nil
    uploader.upsert(
      status: "online",
      lat: loc.coordinate.latitude,
      lng: loc.coordinate.longitude,
      accuracyM: loc.horizontalAccuracy >= 0 ? Int(loc.horizontalAccuracy.rounded()) : nil,
      headingDeg: heading,
      speedKph: speed)
  }
}

// MARK: - Method channel

final class PresenceChannel {
  init(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "drivio/bg_presence", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start", "updateSession":
        guard let args = call.arguments as? [String: Any],
          let session = PresenceChannel.parseSession(args)
        else {
          result(false)
          return
        }
        if call.method == "start" {
          PresenceStore.save(session)
          SignificantLocationManager.shared.start()
        } else {
          PresenceStore.updateTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: session.expiresAt)
        }
        result(true)
      case "stop":
        SignificantLocationManager.shared.stop()
        PresenceStore.clear()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func parseSession(_ args: [String: Any]) -> PresenceSession? {
    guard let url = args["supabaseUrl"] as? String,
      let anon = args["anonKey"] as? String,
      let access = args["accessToken"] as? String,
      let refresh = args["refreshToken"] as? String
    else { return nil }
    let vehicle = args["vehicleId"] as? String
    return PresenceSession(
      supabaseUrl: url,
      anonKey: anon,
      accessToken: access,
      refreshToken: refresh,
      expiresAt: (args["expiresAt"] as? Int) ?? 0,
      vehicleId: vehicle)
  }
}
