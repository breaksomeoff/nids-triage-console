import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_scope.dart';
import '../format.dart';
import '../widgets/common.dart';
import 'company_home_screen.dart';
import 'register_screen.dart';

/// Company login (R2). On success it replaces itself with the reserved area.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _autovalidate = AutovalidateMode.disabled;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const RegisterScreen()));
    if (email == null || !mounted) return;
    setState(() {
      _email.text = email;
      _password.clear();
      _error = null;
    });
    showMessage(
      context,
      'Account creato. Ora accedi con email e password.',
      icon: Icons.check_circle,
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).session
          .login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const CompanyHomeScreen()),
      );
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Area aziende')),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HeaderCard(
                icon: Icons.business,
                label: 'Sei un\'azienda?',
                title: 'Accedi',
                subtitle: 'Pubblica annunci e leggi le candidature ricevute.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Mostra password' : 'Nascondi password',
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    validateRequired(v, 'La password è obbligatoria'),
              ),
              FormErrorText(_error),
              const SizedBox(height: 24),
              BusyButton(
                label: 'Accedi',
                icon: Icons.login,
                busy: _busy,
                onPressed: _login,
              ),
              const SizedBox(height: 32),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Non hai un account?'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy ? null : _register,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Registra la tua azienda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
