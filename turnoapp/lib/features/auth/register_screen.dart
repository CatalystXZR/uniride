/**
 *
 * Project: TurnoApp
 *
 * Original Concept: Agustín Puelma, Cristobal Cordova, Carlos Ibarra
 *
 * Software Architecture & Code: Matías Toledo (catalystxzr)
 *
 * Description: Production-grade implementation for UDD carpooling system.
 *
 * Copyright (c) 2026. All rights reserved.
 *
 */

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase_client.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading_overlay.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  // Universities loaded from DB so we work with real UUIDs
  List<Map<String, dynamic>> _universities = [];
  String? _selectedUniversityId;
  bool _loadingUniversities = true;
  String? _universitiesError;

  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUniversities();
  }

  Future<void> _loadUniversities() async {
    if (mounted) {
      setState(() {
        _loadingUniversities = true;
        _universitiesError = null;
      });
    }
    try {
      final rows = await SupabaseConfig.client
          .from('universities')
          .select('id, name')
          .order('name');
      if (mounted) {
        setState(() {
          _universities = List<Map<String, dynamic>>.from(rows);
          _loadingUniversities = false;
        });
      }
    } catch (e) {
      debugPrint('[RegisterScreen] _loadUniversities error: $e');
      if (mounted) {
        setState(() {
          _loadingUniversities = false;
          _universitiesError = 'No se pudo cargar la lista de universidades';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );
      // After sign-up: upsert profile row with university_id
      final uid = SupabaseConfig.client.auth.currentUser?.id;
      if (uid != null) {
        await SupabaseConfig.client.from('users_profile').upsert({
          'id': uid,
          'full_name': _nameController.text.trim(),
          if (_selectedUniversityId != null)
            'university_id': _selectedUniversityId,
        });
        await SupabaseConfig.client.from('wallets').upsert({
          'user_id': uid,
          'balance_available': 0,
          'balance_held': 0,
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Crear cuenta')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    validator: (v) =>
                        v != null && v.trim().length > 2 ? null : 'Requerido',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo universitario',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        v != null && v.contains('@') ? null : 'Correo inválido',
                  ),
                  const SizedBox(height: 16),
                  _loadingUniversities
                      ? const Center(child: CircularProgressIndicator())
                      : _universitiesError != null
                          ? Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _universitiesError!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadUniversities,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            )
                          : DropdownButtonFormField<String>(
                          value: _selectedUniversityId,
                          decoration: const InputDecoration(
                            labelText: 'Universidad',
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                          items: _universities
                              .map((u) => DropdownMenuItem<String>(
                                    value: u['id'] as String,
                                    child: Text(u['name'] as String),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedUniversityId = v),
                          validator: (v) =>
                              v != null ? null : 'Selecciona tu universidad',
                        ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        v != null && v.length >= 6 ? null : 'Mínimo 6 caracteres',
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Crear cuenta'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
