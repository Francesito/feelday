import 'dart:math';

import 'package:flutter/material.dart';
import 'api_client.dart';

void main() {
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
  });

  final int id;
  final String name;
  final String code;
  final String teacherEmail;
  final String teacherName;
  final bool joined;
  final int studentCount;
  final List<String> studentEmails = [];
  final Map<String, ScheduleUpload> schedules = {};
  final List<MoodEntry> moodEntries = [];
  final List<Justificante> justificantes = [];
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
    required this.studentId,
    required this.studentEmail,
    required this.classId,
    required this.className,
    required this.day,
    required this.mood,
    required this.comment,
    required this.scheduleFileName,
    required this.createdAt,
  });

  final int studentId;
  final String studentEmail;
  final int classId;
  final String className;
  final String day;
  final double mood;
  final String comment;
  final String scheduleFileName;
  final DateTime createdAt;
}

class Justificante {
  Justificante({
    required this.id,
    required this.studentId,
    required this.studentEmail,
    required this.classId,
    required this.className,
    required this.reason,
    required this.imageLabel,
    this.status = JustificanteStatus.pending,
  });

  final int id;
  final int studentId;
  final String studentEmail;
  final int classId;
  final String className;
  final String reason;
  final String imageLabel;
  JustificanteStatus status;
}

enum JustificanteStatus { pending, approved, rejected }

class FeeldayApp extends StatefulWidget {
  const FeeldayApp({super.key});

  @override
  State<FeeldayApp> createState() => _FeeldayAppState();
}

class _FeeldayAppState extends State<FeeldayApp> {
  final ApiClient _api = ApiClient(baseUrl: 'https://feelday.onrender.com');
  final List<ClassRoom> _classes = [];
  final List<MoodEntry> _allMoodEntries = [];
  final List<Justificante> _allJustificantes = [];
  final Map<int, ScheduleUpload> _mySchedules = {};
  UserAccount? _currentUser;
  String _resetEmailMessage = '';
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
            onReset: _handleReset,
            resetMessage: _resetEmailMessage,
          )
        : _currentUser!.role == UserRole.student
            ? StudentShell(
                user: _currentUser!,
                classes: _classes,
                schedules: _mySchedules,
                moodEntries: _allMoodEntries,
                justificantes: _allJustificantes,
                onJoinClass: _joinClass,
                onLogout: _logout,
                onUploadSchedule: _uploadSchedule,
                onSubmitMood: _submitMood,
                onSubmitJustificante: ({required cls, required reason, required imageLabel}) =>
                    _submitJustificante(
                  cls: cls,
                  reason: reason,
                  imageLabel: imageLabel,
                  context: context,
                ),
                onRefresh: _refreshData,
              )
            : TeacherShell(
                user: _currentUser!,
                classes: _classes,
                moodEntries: _allMoodEntries,
                justificantes: _allJustificantes,
                onCreateClass: (name, ctx) => _createClass(name, ctx),
                onLogout: _logout,
                onUpdateJustificante: _updateJustificanteStatus,
              );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'feelday',
      theme: theme,
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

  Future<void> _handleReset(String email, BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await _api.forgot(email);
      setState(() {
        _resetEmailMessage = data['message']?.toString() ?? 'Solicitud enviada';
      });
      messenger.showSnackBar(
        SnackBar(content: Text(_resetEmailMessage)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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

  Future<void> _uploadSchedule(ClassRoom cls, String fileName) async {
    if (_currentUser == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final fakeUrl = 'https://files.example/$fileName';
    try {
      final res = await _api.submitSchedule({
        'classId': cls.id,
        'fileUrl': fakeUrl,
        'fileName': fileName,
      });
      final upload = ScheduleUpload(
        classId: cls.id,
        studentId: _currentUser!.id,
        fileName: res['fileName'] as String? ?? fileName,
        fileUrl: res['fileUrl'] as String? ?? fakeUrl,
        uploadedAt: DateTime.now(),
      );
      setState(() {
        _mySchedules[cls.id] = upload;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submitMood({
    required ClassRoom cls,
    required double mood,
    required String comment,
    required String day,
    required String scheduleFileName,
  }) async {
    if (_currentUser == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await _api.submitMood({
        'classId': cls.id,
        'moodValue': mood.toInt(),
        'comment': comment,
        'dayLabel': day,
        'scheduleFileName': scheduleFileName,
      });
      final entry = MoodEntry(
        studentId: _currentUser!.id,
        studentEmail: _currentUser!.email,
        classId: cls.id,
        className: cls.name,
        day: day,
        mood: mood,
        comment: comment,
        scheduleFileName: scheduleFileName,
        createdAt: DateTime.parse(res['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      );
      setState(() {
        _allMoodEntries.insert(0, entry);
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submitJustificante({
    required ClassRoom cls,
    required String reason,
    required String imageLabel,
    required BuildContext context,
  }) async {
    if (_currentUser == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final fakeUrl = 'https://files.example/$imageLabel';
    try {
      final res = await _api.submitJustificante({
        'classId': cls.id,
        'reason': reason,
        'imageUrl': fakeUrl,
        'imageName': imageLabel,
      });
      final j = Justificante(
        id: res['id'] as int? ?? Random().nextInt(999999),
        studentId: _currentUser!.id,
        studentEmail: _currentUser!.email,
        classId: cls.id,
        className: cls.name,
        reason: reason,
        imageLabel: imageLabel,
      );
      setState(() {
        _allJustificantes.insert(0, j);
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Justificante enviado')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _updateJustificanteStatus(
    Justificante justificante,
    JustificanteStatus status,
  ) async {
    try {
      await _api.updateJustificanteStatus(justificante.id, status.name);
      setState(() {
        justificante.status = status;
      });
    } catch (_) {}
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
          return ClassRoom(
            id: c['id'] as int,
            name: c['name'] as String,
            code: c['code'] as String,
            teacherEmail: teacher?['email']?.toString() ?? '',
            teacherName: teacher?['fullName']?.toString() ?? '',
            joined: enrollments.isNotEmpty || _currentUser!.role == UserRole.teacher,
            studentCount: enrollments.length,
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
            studentId: student['id'] as int? ?? 0,
            studentEmail: student['email']?.toString() ?? '',
            classId: cls['id'] as int? ?? (m['classId'] as int? ?? 0),
            className: cls['name']?.toString() ?? '',
            day: m['dayLabel']?.toString() ?? '',
            mood: (m['moodValue'] as num? ?? 0).toDouble(),
            comment: m['comment']?.toString() ?? '',
            scheduleFileName: m['scheduleFileName']?.toString() ?? '',
            createdAt: DateTime.parse(
              m['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
            ),
          );
        }));

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
            classId: cls['id'] as int? ?? 0,
            className: cls['name']?.toString() ?? '',
            reason: j['reason']?.toString() ?? '',
            imageLabel: j['imageName']?.toString() ?? '',
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
    required this.onReset,
    required this.resetMessage,
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
  final Future<void> Function(String email, BuildContext context) onReset;
  final String resetMessage;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A7E8C), Color(0xFF073F50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 26),
              Text(
                'feelday',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bienvenido, gestiona tus clases y estados de ánimo',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
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
                            onForgot: () => setState(() => _index = 2),
                          )
                        : _index == 1
                            ? RegisterCard(
                                key: const ValueKey('register'),
                                onRegister: widget.onRegister,
                                onBack: () => setState(() => _index = 0),
                              )
                            : ResetCard(
                                key: const ValueKey('reset'),
                                onReset: widget.onReset,
                                lastMessage: widget.resetMessage,
                                onBack: () => setState(() => _index = 0),
                              ),
                  ),
                ),
              ),
            ],
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
    required this.onForgot,
  });

  final Future<void> Function(String email, String password, BuildContext context)
      onLogin;
  final VoidCallback onChangePage;
  final VoidCallback onForgot;

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final emailCtrl = TextEditingController(text: 'alumno@feelday.com');
  final passCtrl = TextEditingController(text: 'feelday123');
  bool hide = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inicia sesión',
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
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passCtrl,
            obscureText: hide,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => hide = !hide),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onForgot,
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          const SizedBox(height: 6),
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
                child: const Text('Crear cuenta'),
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
                'Crear cuenta',
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
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passCtrl,
            obscureText: hide,
            decoration: InputDecoration(
              labelText: 'Contraseña',
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

class ResetCard extends StatefulWidget {
  const ResetCard({
    super.key,
    required this.onReset,
    required this.lastMessage,
    required this.onBack,
  });

  final Future<void> Function(String email, BuildContext context) onReset;
  final String lastMessage;
  final VoidCallback onBack;

  @override
  State<ResetCard> createState() => _ResetCardState();
}

class _ResetCardState extends State<ResetCard> {
  final emailCtrl = TextEditingController();

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
                'Recuperar contraseña',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF073F50),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  widget.onReset(emailCtrl.text.trim(), context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF0A7E8C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Enviar enlace'),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.lastMessage.isNotEmpty)
            Text(
              widget.lastMessage,
              style: const TextStyle(color: Color(0xFF073F50)),
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
    required this.onJoinClass,
    required this.onLogout,
    required this.onUploadSchedule,
    required this.onSubmitMood,
    required this.onSubmitJustificante,
    required this.onRefresh,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final Map<int, ScheduleUpload> schedules;
  final List<MoodEntry> moodEntries;
  final List<Justificante> justificantes;
  final void Function(String code, BuildContext context) onJoinClass;
  final VoidCallback onLogout;
  final void Function(ClassRoom cls, String fileName) onUploadSchedule;
  final void Function({
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
  }) onSubmitJustificante;
  final Future<void> Function() onRefresh;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      StudentClassesPage(
        user: widget.user,
        classes: widget.classes,
        schedules: widget.schedules,
        moodEntries: widget.moodEntries,
        onJoinClass: widget.onJoinClass,
        onUploadSchedule: widget.onUploadSchedule,
        onSubmitMood: widget.onSubmitMood,
        onRefresh: widget.onRefresh,
      ),
      JustificantesPage(
        user: widget.user,
        classes: widget.classes,
        justificantes: widget.justificantes,
        onSubmitJustificante: widget.onSubmitJustificante,
        onRefresh: widget.onRefresh,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('feelday - Alumno'),
        backgroundColor: Colors.white,
        elevation: 0,
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
  final void Function(ClassRoom cls, String fileName) onUploadSchedule;
  final void Function({
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
    final joined = widget.classes.where((c) => c.joined).toList();
    final available = widget.classes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              trailing: IconButton(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cls.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF073F50),
                  ),
                ),
                Chip(
                  label: Text(_selectedDay),
                  avatar: const Icon(Icons.calendar_today, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (schedule == null)
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
              onChanged: (v) => setState(() => _mood = v),
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
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedFile == null
                    ? null
                    : () {
                        widget.onSubmitMood(
                          cls: cls,
                          mood: _mood,
                          comment: commentCtrl.text,
                          day: _selectedDay,
                          scheduleFileName: _selectedFile ?? 'Horario',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enviado al maestro'),
                          ),
                        );
                        commentCtrl.clear();
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
    final controller = TextEditingController(text: 'horario.pdf');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seleccionar PDF'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre del archivo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              widget.onUploadSchedule(cls, controller.text.trim());
              setState(() => _selectedFile = controller.text.trim());
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A7E8C),
            ),
            child: const Text('Usar archivo'),
          ),
        ],
      ),
    );
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
          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF073F50)),
        ),
        subtitle: Text('Código: ${cls.code}\nProfesor: ${cls.teacherEmail}'),
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
  }) onSubmitJustificante;
  final Future<void> Function() onRefresh;

  @override
  State<JustificantesPage> createState() => _JustificantesPageState();
}

class _JustificantesPageState extends State<JustificantesPage> {
  ClassRoom? selectedClass;

  @override
  Widget build(BuildContext context) {
    final joined = widget.classes
        .where((c) => c.studentEmails.contains(widget.user.email))
        .toList();
    return Padding(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 8),
          DropdownButton<ClassRoom>(
            value: selectedClass,
            hint: const Text('Selecciona clase'),
            items: joined
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.name),
                    ))
                .toList(),
            onChanged: (c) => setState(() => selectedClass = c),
          ),
          const SizedBox(height: 12),
          if (selectedClass != null)
            JustificanteForm(
              cls: selectedClass!,
              onSubmit: widget.onSubmitJustificante,
              user: widget.user,
            ),
          const SizedBox(height: 12),
          if (selectedClass != null)
            ...widget.justificantes
                .where((j) =>
                    j.studentEmail == widget.user.email &&
                    j.classId == selectedClass!.id)
                .map(
                  (j) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.image_outlined),
                      title: Text(j.imageLabel),
                      subtitle: Text(j.reason),
                      trailing: Chip(
                        label: Text(_statusLabel(j.status)),
                        backgroundColor: _statusColor(j.status).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _statusColor(j.status),
                          fontWeight: FontWeight.w700,
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
}

class JustificanteForm extends StatefulWidget {
  const JustificanteForm({
    super.key,
    required this.cls,
    required this.onSubmit,
    required this.user,
  });

  final ClassRoom cls;
  final UserAccount user;
  final void Function({
    required ClassRoom cls,
    required String reason,
    required String imageLabel,
  }) onSubmit;

  @override
  State<JustificanteForm> createState() => _JustificanteFormState();
}

class _JustificanteFormState extends State<JustificanteForm> {
  final reasonCtrl = TextEditingController();
  final imageCtrl = TextEditingController(text: 'justificante.png');

  @override
  Widget build(BuildContext context) {
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
            TextField(
              controller: imageCtrl,
              decoration: const InputDecoration(
                labelText: 'Imagen adjunta (nombre)',
                prefixIcon: Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onSubmit(
                    cls: widget.cls,
                    reason: reasonCtrl.text.trim(),
                    imageLabel: imageCtrl.text.trim(),
                  );
                  reasonCtrl.clear();
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
    required this.onCreateClass,
    required this.onLogout,
    required this.onUpdateJustificante,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final List<MoodEntry> moodEntries;
  final List<Justificante> justificantes;
  final void Function(String name, BuildContext context) onCreateClass;
  final VoidCallback onLogout;
  final void Function(Justificante justificante, JustificanteStatus status)
      onUpdateJustificante;

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
      ),
      TeacherPanel(
        classes: myClasses,
        moodEntries: widget.moodEntries,
        justificantes: widget.justificantes,
        onUpdateJustificante: widget.onUpdateJustificante,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('feelday - Profesor'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
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
  });

  final List<ClassRoom> classes;
  final void Function(String name, BuildContext context) onCreate;

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
    required this.onUpdateJustificante,
  });

  final List<ClassRoom> classes;
  final List<MoodEntry> moodEntries;
  final List<Justificante> justificantes;
  final void Function(Justificante justificante, JustificanteStatus status)
      onUpdateJustificante;

  @override
  Widget build(BuildContext context) {
    final allMoodEntries = moodEntries;
    final allJustificantes = justificantes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estados de ánimo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF073F50),
            ),
          ),
          const SizedBox(height: 8),
          ...allMoodEntries.map(
            (m) => Card(
              child: ListTile(
                leading: Text(_emojiForMood(m.mood), style: const TextStyle(fontSize: 26)),
                title: Text('${m.studentEmail} · ${m.className} (${m.day})'),
                subtitle: Text('${m.comment}\nArchivo: ${m.scheduleFileName}'),
                isThreeLine: true,
                trailing: Text(
                  m.mood.toStringAsFixed(0),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A7E8C),
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
            (j) => Card(
              child: ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text('${j.studentEmail} · ${j.className}'),
                subtitle: Text('${j.imageLabel}\n${j.reason}'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Aprobar',
                      onPressed: () =>
                          onUpdateJustificante(j, JustificanteStatus.approved),
                      icon: const Icon(Icons.check_circle_outline, color: Color(0xFF0B8A3A)),
                    ),
                    IconButton(
                      tooltip: 'Rechazar',
                      onPressed: () =>
                          onUpdateJustificante(j, JustificanteStatus.rejected),
                      icon: const Icon(Icons.cancel_outlined, color: Color(0xFFC1121F)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
}
