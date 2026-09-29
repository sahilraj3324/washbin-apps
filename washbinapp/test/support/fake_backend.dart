import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A scripted Washbin API.
///
/// Routes the two endpoints Phase 1 depends on — the phone sign-in exchange
/// and the customer profile read — and records what was asked of it, so tests
/// can assert on the request as well as the outcome.
class FakeBackend {
  FakeBackend({
    this.customerId = 'customer-1',
    this.customerName = 'Rahul Sharma',
    this.customerPhone = '+919876543210',
    this.accessToken = 'washbin-token',
  });

  final String customerId;
  String customerName;
  final String customerPhone;
  final String accessToken;

  /// Bodies posted to `/customer-auth/phone`, oldest first.
  final signInCalls = <Map<String, dynamic>>[];

  /// Authorization headers seen, per request path.
  final authorizationHeaders = <String, String?>{};

  /// When true, `/customer-auth/phone` answers 404 PROFILE_REQUIRED for a call
  /// that carries no name — the real server's "this number has no account".
  bool requiresProfile = true;

  /// Set to fail every call with a transport error, as a dead network would.
  bool offline = false;

  /// Set to fail the profile read only, leaving sign-in working.
  bool profileReadFails = false;

  /// Set to refuse sign-in with 403, as a blocked account is refused.
  bool blocked = false;

  /// Set to fail every catalogue read, leaving auth working.
  bool catalogueFails = false;

  /// The signed-in customer's saved addresses, newest last.
  List<Map<String, dynamic>> addresses = [];

  /// Set to fail every address read and write.
  bool addressesFail = false;

  /// Points inside any of these circles are serviceable. Empty means nowhere
  /// is, which is what an API with no operational areas actually answers.
  List<({double latitude, double longitude, double radiusKm})> serviceAreas = [
    (latitude: 19.076, longitude: 72.8777, radiusKm: 25),
  ];

  /// Bodies posted to check-serviceability, oldest first.
  final serviceabilityChecks = <Map<String, dynamic>>[];

  /// Notifications in this customer's inbox, newest last.
  List<Map<String, dynamic>> notifications = [];

  /// Device tokens registered, and whether each is still active.
  final devices = <String, ({String platform, bool isActive})>{};

  /// Set to fail every notification read and write.
  bool notificationsFail = false;

  /// A stored notification, in the shape the API sends one.
  static Map<String, dynamic> notification({
    required String id,
    String type = 'PARTNER_ACCEPTED',
    String title = 'Partner assigned',
    String body = 'Your service professional has accepted your request.',
    String? bookingId = '68c1f4aa930b148ed80df6ab',
    bool isRead = false,
    String? createdAt,
  }) => {
    '_id': id,
    'userType': 'customer',
    'type': type,
    'title': title,
    'body': body,
    'bookingId': bookingId,
    'isRead': isRead,
    'createdAt':
        createdAt ??
        DateTime.now()
            .subtract(const Duration(minutes: 2))
            .toUtc()
            .toIso8601String(),
  };

  /// Bookings this customer has, newest last.
  List<Map<String, dynamic>> bookings = [];

  /// Bodies posted to /bookings, oldest first — including ones the server
  /// went on to reject, so a test can prove a request was or was not sent.
  final bookingAttempts = <Map<String, dynamic>>[];

  /// Set to fail every booking write.
  bool bookingsFail = false;

  /// How many times the dispatch sweep has been run.
  var sweepRuns = 0;

  var _nextBookingId = 1;

  /// Mirrors the server's schedule bounds.
  static const minScheduleLead = Duration(minutes: 15);
  static const maxScheduleHorizon = Duration(days: 60);

  var _nextAddressId = 1;

  /// A stored booking, in the shape the API sends one.
  static Map<String, dynamic> booking({
    required String id,
    String serviceId = 'svc-1',
    String status = 'searching_partner',
    String bookingType = 'instant',
    String? scheduledAt,
    num basePrice = 299,
    num? finalAmount = 299,
    String? notes,
    String? createdAt,
  }) => {
    '_id': id,
    'serviceId': serviceId,
    'addressId': 'addr-1',
    'addressSnapshot': {
      'fullAddress': '12 Marine Drive',
      'city': 'Mumbai',
      'state': 'Maharashtra',
      'pincode': '400020',
      'latitude': 19.076,
      'longitude': 72.8777,
    },
    'bookingType': bookingType,
    'scheduledAt': scheduledAt,
    'status': status,
    'price': {
      'baseAmount': basePrice,
      'finalAmount': finalAmount,
      'currency': 'INR',
    },
    'notes': notes,
    'createdAt': createdAt ?? DateTime.now().toUtc().toIso8601String(),
  };

  static Map<String, dynamic> address({
    required String id,
    String label = 'home',
    String fullAddress = '12 Marine Drive',
    String? houseNumber,
    String? landmark,
    String city = 'Mumbai',
    String state = 'Maharashtra',
    String pincode = '400020',
    double latitude = 19.076,
    double longitude = 72.8777,
    bool isDefault = false,
    bool isActive = true,
  }) => {
    '_id': id,
    'label': label,
    'fullAddress': fullAddress,
    'houseNumber': houseNumber,
    'landmark': landmark,
    'city': city,
    'state': state,
    'pincode': pincode,
    'latitude': latitude,
    'longitude': longitude,
    'isDefault': isDefault,
    'isActive': isActive,
  };

  /// The catalogue this backend serves, in the shape Mongo sends it.
  List<Map<String, dynamic>> categories = [
    category(id: 'cat-1', name: 'Home Cleaning', sortOrder: 0),
    category(id: 'cat-2', name: 'Cooking', sortOrder: 1),
  ];

  List<Map<String, dynamic>> services = [
    service(
      id: 'svc-1',
      categoryId: 'cat-1',
      name: 'Deep Cleaning',
      basePrice: 299,
      durationMinutes: 30,
    ),
    service(
      id: 'svc-2',
      categoryId: 'cat-2',
      name: 'Home Cook',
      basePrice: 499,
      durationMinutes: 60,
      sortOrder: 1,
    ),
  ];

  /// How many times each path has been requested.
  final requestCounts = <String, int>{};

  /// Query strings seen, per request path — so a test can assert that the
  /// customer-facing reads asked for active rows only.
  final queries = <String, Map<String, String>>{};

  static Map<String, dynamic> category({
    required String id,
    required String name,
    String? description,
    int sortOrder = 0,
    bool isActive = true,
  }) => {
    '_id': id,
    'name': name,
    'slug': name.toLowerCase().replaceAll(' ', '-'),
    'description': description,
    'sortOrder': sortOrder,
    'isActive': isActive,
  };

  static Map<String, dynamic> service({
    required String id,
    required String categoryId,
    required String name,
    required num basePrice,
    String description = 'A thorough job, done well.',
    String pricingType = 'fixed',
    int? durationMinutes,
    int sortOrder = 0,
    bool isActive = true,
  }) => {
    '_id': id,
    'categoryId': categoryId,
    'name': name,
    'slug': name.toLowerCase().replaceAll(' ', '-'),
    'description': description,
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
    queries[path] = request.url.queryParameters;
    requestCounts[path] = (requestCounts[path] ?? 0) + 1;

    return switch (path) {
      '/customer-auth/phone' => _signIn(request),
      '/health' => _json({
        'status': 'ok',
        'database': {'state': 'connected'},
      }),
      '/addresses/check-serviceability' => _checkServiceability(request),
      '/addresses/me' =>
        request.method == 'POST' ? _createAddress(request) : _listAddresses(),
      '/bookings' =>
        request.method == 'POST' ? _createBooking(request) : _listBookings(),
      '/partner-assignment/sweep-expired' => _sweep(),
      '/notifications' => _listNotifications(request),
      '/notifications/unread-count' => _unreadCount(),
      '/notifications/read-all' => _markAllRead(),
      '/notifications/device-token' =>
        request.method == 'POST'
            ? _registerDevice(request)
            : _deactivateDevice(request),
      '/categories' => _catalogue(_filtered(categories, request)),
      '/services' => _catalogue(_filtered(services, request)),
      _ when path.startsWith('/bookings/') && path.endsWith('/cancel') =>
        _cancelBooking(path.split('/')[2]),
      _ when path.startsWith('/notifications/') && path.endsWith('/read') =>
        _markRead(path.split('/')[2]),
      _ when path.startsWith('/bookings/') => _getBooking(path.split('/')[2]),
      _ when path.startsWith('/addresses/me/') => _writeAddress(
        request,
        path.split('/').last,
      ),
      _ when path.startsWith('/customers/') => _profile(),
      _ when path.startsWith('/categories/') && path.endsWith('/services') =>
        _servicesInCategory(path.split('/')[2]),
      _ when path.startsWith('/services/') => _service(path.split('/')[2]),
      _ when path.startsWith('/categories/') => _category(path.split('/')[2]),
      _ => _json({'message': 'Not found'}, 404),
    };
  }

  // ---- addresses -------------------------------------------------------

  http.Response _listAddresses() {
    if (addressesFail) {
      return _json({'message': 'Internal server error'}, 500);
    }

    // The server sorts default first, then newest.
    final rows = [...addresses]
      ..sort((a, b) {
        final byDefault = (b['isDefault'] == true ? 1 : 0).compareTo(
          a['isDefault'] == true ? 1 : 0,
        );
        return byDefault;
      });
    return _jsonList(rows);
  }

  http.Response _createAddress(http.Request request) {
    if (addressesFail) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    // The first address a customer saves is the default whatever they asked.
    final isDefault = body['isDefault'] == true || addresses.isEmpty;

    if (isDefault) {
      for (final row in addresses) {
        row['isDefault'] = false;
      }
    }

    final row = {
      ...address(id: 'addr-${_nextAddressId++}'),
      ...body,
      'isDefault': isDefault,
    };
    addresses.add(row);
    return _json(row);
  }

  http.Response _writeAddress(http.Request request, String id) {
    if (addressesFail) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final index = addresses.indexWhere((row) => row['_id'] == id);
    if (index < 0) {
      return _json({'message': 'Address $id not found'}, 404);
    }

    if (request.method == 'DELETE') {
      final removed = addresses.removeAt(index);
      // Deleting the default promotes another, as the server does.
      if (removed['isDefault'] == true && addresses.isNotEmpty) {
        addresses.last['isDefault'] = true;
      }
      return http.Response('', 204);
    }

    final body = jsonDecode(request.body) as Map<String, dynamic>;

    if (body['isDefault'] == false && addresses[index]['isDefault'] == true) {
      return _json({
        'message':
            'Set another address as the default instead of clearing '
            'this one',
      }, 400);
    }

    if (body['isDefault'] == true) {
      for (final row in addresses) {
        row['isDefault'] = false;
      }
    }

    addresses[index] = {...addresses[index], ...body};
    return _json(addresses[index]);
  }

  http.Response _checkServiceability(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    serviceabilityChecks.add(body);

    final service = services
        .where((row) => row['_id'] == body['serviceId'])
        .firstOrNull;

    if (service == null) {
      return _json({'message': 'Service not found'}, 400);
    }
    if (service['isActive'] == false) {
      return _json({'serviceable': false});
    }

    final latitude = (body['latitude'] as num).toDouble();
    final longitude = (body['longitude'] as num).toDouble();
    final covered = serviceAreas.any(
      (area) =>
          _distanceKm(latitude, longitude, area.latitude, area.longitude) <=
          area.radiusKm,
    );

    return _json({'serviceable': covered});
  }

  /// Good enough for a few kilometres, which is all a test needs.
  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const kmPerDegree = 111.0;
    final dLat = (lat1 - lat2) * kmPerDegree;
    final dLon = (lon1 - lon2) * kmPerDegree * 0.95;
    return math.sqrt(dLat * dLat + dLon * dLon);
  }

  /// Wakes every scheduled booking that is due, as the cron does.
  http.Response _sweep() {
    sweepRuns++;
    var dispatched = 0;

    for (final row in bookings) {
      if (row['bookingType'] == 'scheduled' && row['status'] == 'pending') {
        row['status'] = 'searching_partner';
        dispatched++;
      }
    }

    return _json({'expired': 0, 'readvanced': 0, 'dispatched': dispatched});
  }

  // ---- notifications ---------------------------------------------------

  http.Response _listNotifications(http.Request request) {
    if (notificationsFail) {
      return _json({'message': 'Internal server error'}, 500);
    }
    // The server answers newest first.
    return _jsonList(notifications.reversed.toList());
  }

  http.Response _unreadCount() {
    if (notificationsFail) {
      return _json({'message': 'Internal server error'}, 500);
    }
    return _json({
      'unread': notifications.where((row) => row['isRead'] != true).length,
    });
  }

  http.Response _markAllRead() {
    if (notificationsFail) {
      return _json({'message': 'Internal server error'}, 500);
    }

    var updated = 0;
    for (final row in notifications) {
      if (row['isRead'] != true) {
        row['isRead'] = true;
        updated++;
      }
    }
    return _json({'updated': updated});
  }

  http.Response _markRead(String id) {
    if (notificationsFail) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final index = notifications.indexWhere((row) => row['_id'] == id);
    if (index < 0) {
      return _json({'message': 'Notification $id not found'}, 404);
    }

    notifications[index]['isRead'] = true;
    return _json(notifications[index]);
  }

  http.Response _registerDevice(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final token = body['token'] as String;

    // Upserted on the token, as the server does.
    devices[token] = (platform: body['platform'] as String, isActive: true);
    return _json({'token': token, 'platform': body['platform']});
  }

  http.Response _deactivateDevice(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final token = body['token'] as String;
    final existing = devices[token];

    if (existing != null) {
      // Retired, not deleted.
      devices[token] = (platform: existing.platform, isActive: false);
    }
    return http.Response('', 204);
  }

  // ---- bookings --------------------------------------------------------

  /// Runs the same validations, in the same order, as the real
  /// `BookingsService.createForCustomer`.
  http.Response _createBooking(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    bookingAttempts.add(body);

    if (bookingsFail) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final service = services
        .where((row) => row['_id'] == body['serviceId'])
        .firstOrNull;

    if (service == null) {
      return _json({'message': 'Service not found'}, 400);
    }
    if (service['isActive'] == false) {
      return _json({'message': 'Service is not available'}, 400);
    }

    final address = addresses
        .where((row) => row['_id'] == body['addressId'])
        .firstOrNull;

    if (address == null) {
      return _json({'message': 'Address not found'}, 400);
    }
    if (address['isActive'] == false) {
      return _json({'message': 'Address is no longer in use'}, 400);
    }

    final isScheduled = body['bookingType'] == 'scheduled';
    final rawSchedule = body['scheduledAt'];

    if (!isScheduled && rawSchedule != null) {
      return _json({
        'message': 'scheduledAt is not allowed on an instant booking',
      }, 400);
    }
    if (isScheduled) {
      if (rawSchedule == null) {
        return _json({
          'message': 'scheduledAt is required for a scheduled booking',
        }, 400);
      }

      final when = DateTime.parse(rawSchedule as String);
      final now = DateTime.now();

      if (when.isBefore(now.add(minScheduleLead))) {
        return _json({
          'message': 'scheduledAt must be at least 15 minutes from now',
        }, 400);
      }
      if (when.isAfter(now.add(maxScheduleHorizon))) {
        return _json({
          'message': 'scheduledAt cannot be more than 60 days from now',
        }, 400);
      }
    }

    // Checked against the address's own coordinates, never anything the
    // client sent.
    final covered = serviceAreas.any(
      (area) =>
          _distanceKm(
            (address['latitude'] as num).toDouble(),
            (address['longitude'] as num).toDouble(),
            area.latitude,
            area.longitude,
          ) <=
          area.radiusKm,
    );
    if (!covered) {
      return _json({
        'message': 'That location is not serviceable for this service',
      }, 400);
    }

    final active = bookings.where(
      (row) => activeStatuses.contains(row['status']),
    );

    if (!isScheduled) {
      if (active.isNotEmpty) {
        return _json({
          'message':
              'You already have a booking in progress. Finish or cancel it '
              'first.',
        }, 409);
      }
    } else {
      final when = DateTime.parse(rawSchedule! as String);
      final slot = Duration(
        minutes: (service['estimatedDurationMinutes'] as int?) ?? 60,
      );
      final clash = active.any((row) {
        final other = row['scheduledAt'];
        if (row['bookingType'] != 'scheduled' || other == null) {
          return false;
        }
        final at = DateTime.parse(other as String);
        return at.isAfter(when.subtract(slot)) && at.isBefore(when.add(slot));
      });

      if (clash) {
        return _json({
          'message': 'You already have a booking around that time',
        }, 409);
      }
    }

    final isFixed = service['pricingType'] == 'fixed';
    final booking = {
      '_id': 'booking-${_nextBookingId++}',
      'serviceId': body['serviceId'],
      'addressId': body['addressId'],
      'addressSnapshot': {
        'fullAddress': address['fullAddress'],
        'city': address['city'],
        'state': address['state'],
        'pincode': address['pincode'],
        'latitude': address['latitude'],
        'longitude': address['longitude'],
      },
      'bookingType': body['bookingType'],
      'scheduledAt': rawSchedule,
      // Instant goes straight to searching; scheduled waits for dispatch.
      'status': isScheduled ? 'pending' : 'searching_partner',
      'price': {
        'baseAmount': service['basePrice'],
        'finalAmount': isFixed ? service['basePrice'] : null,
        'currency': 'INR',
      },
      'notes': body['notes'],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    bookings.add(booking);
    return _json(booking);
  }

  http.Response _getBooking(String id) {
    if (bookingsFail) {
      return _json({'message': 'Internal server error'}, 500);
    }

    final row = bookings.where((row) => row['_id'] == id).firstOrNull;
    return row == null
        ? _json({'message': 'Booking $id not found'}, 404)
        : _json(row);
  }

  http.Response _listBookings() {
    if (bookingsFail) {
      return _json({'message': 'Internal server error'}, 500);
    }
    // The server answers newest first.
    return _jsonList(bookings.reversed.toList());
  }

  /// `PATCH /bookings/:id/cancel`, refused from a status the transition table
  /// does not allow cancelling from.
  http.Response _cancelBooking(String id) {
    final index = bookings.indexWhere((row) => row['_id'] == id);

    if (index < 0) {
      return _json({'message': 'Booking $id not found'}, 404);
    }
    if (!cancellableStatuses.contains(bookings[index]['status'])) {
      return _json({
        'message': 'Cannot cancel a booking from ${bookings[index]['status']}',
      }, 409);
    }

    bookings[index] = {
      ...bookings[index],
      'status': 'cancelled',
      'cancelledAt': DateTime.now().toUtc().toIso8601String(),
    };
    return _json(bookings[index]);
  }

  /// Derived the same way the server derives it: every status whose
  /// transitions include 'cancelled'.
  static const cancellableStatuses = [
    'pending',
    'searching_partner',
    'partner_assigned',
    'accepted',
    'on_the_way',
    'arrived',
  ];

  /// Mirrors `ACTIVE_BOOKING_STATUSES`.
  static const activeStatuses = [
    'pending',
    'searching_partner',
    'partner_assigned',
    'accepted',
    'on_the_way',
    'arrived',
    'in_progress',
  ];

  // ---- catalogue -------------------------------------------------------

  http.Response _catalogue(List<Map<String, dynamic>> rows) {
    if (catalogueFails) {
      return _json({'message': 'Internal server error'}, 500);
    }
    return _jsonList(rows);
  }

  http.Response _servicesInCategory(String categoryId) {
    if (categories.every((row) => row['_id'] != categoryId)) {
      // The real route 404s on an unknown category rather than answering with
      // an empty list.
      return _json({'message': 'Category $categoryId not found'}, 404);
    }
    return _catalogue(
      _active(services)
          .where((row) => row['categoryId'] == categoryId)
          .toList(),
    );
  }

  http.Response _service(String id) {
    final row = services.where((row) => row['_id'] == id).firstOrNull;

    return row == null
        ? _json({'message': 'Service $id not found'}, 404)
        : _json(row);
  }

  http.Response _category(String id) {
    final row = categories.where((row) => row['_id'] == id).firstOrNull;

    return row == null
        ? _json({'message': 'Category $id not found'}, 404)
        : _json(row);
  }

  /// Applies the route's optional `isActive` filter, as the server does.
  ///
  /// Customer-facing browsing asks for active rows only; the bookings list
  /// omits the filter so it can still name a service that has been taken down.
  static List<Map<String, dynamic>> _filtered(
    List<Map<String, dynamic>> rows,
    http.Request request,
  ) {
    final wanted = request.url.queryParameters['isActive'];

    if (wanted == null) {
      return rows;
    }
    final isActive = wanted == 'true';
    return rows.where((row) => (row['isActive'] != false) == isActive).toList();
  }

  /// Mirrors the server's `isActive=true` filter.
  static List<Map<String, dynamic>> _active(List<Map<String, dynamic>> rows) =>
      rows.where((row) => row['isActive'] != false).toList();

  http.Response _signIn(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    signInCalls.add(body);

    if (blocked) {
      return _json({'message': 'This account has been blocked'}, 403);
    }

    final name = body['name'] as String?;
    if (requiresProfile && name == null) {
      return _json({
        'statusCode': 404,
        'code': 'PROFILE_REQUIRED',
        'message': 'No account for this number yet.',
      }, 404);
    }

    if (name != null) {
      customerName = name;
      requiresProfile = false;
    }

    return _json({
      'accessToken': accessToken,
      'id': customerId,
      'name': customerName,
      'phone': customerPhone,
      'isNewCustomer': name != null,
    });
  }

  http.Response _profile() {
    if (profileReadFails) {
      return _json({'message': 'Internal server error'}, 500);
    }

    // Mongo's own shape: `_id`, not `id`.
    return _json({
      '_id': customerId,
      'name': customerName,
      'phone': customerPhone,
      'status': 'active',
    });
  }

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
}
