/// Every route path in the app, in one place.
///
/// Feature code never writes a path literal — it references `R.x`, so a route
/// rename is a compile error rather than a dead link discovered in QA.
abstract final class R {
  // ------------------------------------------------------------------- entry
  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String pendingApproval = '/pending-approval';

  /// Shared by both roles.
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';

  /// Design-system gallery. Debug builds only.
  static const String components = '/dev/components';

  // ------------------------------------------------------------------- admin
  static const String adminDashboard = '/admin';
  static const String adminCalendar = '/admin/calendar';
  static const String adminRides = '/admin/rides';
  static const String adminRideNew = '/admin/rides/new';
  static const String adminRideDetail = '/admin/rides/:rideId';
  static const String adminRideEdit = '/admin/rides/:rideId/edit';
  static const String adminDrivers = '/admin/drivers';
  static const String adminDriverApprovals = '/admin/drivers/approvals';
  static const String adminDriverDetail = '/admin/drivers/:driverId';
  static const String adminLiveMap = '/admin/live';
  static const String adminReview = '/admin/review';
  static const String adminReviewItem = '/admin/review/:emailId';
  static const String adminGmail = '/admin/settings/gmail';
  static const String adminSettings = '/admin/settings';

  // ------------------------------------------------------------------ driver
  static const String driverHome = '/driver';
  static const String driverOffers = '/driver/offers';
  static const String driverHistory = '/driver/history';
  static const String driverRideDetail = '/driver/rides/:rideId';
  static const String driverActiveRide = '/driver/rides/:rideId/active';

  // ----------------------------------------------------------------- helpers
  static String adminRide(String rideId) => '/admin/rides/$rideId';
  static String adminRideEditFor(String rideId) => '/admin/rides/$rideId/edit';
  static String adminDriver(String driverId) => '/admin/drivers/$driverId';
  static String adminReviewFor(String emailId) => '/admin/review/$emailId';
  static String driverRide(String rideId) => '/driver/rides/$rideId';
  static String driverActive(String rideId) => '/driver/rides/$rideId/active';

  /// Where a signed-in user lands.
  static String homeFor({required bool isAdmin}) =>
      isAdmin ? adminDashboard : driverHome;
}
