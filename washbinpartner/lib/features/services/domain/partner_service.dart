/// The join row between a partner and one service they have opted in to.
///
/// `isActive` is the whole point of keeping the row rather than deleting it:
/// a partner who stops offering a service keeps the row with the flag off, so
/// re-selecting it later restores rather than recreates. The API has no
/// partner-facing delete for this reason.
class PartnerServiceRow {
  const PartnerServiceRow({
    required this.id,
    required this.serviceId,
    required this.isActive,
  });

  factory PartnerServiceRow.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['_id'];
    final serviceId = json['serviceId'];

    return PartnerServiceRow(
      id: id is String ? id : id.toString(),
      serviceId: serviceId is String ? serviceId : serviceId.toString(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String serviceId;
  final bool isActive;
}
