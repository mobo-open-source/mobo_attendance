import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../CommonWidgets/core/company/providers/company_provider.dart';
import '../../../CommonWidgets/core/company/session/company_session_manager.dart';
import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../CommonWidgets/globals.dart';
import '../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../MainScreens/AppBars/infrastructure/profile_refresh_bus.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';

/// Full-screen page that allows viewing and (if permitted) editing of the current
/// user's profile information (res.partner / res.users related data).
///
/// Features:
///   • Displays personal info (name, email, phone, mobile, job title, etc.)
///   • Profile picture preview + upload (gallery or camera)
///   • Address editing in a popup dialog (street, state, country)
///   • Edit mode toggle (only visible to admins / users with permission)
///   • Loading shimmer + error state with retry
///   • Pull-to-refresh support
///
/// This screen is usually opened from a profile overview or settings menu.
class ProfileFormPage extends StatefulWidget {
  /// Optional callback to refresh the parent profile view after changes
  final Future<void> Function()? refreshProfile;

  const ProfileFormPage({super.key, this.refreshProfile});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  // ────────────────────────────────────────────────
  // Data & Controllers
  // ────────────────────────────────────────────────

  List<Profile> profiles = [];
  Uint8List? profileImageBytes;
  String? base64Image;
  File? _pickedImageFile;
  bool catchError = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyController = TextEditingController();
  final _mobileController = TextEditingController();
  final _websiteController = TextEditingController();
  final _jobTitleController = TextEditingController();
  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> countries = [];
  final _picker = ImagePicker();
  bool isEdited = false;
  final _street1Controller = TextEditingController();
  final _street2Controller = TextEditingController();
  int? selectedStateId;
  Map<String, dynamic>? selectedState;
  int? selectedCountryId;
  Map<String, dynamic>? selectedCountry;
  bool isLoading = true;
  bool isSaving = false;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    canManageSkills();
    loadProfile();
  }

  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Determines whether the current user has admin rights (base.group_system)
  /// Used to show/hide the Edit / Save / Cancel buttons.
  Future<void> canManageSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int userId = prefs.getInt('userId') ?? 0;
    final int majorVersion = parseMajorVersion(version);

    Future<bool> hasGroup(String groupExtId) async {
      if (majorVersion >= 18) {
        return await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': [userId, groupExtId],
              'kwargs': {},
            }) ==
            true;
      } else {
        return await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': [groupExtId],
              'kwargs': {},
            }) ==
            true;
      }
    }

    final admin = await hasGroup('base.group_system');

    setState(() {
      isAdmin = admin;
    });
  }

  /// Loads the current user's profile data + countries + states lists.
  /// Populates form fields and profile picture if available.
  Future<void> loadProfile() async {
    try {
      final profileService = ProfileService();
      await profileService.initializeClient();
      profiles = await profileService.loadProfile();

      countries = await profileService.fetchCountries();
      states = await profileService.fetchStates();

      if (!mounted) return;

      if (profiles.isNotEmpty) {
        final profile = profiles.first;
        _nameController.text = profile.name;
        _emailController.text = profile.mail;
        _phoneController.text = profile.phone;
        _addressController.text = profile.address;
        _companyController.text = profile.company;
        _mobileController.text = profile.mobile;
        _websiteController.text = profile.website;
        _jobTitleController.text = profile.jobTitle;
        _street1Controller.text = profile.street;
        _street2Controller.text = profile.street2;
        selectedState = {'id': profile.stateId, 'name': profile.state};

        selectedCountry = {'id': profile.countryId, 'name': profile.country};

        if (profile.image.isNotEmpty) {
          setState(() {
            profileImageBytes = base64Decode(profile.image);
          });
          base64Image = profile.image;
        }
      }

      if (!mounted) return;
      setState(() {
        isLoading = false;
        catchError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        catchError = true;
      });
    }
  }

  /// Opens gallery to pick a new profile picture and immediately uploads it.
  /// (Note: This method uploads instantly — different from full form save)
  Future<void> _pickImage() async {
    final profileService = ProfileService();
    await profileService.initializeClient();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        profileImageBytes = bytes;
        base64Image = base64String;
        isEdited = true;
      });
      await profileService.updateUserProfile({'image_1920': base64String});
    }
  }

  /// Saves the main editable profile fields (name, email, phone, mobile, image).
  /// Handles version-specific field names (mobile vs mobile_phone).
  Future<void> _saveProfile() async {
    setState(() {
      isSaving = true;
    });
    final prefs = await SharedPreferences.getInstance();
    int version = prefs.getInt('version') ?? 0;

    final profileService = ProfileService();
    await profileService.initializeClient();
    final updateData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'contact_address': _addressController.text.trim(),
      'image_1920': base64Image ?? _pickedImageFile ?? "",
      if (version < 18) 'mobile': _mobileController.text.trim(),
      if (version >= 18) 'mobile_phone': _mobileController.text.trim(),
    };

    final response = await profileService.updateUserProfile(updateData);

    setState(() {
      isEdited = false;
      isSaving = false;
    });

    if (response['success'] == true) {
      CustomSnackbar.showSuccess(context, 'Profile saved successfully');
    } else if (response['error'] != null) {
      CustomSnackbar.showError(
        context,
        'You do not have permission to update profile. Please contact your administrator.',
      );
    } else {
      CustomSnackbar.showError(context, 'Failed to save profile');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  bool isSvgBytes(Uint8List bytes) {
    final str = utf8.decode(bytes, allowMalformed: true);
    return str.contains('<svg');
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────
    // Main Scaffold & Layout
    // ────────────────────────────────────────────────
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        await widget.refreshProfile?.call();
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          title: tr(
            'Profile Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.refreshProfile != null) widget.refreshProfile!();
            },
          ),
          actions: [
            if (isAdmin) ...[
              if (!catchError) ...[
                if (isEdited == false)
                  TextButton(
                    onPressed: () {
                      setState(() => isEdited = true);
                    },
                    child: tr(
                      "Edit",
                      style: TextStyle(
                        color: theme.colorScheme.onBackground,
                        fontWeight: FontWeight.w500,
                        fontSize: 17,
                      ),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => isEdited = false);
                        },
                        child: tr(
                          "cancel",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: isEdited ? _saveProfile : null,
                        child: tr(
                          "Save",
                          style: TextStyle(
                            color: theme.colorScheme.onBackground,
                            fontWeight: FontWeight.w500,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              isLoading = true;
              catchError = false;
            });
            await context.read<CompanyProvider>().initialize();
            ProfileRefreshBus.notifyProfileRefresh();
            CompanyRefreshBus.notify();
            await loadProfile();
          },
          color: isDark ? Colors.white : AppStyle.primaryColor,
          child: isLoading
              ? _buildShimmerLoading()
              : catchError
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Center(
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.8,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset(
                            'assets/Error_404.json',
                            width: 300,
                            height: 300,
                            fit: BoxFit.contain,
                            repeat: true,
                            animate: true,
                          ),
                          tr(
                            'Something went wrong',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          tr(
                            'Pull to refresh or tap retry',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () async {
                              await context
                                  .read<CompanyProvider>()
                                  .initialize();
                              ProfileRefreshBus.notifyProfileRefresh();
                              CompanyRefreshBus.notify();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.grey[600]!
                                    : AppStyle.primaryColor.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: tr(
                              'Retry',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : AppStyle.primaryColor,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: isEdited ? _pickImage : null,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: AppStyle.primaryColor,
                                    child: ClipOval(
                                      child: SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: _pickedImageFile != null
                                            ? Image.file(
                                                _pickedImageFile!,
                                                fit: BoxFit.cover,
                                              )
                                            : profileImageBytes != null
                                            ? isSvgBytes(profileImageBytes!)
                                                  ? SvgPicture.memory(
                                                      profileImageBytes!,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Image.memory(
                                                      profileImageBytes!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => const Icon(
                                                            HugeIcons
                                                                .strokeRoundedUser,
                                                            size: 50,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                            : const Icon(
                                                HugeIcons.strokeRoundedUser,
                                                size: 50,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                  ),

                                  if (isEdited)
                                    Positioned(
                                      child: InkWell(
                                        onTap: _showImageSourceActionSheet,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppStyle.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.grey[900]!
                                                  : Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            HugeIcons.strokeRoundedCamera02,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          tr(
                            "Personal Information",
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoField(
                            Icons.person_outline,
                            "Full Name",
                            _nameController,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoField(
                            Icons.email_outlined,
                            "Email",
                            _emailController,
                          ),
                          const SizedBox(height: 8),

                          _buildInfoField(
                            Icons.phone_outlined,
                            "Phone",
                            _phoneController,
                          ),
                          const SizedBox(height: 8),

                          _buildInfoField(
                            Icons.phone_android_outlined,
                            "Mobile",
                            _mobileController,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoField(
                            Icons.language_outlined,
                            "Website",
                            _websiteController,
                            editable: false,
                          ),
                          const SizedBox(height: 8),

                          _buildInfoField(
                            Icons.work_outline,
                            "Job Title",
                            _jobTitleController,
                            editable: false,
                          ),
                          const SizedBox(height: 8),
                          _buildReadOnlyTextField(
                            Icons.apartment_outlined,
                            "Company",
                            _companyController,
                          ),
                          const SizedBox(height: 8),
                          _buildEditableDetailField(
                            Icons.home,
                            'Address',
                            _addressController,
                            onEdit: () => _showEditPopup(),
                          ),
                        ],
                      ),
                    ),
                    if (isSaving)
                      Positioned.fill(
                        child: Container(
                          child: Center(
                            child: LoadingAnimationWidget.fourRotatingDots(
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              size: 50,
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

  void _showImageSourceActionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedCamera02,
                      size: 24,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 16),
                    tr(
                      'Take Photo',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedImageCrop,
                      size: 24,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 16),
                    tr(
                      'Choose from Gallery',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Picks image from the chosen source and updates local state.
  /// Does **not** upload immediately (unlike `_pickImage()`).
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (picked == null || !mounted) return;

      setState(() => _pickedImageFile = File(picked.path));
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() => base64Image = base64Encode(bytes));

      if (mounted) {
        _showSuccessSnackBar('Image updated successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update image: $e');
      }
    }
  }

  void _showSuccessSnackBar(String msg) {
    CustomSnackbar.showSuccess(context, msg);
  }

  void _showErrorSnackBar(String msg) {
    CustomSnackbar.showError(context, msg);
  }

  /// Builds either editable TextFormField (edit mode) or read-only display row
  Widget _buildInfoField(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool editable = true,
  }) {
    final translationService = context.read<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = (controller.text.isEmpty)
        ? "Not set"
        : controller.text;

    if (isEdited && editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tr(
            label,
            style: TextStyle(
              fontFamily: TextStyle(fontWeight: FontWeight.w400).fontFamily,
              color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
              border: Border.all(color: Colors.transparent, width: 1),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: controller.text.isEmpty
                    ? translationService.getCached('Enter $label')
                    : null,
                hintStyle: TextStyle(
                  fontFamily: TextStyle(fontWeight: FontWeight.w600).fontFamily,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.0,
                ),
                prefixIcon: Icon(
                  icon,
                  color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.transparent,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tr(
            label,
            style: TextStyle(
              fontFamily: TextStyle(fontWeight: FontWeight.w400).fontFamily,
              color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
              border: Border.all(color: Colors.transparent, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayValue == 'Not set'
                        ? context.read<LanguageProvider>().getCached(
                                'Not set',
                              ) ??
                              'Not set'
                        : displayValue,
                    style: TextStyle(
                      fontSize: 15,
                      color: displayValue == 'Not set'
                          ? (isDark ? Colors.grey[500]! : Colors.grey[500]!)
                          : (isDark ? Colors.white70 : Colors.black),
                      fontWeight: displayValue == "Not set"
                          ? FontWeight.w400
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  /// Read-only field variant (used for company, website, job title)
  Widget _buildReadOnlyTextField(
    IconData icon,
    String label,
    TextEditingController controller,
  ) {
    final displayValue = (controller.text.isEmpty)
        ? "Not set"
        : controller.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tr(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
            border: Border.all(color: Colors.transparent, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayValue == 'Not set'
                              ? context.read<LanguageProvider>().getCached(
                                      'Not set',
                                    ) ??
                                    'Not set'
                              : displayValue,
                          style: TextStyle(
                            fontSize: 15,
                            color: displayValue == 'Not set'
                                ? (isDark
                                      ? Colors.grey[500]!
                                      : Colors.grey[500]!)
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xff000000)),
                            fontWeight: displayValue == "Not set"
                                ? FontWeight.w400
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Special tappable field for address that opens detailed popup
  Widget _buildEditableDetailField(
    IconData icon,
    String label,
    TextEditingController controller, {
    required VoidCallback onEdit,
  }) {
    final value = controller.text.isNotEmpty
        ? controller.text
        : 'Tap to add $label';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tr(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
              border: Border.all(color: Colors.transparent, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        color: controller.text.isNotEmpty
                            ? (isDark ? Colors.white70 : Colors.black)
                            : Colors.grey,
                        fontWeight: controller.text.isNotEmpty
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit,
                    size: 18,
                    color: isDark ? Colors.white70 : AppStyle.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens dialog to edit detailed address fields (street1, street2, state, country)
  Future<void> _showEditPopup() async {
    final translationService = context.read<LanguageProvider>();

    await showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        bool isCountryDropdownOpen = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  tr(
                    'Edit Address Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              content: Stack(
                children: [
                  Container(
                    height:
                        MediaQuery.of(context).size.height *
                        (isCountryDropdownOpen ? 0.60 : 0.42),
                    width: MediaQuery.of(context).size.width * 0.95,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          tr(
                            'Street 1',
                            style: TextStyle(
                              fontFamily: TextStyle(
                                fontWeight: FontWeight.w400,
                              ).fontFamily,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xff7F7F7F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xffF8FAFB),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: TextField(
                              controller: _street1Controller,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText: translationService.getCached(
                                  'Enter Street 1',
                                ),
                                hintStyle: TextStyle(
                                  fontFamily: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ).fontFamily,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                  height: 1.0,
                                ),
                                prefixIcon: Icon(
                                  HugeIcons.strokeRoundedNavigator01,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xff7F7F7F),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white
                                        : AppStyle.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          tr(
                            'Street 2',
                            style: TextStyle(
                              fontFamily: TextStyle(
                                fontWeight: FontWeight.w400,
                              ).fontFamily,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xff7F7F7F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xffF8FAFB),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: TextField(
                              controller: _street2Controller,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText: translationService.getCached(
                                  'Enter Street 2',
                                ),
                                hintStyle: TextStyle(
                                  fontFamily: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ).fontFamily,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                  height: 1.0,
                                ),
                                prefixIcon: Icon(
                                  HugeIcons.strokeRoundedNavigator01,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xff7F7F7F),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white
                                        : AppStyle.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          tr(
                            'State',
                            style: TextStyle(
                              fontFamily: TextStyle(
                                fontWeight: FontWeight.w400,
                              ).fontFamily,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xff7F7F7F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xffF8FAFB),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: DropdownSearch<Map<String, dynamic>>(
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                menuProps: MenuProps(
                                  backgroundColor: isDark
                                      ? Colors.black
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  elevation: 4,
                                ),
                                searchFieldProps: TextFieldProps(
                                  style: TextStyle(fontWeight: FontWeight.w400),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    labelText: "Search State",
                                    labelStyle: TextStyle(
                                      fontFamily: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ).fontFamily,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                      fontSize: 14,
                                      height: 1.0,
                                    ),
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              items: states,
                              itemAsString: (item) => item['name'] ?? '',
                              selectedItem: selectedState,
                              onChanged: (value) {
                                setState(() {
                                  selectedState = value;
                                  selectedStateId = value?['id'];
                                });
                              },
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  hintText: translationService.getCached(
                                    'Select State',
                                  ),
                                  hintStyle: TextStyle(
                                    fontFamily: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ).fontFamily,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                    height: 1.0,
                                  ),
                                  prefixIcon: Icon(
                                    HugeIcons.strokeRoundedRoadLocation01,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          tr(
                            'Country',
                            style: TextStyle(
                              fontFamily: TextStyle(
                                fontWeight: FontWeight.w400,
                              ).fontFamily,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xff7F7F7F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xffF8FAFB),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: DropdownSearch<Map<String, dynamic>>(
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                onDismissed: () {
                                  setDialogState(
                                    () => isCountryDropdownOpen = false,
                                  );
                                },
                                menuProps: MenuProps(
                                  backgroundColor: isDark
                                      ? Colors.grey[900]
                                      : Colors.grey[50],
                                  elevation: 12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                searchFieldProps: TextFieldProps(
                                  style: TextStyle(
                                    fontFamily: TextStyle(
                                      fontWeight: FontWeight.w400,
                                    ).fontFamily,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    labelText: "Search Country",
                                    labelStyle: TextStyle(
                                      fontFamily: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ).fontFamily,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                      fontSize: 14,
                                      height: 1.0,
                                    ),
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              onBeforePopupOpening: (selectedState) async {
                                setDialogState(
                                  () => isCountryDropdownOpen = true,
                                );
                                return true;
                              },
                              items: countries,
                              itemAsString: (item) => item['name'] ?? '',
                              selectedItem: selectedCountry,
                              onChanged: (value) {
                                setState(() {
                                  selectedCountry = value;
                                  selectedCountryId = value?['id'];
                                });
                              },
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  hintText: translationService.getCached(
                                    'Select Country',
                                  ),
                                  hintStyle: TextStyle(
                                    fontFamily: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ).fontFamily,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                    height: 1.0,
                                  ),
                                  prefixIcon: Icon(
                                    HugeIcons.strokeRoundedFlag02,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSaving)
                    Positioned.fill(
                      child: Center(
                        child: LoadingAnimationWidget.fourRotatingDots(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          size: 50,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.white,
                          side: BorderSide(
                            color: isDark ? Colors.white : Color(0xFFBB2649),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: tr(
                          "CANCEL",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          setDialogState(() {
                            isSaving = true;
                          });
                          final profileService = ProfileService();
                          await profileService.initializeClient();
                          final updateData = {
                            'street': _street1Controller.text,
                            'street2': _street2Controller.text,
                            'state_id': selectedStateId,
                            'country_id': selectedCountryId,
                          };
                          final result = await profileService.updateUserAddress(
                            updateData,
                          );
                          if (result['success'] == true) {
                            profiles = await profileService.loadProfile();
                            final profile = profiles.first;

                            setState(() {
                              _nameController.text = profile.name;
                              _emailController.text = profile.mail;
                              _phoneController.text = profile.phone;
                              _addressController.text = profile.address;
                              _companyController.text = profile.company;
                              _street1Controller.text = profile.street;
                              _street2Controller.text = profile.street2;
                              selectedState = {
                                'id': profile.stateId,
                                'name': profile.state,
                              };

                              selectedCountry = {
                                'id': profile.countryId,
                                'name': profile.country,
                              };
                              isEdited = true;
                            });
                            setDialogState(() {
                              isSaving = false;
                            });
                            CustomSnackbar.showSuccess(
                              context,
                              'Address updated successfully',
                            );
                          } else if (result['error'] != null) {
                            CustomSnackbar.showError(
                              context,
                              'You do not have permission to update profile. Please contact your administrator.',
                            );
                          } else {
                            setDialogState(() {
                              isSaving = false;
                            });
                            final errorMsg = 'Failed to update address';
                            CustomSnackbar.showError(context, errorMsg);
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white
                              : AppStyle.primaryColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: tr(
                          'SAVE',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shimmer loading UI shown while data is being fetched
  Widget _buildShimmerLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _shimmerBox(height: 50),
          const SizedBox(height: 12),
          _shimmerBox(height: 80),
          const SizedBox(height: 12),
          _shimmerBox(height: 50),
          const SizedBox(height: 12),
          _shimmerBox(height: 50),
          const SizedBox(height: 12),
          _shimmerBox(height: 50),
        ],
      ),
    );
  }

  Widget _shimmerBox({double height = 50}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
