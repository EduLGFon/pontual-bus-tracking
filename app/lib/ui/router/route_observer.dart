// Page-level route observer of the new UI.
//
// The line screen uses it to close its viewer socket while another page
// covers it (PLAN.md 8.8.4 and 10.4.6) and to reopen it on return.
// The type parameter is PageRoute on purpose: RouteObserver only notifies
// when both the pushed and the previous route match. Modal bottom sheets
// and dialogs are PopupRoutes, so opening the share flow sheets over the
// line screen must not stop and restart the stream.
//
// The observer is attached to the root navigator. The line route is
// top-level today; if it ever moves into a shell branch, the branch
// navigator needs the same observer.
import 'package:flutter/material.dart';

/// Notifies the screen below when a full page covers it or returns.
final RouteObserver<PageRoute<dynamic>> appPageRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
