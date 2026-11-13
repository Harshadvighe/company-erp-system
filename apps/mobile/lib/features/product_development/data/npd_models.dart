class NpdProject {
  final String id;
  final String projectCode;
  final String projectName;
  final String? skuId;
  final String productCategory;
  final String targetMcu;
  final String? operatingVoltage;
  final String? formFactor;
  final String? complianceTargets;
  final int currentStep;
  final int currentPhase;
  final String status;
  final bool isRegisterMapFrozen;
  final DateTime? targetCompletionDate;
  final String? createdByStaffName;
  final DateTime createdAt;
  final int? signedOffCount;
  final int? progressPct;

  NpdProject({
    required this.id,
    required this.projectCode,
    required this.projectName,
    this.skuId,
    required this.productCategory,
    required this.targetMcu,
    this.operatingVoltage,
    this.formFactor,
    this.complianceTargets,
    required this.currentStep,
    required this.currentPhase,
    required this.status,
    required this.isRegisterMapFrozen,
    this.targetCompletionDate,
    this.createdByStaffName,
    required this.createdAt,
    this.signedOffCount,
    this.progressPct,
  });

  factory NpdProject.fromJson(Map<String, dynamic> json) {
    return NpdProject(
      id: json['id'] ?? '',
      projectCode: json['projectCode'] ?? '',
      projectName: json['projectName'] ?? '',
      skuId: json['skuId'],
      productCategory: json['productCategory'] ?? 'IoT & Embedded',
      targetMcu: json['targetMcu'] ?? 'ESP32-S3',
      operatingVoltage: json['operatingVoltage'],
      formFactor: json['formFactor'],
      complianceTargets: json['complianceTargets'],
      currentStep: json['currentStep'] ?? 1,
      currentPhase: json['currentPhase'] ?? 1,
      status: json['status'] ?? 'ACTIVE',
      isRegisterMapFrozen: json['isRegisterMapFrozen'] ?? false,
      targetCompletionDate: json['targetCompletionDate'] != null
          ? DateTime.tryParse(json['targetCompletionDate'])
          : null,
      createdByStaffName: json['createdByStaffName'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      signedOffCount: json['signedOffCount'],
      progressPct: json['progressPct'],
    );
  }
}

class NpdWorkflowStep {
  final String id;
  final String projectId;
  final int stepNumber;
  final String stepTitle;
  final int phaseNumber;
  final String phaseName;
  final String trackType;
  final String? hwOwner;
  final String hwDeliverable;
  final String? swOwner;
  final String swDeliverable;
  final String gateType;
  final String status; // PENDING, IN_PROGRESS, SIGNED_OFF, BLOCKED
  final String? signoffStaffName;
  final String? signoffRole;
  final String? signoffComments;
  final DateTime? signedOffAt;
  final String? blockingReasons;

  NpdWorkflowStep({
    required this.id,
    required this.projectId,
    required this.stepNumber,
    required this.stepTitle,
    required this.phaseNumber,
    required this.phaseName,
    required this.trackType,
    this.hwOwner,
    required this.hwDeliverable,
    this.swOwner,
    required this.swDeliverable,
    required this.gateType,
    required this.status,
    this.signoffStaffName,
    this.signoffRole,
    this.signoffComments,
    this.signedOffAt,
    this.blockingReasons,
  });

  factory NpdWorkflowStep.fromJson(Map<String, dynamic> json) {
    return NpdWorkflowStep(
      id: json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      stepNumber: json['stepNumber'] ?? 1,
      stepTitle: json['stepTitle'] ?? '',
      phaseNumber: json['phaseNumber'] ?? 1,
      phaseName: json['phaseName'] ?? '',
      trackType: json['trackType'] ?? 'DUAL_TRACK',
      hwOwner: json['hwOwner'],
      hwDeliverable: json['hwDeliverable'] ?? '',
      swOwner: json['swOwner'],
      swDeliverable: json['swDeliverable'] ?? '',
      gateType: json['gateType'] ?? 'STANDARD',
      status: json['status'] ?? 'PENDING',
      signoffStaffName: json['signoffStaffName'],
      signoffRole: json['signoffRole'],
      signoffComments: json['signoffComments'],
      signedOffAt: json['signedOffAt'] != null
          ? DateTime.tryParse(json['signedOffAt'])
          : null,
      blockingReasons: json['blockingReasons'],
    );
  }
}

class RegisterMapItem {
  final String pcReg;
  final String mbReg;
  final int address;
  final String name;
  final String dataType;
  final String access; // R, W, RW
  final String? defaultVal;
  final String? description;

  RegisterMapItem({
    required this.pcReg,
    required this.mbReg,
    required this.address,
    required this.name,
    required this.dataType,
    required this.access,
    this.defaultVal,
    this.description,
  });

  factory RegisterMapItem.fromJson(Map<String, dynamic> json) {
    return RegisterMapItem(
      pcReg: json['pcReg'] ?? '',
      mbReg: json['mbReg'] ?? '',
      address: json['address'] ?? 0,
      name: json['name'] ?? '',
      dataType: json['dataType'] ?? 'UINT16',
      access: json['access'] ?? 'R',
      defaultVal: json['defaultVal']?.toString(),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
        'pcReg': pcReg,
        'mbReg': mbReg,
        'address': address,
        'name': name,
        'dataType': dataType,
        'access': access,
        'defaultVal': defaultVal,
        'description': description,
      };
}

class NpdBomLink {
  final String id;
  final String projectId;
  final String designator;
  final String mpn;
  final String? manufacturer;
  final String? description;
  final String? package;
  final int quantityPerPcb;
  final String? erpItemId;
  final bool isRohsCompliant;
  final String? rohsCertificateUrl;
  final String lifecycleStatus;
  final double targetUnitCost;

  NpdBomLink({
    required this.id,
    required this.projectId,
    required this.designator,
    required this.mpn,
    this.manufacturer,
    this.description,
    this.package,
    required this.quantityPerPcb,
    this.erpItemId,
    required this.isRohsCompliant,
    this.rohsCertificateUrl,
    required this.lifecycleStatus,
    required this.targetUnitCost,
  });

  factory NpdBomLink.fromJson(Map<String, dynamic> json) {
    return NpdBomLink(
      id: json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      designator: json['designator'] ?? '',
      mpn: json['mpn'] ?? '',
      manufacturer: json['manufacturer'],
      description: json['description'],
      package: json['package'],
      quantityPerPcb: json['quantityPerPcb'] ?? 1,
      erpItemId: json['erpItemId'],
      isRohsCompliant: json['isRohsCompliant'] ?? true,
      rohsCertificateUrl: json['rohsCertificateUrl'],
      lifecycleStatus: json['lifecycleStatus'] ?? 'ACTIVE',
      targetUnitCost: (json['targetUnitCost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NpdArtifact {
  final String id;
  final String projectId;
  final int? stepNumber;
  final String artifactCategory;
  final String fileName;
  final String filePath;
  final int? fileSizeBytes;
  final String? sha256Hash;
  final String? versionTag;
  final bool isFrozen;
  final String? uploadedByName;
  final DateTime createdAt;

  NpdArtifact({
    required this.id,
    required this.projectId,
    this.stepNumber,
    required this.artifactCategory,
    required this.fileName,
    required this.filePath,
    this.fileSizeBytes,
    this.sha256Hash,
    this.versionTag,
    required this.isFrozen,
    this.uploadedByName,
    required this.createdAt,
  });

  factory NpdArtifact.fromJson(Map<String, dynamic> json) {
    return NpdArtifact(
      id: json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      stepNumber: json['stepNumber'],
      artifactCategory: json['artifactCategory'] ?? 'SCHEMATIC',
      fileName: json['fileName'] ?? '',
      filePath: json['filePath'] ?? '',
      fileSizeBytes: json['fileSizeBytes'],
      sha256Hash: json['sha256Hash'],
      versionTag: json['versionTag'],
      isFrozen: json['isFrozen'] ?? false,
      uploadedByName: json['uploadedByName'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class NpdUnitTestLog {
  final String id;
  final String projectId;
  final String serialNumber;
  final String? batchRunId;
  final int stepNumber;
  final String? firmwareVersion;
  final String? firmwareHash;
  final String? testStationId;
  final String? operatorName;
  final String testStatus; // PASS, FAIL
  final Map<String, dynamic>? voltageRailsResult;
  final double? currentConsumptionMa;
  final double? rfRssiDbm;
  final Map<String, dynamic>? peripheralsTested;
  final String? rawTerminalLog;
  final String? failureReason;
  final DateTime testedAt;

  NpdUnitTestLog({
    required this.id,
    required this.projectId,
    required this.serialNumber,
    this.batchRunId,
    required this.stepNumber,
    this.firmwareVersion,
    this.firmwareHash,
    this.testStationId,
    this.operatorName,
    required this.testStatus,
    this.voltageRailsResult,
    this.currentConsumptionMa,
    this.rfRssiDbm,
    this.peripheralsTested,
    this.rawTerminalLog,
    this.failureReason,
    required this.testedAt,
  });

  factory NpdUnitTestLog.fromJson(Map<String, dynamic> json) {
    return NpdUnitTestLog(
      id: json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      serialNumber: json['serialNumber'] ?? '',
      batchRunId: json['batchRunId'],
      stepNumber: json['stepNumber'] ?? 23,
      firmwareVersion: json['firmwareVersion'],
      firmwareHash: json['firmwareHash'],
      testStationId: json['testStationId'],
      operatorName: json['operatorName'],
      testStatus: json['testStatus'] ?? 'PASS',
      voltageRailsResult: json['voltageRailsResult'] is Map<String, dynamic>
          ? json['voltageRailsResult']
          : null,
      currentConsumptionMa:
          (json['currentConsumptionMa'] as num?)?.toDouble(),
      rfRssiDbm: (json['rfRssiDbm'] as num?)?.toDouble(),
      peripheralsTested: json['peripheralsTested'] is Map<String, dynamic>
          ? json['peripheralsTested']
          : null,
      rawTerminalLog: json['rawTerminalLog'],
      failureReason: json['failureReason'],
      testedAt: json['testedAt'] != null
          ? DateTime.tryParse(json['testedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class NpdBoardData {
  final NpdProject project;
  final int signedOffSteps;
  final int totalSteps;
  final int progressPct;
  final int totalBomCount;
  final int rohsCompliantCount;
  final int rohsCompliantPct;
  final int totalTests;
  final int passTests;
  final int failTests;
  final List<NpdWorkflowStep> steps;
  final List<NpdArtifact> artifacts;
  final List<NpdBomLink> bomLinks;
  final List<NpdUnitTestLog> recentTestLogs;

  NpdBoardData({
    required this.project,
    required this.signedOffSteps,
    required this.totalSteps,
    required this.progressPct,
    required this.totalBomCount,
    required this.rohsCompliantCount,
    required this.rohsCompliantPct,
    required this.totalTests,
    required this.passTests,
    required this.failTests,
    required this.steps,
    required this.artifacts,
    required this.bomLinks,
    required this.recentTestLogs,
  });

  factory NpdBoardData.fromJson(Map<String, dynamic> json) {
    final projJson = json['project'] ?? {};
    final summary = json['summary'] ?? {};
    final stepsList = (json['steps'] as List?)
            ?.map((s) => NpdWorkflowStep.fromJson(s))
            .toList() ??
        [];
    final artList = (json['artifacts'] as List?)
            ?.map((a) => NpdArtifact.fromJson(a))
            .toList() ??
        [];
    final bomList = (json['bomLinks'] as List?)
            ?.map((b) => NpdBomLink.fromJson(b))
            .toList() ??
        [];
    final logsList = (json['recentTestLogs'] as List?)
            ?.map((l) => NpdUnitTestLog.fromJson(l))
            .toList() ??
        [];

    return NpdBoardData(
      project: NpdProject.fromJson(projJson),
      signedOffSteps: summary['signedOffSteps'] ?? 0,
      totalSteps: summary['totalSteps'] ?? 24,
      progressPct: summary['progressPct'] ?? 0,
      totalBomCount: summary['totalBomCount'] ?? 0,
      rohsCompliantCount: summary['rohsCompliantCount'] ?? 0,
      rohsCompliantPct: summary['rohsCompliantPct'] ?? 100,
      totalTests: summary['totalTests'] ?? 0,
      passTests: summary['passTests'] ?? 0,
      failTests: summary['failTests'] ?? 0,
      steps: stepsList,
      artifacts: artList,
      bomLinks: bomList,
      recentTestLogs: logsList,
    );
  }
}

