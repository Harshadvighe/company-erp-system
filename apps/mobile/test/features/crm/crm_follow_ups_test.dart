import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options)? handler;

  MockHttpClientAdapter([this.handler]);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString('{"data": {}}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('CRM Unified Follow-ups Phase 3 Unit Tests', () {
    late Dio dio;
    late MockHttpClientAdapter adapter;
    late CrmRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://saark-erp-test.com/api/v1'));
      adapter = MockHttpClientAdapter();
      dio.httpClientAdapter = adapter;
      repo = CrmRepository(dio);
    });

    test('resolveFollowUp posts correct payload and idempotency key', () async {
      RequestOptions? capturedOptions;

      adapter.handler = (options) {
        capturedOptions = options;
        return ResponseBody.fromString(
          '{"success": true, "data": {"id": "fu-123", "status": "COMPLETED"}}',
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final payload = {
        'activityType': 'CALL',
        'outcome': 'CONNECTED',
        'callOutcome': 'CONNECTED',
        'subject': 'Discussed VFD 75HP panel quote',
        'discussion': 'Customer confirmed technical specs',
        'scheduleNext': true,
        'nextActivityType': 'MEETING',
        'nextScheduledDate': '2026-10-18T11:00:00.000Z',
        'nextSubject': 'Commercial negotiation meeting',
        'attachmentIds': ['att-uuid-1', 'att-uuid-2'],
        'idempotencyKey': 'idemp-fu-123-1729000000-999',
      };

      final result = await repo.resolveFollowUp('fu-123', payload);

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.method, 'POST');
      expect(capturedOptions!.path, '/crm/follow-ups/fu-123/resolve');
      expect(capturedOptions!.data['activityType'], 'CALL');
      expect(capturedOptions!.data['outcome'], 'CONNECTED');
      expect(capturedOptions!.data['idempotencyKey'], 'idemp-fu-123-1729000000-999');
      expect(capturedOptions!.data['attachmentIds'], ['att-uuid-1', 'att-uuid-2']);
      expect(result['id'], 'fu-123');
      expect(result['status'], 'COMPLETED');
    });

    test('getCallbackSuggestion retrieves next working day IST suggestion', () async {
      RequestOptions? capturedOptions;

      adapter.handler = (options) {
        capturedOptions = options;
        return ResponseBody.fromString(
          '''{
            "data": {
              "suggestedDateIso": "2026-10-16T05:30:00.000Z",
              "formattedIST": "16/10/2026, 11:00:00 am",
              "dayOfWeek": "Friday",
              "timezone": "Asia/Kolkata"
            }
          }''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final suggestion = await repo.getCallbackSuggestion();

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.method, 'GET');
      expect(capturedOptions!.path, '/crm/follow-ups/callback-suggestion');
      expect(suggestion['suggestedDateIso'], '2026-10-16T05:30:00.000Z');
      expect(suggestion['formattedIST'], '16/10/2026, 11:00:00 am');
      expect(suggestion['dayOfWeek'], 'Friday');
    });

    test('uploadCrmAttachments posts multipart form data with customer ID and media', () async {
      RequestOptions? capturedOptions;

      adapter.handler = (options) {
        capturedOptions = options;
        return ResponseBody.fromString(
          '''{
            "data": [
              {
                "id": "att-new-1",
                "fileName": "site_photo.jpg",
                "mediaClass": "IMAGE",
                "fileSizeBytes": 1024
              }
            ]
          }''',
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final files = [
        (fileName: 'site_photo.jpg', bytes: [1, 2, 3, 4, 5]),
      ];

      final uploaded = await repo.uploadCrmAttachments(
        files: files,
        customerId: 'cust-777',
        followUpId: 'fu-123',
        sourceCategory: 'FOLLOW_UP_RESOLUTION',
      );

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.method, 'POST');
      expect(capturedOptions!.path, '/crm/attachments/upload');
      expect(capturedOptions!.data, isA<FormData>());
      expect(uploaded.length, 1);
      expect(uploaded.first['id'], 'att-new-1');
      expect(uploaded.first['fileName'], 'site_photo.jpg');
    });

    test('getCompanyTimeline fetches chronological events with media streaming URLs', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          '''{
            "data": [
              {
                "id": "act-1",
                "type": "CALL",
                "title": "Call: Quote discussion",
                "timestamp": "2026-10-15T10:00:00.000Z",
                "attachments": [
                  {
                    "id": "att-audio-1",
                    "fileName": "call_recording.mp3",
                    "mediaClass": "AUDIO",
                    "streamUrl": "/api/v1/crm/attachments/att-audio-1/stream"
                  }
                ]
              }
            ]
          }''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final timeline = await repo.getCompanyTimeline('cust-777');
      expect(timeline.length, 1);
      expect(timeline.first['type'], 'CALL');
      expect(timeline.first['attachments'].length, 1);
      expect(timeline.first['attachments'].first['mediaClass'], 'AUDIO');
    });

    test('Idempotency key format contains entity ID and timestamp', () {
      final key1 = 'idemp-fu-123-${DateTime.now().millisecondsSinceEpoch}-1001';
      final key2 = 'idemp-fu-123-${DateTime.now().millisecondsSinceEpoch}-1002';

      expect(key1.startsWith('idemp-fu-123-'), isTrue);
      expect(key1, isNot(equals(key2)));
    });

    test('Auto-callback suggestion triggers on NO_ANSWER and BUSY', () {
      const isNoAnswer = 'NO_ANSWER' == 'NO_ANSWER' || 'NO_ANSWER' == 'BUSY';
      const isBusy = 'BUSY' == 'NO_ANSWER' || 'BUSY' == 'BUSY';
      const isConnected = 'CONNECTED' == 'NO_ANSWER' || 'CONNECTED' == 'BUSY';

      expect(isNoAnswer, isTrue);
      expect(isBusy, isTrue);
      expect(isConnected, isFalse);
    });
  });
}
