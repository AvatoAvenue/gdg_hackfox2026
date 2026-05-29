import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../shared/widgets/app_logo.dart';
import 'auth_error.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  bool _obscure = true;

  FirebaseService get _firebase => context.read<FirebaseService>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authErrorMessage(error)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _runAuth(Future<dynamic> Function() action) async {
    setState(() => _loading = true);
    try {
      final result = await action();
      if (result == null && mounted) {
        setState(() => _loading = false);
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError(e);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text;
    final password = _passwordController.text;
    await _runAuth(() {
      if (_isSignUp) {
        return _firebase.signUpWithEmail(
          email: email,
          password: password,
          displayName: _nameController.text,
        );
      }
      return _firebase.signInWithEmail(email: email, password: password);
    });
  }

  Future<void> _signInWithGoogle() => _runAuth(_firebase.signInWithGoogle);

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe tu correo primero.')),
      );
      return;
    }
    try {
      await _firebase.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correo de restablecimiento enviado.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkDeep,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 700) {
            return _buildWideLayout(context);
          }
          return _buildNarrowLayout(context);
        },
      ),
    );
  }

  // ── Wide layout: left gradient hero  |  right form panel ─────────────────
  Widget _buildWideLayout(BuildContext context) {
    final tagline = _isSignUp
        ? 'Únete para mapear barreras y ayudar\na tu comunidad a moverse con libertad.'
        : 'Accede a rutas accesibles y reporte\nciudadano de barreras en tu ciudad.';

    return Row(
      children: [
        // ── Left: gradient hero panel ────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1B2A), Color(0xFF1C7269)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(56),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLogo(size: 96),
                    const SizedBox(height: 32),
                    Text(
                      'Senda',
                      style: GoogleFonts.lexend(
                        fontSize: 68,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -2.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'MOBILITY FOR ALL',
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPassive,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      tagline,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.surfaceNeutral,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Feature pills
                    const Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Pill(icon: Icons.accessible_forward, label: 'Rutas accesibles'),
                        _Pill(icon: Icons.warning_rounded, label: 'Reporte ciudadano'),
                        _Pill(icon: Icons.sos, label: 'Alertas SOS'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ── Right: form panel ────────────────────────────────────────────────
        SizedBox(
          width: 480,
          child: Container(
            color: AppColors.darkDeep,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(48, 40, 48, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white70, size: 20),
                        tooltip: 'Volver',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isSignUp ? 'Crea tu cuenta' : 'Bienvenido',
                      style: GoogleFonts.lexend(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignUp
                          ? 'Completa tus datos para comenzar.'
                          : 'Nos alegra verte de nuevo en Senda.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.surfacePositive.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildGoogleButton(),
                    const SizedBox(height: 20),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildForm(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 16),
                    _buildToggle(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow layout: stacked gradient + form card (mobile) ─────────────────
  Widget _buildNarrowLayout(BuildContext context) {
    final tagline = _isSignUp
        ? 'Únete para mapear barreras y ayudar\na tu comunidad.'
        : 'Accede a rutas accesibles y reporte\nbarreras en tu ciudad.';

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1B2A), Color(0xFF1C7269)],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(height: 12),
                      const AppLogo(size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Senda',
                        style: GoogleFonts.lexend(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MOBILITY FOR ALL',
                        style: GoogleFonts.lexend(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPassive,
                          letterSpacing: 3.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tagline,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkDeep,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    border: Border(
                      top: BorderSide(
                          color:
                              AppColors.brandPassive.withValues(alpha: 0.20)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.40),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isSignUp ? 'Crea tu cuenta' : 'Bienvenido',
                        style: GoogleFonts.lexend(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isSignUp
                            ? 'Completa tus datos para comenzar.'
                            : 'Nos alegra verte de nuevo en Senda.',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              AppColors.surfacePositive.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildGoogleButton(),
                      const SizedBox(height: 16),
                      _buildDivider(),
                      const SizedBox(height: 16),
                      _buildForm(),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                      const SizedBox(height: 16),
                      _buildToggle(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Shared form widgets
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildGoogleButton() {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _signInWithGoogle,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: AppColors.darkMid,
        side: BorderSide(color: AppColors.brandPassive.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: Colors.white,
      ),
      icon: const Icon(Icons.g_mobiledata, size: 30, color: AppColors.brandActive),
      label: const Text(
        'Continuar con Google',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.brandPassive.withValues(alpha: 0.20)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'o continúa con correo',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.surfacePositive.withValues(alpha: 0.45),
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppColors.brandPassive.withValues(alpha: 0.20)),
        ),
      ],
    );
  }

  Widget _buildForm() {
    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.brandPassive, width: 0.8),
    );
    const focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.brandActive, width: 2),
    );
    const errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.error, width: 1.5),
    );

    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_isSignUp) ...[
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.surfacePositive),
              decoration: const InputDecoration(
                labelText: 'Nombre',
                labelStyle: TextStyle(color: Colors.white60),
                prefixIcon:
                    Icon(Icons.person_outline, color: AppColors.brandPassive),
                filled: true,
                fillColor: AppColors.darkMid,
                border: fieldBorder,
                focusedBorder: focusedBorder,
                enabledBorder: fieldBorder,
                errorBorder: errorBorder,
                focusedErrorBorder: errorBorder,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: AppColors.surfacePositive),
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              labelStyle: TextStyle(color: Colors.white60),
              prefixIcon:
                  Icon(Icons.mail_outline, color: AppColors.brandPassive),
              filled: true,
              fillColor: AppColors.darkMid,
              border: fieldBorder,
              focusedBorder: focusedBorder,
              enabledBorder: fieldBorder,
              errorBorder: errorBorder,
              focusedErrorBorder: errorBorder,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Escribe tu correo';
              if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            style: const TextStyle(color: AppColors.surfacePositive),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              labelStyle: const TextStyle(color: Colors.white60),
              prefixIcon:
                  const Icon(Icons.lock_outline, color: AppColors.brandPassive),
              filled: true,
              fillColor: AppColors.darkMid,
              border: fieldBorder,
              focusedBorder: focusedBorder,
              enabledBorder: fieldBorder,
              errorBorder: errorBorder,
              focusedErrorBorder: errorBorder,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.brandPassive,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Escribe tu contraseña';
              if (v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          if (!_isSignUp)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _resetPassword,
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.brandPassive),
                child: const Text('¿Olvidaste tu contraseña?',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _loading ? null : _submitEmail,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandActive,
        foregroundColor: AppColors.darkDeep,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
      child: _loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(_isSignUp ? 'Crear cuenta' : 'Entrar'),
    );
  }

  Widget _buildToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.surfacePositive.withValues(alpha: 0.55),
          ),
        ),
        TextButton(
          onPressed: _loading ? null : () => setState(() => _isSignUp = !_isSignUp),
          style: TextButton.styleFrom(foregroundColor: AppColors.brandPassive),
          child: Text(
            _isSignUp ? 'Inicia sesión' : 'Regístrate',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature pill (wide layout only)
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.surfaceNeutral, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.surfaceNeutral, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
