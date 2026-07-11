import 'vehicle.dart';

/// Computes the VDP's browser-tab title -- matches the web app's
/// `getVdpTitle`. Three distinct branches: loaded, not-found, and a
/// loading/error branch the two share (both just show the plain
/// [dealerName] -- the web version only names three because error and
/// loading produce the same text, not because error is untitled).
/// [hasData] mirrors `data !== undefined` there: true once the inventory
/// fetch has succeeded at least once, independent of whether [vehicle] was
/// actually found in it -- checked alone (not alongside a loading flag) so
/// a not-found result stays correctly titled even if a future refresh
/// re-enters a loading state while still holding the previous data.
String vdpPageTitle({
  required Vehicle? vehicle,
  required bool hasData,
  required String dealerName,
}) {
  if (vehicle != null) {
    return '${vehicle.year} ${vehicle.make} ${vehicle.model} ${vehicle.trim} | $dealerName';
  }
  if (hasData) {
    return 'Vehicle Not Found | $dealerName';
  }
  return dealerName;
}
