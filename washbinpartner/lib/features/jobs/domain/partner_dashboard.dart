import 'package:washbinpartner/features/jobs/domain/job_offer.dart';

class PartnerDashboard {
  const PartnerDashboard({
    required this.asOf,
    required this.today,
    required this.earnings,
    required this.recentJobs,
    this.activeJob,
  });

  factory PartnerDashboard.fromJson(Map<String, dynamic> json) {
    return PartnerDashboard(
      asOf: DateTime.tryParse(json['asOf'] as String? ?? '')?.toLocal(),
      today: PartnerDashboardPeriod.fromJson(json['today']),
      earnings: PartnerDashboardEarnings.fromJson(json['earnings']),
      activeJob: json['activeJob'] == null
          ? null
          : JobBookingSummary.fromJson(json['activeJob']),
      recentJobs: (json['recentJobs'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(JobBookingSummary.fromJson)
          .toList(growable: false),
    );
  }

  final DateTime? asOf;
  final PartnerDashboardPeriod today;
  final PartnerDashboardEarnings earnings;
  final JobBookingSummary? activeJob;
  final List<JobBookingSummary> recentJobs;

  bool get hasAnyJobs =>
      today.completedJobs > 0 ||
      today.upcomingJobs > 0 ||
      today.cancelledJobs > 0 ||
      activeJob != null ||
      recentJobs.isNotEmpty;
}

class PartnerDashboardPeriod {
  const PartnerDashboardPeriod({
    required this.completedJobs,
    required this.upcomingJobs,
    required this.cancelledJobs,
    required this.earnings,
  });

  factory PartnerDashboardPeriod.fromJson(Object? value) {
    final json = value is Map<String, dynamic> ? value : const {};
    return PartnerDashboardPeriod(
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      upcomingJobs: (json['upcomingJobs'] as num?)?.toInt() ?? 0,
      cancelledJobs: (json['cancelledJobs'] as num?)?.toInt() ?? 0,
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0,
    );
  }

  final int completedJobs;
  final int upcomingJobs;
  final int cancelledJobs;
  final double earnings;
}

class PartnerDashboardEarnings {
  const PartnerDashboardEarnings({
    required this.today,
    required this.week,
    required this.month,
    required this.currency,
  });

  factory PartnerDashboardEarnings.fromJson(Object? value) {
    final json = value is Map<String, dynamic> ? value : const {};
    return PartnerDashboardEarnings(
      today: (json['today'] as num?)?.toDouble() ?? 0,
      week: (json['week'] as num?)?.toDouble() ?? 0,
      month: (json['month'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
    );
  }

  final double today;
  final double week;
  final double month;
  final String currency;

  bool get hasAny => today > 0 || week > 0 || month > 0;
}
