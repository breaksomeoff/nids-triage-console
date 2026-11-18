import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_scope.dart';
import '../format.dart';
import '../widgets/common.dart';

/// Company registration (R1). Pops with the email of the new account.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _autovalidate = AutovalidateMode.disabled;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final company = await AppScope.of(context).api.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pop(company.email);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibility = IconButton(
      tooltip: _obscure ? 'Mostra password' : 'Nascondi password',
      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Registrazione')),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HeaderCard(
                icon: Icons.add_business_outlined,
                label: 'Nuovo account',
                title: 'La tua azienda',
                subtitle: 'Bastano nome, email e una password.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.organizationName],
                decoration: const InputDecoration(
                  labelText: 'Nome azienda',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) =>
                    validateRequired(v, 'Il nome dell\'azienda è obbligatorio'),
              ),
              const SizedBox(height: 12),
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
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'Almeno 8 caratteri',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: visibility,
                ),
                validator: (v) => (v == null || v.length < 8)
                    ? 'La password deve avere almeno 8 caratteri'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Conferma password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) =>
                    v != _password.text ? 'Le password non coincidono' : null,
              ),
              FormErrorText(_error),
              const SizedBox(height: 24),
              BusyButton(
                label: 'Crea account',
                icon: Icons.check,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
