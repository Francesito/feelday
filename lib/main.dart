import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'image_saver.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ignorar eventos de teclado inválidos (bug del embedder en algunas distros Linux).
  final binding = WidgetsBinding.instance;
  binding.platformDispatcher.onKeyData = (KeyData data) {
    if (data.physical == 0 || data.logical == 0) return true; // absorber corruptos
    return false; // dejar pasar los válidos al manejador por defecto
  };
  runApp(const FeeldayApp());
}

enum UserRole { student, teacher }

class UserAccount {
  UserAccount({
    required this.id,
    required this.email,
    required this.password,
    required this.role,
    required this.displayName,
  });

  final int id;
  final String email;
  final String password;
  final UserRole role;
  final String displayName;
}

class ClassRoom {
  ClassRoom({
    required this.id,
    required this.name,
    required this.code,
    required this.teacherEmail,
    this.teacherName = '',
    this.joined = false,
    this.studentCount = 0,
    this.enrollmentStatus = 'none',
    List<EnrollmentRequest>? pendingEnrollments,
  }) : pendingEnrollments = pendingEnrollments ?? const [];

  final int id;
  final String name;
  final String code;
  final String teacherEmail;
  final String teacherName;
  final bool joined;
  final int studentCount;
  final String enrollmentStatus;
  final List<EnrollmentRequest> pendingEnrollments;
  final List<String> studentEmails = [];
  final Map<String, ScheduleUpload> schedules = {};
  final List<MoodEntry> moodEntries = [];
  final List<Justificante> justificantes = [];

  ClassRoom copyWith({
    bool? joined,
    String? enrollmentStatus,
    List<EnrollmentRequest>? pendingEnrollments,
  }) {
    return ClassRoom(
      id: id,
      name: name,
      code: code,
      teacherEmail: teacherEmail,
      teacherName: teacherName,
      joined: joined ?? this.joined,
      studentCount: studentCount,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
      pendingEnrollments: pendingEnrollments ?? this.pendingEnrollments,
    );
  }
}

class EnrollmentRequest {
  EnrollmentRequest({
    required this.id,
    required this.studentEmail,
    required this.studentName,
    required this.status,
    required this.classId,
  });

  final int id;
  final String studentEmail;
  final String studentName;
  final String status;
  final int classId;
}

class ScheduleUpload {
  ScheduleUpload({
    required this.classId,
    required this.studentId,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedAt,
  });
  final int classId;
  final int studentId;
  final String fileName;
  final String fileUrl;
  final DateTime uploadedAt;
}

class MoodEntry {
  MoodEntry({
    required this.id,
    required this.studentId,
    required this.studentEmail,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.day,
    required this.mood,
    required this.comment,
    required this.scheduleFileName,
    required this.createdAt,
    this.teacherRead = false,
  });

  final int id;
  final int studentId;
  final String studentEmail;
  final String studentName;
  final int classId;
  final String className;
  final String day;
  final double mood;
  final String comment;
  final String scheduleFileName;
  final DateTime createdAt;
  final bool teacherRead;
}

class Justificante {
  Justificante({
    required this.id,
    required this.studentId,
    required this.studentEmail,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.reason,
    required this.imageLabel,
    required this.imageUrl,
    this.status = JustificanteStatus.pending,
  });

  final int id;
  final int studentId;
  final String studentEmail;
  final String studentName;
  final int classId;
  final String className;
  final String reason;
  final String imageLabel;
  final String imageUrl;
  JustificanteStatus status;
}

enum JustificanteStatus { pending, approved, rejected }

class FeeldayApp extends StatefulWidget {
  const FeeldayApp({super.key});

  @override
  State<FeeldayApp> createState() => _FeeldayAppState();
}

class _FeeldayAppState extends State<FeeldayApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  // Permite sobreescribir el backend con --dart-define=API_BASE_URL=https://...
  static const String _apiBase =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://feelday.onrender.com');
  final ApiClient _api = ApiClient(baseUrl: _apiBase);
  final List<ClassRoom> _classes = [];
  final List<MoodEntry> _allMoodEntries = [];
  final List<Justificante> _allJustificantes = [];
  final List<Map<String, dynamic>> _perceptions = [];
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _alerts = [];
  Map<String, dynamic> _dashboardSummary = {};
  final Map<int, ScheduleUpload> _mySchedules = {};
  UserAccount? _currentUser;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A7E8C),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF3F7F9),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFBFD8DF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0A7E8C), width: 1.6),
        ),
      ),
    );

    final homeWidget = _currentUser == null
        ? AuthShell(
            onLogin: _handleLogin,
            onRegister: _handleRegister,
          )
        : _currentUser!.role == UserRole.student
            ? StudentShell(
                user: _currentUser!,
                classes: _classes,
                schedules: _mySchedules,
                moodEntries: _allMoodEntries,
                justificantes: _allJustificantes,
                perceptions: _perceptions,
                messages: _messages,
                alerts: _alerts,
                onJoinClass: _joinClass,
                onLogout: _logout,
                onUploadSchedule: _uploadSchedule,
                onSubmitMood: _submitMood,
                onSubmitJustificante:
                    ({required cls, required reason, required imageLabel, required imageUrlOverride}) =>
                    _submitJustificante(
                  cls: cls,
                  reason: reason,
                  imageLabel: imageLabel,
                  imageUrlOverride: imageUrlOverride,
                  context: context,
                ),
                onSubmitPerception: _submitPerception,
                onRefresh: _refreshData,
                onSendMessage: _sendMessage,
              )
            : TeacherShell(
                user: _currentUser!,
                classes: _classes,
                moodEntries: _allMoodEntries,
                justificantes: _allJustificantes,
                perceptions: _perceptions,
                alerts: _alerts,
                messages: _messages,
                dashboardSummary: _dashboardSummary,
                onCreateClass: (name, ctx) => _createClass(name, ctx),
                onViewClassMembers: _viewClassMembers,
                onLogout: _logout,
                onUpdateJustificante: _updateJustificanteStatus,
                onReviewEnrollment: _reviewEnrollment,
                onMarkMoodRead: _markMoodRead,
                onSendMessage: _sendMessage,
                onResolveAlert: _resolveAlert,
                onRefresh: _refreshData,
              );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'feelday',
      theme: theme,
      scaffoldMessengerKey: _messengerKey,
      home: Stack(
        children: [
          homeWidget,
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _handleLogin(String email, String password, BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _loading = true);
      final data = await _api.login(email, password);
      _api.token = data['token'] as String?;
      final userData = data['user'] as Map<String, dynamic>;
      _currentUser = UserAccount(
        id: userData['id'] as int,
        email: userData['email'] as String,
        password: '',
        role: userData['role'] == 'teacher' ? UserRole.teacher : UserRole.student,
        displayName: userData['fullName'] as String,
      );
      await _refreshData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required BuildContext context,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _loading = true);
      final data = await _api.register(email, password, name, role.name);
      _api.token = data['token'] as String?;
      final userData = data['user'] as Map<String, dynamic>;
      _currentUser = UserAccount(
        id: userData['id'] as int,
        email: userData['email'] as String,
        password: '',
        role: userData['role'] == 'teacher' ? UserRole.teacher : UserRole.student,
        displayName: userData['fullName'] as String,
      );
      await _refreshData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _logout() => setState(() {
        _currentUser = null;
        _api.token = null;
        _classes.clear();
        _allMoodEntries.clear();
        _allJustificantes.clear();
        _mySchedules.clear();
      });

  Future<void> _createClass(String name, BuildContext context) async {
    if (_currentUser == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.createClass(name);
      await _refreshData();
      messenger.showSnackBar(
        const SnackBar(content: Text('Clase creada')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _viewClassMembers(ClassRoom cls, BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await _api.fetchClassDetail(cls.id);
      final enrollments = (data['enrollments'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          if (enrollments.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Aún no hay alumnos inscritos en esta clase.'),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alumnos de ${cls.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: enrollments.length,
                    itemBuilder: (_, idx) {
                      final e = enrollments[idx];
                      final student = e['student'] as Map<String, dynamic>? ?? {};
                      final name = student['fullName']?.toString() ?? 'Sin nombre';
                      final email = student['email']?.toString() ?? '';
                      final status = e['status']?.toString() ?? 'pending';
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(name),
                        subtitle: Text(email.isNotEmpty ? email : 'Sin correo'),
                        trailing: Chip(
                          label: Text(status),
                          backgroundColor: const Color(0xFFE3F2F4),
                          side: BorderSide.none,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _joinClass(String code, BuildContext context) async {
    if (_currentUser == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.joinClass(code);
      await _refreshData();
      messenger.showSnackBar(
        const SnackBar(content: Text('Unido a la clase')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _uploadSchedule(ClassRoom cls, String fileName, String fileUrl) async {
    if (_currentUser == null) return;
    final messenger = _messengerKey.currentState;
    try {
      final res = await _api.submitSchedule({
        'classId': cls.id,
        'fileUrl': fileUrl.isNotEmpty ? fileUrl : fileName,
        'fileName': fileName,
      });
      final upload = ScheduleUpload(
        classId: cls.id,
        studentId: _currentUser!.id,
        fileName: res['fileName'] as String? ?? fileName,
        fileUrl: res['fileUrl'] as String? ?? fileUrl,
        uploadedAt: DateTime.now(),
      );
      setState(() {
        _mySchedules[cls.id] = upload;
      });
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool> _submitMood({
    required ClassRoom cls,
    required double mood,
    required String comment,
    required String day,
    required String scheduleFileName,
  }) async {
    if (cls.enrollmentStatus != 'approved') {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Tu solicitud a la clase está pendiente de aprobación.')),
      );
      return false;
    }
    if (_currentUser == null) {
      _messengerKey.currentState
          ?.showSnackBar(const SnackBar(content: Text('Debes iniciar sesión para enviar.')));
      return false;
    }
    final messenger = _messengerKey.currentState;
    final scheduleName = scheduleFileName.isNotEmpty ? scheduleFileName : 'horario.pdf';
    try {
      final res = await _api.submitMood({
        'classId': cls.id,
        'moodValue': mood.toInt(),
        'comment': comment,
        'dayLabel': day,
        'scheduleFileName': scheduleName,
      });
      final entry = MoodEntry(
        id: res['id'] as int? ?? Random().nextInt(999999),
        studentId: _currentUser!.id,
        studentEmail: _currentUser!.email,
        studentName: _currentUser!.displayName,
        classId: cls.id,
        className: cls.name,
        day: day,
        mood: mood,
        comment: comment,
        scheduleFileName: scheduleName,
        createdAt: DateTime.parse(res['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      );
      setState(() {
        _allMoodEntries.insert(0, entry);
      });
      await _refreshData();
      return true;
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }
  }

  Future<void> _submitJustificante({
    required ClassRoom cls,
    required String reason,
    required String imageLabel,
    required String imageUrlOverride,
    required BuildContext context,
  }) async {
    if (cls.enrollmentStatus != 'approved') {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Tu solicitud a la clase está pendiente de aprobación.')),
      );
      return;
    }
    if (_currentUser == null) return;
    try {
      final res = await _api.submitJustificante({
        'classId': cls.id,
        'reason': reason,
        'imageUrl': imageUrlOverride.isNotEmpty ? imageUrlOverride : imageLabel,
        'imageName': imageLabel,
      });
      final j = Justificante(
        id: res['id'] as int? ?? Random().nextInt(999999),
        studentId: _currentUser!.id,
        studentEmail: _currentUser!.email,
        studentName: _currentUser!.displayName,
        classId: cls.id,
        className: cls.name,
        reason: reason,
        imageLabel: imageLabel,
        imageUrl: imageUrlOverride,
      );
      setState(() {
        _allJustificantes.insert(0, j);
      });
      await _refreshData();
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Justificante enviado')),
      );
    } catch (e) {
      _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool> _submitPerception({
    required ClassRoom cls,
    required int subjectId,
    required DateTime perceptionDate,
    required String level,
    String? note,
  }) async {
    if (_currentUser == null) return false;
    try {
      await _api.submitPerception({
        'classId': cls.id,
        'subjectId': subjectId,
        'perceptionDate': perceptionDate.toIso8601String(),
        'level': level,
        'note': note,
      });
      await _refreshData();
      return true;
    } catch (e) {
      _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }
  }

  Future<void> _sendMessage({
    int? classId,
    int? toStudentId,
    required String title,
    required String body,
  }) async {
    try {
      await _api.sendMessage({
        if (classId != null) 'classId': classId,
        if (toStudentId != null) 'toStudentId': toStudentId,
        'title': title,
        'body': body,
      });
      await _refreshData();
      _messengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Mensaje enviado')));
    } catch (e) {
      _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _resolveAlert(int id) async {
    try {
      await _api.resolveAlert(id);
      await _refreshData();
    } catch (e) {
      _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _updateJustificanteStatus(
    Justificante justificante,
    JustificanteStatus status,
  ) async {
    final messenger = _messengerKey.currentState;
    try {
      await _api.updateJustificanteStatus(justificante.id, status.name);
      setState(() {
        justificante.status = status;
      });
      await _refreshData();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(status == JustificanteStatus.approved
              ? 'Justificante aprobado'
              : 'Justificante actualizado'),
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reviewEnrollment(
    int enrollmentId,
    String status,
    BuildContext context,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.updateEnrollmentStatus(enrollmentId, status);
      await _refreshData();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Solicitud aprobada' : 'Solicitud actualizada',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _markMoodRead(int moodId) async {
    try {
      await _api.markMoodAsRead(moodId);
      await _refreshData();
    } catch (e) {
      _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _refreshData() async {
    if (_currentUser == null) return;
    try {
      setState(() => _loading = true);
      final classes = await _api.fetchClasses();
      _classes
        ..clear()
        ..addAll(classes.map((c) {
          final teacher = c['teacher'] as Map<String, dynamic>?;
          final enrollments = (c['enrollments'] as List<dynamic>? ?? []);

          if (_currentUser!.role == UserRole.student) {
            final own = enrollments.cast<Map<String, dynamic>?>().firstWhere(
                  (e) => e?['studentId'] == _currentUser!.id,
                  orElse: () => null,
                );
            final status = own?['status']?.toString() ?? 'none';
            final hasEnrollment = own != null;
            return ClassRoom(
              id: c['id'] as int,
              name: c['name'] as String,
              code: c['code'] as String,
              teacherEmail: teacher?['email']?.toString() ?? '',
              teacherName: teacher?['fullName']?.toString() ?? '',
              joined: hasEnrollment,
              enrollmentStatus: status,
              studentCount: enrollments.length,
              pendingEnrollments: const [],
            );
          }

          final pendingEnrollments = enrollments
              .map((e) => e as Map<String, dynamic>)
              .where((e) => (e['status']?.toString() ?? 'pending') != 'approved')
              .map(
                (e) => EnrollmentRequest(
                  id: e['id'] as int,
                  studentEmail: (e['student']?['email'])?.toString() ?? '',
                  studentName: (e['student']?['fullName'])?.toString() ?? '',
                  status: e['status']?.toString() ?? 'pending',
                  classId: c['id'] as int,
                ),
              )
              .toList();

          return ClassRoom(
            id: c['id'] as int,
            name: c['name'] as String,
            code: c['code'] as String,
            teacherEmail: teacher?['email']?.toString() ?? '',
            teacherName: teacher?['fullName']?.toString() ?? '',
            joined: true,
            enrollmentStatus: 'approved',
            studentCount: enrollments.length,
            pendingEnrollments: pendingEnrollments,
          );
        }));

      final schedules = await _api.fetchSchedules();
      _mySchedules.clear();
      for (final s in schedules) {
        final classId = s['classId'] as int;
        final studentId = s['studentId'] as int;
        final schedule = ScheduleUpload(
          classId: classId,
          studentId: studentId,
          fileName: s['fileName'] as String? ?? 'horario.pdf',
          fileUrl: s['fileUrl'] as String? ?? '',
          uploadedAt: DateTime.parse(
            s['uploadedAt']?.toString() ?? DateTime.now().toIso8601String(),
          ),
        );
        if (studentId == _currentUser!.id) {
          _mySchedules[classId] = schedule;
        }
      }

      final moods = await _api.fetchMoodEntries();
      _allMoodEntries
        ..clear()
        ..addAll(moods.map((m) {
          final student = m['student'] as Map<String, dynamic>? ?? {};
          final cls = m['class'] as Map<String, dynamic>? ?? {};
          return MoodEntry(
            id: m['id'] as int? ?? 0,
            studentId: student['id'] as int? ?? 0,
            studentEmail: student['email']?.toString() ?? '',
            studentName: student['fullName']?.toString() ?? '',
            classId: cls['id'] as int? ?? (m['classId'] as int? ?? 0),
            className: cls['name']?.toString() ?? '',
            day: m['dayLabel']?.toString() ?? '',
            mood: (m['moodValue'] as num? ?? 0).toDouble(),
            comment: m['comment']?.toString() ?? '',
            scheduleFileName: m['scheduleFileName']?.toString() ?? '',
            createdAt: DateTime.parse(
              m['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
            ),
            teacherRead: m['teacherRead'] as bool? ?? false,
          );
        }));

      final perceptions = await _api.fetchPerceptions();
      _perceptions
        ..clear()
        ..addAll(perceptions.cast<Map<String, dynamic>>());

      final messages = await _api.fetchMessages();
      _messages
        ..clear()
        ..addAll(messages.cast<Map<String, dynamic>>());

      final alerts = await _api.fetchAlerts();
      _alerts
        ..clear()
        ..addAll(alerts.cast<Map<String, dynamic>>());

      if (_currentUser!.role == UserRole.teacher) {
        _dashboardSummary = await _api.fetchDashboard();
      } else {
        _dashboardSummary = {};
      }

      final justs = await _api.fetchJustificantes();
      _allJustificantes
        ..clear()
        ..addAll(justs.map((j) {
          final student = j['student'] as Map<String, dynamic>? ?? {};
          final cls = j['class'] as Map<String, dynamic>? ?? {};
          return Justificante(
            id: j['id'] as int? ?? 0,
            studentId: student['id'] as int? ?? 0,
            studentEmail: student['email']?.toString() ?? '',
            studentName: student['fullName']?.toString() ?? '',
            classId: cls['id'] as int? ?? 0,
            className: cls['name']?.toString() ?? '',
            reason: j['reason']?.toString() ?? '',
            imageLabel: j['imageName']?.toString() ?? '',
            imageUrl: j['imageUrl']?.toString() ?? '',
            status: _statusFromString(j['status']?.toString()),
          );
        }));
    } finally {
      setState(() => _loading = false);
    }
  }

  JustificanteStatus _statusFromString(String? status) {
    switch (status) {
      case 'approved':
        return JustificanteStatus.approved;
      case 'rejected':
        return JustificanteStatus.rejected;
      default:
        return JustificanteStatus.pending;
    }
  }
}

class AuthShell extends StatefulWidget {
  const AuthShell({
    super.key,
    required this.onLogin,
    required this.onRegister,
  });

  final Future<void> Function(String email, String password, BuildContext context)
      onLogin;
  final Future<void> Function({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required BuildContext context,
  }) onRegister;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A7E8C), Color(0xFF073F50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: viewInsets + 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      Text(
                        'feelday 🐺',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bienvenido, gestiona tus clases y estados de ánimo ✨',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F7F9),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _index == 0
                              ? LoginCard(
                                  key: const ValueKey('login'),
                                  onLogin: widget.onLogin,
                                  onChangePage: () => setState(() => _index = 1),
                                )
                              : RegisterCard(
                                  key: const ValueKey('register'),
                                  onRegister: widget.onRegister,
                                  onBack: () => setState(() => _index = 0),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class LoginCard extends StatefulWidget {
  const LoginCard({
    super.key,
    required this.onLogin,
    required this.onChangePage,
  });

  final Future<void> Function(String email, String password, BuildContext context)
      onLogin;
  final VoidCallback onChangePage;

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool hide = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inicia sesión ✨',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF073F50),
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Correo',
              hintText: 'tu@correo.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passCtrl,
            obscureText: hide,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => hide = !hide),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onLogin(
                emailCtrl.text.trim(),
                passCtrl.text.trim(),
                context,
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF0A7E8C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Entrar'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('¿No tienes cuenta?'),
              TextButton(
                onPressed: widget.onChangePage,
                child: const Text('Crear cuenta 🚀'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RegisterCard extends StatefulWidget {
  const RegisterCard({
    super.key,
    required this.onRegister,
    required this.onBack,
  });

  final Future<void> Function({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required BuildContext context,
  }) onRegister;
  final VoidCallback onBack;

  @override
  State<RegisterCard> createState() => _RegisterCardState();
}

class _RegisterCardState extends State<RegisterCard> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  UserRole role = UserRole.student;
  bool hide = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_ios_new),
              ),
              const SizedBox(width: 6),
              Text(
                'Crear cuenta 🚀',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF073F50),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              hintText: 'Tu nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Correo',
              hintText: 'tu@correo.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passCtrl,
            obscureText: hide,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => hide = !hide),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Rol',
            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF073F50)),
          ),
          const SizedBox(height: 6),
          ToggleButtons(
            isSelected: [
              role == UserRole.student,
              role == UserRole.teacher,
            ],
            borderRadius: BorderRadius.circular(14),
            onPressed: (i) => setState(
              () => role = i == 0 ? UserRole.student : UserRole.teacher,
            ),
            fillColor: const Color(0xFF0A7E8C),
            selectedColor: Colors.white,
            color: const Color(0xFF073F50),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Text('Alumno'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Text('Profesor'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onRegister(
                  email: emailCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  role: role,
                  context: context,
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF0A7E8C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Crear y entrar'),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentShell extends StatefulWidget {
  const StudentShell({
    super.key,
    required this.user,
    required this.classes,
    required this.schedules,
    required this.moodEntries,
    required this.justificantes,
    required this.perceptions,
    required this.messages,
    required this.alerts,
    required this.onJoinClass,
    required this.onLogout,
    required this.onUploadSchedule,
    required this.onSubmitMood,
    required this.onSubmitJustificante,
    required this.onSubmitPerception,
    required this.onRefresh,
    required this.onSendMessage,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final Map<int, ScheduleUpload> schedules;
  final List<MoodEntry> moodEntries;
  final List<Justificante> justificantes;
  final List<Map<String, dynamic>> perceptions;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> alerts;
  final void Function(String code, BuildContext context) onJoinClass;
  final VoidCallback onLogout;
  final void Function(ClassRoom cls, String fileName, String fileUrl) onUploadSchedule;
  final Future<bool> Function({
    required ClassRoom cls,
    required double mood,
    required String comment,
    required String day,
    required String scheduleFileName,
  }) onSubmitMood;
  final void Function({
    required ClassRoom cls,
    required String reason,
    required String imageLabel,
    required String imageUrlOverride,
  }) onSubmitJustificante;
  final Future<bool> Function({
    required ClassRoom cls,
    required int subjectId,
    required DateTime perceptionDate,
    required String level,
    String? note,
  }) onSubmitPerception;
  final Future<void> Function() onRefresh;
  final Future<void> Function({
    int? classId,
    int? toStudentId,
    required String title,
    required String body,
  }) onSendMessage;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom + 12),
        child: StudentClassesPage(
          user: widget.user,
          classes: widget.classes,
          schedules: widget.schedules,
          moodEntries: widget.moodEntries,
          onJoinClass: widget.onJoinClass,
          onUploadSchedule: widget.onUploadSchedule,
          onSubmitMood: widget.onSubmitMood,
          onRefresh: widget.onRefresh,
        ),
      ),
      JustificantesPage(
        user: widget.user,
        classes: widget.classes,
        justificantes: widget.justificantes,
        onSubmitJustificante: widget.onSubmitJustificante,
        onRefresh: widget.onRefresh,
      ),
      PerceptionsPage(
        user: widget.user,
        classes: widget.classes,
        perceptions: widget.perceptions,
        onSubmitPerception: widget.onSubmitPerception,
        onRefresh: widget.onRefresh,
      ),
      MessagesPage(
        user: widget.user,
        classes: widget.classes,
        messages: widget.messages,
        onSend: widget.onSendMessage,
        onRefresh: widget.onRefresh,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('feelday - Alumno ✨'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: const AssetImage('assets/images/logo.png'),
            backgroundColor: Colors.white,
            onBackgroundImageError: (_, __) {},
          ),
        ),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            label: 'Clases',
          ),
          NavigationDestination(
            icon: Icon(Icons.image_outlined),
            label: 'Justificantes',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            label: 'Percepción',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Mensajes',
          ),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

class StudentClassesPage extends StatefulWidget {
  const StudentClassesPage({
    super.key,
    required this.user,
    required this.classes,
    required this.schedules,
    required this.moodEntries,
    required this.onJoinClass,
    required this.onUploadSchedule,
    required this.onSubmitMood,
    required this.onRefresh,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final Map<int, ScheduleUpload> schedules;
  final List<MoodEntry> moodEntries;
  final void Function(String code, BuildContext context) onJoinClass;
  final void Function(ClassRoom cls, String fileName, String fileUrl) onUploadSchedule;
  final Future<bool> Function({
    required ClassRoom cls,
    required double mood,
    required String comment,
    required String day,
    required String scheduleFileName,
  }) onSubmitMood;
  final Future<void> Function() onRefresh;

  @override
  State<StudentClassesPage> createState() => _StudentClassesPageState();
}

class _StudentClassesPageState extends State<StudentClassesPage> {
  final codeCtrl = TextEditingController();
  final commentCtrl = TextEditingController();
  double _mood = 50;
  String _selectedDay = 'Lunes';
  ClassRoom? _selectedClass;
  String? _selectedFile;

  @override
  Widget build(BuildContext context) {
    final joined = widget.classes.where((c) => c.enrollmentStatus != 'none' || c.joined).toList();
    final available = widget.classes;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A7E8C), Color(0xFF0CB3C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.school, color: Colors.white, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Hola 👋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Organiza tus clases, sube tu horario y comparte tu estado de ánimo.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unirse a clase',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF073F50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código (Classroom style)',
                      prefixIcon: Icon(Icons.qr_code_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        widget.onJoinClass(codeCtrl.text.trim(), context);
                        setState(() {});
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0A7E8C),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Unirme'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mis clases',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF073F50),
            ),
          ),
          const SizedBox(height: 8),
          if (joined.isEmpty)
            const Text('Aún no te unes a ninguna clase'),
          ...joined.map(
            (cls) => ClassCard(
              cls: cls,
              trailing: cls.enrollmentStatus == 'pending'
                  ? const Chip(
                      label: Text('Pendiente'),
                      avatar: Icon(Icons.hourglass_bottom, size: 16),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () => _openClassDetail(context, cls),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Explorar clases (demo)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF073F50),
            ),
          ),
          const SizedBox(height: 8),
          ...available.map(
            (cls) => ClassCard(
              cls: cls,
              trailing: TextButton(
                onPressed: () {
                  codeCtrl.text = cls.code;
                },
                child: const Text('Copiar código'),
              ),
            ),
          ),
          if (_selectedClass != null) const SizedBox(height: 16),
          if (_selectedClass != null)
            _buildMoodForm(context, _selectedClass!),
        ],
      ),
    );
  }

  Widget _buildMoodForm(BuildContext context, ClassRoom cls) {
    final approved = cls.enrollmentStatus == 'approved';
    final schedule = widget.schedules[cls.id];
    _selectedFile = schedule?.fileName;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cls.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF073F50),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(_selectedDay),
                  avatar: const Icon(Icons.calendar_today, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!approved)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'Tu solicitud está pendiente de aprobación por el profesor. Podrás enviar estado y justificantes cuando te aprueben.',
                  style: TextStyle(color: Color(0xFF8C4A00)),
                ),
              )
            else if (schedule == null)
              FilledButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Subir horario (PDF)'),
                onPressed: () => _promptFile(context, cls),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0A7E8C),
                ),
              )
            else
              SchedulePreview(
                upload: schedule,
                onChange: () => _promptFile(context, cls),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('¿Cómo te sientes?'),
                const SizedBox(width: 8),
                Text(
                  _emojiForMood(_mood),
                  style: const TextStyle(fontSize: 26),
                ),
              ],
            ),
              Slider(
                value: _mood,
                onChanged: approved ? (v) => setState(() => _mood = v) : null,
                min: 0,
                max: 100,
                activeColor: const Color(0xFF0A7E8C),
                inactiveColor: const Color(0xFFBFD8DF),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Día'),
                DropdownButton<String>(
                  value: _selectedDay,
                  items: const [
                    'Lunes',
                    'Martes',
                    'Miércoles',
                    'Jueves',
                    'Viernes',
                  ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _selectedDay = v ?? 'Lunes'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comentario',
                hintText: '¿Qué pasó hoy?',
              ),
              enabled: approved,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: !approved
                    ? null
                    : () async {
                        final ok = await widget.onSubmitMood(
                          cls: cls,
                          mood: _mood,
                          comment: commentCtrl.text,
                          day: _selectedDay,
                          scheduleFileName: _selectedFile ?? '',
                        );
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enviado al maestro'),
                            ),
                          );
                          commentCtrl.clear();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo enviar el estado de ánimo'),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF073F50),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enviar estado'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mis envíos',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF073F50),
              ),
            ),
            const SizedBox(height: 8),
            ...widget.moodEntries
                .where((m) =>
                    m.studentEmail == widget.user.email && m.classId == cls.id)
                .map(
                  (m) => ListTile(
                    leading: Text(_emojiForMood(m.mood), style: const TextStyle(fontSize: 24)),
                    title: Text('${m.day} · ${m.className}'),
                    subtitle: Text(m.comment),
                    trailing: Text(
                      m.mood.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _promptFile(BuildContext context, ClassRoom cls) {
    FilePicker.platform
        .pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withReadStream: true,
        )
        .then((result) {
      if (result == null) return;
      final file = result.files.single;
      final name = file.name.isNotEmpty ? file.name : 'horario.pdf';
      final path = file.path ?? '';
      widget.onUploadSchedule(cls, name, path.isNotEmpty ? path : name);
      setState(() {
        _selectedFile = name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Horario seleccionado: $name')),
      );
    });
  }

  void _openClassDetail(BuildContext context, ClassRoom cls) {
    setState(() => _selectedClass = cls);
  }

  String _emojiForMood(double mood) {
    if (mood <= 20) return '😞';
    if (mood <= 40) return '🙁';
    if (mood <= 60) return '😐';
    if (mood <= 80) return '🙂';
    return '😄';
  }
}

class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.cls,
    this.trailing,
  });

  final ClassRoom cls;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(
          cls.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF073F50)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código: ${cls.code}'),
            Text('Profesor: ${cls.teacherEmail}'),
            if (cls.enrollmentStatus != 'none')
              Text(
                'Estado: ${cls.enrollmentStatus}',
                style: TextStyle(
                  color: cls.enrollmentStatus == 'approved'
                      ? const Color(0xFF0B8A3A)
                      : const Color(0xFF8C4A00),
                ),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: trailing,
      ),
    );
  }
}

class SchedulePreview extends StatelessWidget {
  const SchedulePreview({super.key, required this.upload, required this.onChange});

  final ScheduleUpload upload;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F3F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Color(0xFF0A7E8C)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upload.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Subido ${upload.uploadedAt.hour.toString().padLeft(2, '0')}:${upload.uploadedAt.minute.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }
}

class JustificantesPage extends StatefulWidget {
  const JustificantesPage({
    super.key,
    required this.user,
    required this.classes,
    required this.justificantes,
    required this.onSubmitJustificante,
    required this.onRefresh,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final List<Justificante> justificantes;
  final void Function({
    required ClassRoom cls,
    required String reason,
    required String imageLabel,
    required String imageUrlOverride,
  }) onSubmitJustificante;
  final Future<void> Function() onRefresh;

  @override
  State<JustificantesPage> createState() => _JustificantesPageState();
}

class _JustificantesPageState extends State<JustificantesPage> {
  int? selectedClassId;
  String? selectedFileName;
  String? selectedImageDataUrl;

  @override
  Widget build(BuildContext context) {
    final joined = widget.classes.where((c) => c.enrollmentStatus == 'approved').toList();
    // Asegura que el valor seleccionado exista en la lista actual
    if (selectedClassId != null && !joined.any((c) => c.id == selectedClassId)) {
      selectedClassId = null;
    }
    final selectedClass =
        selectedClassId == null ? null : joined.firstWhere((c) => c.id == selectedClassId);
    final myJusts = widget.justificantes.where((j) => j.studentId == widget.user.id).toList();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Justificantes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF073F50),
                ),
              ),
              IconButton(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enviados: ${myJusts.length}',
            style: const TextStyle(color: Color(0xFF073F50), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButton<int>(
            value: selectedClassId,
            hint: const Text('Selecciona clase'),
            items: joined
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    ))
                .toList(),
            onChanged: (id) => setState(() => selectedClassId = id),
          ),
          const SizedBox(height: 12),
          if (selectedClass != null)
            JustificanteForm(
              cls: selectedClass!,
              onSubmit: widget.onSubmitJustificante,
              user: widget.user,
              onPickFile: (name, dataUrl) {
                setState(() {
                  selectedFileName = name;
                  selectedImageDataUrl = dataUrl;
                });
              },
              selectedFileName: selectedFileName,
              selectedFileUrl: selectedImageDataUrl,
            ),
          const SizedBox(height: 12),
          if (selectedClass != null)
            ...widget.justificantes
                .where((j) =>
                    j.studentEmail == widget.user.email &&
                    j.classId == selectedClass!.id)
                .map(
                  (j) => TweenAnimationBuilder<double>(
                    key: ValueKey('std-just-${j.id}'),
                    duration: const Duration(milliseconds: 220),
                    tween: Tween(begin: 0.95, end: 1),
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildThumb(j.imageUrl, j.imageLabel),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        j.imageLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF073F50),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(j.reason),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(_statusLabel(j.status)),
                                  backgroundColor: _statusColor(j.status).withValues(alpha: 0.15),
                                  labelStyle: TextStyle(
                                    color: _statusColor(j.status),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            justificantePreviewImage(j.imageUrl, j.imageLabel, height: 170),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      showJustificanteViewer(context, j.imageUrl, j.imageLabel),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Ver'),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () =>
                                      downloadJustificanteImage(context, j.imageUrl, j.imageLabel),
                                  icon: const Icon(Icons.download_outlined),
                                  label: const Text('Descargar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  String _statusLabel(JustificanteStatus status) {
    switch (status) {
      case JustificanteStatus.pending:
        return 'Pendiente';
      case JustificanteStatus.approved:
        return 'Aprobado';
      case JustificanteStatus.rejected:
        return 'Rechazado';
    }
  }

  Color _statusColor(JustificanteStatus status) {
    switch (status) {
      case JustificanteStatus.pending:
        return const Color(0xFFEE9B00);
      case JustificanteStatus.approved:
        return const Color(0xFF0B8A3A);
      case JustificanteStatus.rejected:
        return const Color(0xFFC1121F);
    }
  }

  Widget _buildThumb(String url, String label) {
    if (url.startsWith('data:image/')) {
      try {
        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE5F3F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
              return const Icon(Icons.image_outlined);
            })
          : const Icon(Icons.image_outlined),
    );
  }
}

Widget justificantePreviewImage(
  String url,
  String label, {
  double height = 180,
}) {
  final placeholder = Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFE5F3F6),
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, size: 40, color: Color(0xFF4F6F77)),
  );

  if (url.isEmpty) return placeholder;

  if (url.startsWith('data:image/')) {
    try {
      final base64Data = url.split(',').last;
      final bytes = base64Decode(base64Data);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return placeholder;
    }
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE5F3F6),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                : null,
          ),
        );
      },
    ),
  );
}

Future<void> downloadJustificanteImage(
  BuildContext context,
  String imageUrl,
  String imageLabel,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await _readImageBytes(imageUrl);
    if (bytes == null) throw Exception('Imagen no disponible');
    final filename = _sanitizeFileName(imageLabel, imageUrl);
    final saved = await saveImageBytes(filename, bytes);
    if (!saved) throw Exception('Descarga no disponible en esta plataforma');
    messenger.showSnackBar(
      SnackBar(content: Text('Imagen descargada: $filename')),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('No se pudo descargar: ${e.toString()}')),
    );
  }
}

void showJustificanteViewer(
  BuildContext context,
  String imageUrl,
  String imageLabel,
) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                imageLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF073F50),
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 440, maxWidth: 520),
                child: InteractiveViewer(
                  child: justificantePreviewImage(imageUrl, imageLabel, height: 380),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        downloadJustificanteImage(context, imageUrl, imageLabel),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Descargar'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<Uint8List?> _readImageBytes(String imageUrl) async {
  if (imageUrl.isEmpty) return null;
  if (imageUrl.startsWith('data:image/')) {
    try {
      final base64Data = imageUrl.split(',').last;
      return base64Decode(base64Data);
    } catch (_) {
      return null;
    }
  }
  final uri = Uri.tryParse(imageUrl);
  if (uri == null) return null;
  final res = await http.get(uri);
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return res.bodyBytes;
  }
  throw Exception('Respuesta ${res.statusCode}');
}

String _sanitizeFileName(String label, String imageUrl) {
  final base = (label.isNotEmpty ? label : 'justificante').trim();
  final cleaned = base.replaceAll(RegExp(r'[\\\\/:*?"<>|]'), '_');
  final extension = _inferImageExtension(cleaned, imageUrl);
  if (cleaned.toLowerCase().endsWith(extension.toLowerCase())) return cleaned;
  return '$cleaned$extension';
}

String _inferImageExtension(String fileName, String imageUrl) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return '.png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return '.jpg';

  final lowerUrl = imageUrl.toLowerCase();
  if (lowerUrl.contains('image/png') || lowerUrl.endsWith('.png')) return '.png';
  if (lowerUrl.contains('image/jpg') ||
      lowerUrl.contains('image/jpeg') ||
      lowerUrl.endsWith('.jpg') ||
      lowerUrl.endsWith('.jpeg')) {
    return '.jpg';
  }
  return '.png';
}

class PerceptionsPage extends StatefulWidget {
  const PerceptionsPage({
    super.key,
    required this.user,
    required this.classes,
    required this.perceptions,
    required this.onSubmitPerception,
    required this.onRefresh,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final List<Map<String, dynamic>> perceptions;
  final Future<bool> Function({
    required ClassRoom cls,
    required int subjectId,
    required DateTime perceptionDate,
    required String level,
    String? note,
  }) onSubmitPerception;
  final Future<void> Function() onRefresh;

  @override
  State<PerceptionsPage> createState() => _PerceptionsPageState();
}

class _PerceptionsPageState extends State<PerceptionsPage> {
  int? selectedClassId;
  late final DateTime currentMonth;
  int selectedDay = DateTime.now().day;
  String level = 'tranquilo';
  final noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentMonth = DateTime(now.year, now.month);
  }

  int _daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;

  String _monthLabel(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatPerceptionDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'Fecha desconocida';
    final twoDigits = (int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(parsed.day)}/${twoDigits(parsed.month)}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final joined = widget.classes.where((c) => c.enrollmentStatus == 'approved').toList();
    final myPerceptions = widget.perceptions
        .where((p) => p['studentId'] == widget.user.id)
        .toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Percepción diaria',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF073F50),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: selectedClassId,
              hint: const Text('Clase'),
              isExpanded: true,
              items: joined
                  .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (id) => setState(() => selectedClassId = id),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Día (${_monthLabel(currentMonth)})'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: selectedDay,
                  items: List.generate(_daysInMonth(currentMonth), (i) => i + 1)
                      .map(
                        (d) => DropdownMenuItem(value: d, child: Text('Día $d')),
                      )
                      .toList(),
                  onChanged: (d) => setState(() => selectedDay = d ?? selectedDay),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _levelChip('estrés alto', '😣'),
                _levelChip('carga media', '😕'),
                _levelChip('tranquilo', '🙂'),
                _levelChip('muy bien', '😄'),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: selectedClassId == null
                    ? null
                    : () async {
                        final date = DateTime(
                          currentMonth.year,
                          currentMonth.month,
                          selectedDay,
                        );
                        final ok = await widget.onSubmitPerception(
                          cls: joined.firstWhere((c) => c.id == selectedClassId),
                          subjectId: selectedClassId!, // clase se usa como materia
                          perceptionDate: date,
                          level: level,
                          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        );
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Percepción registrada')),
                          );
                          noteCtrl.clear();
                        }
                      },
                child: const Text('Enviar percepción'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Historial',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF073F50),
              ),
            ),
            const SizedBox(height: 8),
            ...myPerceptions.map(
              (p) => Card(
                child: ListTile(
                  title: Text(
                    '${_formatPerceptionDate(p['perceptionDate'] ?? p['createdAt'])} · Clase ${p['class']?['name'] ?? p['classId'] ?? ''}',
                  ),
                  subtitle: Text('${p['level']} ${p['note'] != null ? '\n${p['note']}' : ''}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelChip(String value, String emoji) {
    final active = level == value;
    return ChoiceChip(
      label: Text('$emoji $value'),
      selected: active,
      onSelected: (_) => setState(() => level = value),
    );
  }
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    required this.user,
    required this.classes,
    required this.messages,
    required this.onSend,
    required this.onRefresh,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final List<Map<String, dynamic>> messages;
  final Future<void> Function({
    int? classId,
    int? toStudentId,
    required String title,
    required String body,
  }) onSend;
  final Future<void> Function() onRefresh;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  int? selectedId;

  @override
  void initState() {
    super.initState();
    final joined = _joinedClasses();
    if (joined.isNotEmpty) selectedId = joined.first.id;
  }

  List<ClassRoom> _joinedClasses() {
    return widget.user.role == UserRole.student
        ? widget.classes.where((c) => c.enrollmentStatus == 'approved').toList()
        : widget.classes.where((c) => c.teacherEmail == widget.user.email).toList();
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joinedClasses();
    if (selectedId != null && joined.every((c) => c.id != selectedId)) {
      selectedId = joined.isNotEmpty ? joined.first.id : null;
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mensajes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF073F50),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: selectedId,
              isExpanded: true,
              hint: const Text('Clase'),
              items: joined
                  .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (id) => setState(() => selectedId = id),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mensaje'),
            ),
            const SizedBox(height: 8),
            if (widget.user.role == UserRole.teacher)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selectedId == null
                      ? null
                      : () async {
                          await widget.onSend(
                            classId: selectedId,
                            title: titleCtrl.text.trim(),
                            body: bodyCtrl.text.trim(),
                          );
                          titleCtrl.clear();
                          bodyCtrl.clear();
                        },
                  child: const Text('Enviar'),
                ),
              ),
            const SizedBox(height: 12),
            ...widget.messages.map(
              (m) => Card(
                child: ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(m['title']?.toString() ?? 'Mensaje'),
                  subtitle: Text(m['body']?.toString() ?? ''),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.classes,
    required this.onSend,
    required this.isTutor,
  });

  final List<ClassRoom> classes;
  final Future<void> Function({
    int? classId,
    int? toStudentId,
    required String title,
    required String body,
  }) onSend;
  final bool isTutor;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  int? selectedClassId;

  @override
  void initState() {
    super.initState();
    if (widget.classes.isNotEmpty) {
      selectedClassId = widget.classes.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.classes;
    if (selectedClassId != null && available.every((c) => c.id != selectedClassId)) {
      selectedClassId = available.isNotEmpty ? available.first.id : null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<int>(
          value: selectedClassId,
          hint: const Text('Clase'),
          isExpanded: true,
          items: available
              .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
              .toList(),
          onChanged: (id) => setState(() => selectedClassId = id),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: bodyCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Mensaje'),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: selectedClassId == null
                ? null
                : () async {
                    final clsId = selectedClassId!;
                    await widget.onSend(
                      classId: clsId,
                      title: titleCtrl.text.trim(),
                      body: bodyCtrl.text.trim(),
                    );
                    titleCtrl.clear();
                    bodyCtrl.clear();
                  },
            child: const Text('Enviar'),
          ),
        ),
      ],
    );
  }
}

class JustificanteForm extends StatefulWidget {
  const JustificanteForm({
    super.key,
    required this.cls,
    required this.onSubmit,
    required this.user,
    required this.onPickFile,
    this.selectedFileName,
    this.selectedFileUrl,
  });

  final ClassRoom cls;
  final UserAccount user;
  final void Function({
    required ClassRoom cls,
    required String reason,
    required String imageLabel,
    required String imageUrlOverride,
  }) onSubmit;
  final void Function(String? name, String? dataUrl) onPickFile;
  final String? selectedFileName;
  final String? selectedFileUrl;

  @override
  State<JustificanteForm> createState() => _JustificanteFormState();
}

class _JustificanteFormState extends State<JustificanteForm> {
  final reasonCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final fileName = widget.selectedFileName ?? 'Seleccionar imagen';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.cls.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF073F50),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo o comentario',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final res = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['png', 'jpg'],
                  withData: true,
                );
                if (res == null) return;
                final f = res.files.single;
                if (f.bytes == null) return;
                // Rechaza imágenes mayores a 500 KB.
                const int maxBytes = 500 * 1024;
                if (f.bytes!.length > maxBytes) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Imagen muy pesada (${(f.bytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB). Usa otra menor a 2 MB.',
                      ),
                    ),
                  );
                  return;
                }
                final ext = (f.extension ?? 'png').toLowerCase();
                final dataUrl = 'data:image/$ext;base64,${base64Encode(f.bytes!)}';
                widget.onPickFile(f.name, dataUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Imagen seleccionada: ${f.name}')),
                );
              },
              icon: const Icon(Icons.image_outlined),
              label: Text(fileName),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.selectedFileName == null
                    ? null
                      : () {
                          widget.onSubmit(
                            cls: widget.cls,
                            reason: reasonCtrl.text.trim(),
                            imageLabel: widget.selectedFileName ?? 'imagen.png',
                            imageUrlOverride:
                                widget.selectedFileUrl?.isNotEmpty == true
                                    ? widget.selectedFileUrl!
                                    : (widget.selectedFileName ?? 'imagen'),
                          );
                          reasonCtrl.clear();
                          widget.onPickFile(null, null);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Justificante enviado')),
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0A7E8C),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Enviar justificante'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeacherShell extends StatefulWidget {
  const TeacherShell({
    super.key,
    required this.user,
    required this.classes,
    required this.moodEntries,
    required this.justificantes,
    required this.perceptions,
    required this.alerts,
    required this.messages,
    required this.dashboardSummary,
    required this.onCreateClass,
    required this.onViewClassMembers,
    required this.onLogout,
    required this.onUpdateJustificante,
    required this.onReviewEnrollment,
    required this.onMarkMoodRead,
    required this.onSendMessage,
    required this.onResolveAlert,
    required this.onRefresh,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final List<MoodEntry> moodEntries;
  final List<Justificante> justificantes;
  final List<Map<String, dynamic>> perceptions;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic> dashboardSummary;
  final void Function(String name, BuildContext context) onCreateClass;
  final Future<void> Function(ClassRoom cls, BuildContext context) onViewClassMembers;
  final VoidCallback onLogout;
  final void Function(Justificante justificante, JustificanteStatus status)
      onUpdateJustificante;
  final void Function(int enrollmentId, String status, BuildContext context)
      onReviewEnrollment;
  final void Function(int moodId) onMarkMoodRead;
  final Future<void> Function({
    int? classId,
    int? toStudentId,
    required String title,
    required String body,
  }) onSendMessage;
  final Future<void> Function(int id) onResolveAlert;
  final Future<void> Function() onRefresh;

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final myClasses =
        widget.classes.where((c) => c.teacherEmail == widget.user.email).toList();

    final pages = [
      TeacherClassesPage(
        classes: myClasses,
        onCreate: widget.onCreateClass,
        onViewMembers: widget.onViewClassMembers,
      ),
      TeacherPanel(
        classes: myClasses,
        moodEntries: widget.moodEntries,
        justificantes: widget.justificantes,
        perceptions: widget.perceptions,
        alerts: widget.alerts,
        messages: widget.messages,
        dashboardSummary: widget.dashboardSummary,
        onUpdateJustificante: widget.onUpdateJustificante,
        onReviewEnrollment: widget.onReviewEnrollment,
        onMarkMoodRead: widget.onMarkMoodRead,
        onSendMessage: widget.onSendMessage,
        onResolveAlert: widget.onResolveAlert,
        onRefresh: widget.onRefresh,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('feelday - Profesor 🎓'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: const AssetImage('assets/images/logo.png'),
            backgroundColor: Colors.white,
            onBackgroundImageError: (_, __) {},
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            label: 'Clases',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: 'Panel',
          ),
        ],
      ),
    );
  }
}

class TeacherClassesPage extends StatefulWidget {
  const TeacherClassesPage({
    super.key,
    required this.classes,
    required this.onCreate,
    required this.onViewMembers,
  });

  final List<ClassRoom> classes;
  final void Function(String name, BuildContext context) onCreate;
  final Future<void> Function(ClassRoom cls, BuildContext context) onViewMembers;

  @override
  State<TeacherClassesPage> createState() => _TeacherClassesPageState();
}

class _TeacherClassesPageState extends State<TeacherClassesPage> {
  final nameCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Crear clase',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF073F50),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la clase',
                      prefixIcon: Icon(Icons.class_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        widget.onCreate(nameCtrl.text.trim(), context);
                        nameCtrl.clear();
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Clase creada')),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0A7E8C),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Crear'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Mis clases',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF073F50),
            ),
          ),
          const SizedBox(height: 8),
          ...widget.classes.map(
            (c) => Card(
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(c.name),
                subtitle: Text('Código: ${c.code}\nAlumnos: ${c.studentCount}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onViewMembers(c, context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherPanel extends StatelessWidget {
  const TeacherPanel({
    super.key,
    required this.classes,
    required this.moodEntries,
    required this.justificantes,
    required this.perceptions,
    required this.alerts,
    required this.messages,
    required this.dashboardSummary,
    required this.onUpdateJustificante,
    required this.onReviewEnrollment,
    required this.onMarkMoodRead,
    required this.onSendMessage,
    required this.onResolveAlert,
    required this.onRefresh,
  });

  final List<ClassRoom> classes;
  final List<MoodEntry> moodEntries;
  final List<Justificante> justificantes;
  final List<Map<String, dynamic>> perceptions;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic> dashboardSummary;
  final void Function(Justificante justificante, JustificanteStatus status)
      onUpdateJustificante;
  final void Function(int enrollmentId, String status, BuildContext context)
      onReviewEnrollment;
  final void Function(int moodId) onMarkMoodRead;
  final Future<void> Function({
    int? classId,
    int? toStudentId,
    required String title,
    required String body,
  }) onSendMessage;
  final Future<void> Function(int id) onResolveAlert;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final allMoodEntries = moodEntries;
    final allJustificantes = justificantes;
    final pending = classes
        .expand((c) => c.pendingEnrollments.map((e) => {'req': e, 'className': c.name}))
        .toList();
    final weeklyPerceptionSummary = (dashboardSummary['weeklyPerceptionSummary'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pending.isNotEmpty) ...[
              const Text(
                'Solicitudes de ingreso',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF073F50),
                ),
              ),
              const SizedBox(height: 8),
              ...pending.map((p) {
                final EnrollmentRequest req = p['req'] as EnrollmentRequest;
                final className = p['className'] as String;
                return Card(
                  child: ListTile(
                    title: Text('${req.studentName} (${req.studentEmail})'),
                    subtitle: Text('Clase: $className · Estado: ${req.status}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Aprobar',
                          onPressed: () => onReviewEnrollment(req.id, 'approved', context),
                          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF0B8A3A)),
                        ),
                        IconButton(
                          tooltip: 'Rechazar',
                          onPressed: () => onReviewEnrollment(req.id, 'rejected', context),
                          icon: const Icon(Icons.cancel_outlined, color: Color(0xFFC1121F)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
          if (dashboardSummary.isNotEmpty) ...[
            const Text(
              'Resumen del grupo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF073F50),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text(
                    'Check-in semana: ${(((dashboardSummary['checkInRate'] as num? ?? 0) * 100)).toStringAsFixed(0)}%'),
                subtitle: Text(
                  'Alumnos: ${dashboardSummary['studentCount'] ?? 0} · Ánimos bajos: ${dashboardSummary['lowMoodCount'] ?? 0}',
                ),
              ),
            ),
            if ((dashboardSummary['topStressSubjects'] as List? ?? []).isNotEmpty)
              Card(
                child: ListTile(
                  title: const Text('Top materias con estrés'),
                  subtitle: Text(
                    (dashboardSummary['topStressSubjects'] as List<dynamic>)
                        .map((e) => '${e['subject']}: ${e['score']}')
                        .join(' · '),
                  ),
                ),
              ),
            if (weeklyPerceptionSummary.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seguimiento semanal de percepciones',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      ...weeklyPerceptionSummary.map(
                        (w) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(w['week']?.toString() ?? ''),
                              Text(
                                'Total: ${w['total'] ?? 0} · Estrés: ${w['stress'] ?? 0}',
                                style: const TextStyle(color: Color(0xFF073F50)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if ((dashboardSummary['justificanteHistogram'] as List? ?? []).isNotEmpty)
              Card(
                child: ListTile(
                  title: const Text('Justificantes por tipo'),
                  subtitle: Text(
                    (dashboardSummary['justificanteHistogram'] as List<dynamic>)
                        .map((e) => '${e['type']}: ${e['count']}')
                        .join(' · '),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Alertas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF073F50),
            ),
          ),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle, color: Color(0xFF0B8A3A)),
                title: Text('Sin alertas activas'),
              ),
            )
          else
            ...alerts.map(
              (a) => Card(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFC1121F)),
                  title: Text('${a['description'] ?? ''}'),
                  subtitle: Text('Tipo: ${a['type']} · Severidad: ${a['severity']}'),
                  trailing: a['resolved'] == true
                      ? const Icon(Icons.check, color: Color(0xFF0B8A3A))
                      : TextButton(
                          onPressed: () => onResolveAlert(a['id'] as int),
                          child: const Text('Resolver'),
                        ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Mensajes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF073F50),
            ),
          ),
          const SizedBox(height: 8),
          MessageComposer(
            classes: classes,
            onSend: onSendMessage,
            isTutor: true,
          ),
          const SizedBox(height: 8),
          ...messages.map(
            (m) => Card(
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(m['title']?.toString() ?? 'Mensaje'),
                subtitle: Text(m['body']?.toString() ?? ''),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                  'Panel de emociones',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF073F50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (allMoodEntries.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.sentiment_satisfied_alt, color: Color(0xFF0A7E8C)),
                  title: Text('Aún no hay emociones enviadas'),
                  subtitle: Text('Pide a tus alumnos que registren su estado de ánimo.'),
                ),
              )
            else
              ...allMoodEntries.map(
                (m) => TweenAnimationBuilder<double>(
                  key: ValueKey('mood-${m.classId}-${m.studentId}-${m.createdAt.toIso8601String()}'),
                  duration: const Duration(milliseconds: 220),
                  tween: Tween(begin: 0.95, end: 1),
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Card(
                    color: m.scheduleFileName.isNotEmpty
                        ? Colors.white
                        : const Color(0xFFFFF4E5),
                    child: ListTile(
                      leading: Text(_emojiForMood(m.mood), style: const TextStyle(fontSize: 26)),
                      title: Text('${m.studentName.isNotEmpty ? m.studentName : m.studentEmail} · ${m.className} (${m.day})'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.comment),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFFB00020)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  m.scheduleFileName.isNotEmpty
                                      ? m.scheduleFileName
                                      : 'Sin horario adjunto',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: false,
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m.mood.toStringAsFixed(0),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0A7E8C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (!m.teacherRead)
                            TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                              onPressed: () => onMarkMoodRead(m.id),
                              child: const Text('Marcar leído'),
                            )
                          else
                            const Icon(Icons.check_circle, color: Color(0xFF0B8A3A), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Justificantes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF073F50),
              ),
            ),
            const SizedBox(height: 8),
            ...allJustificantes.map(
              (j) => TweenAnimationBuilder<double>(
                key: ValueKey('teach-just-${j.id}'),
                duration: const Duration(milliseconds: 230),
                tween: Tween(begin: 0.95, end: 1),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildThumb(j.imageUrl, j.imageLabel),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${j.studentName.isNotEmpty ? j.studentName : j.studentEmail} · ${j.className}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF073F50),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(j.reason),
                                  const SizedBox(height: 4),
                                  Text(
                                    j.imageLabel,
                                    style: const TextStyle(color: Color(0xFF4F6F77)),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Aprobar',
                                  onPressed: () =>
                                      onUpdateJustificante(j, JustificanteStatus.approved),
                                  icon:
                                      const Icon(Icons.check_circle_outline, color: Color(0xFF0B8A3A)),
                                ),
                                IconButton(
                                  tooltip: 'Rechazar',
                                  onPressed: () =>
                                      onUpdateJustificante(j, JustificanteStatus.rejected),
                                  icon:
                                      const Icon(Icons.cancel_outlined, color: Color(0xFFC1121F)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        justificantePreviewImage(j.imageUrl, j.imageLabel, height: 190),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  showJustificanteViewer(context, j.imageUrl, j.imageLabel),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Ver'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  downloadJustificanteImage(context, j.imageUrl, j.imageLabel),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Descargar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emojiForMood(double mood) {
    if (mood <= 20) return '😞';
    if (mood <= 40) return '🙁';
    if (mood <= 60) return '😐';
    if (mood <= 80) return '🙂';
    return '😄';
  }

  Widget _buildThumb(String url, String label) {
    if (url.startsWith('data:image/')) {
      try {
        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE5F3F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
              return const Icon(Icons.image_outlined);
            })
          : const Icon(Icons.image_outlined),
    );
  }
}
