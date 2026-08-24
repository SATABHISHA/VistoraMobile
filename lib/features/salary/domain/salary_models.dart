import 'package:vistora_mobile/core/api/api_parsing.dart';

class SalaryRosterPage {
  const SalaryRosterPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
    required this.year,
  });

  final List<SalaryRosterEmployee> items;
  final int page;
  final int lastPage;
  final int total;
  final int year;

  bool get hasMore => page < lastPage;
}

class SalaryRosterEmployee {
  const SalaryRosterEmployee({
    required this.employeeId,
    required this.code,
    required this.name,
    required this.status,
    this.email,
    this.mobile,
    this.salary,
  });

  final int employeeId;
  final String code;
  final String name;
  final String status;
  final String? email;
  final String? mobile;
  final SalaryStructureRecord? salary;

  factory SalaryRosterEmployee.fromJson(Map<String, dynamic> json) =>
      SalaryRosterEmployee(
        employeeId: asInt(json['employee_id']),
        code: json['emp_code']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Employee',
        status: json['status']?.toString() ?? 'active',
        email: asNullableString(json['email']),
        mobile: asNullableString(json['mobile']),
        salary: json['salary'] is Map
            ? SalaryStructureRecord.fromJson(asMap(json['salary']))
            : null,
      );
}

class SalaryEmployeeDetail {
  const SalaryEmployeeDetail({
    required this.employeeId,
    required this.code,
    required this.name,
    required this.structures,
    required this.revisions,
  });

  final int employeeId;
  final String code;
  final String name;
  final List<SalaryStructureRecord> structures;
  final List<SalaryRevisionRecord> revisions;

  factory SalaryEmployeeDetail.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final name =
        [employee['first_name'], employee['middle_name'], employee['last_name']]
            .where(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )
            .join(' ');
    return SalaryEmployeeDetail(
      employeeId: asInt(employee['id']),
      code: employee['emp_code']?.toString() ?? '',
      name: name.isEmpty ? 'Employee' : name,
      structures: asList(
        json['structures'],
      ).map((value) => SalaryStructureRecord.fromJson(asMap(value))).toList(),
      revisions: asList(
        json['revisions'],
      ).map((value) => SalaryRevisionRecord.fromJson(asMap(value))).toList(),
    );
  }

  SalaryStructureRecord? forYear(int year) {
    for (final structure in structures) {
      if (structure.year == year) return structure;
    }
    return null;
  }
}

class SalaryStructureRecord {
  const SalaryStructureRecord({
    required this.id,
    required this.year,
    required this.payGroupName,
    required this.ctcAnnual,
    required this.grossMonthly,
    required this.deductionMonthly,
    required this.netMonthly,
    required this.snapshot,
  });

  final int id;
  final int year;
  final String payGroupName;
  final double ctcAnnual;
  final double grossMonthly;
  final double deductionMonthly;
  final double netMonthly;
  final Map<String, dynamic> snapshot;

  factory SalaryStructureRecord.fromJson(Map<String, dynamic> json) =>
      SalaryStructureRecord(
        id: asInt(json['id']),
        year: asInt(json['year']),
        payGroupName: json['pay_group_name']?.toString() ?? 'Salary structure',
        ctcAnnual: asDouble(json['ctc_annual']),
        grossMonthly: asDouble(json['gross_monthly']),
        deductionMonthly: asDouble(json['deduction_monthly']),
        netMonthly: asDouble(json['net_monthly']),
        snapshot: asMap(json['pay_group_snapshot_json']),
      );
}

class SalaryRevisionRecord {
  const SalaryRevisionRecord({
    required this.id,
    required this.year,
    required this.revisionDate,
    required this.incrementAmount,
    required this.actionStatus,
    required this.oldNetMonthly,
    required this.newNetMonthly,
    required this.arrearsDue,
    required this.arrearsStatus,
    this.arrearEffectiveDate,
  });

  final int id;
  final int year;
  final DateTime revisionDate;
  final DateTime? arrearEffectiveDate;
  final double incrementAmount;
  final String actionStatus;
  final double oldNetMonthly;
  final double newNetMonthly;
  final double arrearsDue;
  final String arrearsStatus;

  bool get canRollback =>
      actionStatus == 'applied' && arrearsStatus != 'disbursed';

  factory SalaryRevisionRecord.fromJson(Map<String, dynamic> json) =>
      SalaryRevisionRecord(
        id: asInt(json['id']),
        year: asInt(json['year']),
        revisionDate: asDateTime(json['revision_date']) ?? DateTime.now(),
        arrearEffectiveDate: asDateTime(json['arrear_effective_date']),
        incrementAmount: asDouble(json['increment_amount']),
        actionStatus: json['action_status']?.toString() ?? 'applied',
        oldNetMonthly: asDouble(json['old_net_monthly']),
        newNetMonthly: asDouble(json['new_net_monthly']),
        arrearsDue: asDouble(json['arrears_due']),
        arrearsStatus: json['arrears_status']?.toString() ?? 'none',
      );
}

class SalaryPayComponent {
  const SalaryPayComponent({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.taxable,
    required this.description,
  });

  final int id;
  final String name;
  final String code;
  final String type;
  final String taxable;
  final String description;

  bool get isDeduction => type.toLowerCase() == 'deduction';
  bool get isReimbursement => type.toLowerCase() == 'reimbursement';

  SalaryPayComponent copyWith({
    int? id,
    String? name,
    String? code,
    String? type,
    String? taxable,
    String? description,
  }) => SalaryPayComponent(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    type: type ?? this.type,
    taxable: taxable ?? this.taxable,
    description: description ?? this.description,
  );

  factory SalaryPayComponent.fromJson(Map<String, dynamic> json) =>
      SalaryPayComponent(
        id: asInt(json['id']),
        name: json['name']?.toString() ?? 'Pay component',
        code: json['code']?.toString() ?? '',
        type: json['type']?.toString() ?? 'Earning',
        taxable: json['taxable']?.toString() ?? '0',
        description: (json['description'] ?? json['desc'])?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'type': type,
    'taxable': taxable,
    'desc': description,
  };
}

class SalaryPayGroup {
  const SalaryPayGroup({
    required this.id,
    required this.name,
    required this.componentIds,
  });

  final int id;
  final String name;
  final List<int> componentIds;

  SalaryPayGroup copyWith({int? id, String? name, List<int>? componentIds}) =>
      SalaryPayGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        componentIds: componentIds ?? this.componentIds,
      );

  factory SalaryPayGroup.fromJson(Map<String, dynamic> json) => SalaryPayGroup(
    id: asInt(json['id']),
    name: json['name']?.toString() ?? 'Pay group',
    componentIds: asList(
      json['component_ids'] ?? json['comps'],
    ).map(asInt).where((id) => id > 0).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'comps': componentIds,
  };
}

class SalaryFormula {
  const SalaryFormula({
    required this.id,
    required this.componentId,
    required this.type,
    required this.value,
    this.referenceComponentId,
  });

  final int id;
  final int componentId;
  final String type;
  final double value;
  final int? referenceComponentId;

  SalaryFormula copyWith({
    int? id,
    int? componentId,
    String? type,
    double? value,
    int? referenceComponentId,
    bool clearReference = false,
  }) => SalaryFormula(
    id: id ?? this.id,
    componentId: componentId ?? this.componentId,
    type: type ?? this.type,
    value: value ?? this.value,
    referenceComponentId: clearReference
        ? null
        : referenceComponentId ?? this.referenceComponentId,
  );

  factory SalaryFormula.fromJson(Map<String, dynamic> json) => SalaryFormula(
    id: asInt(json['id']),
    componentId: asInt(json['component_id'] ?? json['compId']),
    type: json['type']?.toString() ?? 'fixed',
    value: asDouble(json['value']),
    referenceComponentId:
        asInt(json['reference_component_id'] ?? json['refId']) > 0
        ? asInt(json['reference_component_id'] ?? json['refId'])
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'compId': componentId,
    'type': type,
    'value': value,
    'refId': referenceComponentId,
  };
}

class SalaryBreakupLine {
  const SalaryBreakupLine({required this.component, required this.monthly});

  final SalaryPayComponent component;
  final double monthly;
  double get annual => monthly * 12;
}

class SalaryBreakup {
  const SalaryBreakup({
    required this.lines,
    required this.grossMonthly,
    required this.deductionMonthly,
    required this.netMonthly,
  });

  final List<SalaryBreakupLine> lines;
  final double grossMonthly;
  final double deductionMonthly;
  final double netMonthly;
}

class SalaryDesignerState {
  const SalaryDesignerState({
    required this.components,
    required this.payGroups,
    required this.formulas,
  });

  final List<SalaryPayComponent> components;
  final List<SalaryPayGroup> payGroups;
  final List<SalaryFormula> formulas;

  static const defaults = SalaryDesignerState(
    components: [
      SalaryPayComponent(
        id: 1,
        name: 'Basic Salary',
        code: 'BASIC',
        type: 'Earning',
        taxable: '1',
        description: '40% of monthly CTC',
      ),
      SalaryPayComponent(
        id: 2,
        name: 'House Rent Allowance',
        code: 'HRA',
        type: 'Earning',
        taxable: 'partial',
        description: '20% of monthly CTC — HRA exemption applies',
      ),
      SalaryPayComponent(
        id: 3,
        name: 'Special Allowance',
        code: 'SPCL',
        type: 'Earning',
        taxable: '1',
        description: 'Balance of gross after other components',
      ),
      SalaryPayComponent(
        id: 4,
        name: 'Leave Travel Allowance',
        code: 'LTA',
        type: 'Reimbursement',
        taxable: '0',
        description: '5% of CTC — exemption up to 2 journeys in 4 years',
      ),
      SalaryPayComponent(
        id: 5,
        name: 'Medical Allowance',
        code: 'MED',
        type: 'Reimbursement',
        taxable: '0',
        description: '₹1,250/month medical reimbursement',
      ),
      SalaryPayComponent(
        id: 6,
        name: 'PF Employee (12%)',
        code: 'PF_EMP',
        type: 'Deduction',
        taxable: '0',
        description: '12% of Basic — employee PF contribution',
      ),
      SalaryPayComponent(
        id: 7,
        name: 'Professional Tax',
        code: 'PT',
        type: 'Deduction',
        taxable: '0',
        description: 'Statutory deduction as per state slab',
      ),
    ],
    payGroups: [
      SalaryPayGroup(
        id: 1,
        name: 'Standard (All Components)',
        componentIds: [1, 2, 3, 4, 5, 6, 7],
      ),
      SalaryPayGroup(id: 2, name: 'Basic + PF only', componentIds: [1, 6, 7]),
      SalaryPayGroup(
        id: 3,
        name: 'Senior Executive Pack',
        componentIds: [1, 2, 3, 4, 5, 6, 7],
      ),
    ],
    formulas: [
      SalaryFormula(id: 1, componentId: 1, type: 'percent_ctc', value: 40),
      SalaryFormula(id: 2, componentId: 2, type: 'percent_ctc', value: 20),
      SalaryFormula(id: 3, componentId: 3, type: 'percent_ctc', value: 25),
      SalaryFormula(id: 4, componentId: 4, type: 'percent_ctc', value: 5),
      SalaryFormula(id: 5, componentId: 5, type: 'fixed', value: 1250),
      SalaryFormula(
        id: 6,
        componentId: 6,
        type: 'percent_comp',
        value: 12,
        referenceComponentId: 1,
      ),
      SalaryFormula(id: 7, componentId: 7, type: 'fixed', value: 200),
    ],
  );

  SalaryDesignerState copyWith({
    List<SalaryPayComponent>? components,
    List<SalaryPayGroup>? payGroups,
    List<SalaryFormula>? formulas,
  }) => SalaryDesignerState(
    components: components ?? this.components,
    payGroups: payGroups ?? this.payGroups,
    formulas: formulas ?? this.formulas,
  );

  factory SalaryDesignerState.fromJson(Map<String, dynamic> json) {
    final components = asList(
      json['components'],
    ).map((item) => SalaryPayComponent.fromJson(asMap(item))).toList();
    final groups = asList(
      json['payGroups'] ?? json['pay_groups'],
    ).map((item) => SalaryPayGroup.fromJson(asMap(item))).toList();
    final formulas = asList(
      json['formulas'],
    ).map((item) => SalaryFormula.fromJson(asMap(item))).toList();
    return SalaryDesignerState(
      components: components.isEmpty ? defaults.components : components,
      payGroups: groups.isEmpty ? defaults.payGroups : groups,
      formulas: formulas.isEmpty ? defaults.formulas : formulas,
    );
  }

  Map<String, dynamic> toJson() => {
    'components': components.map((item) => item.toJson()).toList(),
    'payGroups': payGroups.map((item) => item.toJson()).toList(),
    'formulas': formulas.map((item) => item.toJson()).toList(),
  };

  int nextComponentId() => _nextId(components.map((item) => item.id));
  int nextPayGroupId() => _nextId(payGroups.map((item) => item.id));
  int nextFormulaId() => _nextId(formulas.map((item) => item.id));

  SalaryBreakup calculate(SalaryPayGroup group, double annualCtc) {
    final selected = group.componentIds
        .map(componentById)
        .whereType<SalaryPayComponent>()
        .toList();
    final cache = <int, double>{};
    final resolving = <int>{};

    double resolve(SalaryPayComponent component) {
      final cached = cache[component.id];
      if (cached != null) return cached;
      if (!resolving.add(component.id)) return 0;
      SalaryFormula? formula;
      for (final item in formulas) {
        if (item.componentId == component.id) {
          formula = item;
          break;
        }
      }
      final monthlyCtc = annualCtc / 12;
      double value;
      if (formula == null) {
        value = switch (component.code.toUpperCase()) {
          'BASIC' => monthlyCtc * .40,
          'HRA' => monthlyCtc * .20,
          'SPCL' => monthlyCtc * .30,
          String code when code.startsWith('PF') => monthlyCtc * .40 * .12,
          _ => monthlyCtc * .10,
        };
      } else {
        final activeFormula = formula;
        value = switch (activeFormula.type) {
          'percent_ctc' => monthlyCtc * activeFormula.value / 100,
          'percent_comp' => () {
            final reference = componentById(
              activeFormula.referenceComponentId ?? 0,
            );
            return reference == null
                ? 0.0
                : resolve(reference) * activeFormula.value / 100;
          }(),
          _ => activeFormula.value,
        };
      }
      resolving.remove(component.id);
      final rounded = value.roundToDouble();
      cache[component.id] = rounded;
      return rounded;
    }

    final lines = selected
        .map(
          (component) => SalaryBreakupLine(
            component: component,
            monthly: resolve(component),
          ),
        )
        .toList();
    final gross = lines
        .where((line) => !line.component.isDeduction)
        .fold<double>(0, (sum, line) => sum + line.monthly);
    final deductions = lines
        .where((line) => line.component.isDeduction)
        .fold<double>(0, (sum, line) => sum + line.monthly);
    return SalaryBreakup(
      lines: lines,
      grossMonthly: gross,
      deductionMonthly: deductions,
      netMonthly: gross - deductions,
    );
  }

  SalaryPayComponent? componentById(int id) {
    for (final component in components) {
      if (component.id == id) return component;
    }
    return null;
  }

  Map<String, dynamic> snapshotFor(SalaryPayGroup group) {
    final ids = group.componentIds.toSet();
    return {
      'id': group.id,
      'name': group.name,
      'components': components
          .where((item) => ids.contains(item.id))
          .map((item) => item.toJson())
          .toList(),
      'formulas': formulas
          .where((item) => ids.contains(item.componentId))
          .map((item) => item.toJson())
          .toList(),
    };
  }

  static int _nextId(Iterable<int> ids) {
    var highest = 0;
    for (final id in ids) {
      if (id > highest) highest = id;
    }
    return highest + 1;
  }
}
