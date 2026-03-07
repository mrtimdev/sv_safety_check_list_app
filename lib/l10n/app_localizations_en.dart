// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Safety Check Lists';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get home => 'Home';

  @override
  String get welcome => 'Welcome';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get khmer => 'Khmer';

  @override
  String get checkIn => 'Check In';

  @override
  String get checkOut => 'Check Out';

  @override
  String get cancel => 'Cancel';

  @override
  String get submit => 'Submit';

  @override
  String get save => 'Save';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get createdAt => 'Created At';

  @override
  String get cancelledAt => 'Cancelled At';

  @override
  String get noData => 'No Data Available';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Something went wrong';

  @override
  String get todayIsDayOff => 'Today is day-off. Please check your roster or contact HR.';

  @override
  String get checkOtRequest => 'Please check your OT request and try again.';

  @override
  String get about => 'About';

  @override
  String get appName => 'Safety Checklists';

  @override
  String version(Object version) {
    return 'Version $version';
  }

  @override
  String get appDescription => 'A comprehensive vehicle inspection system for safety compliance and monitoring.';

  @override
  String get close => 'Close';

  @override
  String get safetyChecklists => 'Safety Checklists';

  @override
  String get totalChecks => 'Total Checks';

  @override
  String get thisWeek => 'This Week';

  @override
  String get avgPassRate => 'Avg Pass Rate';

  @override
  String get allTime => 'All Time';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get last7Days => 'Last 7 Days';

  @override
  String get last30Days => 'Last 30 Days';

  @override
  String get filterChecklists => 'Filter Checklists';

  @override
  String get selectTimePeriod => 'Select a time period to filter your inspections';

  @override
  String get dashboardOverview => 'Dashboard Overview';

  @override
  String get confirmExit => 'Are you sure you want to exit the system?';

  @override
  String get no => 'No';

  @override
  String get okay => 'Okay';

  @override
  String get editSafetyCheck => 'Edit Safety Check';

  @override
  String get newSafetyCheck => 'New Safety Check';

  @override
  String get safetyChecklistDetails => 'Safety Checklist Details';

  @override
  String get scanPlateNumber => 'Scan Vehicle Plate Number';

  @override
  String get update => 'Update';

  @override
  String get onlyCreatorCanEditChecklist => 'Only the creator of this checklist can edit it.';

  @override
  String get checklistCancelled => 'This checklist has been cancelled and cannot be edited.';

  @override
  String get checklistUpdated => 'Checklist updated successfully.';

  @override
  String get checklistCancelledMessage => 'Checklist cancelled successfully.';

  @override
  String get confirmCancelChecklist => 'Are you sure you want to cancel this checklist?';
}
