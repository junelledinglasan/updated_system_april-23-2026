// lib/utils/nav_key.dart
// Global navigator key para magamit ng mga class na wala namang direktang
// access sa BuildContext (tulad ng ApiClient) para mag-navigate — hal.
// pag kailangang balikan agad ang Login screen kapag na-expire/invalid
// na yung session, kahit saang API call ito nangyari.

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();