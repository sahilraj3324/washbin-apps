import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _activeStatuses = {
  'partner_assigned',
  'accepted',
  'on_the_way',
  'arrived',
  'in_progress',
};

/// A scripted Washbin API.
///
/// Routes the endpoints the partner app depends on — the sign-in exchange, the
/// partner's own record, the catalogue and the partner-services join — and
/// records what was asked of it, so tests can assert on the request as well as
/// the outcome.
///
/// Mirrors the real server's rules where they matter: `submit-for-review`
/// refuses an incomplete profile and a partner with no services, and adding a
/// service twice conflicts on the unique index.
class FakeBackend {
  FakeBackend({
    this.partnerId = 'partner-1',
    this.businessName = 'Sharma Home Services',
    this.ownerName = 'Rahul Sharma',
    this.partnerPhone = '+919876543210',
    this.accessToken = 'washbin-partner-token',
    this.verificationStatus = 'pending',
    this.partnerStatus = 'active',
  });

  final String partnerId;
  String businessName;
  String ownerName;
  final String partnerPhone;
  final String accessToken;

  /// Where document checking has got to: pending, submitted, verified,
  /// rejected.
  String verificationStatus;

  /// The account's own standing: active, inactive, suspended.
  String partnerStatus;

  /// Why the last review was refused, as the app shows on a rejection.
  String? rejectionReason;

  String? submittedAt;

  // ---- profile ----------------------------------------------------------

  String? email;
  int? experienceYears;
  Map<String, dynamic>? address;
  Map<String, dynamic>? emergencyContact;
  String? gender;

  /// A profile that would pass the server's completeness check.
  void completeProfile() {
    email = 'rahul@example.com';
    experienceYears = 6;
    address = {
      'line1': '14 Shivaji Road',
      'city': 'Mumbai',
      'state': 'Maharashtra',
      'pincode': '400020',
    };
  }

  /// Bodies posted to `/partner-auth/phone`, oldest first.
  final signInCalls = <Map<String, dynamic>>[];

  /// Bodies sent to `PATCH /partners/me`, oldest first.
  final profileUpdates = <Map<String, dynamic>>[];

  /// How many times the partner asked to be reviewed.
  var submitCalls = 0;

  /// Authorization headers seen, per request path.
  final authorizationHeaders = <String, String?>{};

  /// How many times each path has been requested.
  final requestCounts = <String, int>{};

  /// When true, `/partner-auth/phone` answers 404 PROFILE_REQUIRED for a call
  /// that carries no business name — the real server's "this number has no
  /// account".
  bool requiresProfile = true;

  /// Set to fail every call with a transport error, as a dead network would.
  bool offline = false;

  /// Set to fail the profile read only, leaving sign-in working.
  bool profileReadFails = false;

  /// Set to have the profile read reject the token, as an expired one is.
  bool profileReadUnauthorized = false;

  /// Set to refuse sign-in with 403, as the API refuses a suspended partner.
  bool suspended = false;

  /// Set to fail every catalogue read, leaving the rest working.
  bool catalogueFails = false;

  /// Set to fail every partner-services read and write.
  bool partnerServicesFail = false;

  /// Set to fail availability reads and writes.
  bool availabilityFails = false;

  /// Set to reject a go-online request, as the real backend would when a
  /// partner loses approval or service eligibility between app refreshes.
  bool goOnlineRejected = false;

  // ---- catalogue --------------------------------------------------------

  List<Map<String, dynamic>> categories = [
    category(id: 'cat-1', name: 'Home Cleaning', sortOrder: 0),
    category(id: 'cat-2', name: 'Cooking', sortOrder: 1),
  ];

  List<Map<String, dynamic>> services = [
    service(id: 'svc-1', categoryId: 'cat-1', name: 'Deep Cleaning'),
    service(
      id: 'svc-2',
      categoryId: 'cat-1',
      name: 'Bathroom Cleaning',
      basePrice: 199,
      sortOrder: 1,
    ),
    service(
      id: 'svc-3',
      categoryId: 'cat-2',
      name: 'Home Cook',
      basePrice: 499,
    ),
  ];

  /// This partner's join rows, keyed by row id.
  final partnerServices = <String, Map<String, dynamic>>{};

  var isOnline = false;
  var isAvailable = false;
  var serviceRadiusKm = 10.0;
  double? latitude;
  double? longitude;
  String? lastLocationUpdatedAt;

  final availabilityUpdates = <Map<String, dynamic>>[];
  final locationUpdates = <Map<String, dynamic>>[];
  final jobOffers = <String, Map<String, dynamic>>{};
  final acceptedOffers = <String>[];
  final rejectedOffers = <String>[];
  final registeredDeviceTokens = <Map<String, dynamic>>[];
  final deactivatedDeviceTokens = <String>[];
  final notifications = <Map<String, dynamic>>[];
  bool acceptOfferFailsAsExpired = false;
  bool rejectOfferFailsAsExpired = false;
  bool nextJobTransitionFails = false;

  var _nextRowId = 1;
  var _nextOfferId = 1;

  /// Seeds an active row, as a partner who has already chosen a service has.
  void offerService(String serviceId, {bool isActive = true}) {
    final id = 'ps-${_nextRowId++}';
    partnerServices[id] = {
      '_id': id,
      'partnerId': partnerId,
      'serviceId': serviceId,
      'isActive': isActive,
    };
  }

  Map<String, dynamic> addJobOffer({
    String serviceName = 'Home Assistance',
    String customerName = 'Priya Mehta',
    String location = 'Sector 45, Gurugram',
    String city = 'Gurugram',
    String state = 'Haryana',
    num distanceKm = 2.4,
    num amount = 350,
    Duration expiresIn = const Duration(seconds: 60),
  }) {
    final id = 'as-${_nextOfferId++}';
    final bookingId = 'booking-$id';
    final now = DateTime.now().toUtc();
    final offer = {
      '_id': id,
      'bookingId': {
        '_id': bookingId,
        'customerId': {
          '_id': 'customer-$id',
          'name': customerName,
          'phone': '+919999999999',
        },
        'serviceId': {
          '_id': 'svc-offer-$id',
          'name': serviceName,
          'pricingType': 'fixed',
          'basePrice': amount,
          'estimatedDurationMinutes': 60,
        },
        'addressSnapshot': {
          'fullAddress': location,
          'city': city,
          'state': state,
          'pincode': '122003',
          'latitude': 28.4595,
          'longitude': 77.0266,
        },
        'bookingType': 'instant',
        'status': 'partner_assigned',
        'price': {
          'baseAmount': amount,
          'finalAmount': amount,
          'currency': 'INR',
        },
      },
      'partnerId': partnerId,
      'status': 'offered',
      'offeredAt': now.toIso8601String(),
      'expiresAt': now.add(expiresIn).toIso8601String(),
      'distanceKm': distanceKm,
    };
    jobOffers[id] = offer;
    return offer;
  }

  void addNotification({
    String title = 'New Job Request',
    String body = '2.1 km away',
    String type = 'PARTNER_OFFERED',
    String? bookingId,
    bool isRead = false,
  }) {
    final id = 'notif-${notifications.length + 1}';
    notifications.add({
      '_id': id,
      'type': type,
      'title': title,
      'body': body,
      'bookingId': bookingId,
      'isRead': isRead,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Map<String, dynamic> category({
    required String id,
    required String name,
    int sortOrder = 0,
    bool isActive = true,
  }) => {
    '_id': id,
    'name': name,
    'slug': name.toLowerCase().replaceAll(' ', '-'),
    'sortOrder': sortOrder,
    'isActive': isActive,
  };

  static Map<String, dynamic> service({
    required String id,
    required String categoryId,
    required String name,
    num basePrice = 299,
    String pricingType = 'fixed',
    int? durationMinutes = 60,
    int sortOrder = 0,
    bool isActive = true,
  }) => {
    '_id': id,
    'categoryId': categoryId,
    'name': name,
    'slug': name.toLowerCase().replaceAll(' ', '-'),
    'description': 'A thorough job, done well.',
    'pricingType': pricingType,
    'basePrice': basePrice,
    'estimatedDurationMinutes': durationMinutes,
    'sortOrder': sortOrder,
    'isActive': isActive,
  };

  http.Client get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    authorizationHeaders[request.url.path] =
        request.headers['Authorization'] ?? request.headers['authorization'];

    if (offline) {
      throw http.ClientException('connection failed', request.url);
    }

    final path = request.url.path;
    requestCounts[path] = (requestCounts[path] ?? 0) + 1;

    return switch (path) {
      '/partner-auth/phone' => _signIn(request),
      '/health' => _json({
        'status': 'ok',
        'database': {'state': 'connected'},
      }),
      '/partners/me' =>
        request.method == 'PATCH' ? _updateProfile(request) : _profile(),
      '/partners/me/submit-for-review' => _submitForReview(),
      '/categories' => _catalogue(categories),
      '/services' => _catalogue(services),
      '/partner-services/me' =>
        request.method == 'POST'
            ? _addPartnerService(request)
            : _listPartnerServices(),
      '/availability/me' =>
        request.method == 'PATCH'
            ? _updateAvailability(request)
            : _availability(),
      '/availability/me/location' => _updateLocation(request),
      '/bookings/me/active' => _activeBooking(),
      '/bookings/me/dashboard' => _dashboard(),
      '/bookings/me/history' => _jobHistory(request),
      _ when path.startsWith('/bookings/') => _updateActiveBooking(path),
      '/notifications' => _notifications(request),
      '/notifications/unread-count' => _json({
        'unread': notifications.where((row) => row['isRead'] != true).length,
      }),
      '/notifications/read-all' => _markAllNotificationsRead(),
      '/notifications/device-token' =>
        request.method == 'DELETE'
            ? _deactivateDeviceToken(request)
            : _registerDeviceToken(request),
      _ when path.startsWith('/notifications/') => _markNotificationRead(path),
      '/partner-assignment/offers/me' => _listJobOffers(),
      _ when path.startsWith('/partner-assignment/') => _updateJobOffer(path),
      _ when path.startsWith('/partner-services/me/') => _updatePartnerService(
        request,
        path.split('/').last,
      ),
      _ => _json({'message': 'Not found'}, 404),
    };
  }

  http.Response _signIn(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    signInCalls.add(body);

    // Checked before the account even exists, as `assertCanSignIn` is: a
    // suspended partner never receives a token.
    if (suspended) {
      return _json({'message': 'This partner account has been suspended'}, 403);
    }

    final business = body['businessName'] as String?;
    final owner = body['ownerName'] as String?;

    if (requiresProfile && (business == null || owner == null)) {
      return _json({
        'statusCode': 404,
        'code': 'PROFILE_REQUIRED',
        'message': 'No partner account for this number yet.',
      }, 404);
    }

    if (business != null && owner != null) {
      businessName = business;
      ownerName = owner;
      requiresProfile = false;
    }

    return _json({
      'accessToken': accessToken,
      'id': partnerId,
      'businessName': businessName,
      'ownerName': ownerName,
      'phone': partnerPhone,
      'verificationStatus': verificationStatus,
      'isNewPartner': business != null,
    });
  }

  Map<String, dynamic> get _partnerJson => {
    '_id': partnerId,
    'businessName': businessName,
    'ownerName': ownerName,
    'phone': partnerPhone,
    'email': email,
    'gender': gender,
    'experienceYears': experienceYears,
    'address': address,
    'emergencyContact': emergencyContact,
    'verificationStatus': verificationStatus,
    'status': partnerStatus,
    'rejectionReason': rejectionReason,
    'submittedAt': submittedAt,
    'rating': 0,
  };

  http.Response _profile() {
    if (profileReadUnauthorized) {
      return _json({'message': 'Invalid or expired token'}, 401);
    }
    if (profileReadFails) {
      return _json({'message': 'Internal server error'}, 500);
    }

    // Mongo's own shape: `_id`, not `id`.
    return _json(_partnerJson);
  }

  /// PATCH /partners/me. Absent means "leave alone", as the server treats it.
  http.Response _updateProfile(http.Request request) {
    if (profileReadFails) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    profileUpdates.add(body);

    // The route's allow-list. Anything else is a 400 from the ValidationPipe,
    // which is what stops a partner approving themselves.
    const allowed = {
      'businessName',
      'ownerName',
      'email',
      'profileImage',
      'gender',
      'experienceYears',
      'address',
      'emergencyContact',
    };
    final rejected = body.keys.where((key) => !allowed.contains(key));
    if (rejected.isNotEmpty) {
      return _json({
        'message': rejected.map((k) => 'property $k should not exist').toList(),
      }, 400);
    }

    businessName = body['businessName'] as String? ?? businessName;
    ownerName = body['ownerName'] as String? ?? ownerName;
    email = body['email'] as String? ?? email;
    gender = body['gender'] as String? ?? gender;
    experienceYears =
        (body['experienceYears'] as num?)?.toInt() ?? experienceYears;
    address = body['address'] as Map<String, dynamic>? ?? address;
    emergencyContact =
        body['emergencyContact'] as Map<String, dynamic>? ?? emergencyContact;

    return _json(_partnerJson);
  }

  /// Mirrors `PartnersService.submitForReview`, including the order of its
  /// checks — the profile before the services.
  http.Response _submitForReview() {
    submitCalls++;

    if (partnerStatus == 'suspended') {
      return _json({'message': 'This partner account has been suspended'}, 403);
    }
    if (verificationStatus == 'verified') {
      return _json({'message': 'This partner is already verified'}, 409);
    }
    if (verificationStatus == 'submitted') {
      return _json({'partner': _partnerJson, 'submitted': false});
    }

    final missing = [
      if ((email ?? '').trim().isEmpty) 'email',
      if (experienceYears == null) 'experienceYears',
      if (address == null) 'address',
    ];
    if (missing.isNotEmpty) {
      return _json({
        'message':
            'Complete your profile first — missing: '
            '${missing.join(', ')}',
      }, 400);
    }

    final active = partnerServices.values.where(
      (row) => row['isActive'] == true,
    );
    if (active.isEmpty) {
      return _json({
        'message': 'Choose at least one service before submitting for review',
      }, 400);
    }

    verificationStatus = 'submitted';
    submittedAt = DateTime.now().toUtc().toIso8601String();
    rejectionReason = null;

    return _json({'partner': _partnerJson, 'submitted': true});
  }

  http.Response _catalogue(List<Map<String, dynamic>> rows) {
    if (catalogueFails) {
      return _json({'message': 'Internal server error'}, 500);
    }
    return _jsonList(rows.where((row) => row['isActive'] != false).toList());
  }

  http.Response _listPartnerServices() {
    if (partnerServicesFail) {
      return _json({'message': 'Internal server error'}, 500);
    }
    return _jsonList(partnerServices.values.toList());
  }

  http.Response _addPartnerService(http.Request request) {
    if (partnerServicesFail) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final serviceId = body['serviceId'] as String;

    if (services.every((row) => row['_id'] != serviceId)) {
      return _json({'message': 'Service $serviceId not found'}, 400);
    }

    // The unique index on (partnerId, serviceId): a second row is refused,
    // which is why the app reactivates a paused one instead of adding.
    if (partnerServices.values.any((row) => row['serviceId'] == serviceId)) {
      return _json({
        'message': 'That partner already offers that service',
      }, 409);
    }

    final id = 'ps-${_nextRowId++}';
    final row = {
      '_id': id,
      'partnerId': partnerId,
      'serviceId': serviceId,
      'isActive': body['isActive'] ?? true,
    };
    partnerServices[id] = row;
    return _json(row);
  }

  http.Response _updatePartnerService(http.Request request, String id) {
    if (partnerServicesFail) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final row = partnerServices[id];
    if (row == null) {
      return _json({'message': 'Partner service $id not found'}, 404);
    }

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    row['isActive'] = body['isActive'] as bool? ?? row['isActive'];
    return _json(row);
  }

  http.Response _availability() {
    if (availabilityFails) {
      return _json({'message': 'Internal server error'}, 500);
    }

    return _json(_availabilityJson);
  }

  http.Response _updateAvailability(http.Request request) {
    if (availabilityFails) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    availabilityUpdates.add(body);

    final wantsOnline = body['isOnline'] as bool? ?? isOnline;
    if (wantsOnline) {
      if (goOnlineRejected) {
        return _json({'message': 'Only approved partners can go online'}, 403);
      }
      if (partnerServices.values.every((row) => row['isActive'] != true)) {
        return _json({
          'message': 'Choose at least one active service before going online',
        }, 400);
      }
      final hasStoredLocation = latitude != null && longitude != null;
      final hasLocationUpdate =
          body['latitude'] != null && body['longitude'] != null;
      if (!hasStoredLocation && !hasLocationUpdate) {
        return _json({
          'message': 'Current location is required before going online',
        }, 400);
      }
    }

    if (body['latitude'] != null && body['longitude'] != null) {
      latitude = (body['latitude'] as num).toDouble();
      longitude = (body['longitude'] as num).toDouble();
      lastLocationUpdatedAt = DateTime.now().toUtc().toIso8601String();
    }

    isOnline = wantsOnline;
    isAvailable = body['isAvailable'] as bool? ?? isAvailable;
    if (!isOnline) {
      isAvailable = false;
    }
    serviceRadiusKm =
        (body['serviceRadiusKm'] as num?)?.toDouble() ?? serviceRadiusKm;

    return _json(_availabilityJson);
  }

  http.Response _updateLocation(http.Request request) {
    if (availabilityFails) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    locationUpdates.add(body);
    latitude = (body['latitude'] as num).toDouble();
    longitude = (body['longitude'] as num).toDouble();
    lastLocationUpdatedAt = DateTime.now().toUtc().toIso8601String();

    return _json(_availabilityJson);
  }

  http.Response _listJobOffers() {
    final now = DateTime.now();
    for (final offer in jobOffers.values) {
      final expiresAt = DateTime.tryParse(offer['expiresAt'] as String? ?? '');
      if (offer['status'] == 'offered' &&
          expiresAt != null &&
          !expiresAt.isAfter(now)) {
        offer['status'] = 'expired';
        offer['respondedAt'] = now.toUtc().toIso8601String();
      }
    }

    return _jsonList(
      jobOffers.values.where((offer) => offer['status'] == 'offered').toList(),
    );
  }

  http.Response _updateJobOffer(String path) {
    final parts = path.split('/');
    final id = parts.length >= 3 ? parts[2] : '';
    final action = parts.length >= 4 ? parts[3] : '';
    final offer = jobOffers[id];

    if (offer == null) {
      return _json({'message': 'Assignment $id not found'}, 404);
    }

    final expiresAt = DateTime.tryParse(offer['expiresAt'] as String? ?? '');
    final isExpired = expiresAt != null && !expiresAt.isAfter(DateTime.now());

    if (action == 'accept') {
      if (acceptOfferFailsAsExpired || isExpired) {
        offer['status'] = 'expired';
        return _json({'message': 'That offer has expired'}, 409);
      }
      if (offer['status'] != 'offered') {
        return _json({
          'message': 'That offer was already ${offer['status']}',
        }, 409);
      }
      acceptedOffers.add(id);
      offer['status'] = 'accepted';
      offer['respondedAt'] = DateTime.now().toUtc().toIso8601String();
      final booking = offer['bookingId'] as Map<String, dynamic>;
      booking['status'] = 'accepted';
      booking['acceptedAt'] = DateTime.now().toUtc().toIso8601String();
      isOnline = true;
      isAvailable = false;
      return _json(offer);
    }

    if (action == 'reject') {
      if (rejectOfferFailsAsExpired || isExpired) {
        offer['status'] = 'expired';
        return _json({'message': 'That offer has expired'}, 409);
      }
      rejectedOffers.add(id);
      offer['status'] = 'rejected';
      offer['respondedAt'] = DateTime.now().toUtc().toIso8601String();
      return _json(offer);
    }

    return _json({'message': 'Not found'}, 404);
  }

  http.Response _activeBooking() {
    final booking = _currentActiveBooking;
    return booking == null ? _jsonRaw(null) : _json(booking);
  }

  http.Response _dashboard() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekStart = todayStart.subtract(
      Duration(days: todayStart.weekday - 1),
    );
    final monthStart = DateTime(now.year, now.month);
    final bookings = _allBookings;

    final completedToday = bookings.where(
      (booking) =>
          booking['status'] == 'completed' &&
          _isInRange(booking['completedAt'], todayStart, todayEnd),
    );
    final cancelledToday = bookings.where(
      (booking) =>
          booking['status'] == 'cancelled' &&
          _isInRange(booking['cancelledAt'], todayStart, todayEnd),
    );
    final upcomingToday = bookings.where(
      (booking) =>
          booking['bookingType'] == 'scheduled' &&
          _activeStatuses.contains(booking['status']) &&
          _isInRange(booking['scheduledAt'], now, todayEnd),
    );
    final completedThisMonth = bookings.where(
      (booking) =>
          booking['status'] == 'completed' &&
          _isInRange(booking['completedAt'], monthStart, null),
    );
    final completedThisWeek = completedThisMonth.where(
      (booking) => _isInRange(booking['completedAt'], weekStart, null),
    );

    return _json({
      'asOf': now.toUtc().toIso8601String(),
      'today': {
        'completedJobs': completedToday.length,
        'upcomingJobs': upcomingToday.length,
        'cancelledJobs': cancelledToday.length,
        'earnings': _sumEarnings(completedToday),
      },
      'earnings': {
        'today': _sumEarnings(completedToday),
        'week': _sumEarnings(completedThisWeek),
        'month': _sumEarnings(completedThisMonth),
        'currency': 'INR',
      },
      'activeJob': _currentActiveBooking,
      'recentJobs': bookings.reversed.take(5).toList(),
    });
  }

  http.Response _jobHistory(http.Request request) {
    final status = request.url.queryParameters['status'];
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 30;
    final skip = int.tryParse(request.url.queryParameters['skip'] ?? '') ?? 0;
    final rows = <Map<String, dynamic>>[];
    for (final offer in jobOffers.values) {
      final booking = offer['bookingId'];
      if (booking is Map<String, dynamic> &&
          (status == null || booking['status'] == status)) {
        rows.add(booking);
      }
    }
    return _jsonList(rows.skip(skip).take(limit).toList());
  }

  http.Response _updateActiveBooking(String path) {
    final parts = path.split('/');
    final bookingId = parts.length >= 3 ? parts[2] : '';
    final action = parts.length >= 4 ? parts[3] : '';
    final booking = _bookingById(bookingId);

    if (booking == null) {
      return _json({'message': 'Booking $bookingId not found'}, 404);
    }
    if (nextJobTransitionFails) {
      nextJobTransitionFails = false;
      return _json({
        'message':
            'That booking was just updated by another request. Try again.',
      }, 409);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final status = booking['status'] as String? ?? 'accepted';

    if (action == 'on-the-way' && status == 'accepted') {
      booking['status'] = 'on_the_way';
      booking['onTheWayAt'] = now;
      return _json(booking);
    }
    if (action == 'arrive' && status == 'on_the_way') {
      booking['status'] = 'arrived';
      booking['arrivedAt'] = now;
      return _json(booking);
    }
    if ((action == 'start' || action == 'verify-start-otp') &&
        status == 'arrived') {
      booking['status'] = 'in_progress';
      booking['startedAt'] = now;
      return _json(booking);
    }
    if (action == 'complete' && status == 'in_progress') {
      booking['status'] = 'completed';
      booking['completedAt'] = now;
      isOnline = true;
      isAvailable = true;
      return _json(booking);
    }

    return _json({
      'message': 'A booking that is $status cannot move to $action',
    }, 409);
  }

  Map<String, dynamic>? get _currentActiveBooking {
    for (final offer in jobOffers.values) {
      final booking = offer['bookingId'];
      if (booking is Map<String, dynamic> &&
          _activeStatuses.contains(booking['status'])) {
        return booking;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _allBookings {
    final rows = <Map<String, dynamic>>[];
    for (final offer in jobOffers.values) {
      final booking = offer['bookingId'];
      if (booking is Map<String, dynamic>) {
        rows.add(booking);
      }
    }
    return rows;
  }

  Map<String, dynamic>? _bookingById(String bookingId) {
    for (final offer in jobOffers.values) {
      final booking = offer['bookingId'];
      if (booking is Map<String, dynamic> && booking['_id'] == bookingId) {
        return booking;
      }
    }
    return null;
  }

  http.Response _notifications(http.Request request) {
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 50;
    final skip = int.tryParse(request.url.queryParameters['skip'] ?? '') ?? 0;
    return _jsonList(notifications.skip(skip).take(limit).toList());
  }

  http.Response _registerDeviceToken(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    registeredDeviceTokens.add(body);
    return _json({
      '_id': 'device-token-1',
      'userId': partnerId,
      'userType': 'partner',
      ...body,
      'isActive': true,
    });
  }

  http.Response _deactivateDeviceToken(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final token = body['token'] as String? ?? '';
    deactivatedDeviceTokens.add(token);
    return http.Response('', 204);
  }

  http.Response _markAllNotificationsRead() {
    for (final row in notifications) {
      row['isRead'] = true;
    }
    return _json({'updated': notifications.length});
  }

  http.Response _markNotificationRead(String path) {
    final id = path.split('/').elementAtOrNull(2);
    final row = notifications.cast<Map<String, dynamic>?>().firstWhere(
      (candidate) => candidate?['_id'] == id,
      orElse: () => null,
    );
    if (row == null) {
      return _json({'message': 'Notification $id not found'}, 404);
    }
    row['isRead'] = true;
    return _json(row);
  }

  Map<String, dynamic> get _availabilityJson => {
    '_id': 'availability-1',
    'partnerId': partnerId,
    'isOnline': isOnline,
    'isAvailable': isAvailable,
    'serviceRadiusKm': serviceRadiusKm,
    'currentLocation': latitude == null || longitude == null
        ? null
        : {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
    'lastLocationUpdatedAt': lastLocationUpdatedAt,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  static http.Response _jsonList(List<Map<String, dynamic>> body) {
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  static http.Response _json(Map<String, dynamic> body, [int status = 200]) {
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  static http.Response _jsonRaw(Object? body, [int status = 200]) {
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

bool _isInRange(Object? value, DateTime start, DateTime? end) {
  final date = DateTime.tryParse(value as String? ?? '');
  if (date == null || date.isBefore(start)) {
    return false;
  }
  return end == null || date.isBefore(end);
}

num _sumEarnings(Iterable<Map<String, dynamic>> bookings) {
  return bookings.fold<num>(0, (sum, booking) {
    final price = booking['price'];
    if (price is! Map<String, dynamic>) {
      return sum;
    }
    return sum +
        ((price['finalAmount'] as num?) ?? (price['baseAmount'] as num?) ?? 0);
  });
}
