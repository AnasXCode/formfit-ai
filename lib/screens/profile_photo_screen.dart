import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/primary_button.dart';
import '../widgets/user_avatar.dart';

/// Hero tag shared by the small avatar on the Profile screen and the big photo
/// here, so the picture grows smoothly when opened.
const String kProfileAvatarHeroTag = 'profile-avatar';

/// Photos are shrunk to this size before saving. It keeps each one around
/// 30-60 KB, so it can live directly in the user's Firestore document.
const double _kMaxPhotoSide = 512;
const int _kPhotoQuality = 75;
const int _kMaxPhotoBytes = 300 * 1024;

class ProfilePhotoScreen extends ConsumerStatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  ConsumerState<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends ConsumerState<ProfilePhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _changePhoto() async {
    if (_busy) return;
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);

    // Step 1: open the gallery.
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _kMaxPhotoSide,
        maxHeight: _kMaxPhotoSide,
        imageQuality: _kPhotoQuality,
      );
    } catch (error) {
      debugPrint('Gallery failed: $error');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is MissingPluginException
                ? 'Gallery is not ready yet. Stop the app completely and run it '
                'again (a hot reload is not enough after adding a plugin).'
                : 'Couldn’t open the gallery: ${_short(error)}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    if (picked == null) return; // the user closed the gallery

    // Step 2: save it.
    if (mounted) setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.length > _kMaxPhotoBytes) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('That photo is too large. Pick another one.'),
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'customPhotoBase64': base64Encode(bytes),
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } on FirebaseException catch (error) {
      debugPrint('Saving photo failed: ${error.code} ${error.message}');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Firestore rules do not allow saving the photo '
                '(permission-denied).'
                : 'Couldn’t save your photo (${error.code}).',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      debugPrint('Saving photo failed: $error');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Couldn’t save your photo: ${_short(error)}'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _short(Object error) {
    final text = error.toString();
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  Future<void> _removePhoto() async {
    if (_busy) return;
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'customPhotoBase64': FieldValue.delete(),
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile photo removed')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn’t remove your photo. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final authUser = ref.watch(authProvider);
    final isGuest = authUser?.isAnonymous ?? true;

    final customBytes = UserAvatar.decodePhoto(profile?.customPhotoBase64);
    final googleUrl = profile?.photoUrl?.trim();
    final hasGoogle = googleUrl != null && googleUrl.isNotEmpty;

    final name = profile?.effectiveDisplayName ??
        (isGuest ? 'Guest Athlete' : (authUser?.displayName ?? 'Athlete'));
    final initials = profile?.initials ??
        (isGuest ? 'G' : (name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase()));

    Widget photo;
    if (customBytes != null) {
      photo = Image.memory(
        customBytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    } else if (hasGoogle) {
      photo = Image.network(
        _largerGooglePhoto(googleUrl),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => UserAvatar(
          radius: 110,
          fontSize: 72,
          initials: initials,
          avatarColorHex: profile?.avatarColor,
        ),
      );
    } else {
      photo = UserAvatar(
        radius: 110,
        fontSize: 72,
        initials: initials,
        avatarColorHex: profile?.avatarColor,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile photo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Hero(
                  tag: kProfileAvatarHeroTag,
                  // Pinch to zoom.
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: photo,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: CircularProgressIndicator(color: Colors.white70),
                    ),
                  PrimaryButton(
                    label: 'Choose from gallery',
                    icon: Icons.photo_library_outlined,
                    onPressed: _busy ? null : _changePhoto,
                  ),
                  if (customBytes != null) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _busy ? null : _removePhoto,
                      child: const Text('Remove photo'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google account photos usually end in "=s96-c" (96 px). Ask for a bigger one
/// so it stays sharp when shown full screen.
String _largerGooglePhoto(String url) {
  return url.replaceFirst(RegExp(r'=s\d+-c'), '=s600-c');
}