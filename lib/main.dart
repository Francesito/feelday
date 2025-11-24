import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const FeeldayApp());
}

enum UserRole { student, teacher }

class UserAccount {
  UserAccount({
    required this.email,
    required this.password,
    required this.role,
    required this.displayName,
  });

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
  });

  final String id;
  final String name;
  final String code;
  final String teacherEmail;
  final List<String> studentEmails = [];
  final Map<String, ScheduleUpload> schedules = {};
  final List<MoodEntry> moodEntries = [];
  final List<Justificante> justificantes = [];
}

class ScheduleUpload {
  ScheduleUpload({required this.fileName, required this.uploadedAt});
  final String fileName;
  final DateTime uploadedAt;
}

class MoodEntry {
  MoodEntry({
    required this.studentEmail,
    required this.classId,
    required this.className,
    required this.teacherEmail,
    required this.day,
    required this.mood,
    required this.comment,
    required this.scheduleFileName,
    required this.createdAt,
  });

  final String studentEmail;
  final String classId;
  final String className;
  final String teacherEmail;
  final String day;
  final double mood;
  final String comment;
  final String scheduleFileName;
  final DateTime createdAt;
}

class Justificante {
  Justificante({
    required this.id,
    required this.studentEmail,
    required this.classId,
    required this.className,
    required this.reason,
    required this.imageLabel,
    this.status = JustificanteStatus.pending,
  });

  final String id;
  final String studentEmail;
  final String classId;
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
  final List<UserAccount> _accounts = [
    UserAccount(
      email: 'profe@feelday.com',
      password: 'feelday123',
      role: UserRole.teacher,
      displayName: 'Profe Demo',
    ),
    UserAccount(
      email: 'alumno@feelday.com',
      password: 'feelday123',
      role: UserRole.student,
      displayName: 'Alumno Demo',
    ),
  ];

  final List<ClassRoom> _classes = [];
  UserAccount? _currentUser;
  String _resetEmailMessage = '';

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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'feelday',
      theme: theme,
      home: _currentUser == null
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
                  onJoinClass: _joinClass,
                  onLogout: _logout,
                  onUploadSchedule: _uploadSchedule,
                  onSubmitMood: _submitMood,
                  onSubmitJustificante: _submitJustificante,
                )
              : TeacherShell(
                  user: _currentUser!,
                  classes: _classes,
                  onCreateClass: _createClass,
                  onLogout: _logout,
                  onUpdateJustificante: _updateJustificanteStatus,
                ),
    );
  }

  void _handleLogin(String email, String password, BuildContext context) {
    final account = _accounts.where((a) => a.email == email).firstOrNull;
    if (account != null && account.password == password) {
      setState(() => _currentUser = account);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciales incorrectas')),
      );
    }
  }

  void _handleRegister({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required BuildContext context,
  }) {
    if (_accounts.any((a) => a.email == email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este correo ya está registrado')),
      );
      return;
    }
    final newAccount = UserAccount(
      email: email,
      password: password,
      role: role,
      displayName: name,
    );
    setState(() {
      _accounts.add(newAccount);
      _currentUser = newAccount;
    });
  }

  void _handleReset(String email, BuildContext context) {
    final exists = _accounts.any((a) => a.email == email);
    setState(() {
      _resetEmailMessage = exists
          ? 'Enviamos un enlace de recuperación a $email (simulado).'
          : 'No encontramos el correo $email.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_resetEmailMessage)),
    );
  }

  void _logout() => setState(() => _currentUser = null);

  void _createClass(String name) {
    if (_currentUser == null) return;
    final code = _generateCode();
    final cls = ClassRoom(
      id: UniqueKey().toString(),
      name: name,
      code: code,
      teacherEmail: _currentUser!.email,
    );
    setState(() {
      _classes.add(cls);
    });
  }

  void _joinClass(String code, BuildContext context) {
    if (_currentUser == null) return;
    final cls = _classes.where((c) => c.code == code).firstOrNull;
    if (cls == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No encontramos la clase con ese código')),
      );
      return;
    }
    if (!cls.studentEmails.contains(_currentUser!.email)) {
      setState(() => cls.studentEmails.add(_currentUser!.email));
    }
  }

  void _uploadSchedule(ClassRoom cls, String fileName) {
    if (_currentUser == null) return;
    setState(() {
      cls.schedules[_currentUser!.email] = ScheduleUpload(
        fileName: fileName,
        uploadedAt: DateTime.now(),
      );
    });
  }

  void _submitMood({
    required ClassRoom cls,
    required double mood,
    required String comment,
    required String day,
    required String scheduleFileName,
  }) {
    if (_currentUser == null) return;
    final entry = MoodEntry(
      studentEmail: _currentUser!.email,
      classId: cls.id,
      className: cls.name,
      teacherEmail: cls.teacherEmail,
      day: day,
      mood: mood,
      comment: comment,
      scheduleFileName: scheduleFileName,
      createdAt: DateTime.now(),
    );
    setState(() {
      cls.moodEntries.add(entry);
    });
  }

  void _submitJustificante({
    required ClassRoom cls,
    required String reason,
    required String imageLabel,
  }) {
    if (_currentUser == null) return;
    final justificante = Justificante(
      id: UniqueKey().toString(),
      studentEmail: _currentUser!.email,
      classId: cls.id,
      className: cls.name,
      reason: reason,
      imageLabel: imageLabel,
    );
    setState(() {
      cls.justificantes.add(justificante);
    });
  }

  void _updateJustificanteStatus(
    Justificante justificante,
    JustificanteStatus status,
  ) {
    setState(() {
      justificante.status = status;
    });
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
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

  final void Function(String email, String password, BuildContext context)
      onLogin;
  final void Function({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required BuildContext context,
  }) onRegister;
  final void Function(String email, BuildContext context) onReset;
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

  final void Function(String email, String password, BuildContext context)
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

  final void Function({
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

  final void Function(String email, BuildContext context) onReset;
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
    required this.onJoinClass,
    required this.onLogout,
    required this.onUploadSchedule,
    required this.onSubmitMood,
    required this.onSubmitJustificante,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
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
        onJoinClass: widget.onJoinClass,
        onUploadSchedule: widget.onUploadSchedule,
        onSubmitMood: widget.onSubmitMood,
      ),
      JustificantesPage(
        user: widget.user,
        classes: widget.classes,
        onSubmitJustificante: widget.onSubmitJustificante,
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
    required this.onJoinClass,
    required this.onUploadSchedule,
    required this.onSubmitMood,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final void Function(String code, BuildContext context) onJoinClass;
  final void Function(ClassRoom cls, String fileName) onUploadSchedule;
  final void Function({
    required ClassRoom cls,
    required double mood,
    required String comment,
    required String day,
    required String scheduleFileName,
  }) onSubmitMood;

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
    final joined = widget.classes
        .where((c) => c.studentEmails.contains(widget.user.email))
        .toList();
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
    final schedule = cls.schedules[widget.user.email];
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
            ...cls.moodEntries
                .where((m) => m.studentEmail == widget.user.email)
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
    required this.onSubmitJustificante,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final void Function({
    required ClassRoom cls,
    required String reason,
    required String imageLabel,
  }) onSubmitJustificante;

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
          const Text(
            'Justificantes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF073F50),
            ),
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
            ...selectedClass!.justificantes
                .where((j) => j.studentEmail == widget.user.email)
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
    required this.onCreateClass,
    required this.onLogout,
    required this.onUpdateJustificante,
  });

  final UserAccount user;
  final List<ClassRoom> classes;
  final void Function(String name) onCreateClass;
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
  final void Function(String name) onCreate;

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
                        widget.onCreate(nameCtrl.text.trim());
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
                subtitle: Text('Código: ${c.code}\nAlumnos: ${c.studentEmails.length}'),
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
    required this.onUpdateJustificante,
  });

  final List<ClassRoom> classes;
  final void Function(Justificante justificante, JustificanteStatus status)
      onUpdateJustificante;

  @override
  Widget build(BuildContext context) {
    final allMoodEntries = classes.expand((c) => c.moodEntries).toList();
    final allJustificantes = classes.expand((c) => c.justificantes).toList();

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

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
