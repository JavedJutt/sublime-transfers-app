import 'enums.dart';

/// An email that arrived in a connected mailbox, as read through the
/// `admin_emails` view. Carries the parser's output — a confidence, an error
/// reason, and a best-effort [parsedPayload] the reviewer corrects and imports.
class InboundEmail {
  const InboundEmail({
    required this.id,
    required this.parseStatus,
    required this.createdAt,
    this.gmailAccountId,
    this.adminId,
    this.fromAddress,
    this.subject,
    this.receivedAt,
    this.bodyText,
    this.parsedPayload,
    this.confidence,
    this.modelId,
    this.parseError,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.createdRideId,
    this.mailboxAddress,
  });

  final String id;
  final ParseStatus parseStatus;
  final DateTime createdAt;
  final String? gmailAccountId;
  final String? adminId;
  final String? fromAddress;
  final String? subject;
  final DateTime? receivedAt;
  final String? bodyText;
  final Map<String, dynamic>? parsedPayload;
  final double? confidence;
  final String? modelId;
  final String? parseError;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? createdRideId;
  final String? mailboxAddress;

  bool get wasImported => createdRideId != null;

  /// The booking the parser managed to pull out, if the payload is ride-shaped
  /// (an extraction) rather than a review flag.
  ParsedBooking? get booking {
    final p = parsedPayload;
    if (p == null) return null;
    // A flag_for_review payload has a `reason`, not ride fields.
    if (p.containsKey('reason') && !p.containsKey('pickup_at')) return null;
    return ParsedBooking.fromMap(p);
  }

  static DateTime? _t(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  factory InboundEmail.fromMap(Map<String, dynamic> m) => InboundEmail(
        id: m['id'] as String,
        parseStatus: ParseStatus.fromWire(m['parse_status'] as String),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        gmailAccountId: m['gmail_account_id'] as String?,
        adminId: m['admin_id'] as String?,
        fromAddress: m['from_address'] as String?,
        subject: m['subject'] as String?,
        receivedAt: _t(m['received_at']),
        bodyText: m['body_text'] as String?,
        parsedPayload: (m['parsed_payload'] as Map?)?.cast<String, dynamic>(),
        confidence: (m['confidence'] as num?)?.toDouble(),
        modelId: m['model_id'] as String?,
        parseError: m['parse_error'] as String?,
        reviewedBy: m['reviewed_by'] as String?,
        reviewedByName: m['reviewed_by_name'] as String?,
        reviewedAt: _t(m['reviewed_at']),
        createdRideId: m['created_ride_id'] as String?,
        mailboxAddress: m['mailbox_address'] as String?,
      );
}

/// The ride-shaped payload the parser produces and the reviewer edits. All
/// fields optional — the whole point of review is that some are missing.
class ParsedBooking {
  const ParsedBooking({
    this.pickupAt,
    this.customerName,
    this.customerPhone,
    this.pickupAddress,
    this.dropoffAddress,
    this.passengers,
    this.luggage,
    this.fareAmount,
    this.fareCurrency,
    this.vehicleType,
    this.flightNumber,
    this.notes,
  });

  final DateTime? pickupAt;
  final String? customerName;
  final String? customerPhone;
  final String? pickupAddress;
  final String? dropoffAddress;
  final int? passengers;
  final int? luggage;
  final num? fareAmount;
  final String? fareCurrency;
  final VehicleType? vehicleType;
  final String? flightNumber;
  final String? notes;

  factory ParsedBooking.fromMap(Map<String, dynamic> m) {
    DateTime? at;
    final raw = m['pickup_at'];
    if (raw is String && raw.isNotEmpty) {
      at = DateTime.tryParse(raw)?.toLocal();
    }
    return ParsedBooking(
      pickupAt: at,
      customerName: m['customer_name'] as String?,
      customerPhone: m['customer_phone'] as String?,
      pickupAddress: m['pickup_address'] as String?,
      dropoffAddress: m['dropoff_address'] as String?,
      passengers: (m['passengers'] as num?)?.toInt(),
      luggage: (m['luggage'] as num?)?.toInt(),
      fareAmount: m['fare_amount'] as num?,
      fareCurrency: m['fare_currency'] as String?,
      vehicleType: switch (m['vehicle_type']) {
        final String v when v.isNotEmpty => VehicleType.fromWire(v),
        _ => null,
      },
      flightNumber: m['flight_number'] as String?,
      notes: m['notes'] as String?,
    );
  }

  /// Serialise back to the snake_case payload the import RPC consumes.
  Map<String, dynamic> toPayload() => {
        'pickup_at': pickupAt?.toUtc().toIso8601String(),
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'passengers': passengers,
        'luggage': luggage,
        'fare_amount': fareAmount,
        'fare_currency': fareCurrency,
        'vehicle_type': vehicleType?.wire,
        'flight_number': flightNumber,
        'notes': notes,
      };
}
