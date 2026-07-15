import 'package:flutter_test/flutter_test.dart';
import 'package:moongate/services/printer_status_service.dart';

void main() {
  group('PrinterStatusService.go2rtcFrameUrl', () {
    test('rewrites a go2rtc player page to the frame endpoint', () {
      expect(
        PrinterStatusService.go2rtcFrameUrl(
            'https://cameratrident.domain.xyz/stream.html?src=chamber&mode=webrtc'),
        'https://cameratrident.domain.xyz/api/frame.jpeg?src=chamber',
      );
    });

    test('survives a reverse-proxy subpath', () {
      expect(
        PrinterStatusService.go2rtcFrameUrl(
            'http://192.168.1.50/go2rtc/stream.html?src=cam1'),
        'http://192.168.1.50/go2rtc/api/frame.jpeg?src=cam1',
      );
    });

    test('keeps an explicit port', () {
      expect(
        PrinterStatusService.go2rtcFrameUrl(
            'http://192.168.1.50:1984/stream.html?src=cam1&mode=mse'),
        'http://192.168.1.50:1984/api/frame.jpeg?src=cam1',
      );
    });

    test('is case-insensitive on the page name', () {
      expect(
        PrinterStatusService.go2rtcFrameUrl(
            'http://cam.local:1984/Stream.HTML?src=x'),
        'http://cam.local:1984/api/frame.jpeg?src=x',
      );
    });

    test('leaves non-go2rtc URLs alone', () {
      expect(
        PrinterStatusService.go2rtcFrameUrl(
            'http://192.168.0.107:8080/video'),
        isNull,
      );
      expect(
        PrinterStatusService.go2rtcFrameUrl(
            'http://192.168.1.20/webcam/?action=stream'),
        isNull,
      );
    });

    test('requires a src parameter', () {
      expect(
        PrinterStatusService.go2rtcFrameUrl(
            'http://cam.local:1984/stream.html'),
        isNull,
      );
      expect(
        PrinterStatusService.go2rtcFrameUrl(
            'http://cam.local:1984/stream.html?src='),
        isNull,
      );
    });

    test('rejects garbage and relative input', () {
      expect(PrinterStatusService.go2rtcFrameUrl('stream.html?src=x'), isNull);
      expect(PrinterStatusService.go2rtcFrameUrl(''), isNull);
    });
  });
}
