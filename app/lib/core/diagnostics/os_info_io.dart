// Native variant: real OS string. dart:io is allowed here.
import 'dart:io';

/// Returns the operating system name and version.
String osString() =>
    '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
