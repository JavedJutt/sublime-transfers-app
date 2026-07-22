import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Curated icon aliases.
///
/// Feature code references `AppIcons.x` rather than reaching into Phosphor
/// directly, so the icon set stays consistent and a swap is a single-file
/// change. Regular weight is the default; [fill] variants are used only for
/// selected navigation items and map markers.
abstract final class AppIcons {
  // ------------------------------------------------------------- navigation
  static const IconData dashboard = PhosphorIconsRegular.squaresFour;
  static const IconData dashboardActive = PhosphorIconsFill.squaresFour;
  static const IconData calendar = PhosphorIconsRegular.calendarBlank;
  static const IconData calendarActive = PhosphorIconsFill.calendarBlank;
  static const IconData rides = PhosphorIconsRegular.rows;
  static const IconData ridesActive = PhosphorIconsFill.rows;
  static const IconData drivers = PhosphorIconsRegular.users;
  static const IconData driversActive = PhosphorIconsFill.users;
  static const IconData liveMap = PhosphorIconsRegular.mapTrifold;
  static const IconData liveMapActive = PhosphorIconsFill.mapTrifold;
  static const IconData reviewQueue = PhosphorIconsRegular.clipboardText;
  static const IconData reviewQueueActive = PhosphorIconsFill.clipboardText;
  static const IconData settings = PhosphorIconsRegular.gearSix;
  static const IconData settingsActive = PhosphorIconsFill.gearSix;
  static const IconData home = PhosphorIconsRegular.house;
  static const IconData homeActive = PhosphorIconsFill.house;
  static const IconData offers = PhosphorIconsRegular.broadcast;
  static const IconData offersActive = PhosphorIconsFill.broadcast;
  static const IconData history = PhosphorIconsRegular.clockCountdown;
  static const IconData profile = PhosphorIconsRegular.userCircle;
  static const IconData profileActive = PhosphorIconsFill.userCircle;

  // ------------------------------------------------------------------ rides
  static const IconData ride = PhosphorIconsRegular.car;
  static const IconData pickup = PhosphorIconsRegular.mapPin;
  static const IconData dropoff = PhosphorIconsFill.mapPin;
  static const IconData passengers = PhosphorIconsRegular.users;
  static const IconData luggage = PhosphorIconsRegular.suitcaseSimple;
  static const IconData fare = PhosphorIconsRegular.currencyGbp;
  static const IconData flight = PhosphorIconsRegular.airplaneTilt;
  static const IconData notes = PhosphorIconsRegular.note;
  static const IconData vehicle = PhosphorIconsRegular.car;
  static const IconData customer = PhosphorIconsRegular.user;
  static const IconData phone = PhosphorIconsRegular.phone;
  static const IconData time = PhosphorIconsRegular.clock;
  static const IconData navigate = PhosphorIconsRegular.navigationArrow;

  // ------------------------------------------------------------- assignment
  static const IconData assignDirect = PhosphorIconsRegular.paperPlaneTilt;
  static const IconData broadcast = PhosphorIconsRegular.broadcast;
  static const IconData manual = PhosphorIconsRegular.pencilSimple;
  static const IconData reassign = PhosphorIconsRegular.arrowsClockwise;

  // ------------------------------------------------------------------ gmail
  static const IconData mailbox = PhosphorIconsRegular.envelopeSimple;
  static const IconData syncOk = PhosphorIconsRegular.checkCircle;
  static const IconData syncFailed = PhosphorIconsRegular.warningCircle;

  // ---------------------------------------------------------------- actions
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData edit = PhosphorIconsRegular.pencilSimple;
  static const IconData delete = PhosphorIconsRegular.trashSimple;
  static const IconData filter = PhosphorIconsRegular.funnel;
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData more = PhosphorIconsRegular.dotsThree;
  static const IconData refresh = PhosphorIconsRegular.arrowsClockwise;
  static const IconData signOut = PhosphorIconsRegular.signOut;
  static const IconData approve = PhosphorIconsRegular.shieldCheck;
  static const IconData addDriver = PhosphorIconsRegular.userPlus;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData check = PhosphorIconsRegular.check;

  // ---------------------------------------------------------------- feedback
  static const IconData success = PhosphorIconsRegular.checkCircle;
  static const IconData warning = PhosphorIconsRegular.warningCircle;
  static const IconData error = PhosphorIconsRegular.xCircle;
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData offline = PhosphorIconsRegular.wifiSlash;
  static const IconData empty = PhosphorIconsRegular.tray;
  static const IconData notification = PhosphorIconsRegular.bell;
  static const IconData notificationUnread = PhosphorIconsFill.bellRinging;
  static const IconData location = PhosphorIconsRegular.mapPin;
  static const IconData locationOff = PhosphorIconsRegular.mapPinSimpleArea;

  // ------------------------------------------------------------- directional
  static const IconData chevronLeft = PhosphorIconsRegular.caretLeft;
  static const IconData chevronRight = PhosphorIconsRegular.caretRight;
  static const IconData chevronDown = PhosphorIconsRegular.caretDown;
  static const IconData chevronUp = PhosphorIconsRegular.caretUp;
  static const IconData arrowRight = PhosphorIconsRegular.arrowRight;
  static const IconData arrowLeft = PhosphorIconsRegular.arrowLeft;
  static const IconData menu = PhosphorIconsRegular.list;
}
