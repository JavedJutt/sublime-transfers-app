import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sublime_transfers/core/design/app_theme.dart';
import 'package:sublime_transfers/data/models/enums.dart';
import 'package:sublime_transfers/data/repositories/driver_repository.dart';
import 'package:sublime_transfers/features/admin/presentation/driver_approvals_screen.dart';
import 'package:sublime_transfers/features/admin/presentation/drivers_screen.dart';
import 'package:sublime_transfers/features/admin/widgets/drivers/driver_card.dart';
import 'package:sublime_transfers/providers/driver_providers.dart';
import 'package:sublime_transfers/shared/widgets/feedback/empty_state.dart';

DriverListItem _driver({
  String id = 'd1',
  String name = 'Marcus Bell',
  DriverApprovalStatus status = DriverApprovalStatus.approved,
  bool onDuty = false,
}) =>
    DriverListItem(
      id: id,
      fullName: name,
      email: '$id@sublimetransfers.test',
      approvalStatus: status,
      phone: '+44 7700 900101',
      vehicleType: VehicleType.executive,
      vehiclePlate: 'LX21 ATE',
      isOnDuty: onDuty,
      createdAt: DateTime.now(),
    );

Widget _appFor(Widget screen) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
  );
  return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
}

Future<void> _pump(WidgetTester tester, Widget scope,
    {double width = 1200, double height = 1400}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(scope);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  group('DriversScreen', () {
    testWidgets('lists drivers and shows a pending review CTA', (tester) async {
      await _pump(
        tester,
        ProviderScope(
          overrides: [
            driverListProvider.overrideWith((ref) async => [
                  _driver(onDuty: true),
                  _driver(id: 'd2', name: 'Sam Okafor', status: DriverApprovalStatus.pending),
                ]),
            pendingDriversProvider.overrideWith((ref) async => [
                  _driver(id: 'd2', name: 'Sam Okafor', status: DriverApprovalStatus.pending),
                ]),
          ],
          child: _appFor(const DriversScreen()),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DriverCard), findsNWidgets(2));
      expect(find.textContaining('Review 1 pending'), findsOneWidget);
    });
  });

  group('DriverApprovalsScreen', () {
    testWidgets('renders each pending applicant with approve/reject',
        (tester) async {
      await _pump(
        tester,
        ProviderScope(
          overrides: [
            pendingDriversProvider.overrideWith((ref) async => [
                  _driver(id: 'd2', name: 'Sam Okafor', status: DriverApprovalStatus.pending),
                ]),
          ],
          child: _appFor(const DriverApprovalsScreen()),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Sam Okafor'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('shows the positive empty state when nothing is pending',
        (tester) async {
      await _pump(
        tester,
        ProviderScope(
          overrides: [
            pendingDriversProvider.overrideWith((ref) async => <DriverListItem>[]),
          ],
          child: _appFor(const DriverApprovalsScreen()),
        ),
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No pending approvals'), findsOneWidget);
    });
  });
}
