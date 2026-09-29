import 'package:washbinpartner/features/availability/data/partner_location_service.dart';
import 'package:washbinpartner/features/availability/domain/partner_availability.dart';

class FakePartnerLocationService extends PartnerLocationService {
  FakePartnerLocationService({
    this.latitude = 19.076,
    this.longitude = 72.8777,
  });

  double latitude;
  double longitude;
  PartnerLocationException? nextError;
  var currentPositionCalls = 0;
  var openSettingsCalls = 0;

  @override
  Future<PartnerCoordinates> currentPosition() async {
    currentPositionCalls++;
    final error = nextError;
    nextError = null;
    if (error != null) {
      throw error;
    }

    return PartnerCoordinates(latitude: latitude, longitude: longitude);
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }
}
