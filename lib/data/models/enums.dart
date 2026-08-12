import '../../shared/widgets/display/status_chip.dart';

/// Driver approval state. Mirrors `driver_status`.
enum DriverApprovalStatus {
  pending,
  approved,
  rejected,
  suspended;

  static DriverApprovalStatus fromWire(String value) => switch (value) {
        'pending' => DriverApprovalStatus.pending,
        'approved' => DriverApprovalStatus.approved,
        'rejected' => DriverApprovalStatus.rejected,
        'suspended' => DriverApprovalStatus.suspended,
        _ => throw ArgumentError('Unknown driver_status: $value'),
      };

  String get wire => name;

  String get label => switch (this) {
        DriverApprovalStatus.pending => 'Pending',
        DriverApprovalStatus.approved => 'Approved',
        DriverApprovalStatus.rejected => 'Rejected',
        DriverApprovalStatus.suspended => 'Suspended',
      };

  StatusTone get tone => switch (this) {
        DriverApprovalStatus.pending => StatusTone.pending,
        DriverApprovalStatus.approved => StatusTone.complete,
        DriverApprovalStatus.rejected => StatusTone.urgent,
        DriverApprovalStatus.suspended => StatusTone.dormant,
      };

  bool get isApproved => this == DriverApprovalStatus.approved;
}

/// How a ride reached its driver. Mirrors `assignment_method`.
enum AssignmentMethod {
  direct,
  broadcast,
  manual;

  static AssignmentMethod? fromWire(String? value) => switch (value) {
        'direct' => AssignmentMethod.direct,
        'broadcast' => AssignmentMethod.broadcast,
        'manual' => AssignmentMethod.manual,
        null => null,
        _ => throw ArgumentError('Unknown assignment_method: $value'),
      };

  String get wire => name;

  String get label => switch (this) {
        AssignmentMethod.direct => 'Direct',
        AssignmentMethod.broadcast => 'Broadcast',
        AssignmentMethod.manual => 'Manual entry',
      };
}

/// Vehicle class. Mirrors `vehicle_type`.
enum VehicleType {
  sedan,
  estate,
  mpv,
  executive,
  minibus;

  static VehicleType? fromWire(String? value) => switch (value) {
        'sedan' => VehicleType.sedan,
        'estate' => VehicleType.estate,
        'mpv' => VehicleType.mpv,
        'executive' => VehicleType.executive,
        'minibus' => VehicleType.minibus,
        null => null,
        _ => throw ArgumentError('Unknown vehicle_type: $value'),
      };

  String get wire => name;

  String get label => switch (this) {
        VehicleType.sedan => 'Sedan',
        VehicleType.estate => 'Estate',
        VehicleType.mpv => 'MPV',
        VehicleType.executive => 'Executive',
        VehicleType.minibus => 'Minibus',
      };

  String get description => switch (this) {
        VehicleType.sedan => 'Up to 3 passengers',
        VehicleType.estate => 'Extra luggage capacity',
        VehicleType.mpv => 'Up to 6 passengers',
        VehicleType.executive => 'Premium saloon',
        VehicleType.minibus => 'Up to 8 passengers',
      };
}

/// Offer lifecycle. Mirrors `offer_status`.
enum OfferStatus {
  pending,
  accepted,
  declined,
  expired,
  withdrawn;

  static OfferStatus fromWire(String value) => switch (value) {
        'pending' => OfferStatus.pending,
        'accepted' => OfferStatus.accepted,
        'declined' => OfferStatus.declined,
        'expired' => OfferStatus.expired,
        'withdrawn' => OfferStatus.withdrawn,
        _ => throw ArgumentError('Unknown offer_status: $value'),
      };

  String get wire => name;
}

/// Email parse pipeline state. Mirrors `parse_status`.
enum ParseStatus {
  needsReview,
  parsed,
  rejected,
  imported;

  static ParseStatus fromWire(String value) => switch (value) {
        'needs_review' => ParseStatus.needsReview,
        'parsed' => ParseStatus.parsed,
        'rejected' => ParseStatus.rejected,
        'imported' => ParseStatus.imported,
        _ => throw ArgumentError('Unknown parse_status: $value'),
      };

  String get wire => switch (this) {
        ParseStatus.needsReview => 'needs_review',
        ParseStatus.parsed => 'parsed',
        ParseStatus.rejected => 'rejected',
        ParseStatus.imported => 'imported',
      };

  String get label => switch (this) {
        ParseStatus.needsReview => 'Needs review',
        ParseStatus.parsed => 'Auto-created',
        ParseStatus.rejected => 'Rejected',
        ParseStatus.imported => 'Imported',
      };

  bool get isOpen => this == ParseStatus.needsReview;
}
