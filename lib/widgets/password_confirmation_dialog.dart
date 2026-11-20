import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Reusable password confirmation gate.
/// Prompts the operator for their password before executing sensitive actions
/// like Adding, Editing, or Deleting a Party.
Future<bool> promptPasswordConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = 'Confirm',
  IconData icon = Icons.security,
  Color iconColor = AppColors.primary,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PasswordConfirmationDialog(
      title: title,
      message: message,
      actionLabel: actionLabel,
      icon: icon,
      iconColor: iconColor,
    ),
  );
  return result ?? false;
}

class _PasswordConfirmationDialog extends StatefulWidget {
  final String title;
  final String message;
  final String actionLabel;
  final IconData icon;
  final Color iconColor;

  const _PasswordConfirmationDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.icon,
    required this.iconColor,
  });

  @override
  State<_PasswordConfirmationDialog> createState() => _PasswordConfirmationDialogState();
}

class _PasswordConfirmationDialogState extends State<_PasswordConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscureText = true;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    final auth = context.read<AuthProvider>();
    final entered = _controller.text;

    if (entered.trim().isEmpty) {
      setState(() {
        _errorText = 'Please enter password to continue.';
      });
      return;
    }

    if (auth.verifyPassword(entered)) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorText = 'Incorrect password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              obscureText: _obscureText,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verify(),
              decoration: InputDecoration(
                labelText: 'Enter Master / Operator Password *',
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                errorText: _errorText,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.iconColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _verify,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

