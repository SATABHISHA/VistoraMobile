import 'package:vistora_mobile/core/api/api_parsing.dart';

class EmployeePage {
  const EmployeePage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<ManagedEmployee> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

class ManagedEmployee {
  const ManagedEmployee({
    required this.id,
    required this.code,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
    this.workEmail,
    this.mobile,
    this.branch,
    this.department,
    this.designation,
    this.username,
    this.ctcAnnual,
    this.netMonthly,
    this.middleName,
    this.dob,
    this.gender,
    this.nationality,
    this.state,
    this.businessUnit,
    this.reportingManager,
    this.joiningDate,
    this.prefix,
    this.personalEmail,
    this.maritalStatus,
    this.bloodGroup,
    this.pan,
    this.aadhaar,
    this.passportNo,
    this.passportExpiry,
    this.permanentAddress,
    this.permanentCity,
    this.permanentState,
    this.permanentCountry,
    this.permanentPin,
    this.currentAddress,
    this.currentCity,
    this.currentState,
    this.currentCountry,
    this.currentPin,
    this.employmentType,
    this.employmentStatus,
    this.branchId,
    this.stateId,
    this.businessUnitId,
    this.departmentId,
    this.designationId,
    this.supervisorIds = const [],
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelation,
  });

  final int id;
  final String code;
  final String firstName;
  final String lastName;
  final String role;
  final String status;
  final String? workEmail;
  final String? mobile;
  final String? branch;
  final String? department;
  final String? designation;
  final String? username;
  final double? ctcAnnual;
  final double? netMonthly;
  final String? middleName;
  final DateTime? dob;
  final String? gender;
  final String? nationality;
  final String? state;
  final String? businessUnit;
  final String? reportingManager;
  final DateTime? joiningDate;
  final String? prefix;
  final String? personalEmail;
  final String? maritalStatus;
  final String? bloodGroup;
  final String? pan;
  final String? aadhaar;
  final String? passportNo;
  final DateTime? passportExpiry;
  final String? permanentAddress;
  final String? permanentCity;
  final String? permanentState;
  final String? permanentCountry;
  final String? permanentPin;
  final String? currentAddress;
  final String? currentCity;
  final String? currentState;
  final String? currentCountry;
  final String? currentPin;
  final String? employmentType;
  final String? employmentStatus;
  final int? branchId;
  final int? stateId;
  final int? businessUnitId;
  final int? departmentId;
  final int? designationId;
  final List<int> supervisorIds;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;

  String get name => '$firstName $lastName'.trim();
  bool get hasCredentials => username?.isNotEmpty == true;

  factory ManagedEmployee.fromJson(Map<String, dynamic> json) {
    final salary = asMap(json['current_salary']);
    final user = asMap(json['user']);
    return ManagedEmployee(
      id: asInt(json['id']),
      code: json['emp_code']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      middleName: asNullableString(json['middle_name']),
      role: json['role_type']?.toString() ?? 'Employee',
      status: json['status']?.toString() ?? 'inactive',
      workEmail: asNullableString(json['work_email']),
      mobile: asNullableString(json['mobile']),
      branch: asNullableString(asMap(json['branch'])['name']),
      department: asNullableString(asMap(json['department'])['name']),
      designation: asNullableString(asMap(json['designation'])['name']),
      username: asNullableString(user['username']),
      ctcAnnual: salary['ctc_annual'] == null
          ? null
          : asDouble(salary['ctc_annual']),
      netMonthly: salary['net_monthly'] == null
          ? null
          : asDouble(salary['net_monthly']),
      dob: asDateTime(json['dob']),
      gender: asNullableString(json['gender']),
      nationality: asNullableString(json['nationality']),
      state: asNullableString(asMap(json['state'])['name']),
      businessUnit: asNullableString(asMap(json['business_unit'])['name']),
      reportingManager: asNullableString(
        asMap(json['reporting_manager'])['first_name'],
      ),
      joiningDate: asDateTime(json['doj']),
      prefix: asNullableString(json['prefix']),
      personalEmail: asNullableString(json['personal_email']),
      maritalStatus: asNullableString(json['marital_status']),
      bloodGroup: asNullableString(json['blood_group']),
      pan: asNullableString(json['pan']),
      aadhaar: asNullableString(json['aadhaar']),
      passportNo: asNullableString(json['passport_no']),
      passportExpiry: asDateTime(json['passport_expiry']),
      permanentAddress: asNullableString(json['permanent_address']),
      permanentCity: asNullableString(json['permanent_city']),
      permanentState: asNullableString(json['permanent_state']),
      permanentCountry: asNullableString(json['permanent_country']),
      permanentPin: asNullableString(json['permanent_pin']),
      currentAddress: asNullableString(json['current_address']),
      currentCity: asNullableString(json['current_city']),
      currentState: asNullableString(json['current_state']),
      currentCountry: asNullableString(json['current_country']),
      currentPin: asNullableString(json['current_pin']),
      employmentType: asNullableString(json['employment_type']),
      employmentStatus: asNullableString(json['employment_status']),
      branchId: _relationId(json['branch'], json['branch_id']),
      stateId: _relationId(json['state'], json['state_id']),
      businessUnitId: _relationId(
        json['business_unit'],
        json['business_unit_id'],
      ),
      departmentId: _relationId(json['department'], json['department_id']),
      designationId: _relationId(json['designation'], json['designation_id']),
      supervisorIds: asList(
        json['supervisors'],
      ).map((item) => asInt(asMap(item)['id'])).where((id) => id > 0).toList(),
      emergencyContactName: asNullableString(json['emergency_contact_name']),
      emergencyContactPhone: asNullableString(json['emergency_contact_phone']),
      emergencyContactRelation: asNullableString(
        json['emergency_contact_relation'],
      ),
    );
  }

  static int? _relationId(dynamic relation, dynamic direct) {
    final id = direct ?? asMap(relation)['id'];
    return id == null ? null : asInt(id);
  }
}
