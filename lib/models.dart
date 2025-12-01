/// Modelos base para consumir la API de tutoría/estadística.
class AppUser {
  AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    this.matricula,
    this.token,
  });

  final int id;
  final String role; // student | teacher
  final String name;
  final String email;
  final String? matricula;
  final String? token;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        role: json['role'] as String,
        name: json['fullName'] as String? ?? json['name'] as String? ?? '',
        email: json['email'] as String,
        matricula: json['matricula'] as String?,
        token: json['token'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'fullName': name,
        'email': email,
        if (matricula != null) 'matricula': matricula,
        if (token != null) 'token': token,
      };
}

class Group {
  Group({
    required this.id,
    required this.name,
    required this.code,
    required this.tutorId,
  });

  final int id;
  final String name;
  final String code;
  final int tutorId;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as int,
        name: json['name'] as String,
        code: json['code'] as String,
        tutorId: json['teacherId'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'teacherId': tutorId,
      };
}

class GroupMember {
  GroupMember({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.status,
    required this.term,
  });

  final int id;
  final int groupId;
  final int studentId;
  final String status;
  final String term;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id'] as int,
        groupId: json['classId'] as int,
        studentId: json['studentId'] as int,
        status: json['status'] as String? ?? 'pending',
        term: json['term'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'classId': groupId,
        'studentId': studentId,
        'status': status,
        'term': term,
      };
}

class DailyRecord {
  DailyRecord({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.date,
    required this.emoji,
    this.note,
  });

  final int id;
  final int studentId;
  final int classId;
  final DateTime date;
  final int emoji;
  final String? note;

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
        id: json['id'] as int,
        studentId: json['studentId'] as int,
        classId: json['classId'] as int? ?? 0,
        date: DateTime.parse(json['moodDate']?.toString() ?? json['createdAt'] as String),
        emoji: json['moodValue'] as int,
        note: json['comment'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'classId': classId,
        'moodDate': date.toIso8601String(),
        'moodValue': emoji,
        if (note != null) 'comment': note,
      };
}

class DailyPerception {
  DailyPerception({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.subjectId,
    required this.perceptionDate,
    required this.level,
    this.note,
  });

  final int id;
  final int studentId;
  final int classId;
  final int subjectId;
  final DateTime perceptionDate;
  final String level;
  final String? note;

  factory DailyPerception.fromJson(Map<String, dynamic> json) => DailyPerception(
        id: json['id'] as int,
        studentId: json['studentId'] as int,
        classId: json['classId'] as int,
        subjectId: json['subjectId'] as int,
        perceptionDate: DateTime.parse(
          json['perceptionDate']?.toString() ?? json['createdAt'] as String,
        ),
        level: json['level'] as String,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'classId': classId,
        'subjectId': subjectId,
        'perceptionDate': perceptionDate.toIso8601String(),
        'level': level,
        if (note != null) 'note': note,
      };
}

class Subject {
  Subject({required this.id, required this.name});

  final int id;
  final String name;

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as int,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class JustificanteModel {
  JustificanteModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.type,
    required this.reason,
    required this.status,
    this.evidence,
    this.term,
    this.createdAt,
  });

  final int id;
  final int studentId;
  final int classId;
  final String type;
  final String reason;
  final String status;
  final String? evidence;
  final String? term;
  final DateTime? createdAt;

  factory JustificanteModel.fromJson(Map<String, dynamic> json) => JustificanteModel(
        id: json['id'] as int,
        studentId: json['studentId'] as int,
        classId: json['classId'] as int,
        type: json['type'] as String? ?? 'otro',
        reason: json['reason'] as String,
        status: json['status'] as String? ?? 'pending',
        evidence: json['imageUrl'] as String?,
        term: json['term'] as String?,
        createdAt:
            json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'classId': classId,
        'type': type,
        'reason': reason,
        'status': status,
        if (evidence != null) 'imageUrl': evidence,
        if (term != null) 'term': term,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}

class AlertModel {
  AlertModel({
    required this.id,
    required this.studentId,
    this.classId,
    required this.type,
    required this.description,
    required this.severity,
    required this.resolved,
    required this.createdAt,
  });

  final int id;
  final int studentId;
  final int? classId;
  final String type;
  final String description;
  final String severity;
  final bool resolved;
  final DateTime createdAt;

  factory AlertModel.fromJson(Map<String, dynamic> json) => AlertModel(
        id: json['id'] as int,
        studentId: json['studentId'] as int,
        classId: json['classId'] as int?,
        type: json['type'] as String,
        description: json['description'] as String,
        severity: json['severity'] as String? ?? 'low',
        resolved: json['resolved'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'classId': classId,
        'type': type,
        'description': description,
        'severity': severity,
        'resolved': resolved,
        'createdAt': createdAt.toIso8601String(),
      };
}

class MessageModel {
  MessageModel({
    required this.id,
    this.classId,
    this.toStudentId,
    required this.fromTutorId,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final int? classId;
  final int? toStudentId;
  final int fromTutorId;
  final String title;
  final String body;
  final DateTime createdAt;

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] as int,
        classId: json['classId'] as int?,
        toStudentId: json['toStudentId'] as int?,
        fromTutorId: json['fromTutorId'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'classId': classId,
        'toStudentId': toStudentId,
        'fromTutorId': fromTutorId,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };
}

class DashboardSummary {
  DashboardSummary({
    required this.studentCount,
    required this.checkInRate,
    required this.lowMoodCount,
    required this.topStressSubjects,
    required this.justificanteHistogram,
  });

  final int studentCount;
  final double checkInRate;
  final int lowMoodCount;
  final List<Map<String, dynamic>> topStressSubjects;
  final List<Map<String, dynamic>> justificanteHistogram;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        studentCount: json['studentCount'] as int? ?? 0,
        checkInRate: (json['checkInRate'] as num?)?.toDouble() ?? 0,
        lowMoodCount: json['lowMoodCount'] as int? ?? 0,
        topStressSubjects:
            (json['topStressSubjects'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
        justificanteHistogram:
            (json['justificanteHistogram'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      );

  Map<String, dynamic> toJson() => {
        'studentCount': studentCount,
        'checkInRate': checkInRate,
        'lowMoodCount': lowMoodCount,
        'topStressSubjects': topStressSubjects,
        'justificanteHistogram': justificanteHistogram,
      };
}
