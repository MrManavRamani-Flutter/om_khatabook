import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';

class BrandingDialogs {
  /// Picks an image file natively from macOS or Windows and returns its Base64 string.
  static Future<String?> pickImageAsBase64() async {
    try {
      String? filePath;
      if (Platform.isMacOS) {
        final res = await Process.run('osascript', [
          '-e',
          'POSIX path of (choose file of type {"png", "jpg", "jpeg", "webp"} with prompt "Select Logo Image File")',
        ]);
        if (res.exitCode == 0) {
          filePath = res.stdout.toString().trim();
        }
      } else if (Platform.isWindows) {
        const script = '''
Add-Type -AssemblyName System.Windows.Forms
\$f = New-Object System.Windows.Forms.OpenFileDialog
\$f.Filter = "Image Files (*.png;*.jpg;*.jpeg;*.webp)|*.png;*.jpg;*.jpeg;*.webp"
if (\$f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output \$f.FileName
}
''';
        final res = await Process.run('powershell', ['-NoProfile', '-Command', script]);
        if (res.exitCode == 0) {
          filePath = res.stdout.toString().trim();
        }
      }

      if (filePath != null && filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return base64Encode(bytes);
        }
      }
    } catch (e) {
      debugPrint('Native image file picker error: $e');
    }
    return null;
  }

  /// Dialog to edit App Logo, Company Name, and Company Tagline
  static Future<void> showAppBrandingDialog(BuildContext context) async {
    final provider = context.read<ChallanProvider>();
    final nameController = TextEditingController(text: provider.companyName);
    final taglineController = TextEditingController(text: provider.companyTagline);
    final manualPathController = TextEditingController();
    String currentBase64 = provider.appLogoBase64;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.business_center, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Customize App Logo & Branding'),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Changes will update the sidebar, printed invoices, and will be preserved in backup files.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 18),

                    // LOGO PREVIEW & UPLOAD ROW
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: currentBase64.isNotEmpty
                                  ? Image.memory(
                                      base64Decode(currentBase64),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Image.asset(
                                        'assets/logo/app_logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/logo/app_logo.png',
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.file_upload_outlined, size: 18),
                                label: const Text('Choose Image File...'),
                                onPressed: () async {
                                  final base64 = await pickImageAsBase64();
                                  if (base64 != null) {
                                    setDialogState(() {
                                      currentBase64 = base64;
                                    });
                                  }
                                },
                              ),
                              if (currentBase64.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.restore, size: 16),
                                  label: const Text('Reset Default'),
                                  onPressed: () {
                                    setDialogState(() {
                                      currentBase64 = '';
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OPTIONAL MANUAL FILE PATH INPUT
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: manualPathController,
                            decoration: const InputDecoration(
                              labelText: 'Or Image File Path / URL',
                              hintText: '/path/to/my_logo.png',
                              isDense: true,
                              prefixIcon: Icon(Icons.image_search, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final p = manualPathController.text.trim();
                            if (p.isNotEmpty) {
                              try {
                                final file = File(p);
                                if (await file.exists()) {
                                  final bytes = await file.readAsBytes();
                                  setDialogState(() {
                                    currentBase64 = base64Encode(bytes);
                                  });
                                }
                              } catch (e) {
                                debugPrint('Manual file read failed: $e');
                              }
                            }
                          },
                          child: const Text('Load'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // COMPANY NAME
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Company / Business Name *',
                        prefixIcon: Icon(Icons.business, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // COMPANY TAGLINE
                    TextField(
                      controller: taglineController,
                      decoration: const InputDecoration(
                        labelText: 'Tagline / App Subtitle',
                        prefixIcon: Icon(Icons.subtitles_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.person, size: 16),
                label: const Text('Edit Admin Profile'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  showProfileDialog(context);
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  final tagline = taglineController.text.trim();
                  if (name.isNotEmpty) {
                    provider.setCompanyBranding(
                      name: name,
                      tagline: tagline.isNotEmpty ? tagline : 'Khata Book Desktop',
                    );
                    provider.setAppLogoBase64(currentBase64);
                  }
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('App logo and branding updated successfully!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                child: const Text('Save Branding'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog to edit Profile Avatar, Admin Name, and Role
  static Future<void> showProfileDialog(BuildContext context) async {
    final provider = context.read<ChallanProvider>();
    final nameController = TextEditingController(text: provider.adminName);
    final roleController = TextEditingController(text: provider.adminRole);
    final manualPathController = TextEditingController();
    String currentBase64 = provider.profileLogoBase64;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Customize Admin Profile & Avatar'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customize your user profile displayed at the bottom of the navigation sidebar.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 18),

                    // AVATAR PREVIEW & UPLOAD ROW
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            backgroundImage: currentBase64.isNotEmpty
                                ? MemoryImage(base64Decode(currentBase64))
                                : null,
                            child: currentBase64.isEmpty
                                ? Text(
                                    provider.adminName.isNotEmpty
                                        ? provider.adminName[0].toUpperCase()
                                        : 'O',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.file_upload_outlined, size: 18),
                                label: const Text('Choose Photo...'),
                                onPressed: () async {
                                  final base64 = await pickImageAsBase64();
                                  if (base64 != null) {
                                    setDialogState(() {
                                      currentBase64 = base64;
                                    });
                                  }
                                },
                              ),
                              if (currentBase64.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.restore, size: 16),
                                  label: const Text('Reset Initial'),
                                  onPressed: () {
                                    setDialogState(() {
                                      currentBase64 = '';
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OPTIONAL MANUAL FILE PATH INPUT
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: manualPathController,
                            decoration: const InputDecoration(
                              labelText: 'Or Photo File Path / URL',
                              hintText: '/path/to/my_photo.jpg',
                              isDense: true,
                              prefixIcon: Icon(Icons.image_search, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final p = manualPathController.text.trim();
                            if (p.isNotEmpty) {
                              try {
                                final file = File(p);
                                if (await file.exists()) {
                                  final bytes = await file.readAsBytes();
                                  setDialogState(() {
                                    currentBase64 = base64Encode(bytes);
                                  });
                                }
                              } catch (e) {
                                debugPrint('Manual file read failed: $e');
                              }
                            }
                          },
                          child: const Text('Load'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // ADMIN NAME
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Admin / User Name *',
                        prefixIcon: Icon(Icons.badge_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ADMIN ROLE
                    TextField(
                      controller: roleController,
                      decoration: const InputDecoration(
                        labelText: 'Role / Designation',
                        prefixIcon: Icon(Icons.shield_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.business_center, size: 16),
                label: const Text('Edit App Logo'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  showAppBrandingDialog(context);
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  final role = roleController.text.trim();
                  if (name.isNotEmpty) {
                    provider.setAdminProfile(
                      name: name,
                      role: role.isNotEmpty ? role : 'Administrator',
                    );
                    provider.setProfileLogoBase64(currentBase64);
                  }
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Admin profile and avatar updated successfully!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                child: const Text('Save Profile'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A reactive App Logo widget that always displays the up-to-date custom or default app logo across the entire app.
class AppLogoWidget extends StatelessWidget {
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const AppLogoWidget({
    super.key,
    this.size = 44,
    this.borderRadius = 12,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final logoBase64 = provider.appLogoBase64;

    Widget imageWidget;
    if (logoBase64.isNotEmpty) {
      try {
        imageWidget = Image.memory(
          base64Decode(logoBase64),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/logo/app_logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        imageWidget = Image.asset(
          'assets/logo/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }
    } else {
      imageWidget = Image.asset(
        'assets/logo/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    Widget content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      ),
    );

    if (showEditBadge) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1),
              ),
              child: const Icon(Icons.edit, size: 9, color: AppColors.primary),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }
    return content;
  }
}

/// A reactive Profile Avatar widget that always displays the up-to-date custom photo or initials across the entire app.
class ProfileAvatarWidget extends StatelessWidget {
  final double radius;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const ProfileAvatarWidget({
    super.key,
    this.radius = 17,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final profileBase64 = provider.profileLogoBase64;
    final initial = provider.adminName.isNotEmpty ? provider.adminName[0].toUpperCase() : 'O';

    Widget avatarWidget = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      foregroundColor: AppColors.primary,
      backgroundImage: profileBase64.isNotEmpty ? MemoryImage(base64Decode(profileBase64)) : null,
      child: profileBase64.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );

    if (showEditBadge) {
      avatarWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            bottom: -1,
            right: -1,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 0.8),
              ),
              child: const Icon(Icons.edit, size: 7, color: AppColors.primary),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: avatarWidget,
      );
    }
    return avatarWidget;
  }
}
