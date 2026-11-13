import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'npd_models.dart';

class NpdRepository {
  final Dio _dio;

  NpdRepository(this._dio);

  // 1. Projects
  Future<List<NpdProject>> getProjects({String? status, int? phase, String? search}) async {
    final response = await _dio.get('/npd/projects', queryParameters: {
      if (status != null) 'status': status,
      if (phase != null) 'phase': phase,
      if (search != null && search.isNotEmpty) 'search': search,
    });

    final data = response.data;
    List list = [];
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      list = data['data'] as List? ?? [];
    } else if (data is List) {
      list = data;
    }
    return list.map((j) => NpdProject.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<NpdBoardData> createProject(Map<String, dynamic> payload) async {
    final response = await _dio.post('/npd/projects', data: payload);
    final data = response.data;
    final json = (data is Map<String, dynamic> && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return NpdBoardData.fromJson(json);
  }

  // 2. Full Board
  Future<NpdBoardData> getProjectBoard(String projectId) async {
    final response = await _dio.get('/npd/projects/$projectId/board');
    final data = response.data;
    final json = (data is Map<String, dynamic> && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return NpdBoardData.fromJson(json);
  }

  // 3. Step Sign-off
  Future<Map<String, dynamic>> signoffStep(
    String projectId,
    int stepNumber, {
    String? comments,
    String? role,
    bool bypassGate = false,
    String? firmwareHash,
  }) async {
    final response = await _dio.post(
      '/npd/projects/$projectId/steps/$stepNumber/signoff',
      data: {
        'signoffComments': comments,
        'signoffRole': role,
        'bypassGate': bypassGate,
        'firmwareHash': firmwareHash,
      },
    );
    final data = response.data;
    return (data is Map<String, dynamic> && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
  }

  // 4. SSOT Register Map
  Future<Map<String, dynamic>> getRegisterMap(String projectId) async {
    final response = await _dio.get('/npd/projects/$projectId/register-map');
    final data = response.data;
    return (data is Map<String, dynamic> && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRegisterMap(
    String projectId,
    List<Map<String, dynamic>> registers,
  ) async {
    final response = await _dio.put(
      '/npd/projects/$projectId/register-map',
      data: {'registers': registers},
    );
    final data = response.data;
    return (data is Map<String, dynamic> && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
  }

  // 5. BOM Links
  Future<List<NpdBomLink>> getBomLinks(String projectId) async {
    final response = await _dio.get('/npd/projects/$projectId/bom');
    final data = response.data;
    List list = [];
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      list = data['data'] as List? ?? [];
    } else if (data is List) {
      list = data;
    }
    return list.map((j) => NpdBomLink.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<NpdBomLink>> syncBom(
    String projectId,
    List<Map<String, dynamic>> items,
  ) async {
    final response = await _dio.post(
      '/npd/projects/$projectId/bom-sync',
      data: {'items': items},
    );
    final data = response.data;
    List list = [];
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      list = data['data'] as List? ?? [];
    } else if (data is List) {
      list = data;
    }
    return list.map((j) => NpdBomLink.fromJson(j as Map<String, dynamic>)).toList();
  }

  // 6. Artifacts
  Future<List<NpdArtifact>> getArtifacts(String projectId) async {
    final response = await _dio.get('/npd/projects/$projectId/artifacts');
    final data = response.data;
    List list = [];
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      list = data['data'] as List? ?? [];
    } else if (data is List) {
      list = data;
    }
    return list.map((j) => NpdArtifact.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<NpdArtifact> createArtifact(
    String projectId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post('/npd/projects/$projectId/artifacts', data: payload);
    final data = response.data;
    final json = (data is Map<String, dynamic> && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return NpdArtifact.fromJson(json);
  }

  // 7. Test Logs & Ingestion
  Future<List<NpdUnitTestLog>> getTestLogs(String projectId, {String? serial}) async {
    final response = await _dio.get(
      '/npd/projects/$projectId/test-logs',
      queryParameters: {if (serial != null) 'serial': serial},
    );
    final data = response.data;
    List list = [];
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      list = data['data'] as List? ?? [];
    } else if (data is List) {
      list = data;
    }
    return list.map((j) => NpdUnitTestLog.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<NpdUnitTestLog> ingestFactoryTestLog(Map<String, dynamic> payload) async {
    final response = await _dio.post('/npd/factory-test', data: payload);
    final data = response.data;
    final json = (data is Map<String, dynamic> && data.containsKey('data'))
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return NpdUnitTestLog.fromJson(json);
  }
}

// ─── Riverpod Providers ──────────────────────────────────────────────────────

final npdRepositoryProvider = Provider<NpdRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return NpdRepository(dio);
});

final npdProjectsProvider = FutureProvider.autoDispose<List<NpdProject>>((ref) async {
  final repo = ref.watch(npdRepositoryProvider);
  return repo.getProjects();
});

final selectedNpdProjectIdProvider = StateProvider<String?>((ref) => null);

final currentBoardDataProvider = FutureProvider.autoDispose<NpdBoardData?>((ref) async {
  final selectedId = ref.watch(selectedNpdProjectIdProvider);
  if (selectedId == null) {
    // If no project selected, check projects list
    final projects = await ref.watch(npdProjectsProvider.future);
    if (projects.isNotEmpty) {
      ref.read(selectedNpdProjectIdProvider.notifier).state = projects.first.id;
      final repo = ref.watch(npdRepositoryProvider);
      return repo.getProjectBoard(projects.first.id);
    }
    return null;
  }
  final repo = ref.watch(npdRepositoryProvider);
  return repo.getProjectBoard(selectedId);
});

