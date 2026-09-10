import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/auth_error_message.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
    final error = ref.read(authControllerProvider).asError;
    if (error != null && mounted) {
      showErrorSnackBar(
        context,
        authErrorMessage(error.error),
        error: error.error,
      );
    }
  }

  Future<void> _resetPassword() async {
    final controller =
        TextEditingController(text: _emailController.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Ton adresse email'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (email == null || !mounted) return;
    if (!email.contains('@')) {
      showErrorSnackBar(context, "L'adresse email n'est pas valide.");
      return;
    }

    await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
    if (!mounted) return;

    final error = ref.read(authControllerProvider).asError;
    if (error != null) {
      showErrorSnackBar(context, authErrorMessage(error.error),
          error: error.error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      // Formulé sans confirmer l'existence du compte : Firebase protège
      // contre l'énumération des adresses, autant ne pas la trahir ici.
      const SnackBar(
        content: Text(
          "Si un compte existe pour cette adresse, l'email de "
          'réinitialisation vient de partir.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.favorite, size: 56, color: Colors.pink),
                const SizedBox(height: 12),
                Text(
                  'Bon retour',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => (value == null || !value.contains('@'))
                      ? 'Email invalide'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  validator: (value) => (value == null || value.length < 6)
                      ? '6 caractères minimum'
                      : null,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Se connecter',
                  isLoading: authState.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: authState.isLoading ? null : _resetPassword,
                  child: const Text('Mot de passe oublié ?'),
                ),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Pas encore de compte ? Inscris-toi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
