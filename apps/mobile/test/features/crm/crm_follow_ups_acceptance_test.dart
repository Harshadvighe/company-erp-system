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
  group('CRM Unified Follow-ups Phase 4 Acceptance Tests', () {
    late Dio dio;
    late MockHttpClientAdapter adapter;
    late CrmRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://saark-erp-test.com/api/v1'));
      adapter = MockHttpClientAdapter();
      dio.httpClientAdapter = adapter;
      repo = CrmRepository(dio);
    });

    // ─── SECTION A: AUTHENTICATION & PERMISSIONS ─────────────────────────────
    group('Section A: Authentication & Permissions', () {
      test('Handles 401 Unauthorized safely when session expires', () async {
        adapter.handler = (options) {
          return ResponseBody.fromString(
            '{"statusCode": 401, "message": "Unauthorized"}',
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        };

        expect(
          () => repo.getFollowUps(),
          throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          )),
        );
      });

      test('Handles 403 Forbidden safely when unauthorized user accesses restricted action', () async {
        adapter.handler = (options) {
          return ResponseBody.fromString(
            '{"statusCode": 403, "message": "Forbidden resource"}',
            403,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        };

        expect(
          () => repo.resolveFollowUp('fu-restricted-99', {
            'outcome': 'CONNECTED',
            'idempotencyKey': 'idemp-test-403',
          }),
          throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            403,
          )),
        );
      });
    });

    // ─── SECTION B: FOLLOW-UP CREATION AND LISTING ───────────────────────────
    group('Section B: Follow-up Creation & Listing', () {
      test('createFollowUp sends correct required fields and reminder config', () async {
        RequestOptions? capturedOptions;

        adapter.handler = (options) {
          capturedOptions = options;
          return ResponseBody.fromString(
            '{"statusCode": 201, "data": {"id": "fu-created-1", "status": "PENDING", "reminderMinutes": 15}}',
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        };

        final payload = {
          'customerId': 'cust-ph4-001',
          'activityType': 'CALL',
          'title': 'Phase 4 Introductory Technical Call',
          'assignedStaffId': 'staff-sales-1',
          'scheduledDate': '2026-10-16T11:00:00.000Z',
          'reminderMinutes': 15,
          'priority': 'HIGH',
        };

        final response = await repo.createFollowUp(payload);

        expect(capturedOptions, isNotNull);
        expect(capturedOptions!.method, 'POST');
        expect(capturedOptions!.path, '/crm/follow-ups');
        expect(capturedOptions!.data['customerId'], 'cust-ph4-001');
        expect(capturedOptions!.data['activityType'], 'CALL');
        expect(capturedOptions!.data['reminderMinutes'], 15);
        expect(response['data']['id'], 'fu-created-1');
      });

      test('FollowUpListNotifier loads follow-ups with filter queries (My Day, Overdue, Upcoming, Completed)', () async {
        final notifier = FollowUpListNotifier(repo);

        // 1. Initial State
        expect(notifier.state.followUps, isEmpty);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, isNull);

        // 2. Load My Day (due: 'today')
        adapter.handler = (options) {
          expect(options.queryParameters['due'], 'today');
          return ResponseBody.fromString(
            '{"data": [{"id": "fu-today-1", "title": "Today Call", "status": "PENDING"}]}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        await notifier.loadFollowUps(due: 'today');
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.followUps.length, 1);
        expect(notifier.state.followUps.first['title'], 'Today Call');

        // 3. Load Overdue (due: 'overdue')
        adapter.handler = (options) {
          expect(options.queryParameters['due'], 'overdue');
          return ResponseBody.fromString(
            '{"data": [{"id": "fu-overdue-1", "title": "Overdue Call", "status": "OVERDUE"}]}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        await notifier.loadFollowUps(due: 'overdue');
        expect(notifier.state.followUps.length, 1);
        expect(notifier.state.followUps.first['title'], 'Overdue Call');

        // 4. Load Completed (status: 'COMPLETED')
        adapter.handler = (options) {
          expect(options.queryParameters['status'], 'COMPLETED');
          return ResponseBody.fromString(
            '{"data": [{"id": "fu-comp-1", "title": "Completed Call", "status": "COMPLETED"}]}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        await notifier.loadFollowUps(status: 'COMPLETED');
        expect(notifier.state.followUps.length, 1);
        expect(notifier.state.followUps.first['status'], 'COMPLETED');

        // 5. Error handling state
        adapter.handler = (options) {
          return ResponseBody.fromString(
            '{"message": "Database network timeout"}',
            500,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        await notifier.loadFollowUps(due: 'today');
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, isNotNull);
      });

      test('getFollowUpCompanies supports search, status, and pagination', () async {
        RequestOptions? capturedOptions;

        adapter.handler = (options) {
          capturedOptions = options;
          return ResponseBody.fromString(
            '''{
              "data": {
                "data": [
                  {
                    "id": "comp-1",
                    "companyName": "Apex Pumps Ltd",
                    "pendingFollowUps": 2,
                    "overdueFollowUps": 1
                  }
                ],
                "meta": {
                  "total": 1,
                  "page": 1,
                  "totalPages": 1
                }
              }
            }''',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        final result = await repo.getFollowUpCompanies(
          search: 'Apex',
          status: 'TODAY',
          page: 1,
          limit: 20,
        );

        expect(capturedOptions, isNotNull);
        expect(capturedOptions!.path, '/crm/follow-ups/companies');
        expect(capturedOptions!.queryParameters['search'], 'Apex');
        expect(capturedOptions!.queryParameters['status'], 'TODAY');
        expect(capturedOptions!.queryParameters['page'], 1);
        expect(result['data'], isNotEmpty);
        expect(result['meta']['total'], 1);
      });
    });

    // ─── SECTION C: ATOMIC RESOLUTION AND CALLBACK ───────────────────────────
    group('Section C: Atomic Resolution & Callback', () {
      test('Resolve with CONNECTED records activity outcome and marks completed', () async {
        RequestOptions? capturedOptions;

        adapter.handler = (options) {
          capturedOptions = options;
          return ResponseBody.fromString(
            '''{
              "data": {
                "id": "fu-101",
                "status": "COMPLETED",
                "activity": {
                  "id": "act-101",
                  "activityType": "CALL",
                  "outcome": "CONNECTED"
                }
              }
            }''',
            201,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        final payload = {
          'activityType': 'CALL',
          'outcome': 'CONNECTED',
          'callOutcome': 'CONNECTED',
          'subject': 'Discussed VFD panel quotation',
          'discussion': 'Customer confirmed delivery dates',
          'scheduleNext': false,
          'idempotencyKey': 'idemp-resolve-connected-101',
        };

        final res = await repo.resolveFollowUp('fu-101', payload);

        expect(capturedOptions, isNotNull);
        expect(capturedOptions!.method, 'POST');
        expect(capturedOptions!.path, '/crm/follow-ups/fu-101/resolve');
        expect(capturedOptions!.data['outcome'], 'CONNECTED');
        expect(capturedOptions!.data['scheduleNext'], isFalse);
        expect(res['status'], 'COMPLETED');
      });

      test('Resolve with NO_ANSWER triggers callback suggestion and next follow-up', () async {
        adapter.handler = (options) {
          return ResponseBody.fromString(
            '''{
              "data": {
                "id": "fu-102",
                "status": "COMPLETED",
                "activity": {
                  "id": "act-102",
                  "outcome": "NO_ANSWER"
                },
                "nextFollowUp": {
                  "id": "fu-103",
                  "status": "PENDING",
                  "scheduledDate": "2026-10-16T05:30:00.000Z",
                  "title": "Follow-up #2: Client Consultation"
                }
              }
            }''',
            201,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        final payload = {
          'activityType': 'CALL',
          'outcome': 'NO_ANSWER',
          'callOutcome': 'NO_ANSWER',
          'scheduleNext': true,
          'nextActivityType': 'CALL',
          'nextScheduledDate': '2026-10-16T05:30:00.000Z',
          'idempotencyKey': 'idemp-resolve-no-answer-102',
        };

        final res = await repo.resolveFollowUp('fu-102', payload);

        expect(res['status'], 'COMPLETED');
        expect(res['nextFollowUp'], isNotNull);
        expect(res['nextFollowUp']['status'], 'PENDING');
        expect(res['nextFollowUp']['scheduledDate'], '2026-10-16T05:30:00.000Z');
      });

      test('Resolve with explicit opt-out (scheduleNext: false) does not create next follow-up', () async {
        adapter.handler = (options) {
          return ResponseBody.fromString(
            '''{
              "data": {
                "id": "fu-104",
                "status": "COMPLETED",
                "nextFollowUp": null
              }
            }''',
            201,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        final payload = {
          'activityType': 'CALL',
          'outcome': 'NO_ANSWER',
          'scheduleNext': false,
          'idempotencyKey': 'idemp-resolve-optout-104',
        };

        final res = await repo.resolveFollowUp('fu-104', payload);
        expect(res['status'], 'COMPLETED');
        expect(res['nextFollowUp'], isNull);
      });
    });

    // ─── SECTION D & E: ATTACHMENTS & TIMELINE ───────────────────────────────
    group('Section E & F: Attachments & Customer Timeline', () {
      test('uploadCrmAttachments validates files and posts multipart form', () async {
        RequestOptions? capturedOptions;

        adapter.handler = (options) {
          capturedOptions = options;
          return ResponseBody.fromString(
            '''{
              "data": [
                {
                  "id": "att-photo-1",
                  "fileName": "panel_wiring.jpg",
                  "mediaClass": "IMAGE",
                  "mimeType": "image/jpeg"
                },
                {
                  "id": "att-doc-1",
                  "fileName": "specification.pdf",
                  "mediaClass": "DOCUMENT",
                  "mimeType": "application/pdf"
                }
              ]
            }''',
            201,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        final uploaded = await repo.uploadCrmAttachments(
          files: [
            (fileName: 'panel_wiring.jpg', bytes: [255, 216, 255, 224]),
            (fileName: 'specification.pdf', bytes: [37, 80, 68, 70]),
          ],
          customerId: 'cust-ph4-001',
          sourceCategory: 'FOLLOW_UP_RESOLUTION',
        );

        expect(capturedOptions, isNotNull);
        expect(capturedOptions!.path, '/crm/attachments/upload');
        expect(uploaded.length, 2);
        expect(uploaded[0]['mediaClass'], 'IMAGE');
        expect(uploaded[1]['mediaClass'], 'DOCUMENT');
      });

      test('getCompanyTimeline returns chronological timeline events with streaming URLs', () async {
        adapter.handler = (options) {
          return ResponseBody.fromString(
            '''{
              "data": [
                {
                  "id": "evt-2",
                  "type": "CALL",
                  "title": "Call: Customer connected",
                  "timestamp": "2026-10-15T12:00:00.000Z",
                  "attachments": [
                    {
                      "id": "att-1",
                      "fileName": "call_record.webm",
                      "mediaClass": "AUDIO",
                      "streamUrl": "/api/v1/crm/attachments/att-1/stream"
                    }
                  ]
                },
                {
                  "id": "evt-1",
                  "type": "FOLLOW_UP",
                  "title": "Initial Lead Follow-up",
                  "timestamp": "2026-10-14T09:00:00.000Z",
                  "attachments": []
                }
              ]
            }''',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        };

        final timeline = await repo.getCompanyTimeline('cust-ph4-001');

        expect(timeline.length, 2);
        expect(timeline[0]['id'], 'evt-2');
        expect(timeline[0]['attachments'].length, 1);
        expect(timeline[0]['attachments'][0]['streamUrl'], contains('/api/v1/crm/attachments/'));
        expect(timeline[1]['id'], 'evt-1');
      });
    });
  });
}
