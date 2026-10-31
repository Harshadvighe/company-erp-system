/// Platform-conditional export for LiveCameraStreamViewport.
/// On web (dart.library.html available): uses WebRTC getUserMedia via dart:html.
/// On Android/iOS: uses mobile stub with placeholder UI.
export 'live_camera_stream_viewport_mobile.dart'
    if (dart.library.html) 'live_camera_stream_viewport_web.dart';
